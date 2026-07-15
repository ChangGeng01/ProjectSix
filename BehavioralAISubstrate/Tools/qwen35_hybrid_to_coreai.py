#!/usr/bin/env python3
"""WEIGHTS-FREE Qwen3.5 HYBRID (GatedDeltaNet + full-attention) decode-step → CoreAI convertibility probe.

Supersedes the GDN-only probe: builds the REAL Qwen3.5 structure — every 4th layer full-attn, the rest GDN
(`fullAttentionInterval=4`, `isLinear=(i+1)%4!=0`, Qwen35.swift:448) — with ONE fused state buffer, and lowers
it through coreai_torch 0.4.0. Random weights: tests OP-TYPE convertibility of the hybrid graph, not numerics.

GDN step  (GatedDelta.swift:180-192):  state*=decay; kv=(state*k).sum(-1); d=(v-kv)*beta; state+=k⊗d; y=(state*q).sum(-1)
Full-attn step (windowed static KV, ANE-friendly):  roll (k,v) into a fixed-W buffer; softmax(q·K/√d)·V
All ops (elementwise-mul, sum, softmax, cat/roll, exp/softplus/sigmoid/silu) already lower for Mamba-3 / Llama.
"""
from __future__ import annotations
import shutil, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
import coreai_torch

VOCAB, D_MODEL, L, H, DK, DV, W, FA_INT = 1000, 512, 8, 4, 64, 64, 16, 4
GDN_S = H * DV * DK               # GDN carried state size
FA_S = W * H * DK + W * H * DV     # full-attn KV-window state size
ROW = max(GDN_S, FA_S)            # uniform fused-row width (pad the smaller)


def is_linear(i: int) -> bool:    # True = GDN layer, False = full-attention layer
    return (i + 1) % FA_INT != 0


def rmsnorm(x, w, eps=1e-6):
    return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + eps) * w


class GDNLayer(nn.Module):
    def __init__(self):
        super().__init__()
        self.q = nn.Linear(D_MODEL, H * DK, bias=False); self.k = nn.Linear(D_MODEL, H * DK, bias=False)
        self.v = nn.Linear(D_MODEL, H * DV, bias=False); self.g = nn.Linear(D_MODEL, H, bias=False)
        self.b = nn.Linear(D_MODEL, H, bias=False); self.z = nn.Linear(D_MODEL, H * DV, bias=False)
        self.o = nn.Linear(H * DV, D_MODEL, bias=False); self.nw = nn.Parameter(torch.ones(H * DV))

    def forward(self, x, state):                       # state [H,DV,DK]
        q = self.q(x).view(H, DK); k = self.k(x).view(H, DK); v = self.v(x).view(H, DV)
        decay = torch.exp(-F.softplus(self.g(x))).view(H, 1, 1); beta = torch.sigmoid(self.b(x)).view(H, 1)
        z = self.z(x).view(H, DV)
        state = state * decay
        kvMem = (state * k.view(H, 1, DK)).sum(-1)
        delta = (v - kvMem) * beta
        state = state + k.view(H, 1, DK) * delta.view(H, DV, 1)
        y = (state * q.view(H, 1, DK)).sum(-1)
        y = rmsnorm(y.reshape(H * DV), self.nw)
        return x + self.o(y * F.silu(z.reshape(H * DV))), state


class FALayer(nn.Module):
    def __init__(self):
        super().__init__()
        self.q = nn.Linear(D_MODEL, H * DK, bias=False); self.k = nn.Linear(D_MODEL, H * DK, bias=False)
        self.v = nn.Linear(D_MODEL, H * DV, bias=False); self.o = nn.Linear(H * DV, D_MODEL, bias=False)
        self.nw = nn.Parameter(torch.ones(H * DV))

    def forward(self, x, kbuf, vbuf):                  # kbuf [W,H,DK], vbuf [W,H,DV]
        q = self.q(x).view(H, DK); k = self.k(x).view(H, DK); v = self.v(x).view(H, DV)
        kbuf = torch.cat([kbuf[1:], k.view(1, H, DK)], 0)   # static-shape ring shift-in
        vbuf = torch.cat([vbuf[1:], v.view(1, H, DV)], 0)
        scores = (q.view(1, H, DK) * kbuf).sum(-1) / (DK ** 0.5)   # [W,H]
        attn = torch.softmax(scores, 0)
        out = (attn.view(W, H, 1) * vbuf).sum(0)                   # [H,DV]
        out = rmsnorm(out.reshape(H * DV), self.nw)
        return x + self.o(out), kbuf, vbuf


class Hybrid(nn.Module):
    def __init__(self):
        super().__init__()
        self.emb = nn.Embedding(VOCAB, D_MODEL)
        self.layers = nn.ModuleList([GDNLayer() if is_linear(i) else FALayer() for i in range(L)])
        self.fw = nn.Parameter(torch.ones(D_MODEL))
        self.register_buffer("state_all", torch.zeros(L, ROW))    # ONE fused state (ANE ordering-safe)

    def forward(self, input_id):
        ew = self.emb.weight
        x = F.embedding(input_id, ew).view(D_MODEL)
        new = []
        for i, lyr in enumerate(self.layers):
            row = self.state_all[i]
            if is_linear(i):
                x, s2 = lyr(x, row[:GDN_S].reshape(H, DV, DK))
                new.append(F.pad(s2.reshape(-1), (0, ROW - GDN_S)))
            else:
                kbuf = row[:W * H * DK].reshape(W, H, DK); vbuf = row[W * H * DK:FA_S].reshape(W, H, DV)
                x, k2, v2 = lyr(x, kbuf, vbuf)
                new.append(F.pad(torch.cat([k2.reshape(-1), v2.reshape(-1)]), (0, ROW - FA_S)))
        self.state_all[:] = torch.stack(new, 0)
        x = rmsnorm(x, self.fw)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main():
    torch.manual_seed(0)
    gdn = sum(is_linear(i) for i in range(L)); fa = L - gdn
    print(f"=== Qwen3.5 HYBRID CoreAI convertibility probe (L={L}: {gdn} GDN + {fa} full-attn, interval={FA_INT}) ===")
    m = Hybrid().eval().half()
    out = m(torch.zeros(1, 1, dtype=torch.long))
    print(f"    torch forward OK, logits {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    torch.export + decomp OK; {len(states)} fused CoreAI state(s): {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    OUT = "/tmp/gdn_coreai/Qwen35Hybrid_probe.aimodel"
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ HYBRID (GDN + full-attn) CONVERTED + SAVED {OUT}  main.mlirb={sz/1e6:.2f} MB  in {time.time()-t0:.0f}s")
    print(f">> fused states: {states}")


if __name__ == "__main__":
    main()
