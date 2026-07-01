#!/usr/bin/env python3
"""WEIGHTS-FREE GatedDeltaNet (Qwen3.5 GDN layer) decode-step → CoreAI .aimodel convertibility probe.

Mirrors Tools/mamba3_to_coreai.py exactly (single fused-state buffer, torch.export -> get_decomp_table ->
TorchConverter -> to_coreai -> save_asset). GDN's recurrence is a STRICT SUBSET of the already-proven Mamba-3
op-graph — this runs the REAL coreai_torch 0.4.0 toolchain on the GDN ops to turn "subset reasoning" into a
toolchain proof. Random weights: numerics irrelevant, we test OP-TYPE convertibility (does it lower, or is
there an unsupported op?).

GDN gated-delta step, faithful to Vendor/.../GatedDelta.swift:180-192 (gatedDeltaStepOps):
  decay = exp(-softplus(g))              # per-head decay in (0,1)
  state = state * decay
  kvMem = (state * k).sum(-1)            # read key from state  [H,Dv]
  delta = (v - kvMem) * beta             # delta rule           [H,Dv]
  state = state + k(outer)delta          # rank-1 state update
  y     = (state * q).sum(-1)            # read query -> output [H,Dv]
Only elementwise-mul + sum(-1) + sub + exp/softplus/sigmoid/silu — every op already lowered for Mamba-3.
"""
from __future__ import annotations
import shutil, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
import coreai_torch

VOCAB, D_MODEL, L, H, DK, DV = 1000, 512, 4, 4, 64, 64   # probe scale; op-types are what matter
INNER = H * DV


def rmsnorm(x, w, eps=1e-6):
    return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + eps) * w


class GDNLayer(nn.Module):
    def __init__(self):
        super().__init__()
        self.q = nn.Linear(D_MODEL, H * DK, bias=False)
        self.k = nn.Linear(D_MODEL, H * DK, bias=False)
        self.v = nn.Linear(D_MODEL, H * DV, bias=False)
        self.g = nn.Linear(D_MODEL, H, bias=False)     # decay gate
        self.b = nn.Linear(D_MODEL, H, bias=False)     # beta (delta strength)
        self.z = nn.Linear(D_MODEL, H * DV, bias=False)  # output gate
        self.o = nn.Linear(H * DV, D_MODEL, bias=False)
        self.nw = nn.Parameter(torch.ones(H * DV))

    def forward(self, x, state):                        # x [D_MODEL], state [H,DV,DK]
        q = self.q(x).view(H, DK)
        k = self.k(x).view(H, DK)
        v = self.v(x).view(H, DV)
        decay = torch.exp(-F.softplus(self.g(x))).view(H, 1, 1)
        beta = torch.sigmoid(self.b(x)).view(H, 1)
        z = self.z(x).view(H, DV)
        state = state * decay
        kvMem = (state * k.view(H, 1, DK)).sum(-1)       # [H,DV]
        delta = (v - kvMem) * beta                       # [H,DV]
        state = state + k.view(H, 1, DK) * delta.view(H, DV, 1)
        y = (state * q.view(H, 1, DK)).sum(-1)           # [H,DV]
        y = rmsnorm(y.reshape(H * DV), self.nw)
        out = self.o(y * F.silu(z.reshape(H * DV)))
        return x + out, state


class GDN(nn.Module):
    def __init__(self):
        super().__init__()
        self.emb = nn.Embedding(VOCAB, D_MODEL)
        self.layers = nn.ModuleList([GDNLayer() for _ in range(L)])
        self.fw = nn.Parameter(torch.ones(D_MODEL))
        # SINGLE fused state buffer [L, H*DV*DK] — mamba3's trick to avoid ANE state-ordering SIGSEGV.
        self.register_buffer("state_all", torch.zeros(L, H * DV * DK))

    def forward(self, input_id):
        ew = self.emb.weight
        x = F.embedding(input_id, ew).view(D_MODEL)
        new = []
        for i, lyr in enumerate(self.layers):
            s = self.state_all[i].reshape(H, DV, DK)
            x, s2 = lyr(x, s)
            new.append(s2.reshape(-1))
        self.state_all[:] = torch.stack(new, 0)
        x = rmsnorm(x, self.fw)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main():
    torch.manual_seed(0)
    print(f"=== GDN weights-free CoreAI convertibility probe (L={L} d={D_MODEL} H={H} DK={DK} DV={DV}) ===")
    m = GDN().eval().half()
    out = m(torch.zeros(1, 1, dtype=torch.long))
    print(f"    torch forward OK, logits {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    torch.export + decomp OK; {len(states)} CoreAI state(s): {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai()
    prog.optimize()
    OUT = "/tmp/gdn_coreai/GDN_probe.aimodel"
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ GDN CONVERTED + SAVED {OUT}  main.mlirb={sz/1e6:.2f} MB  in {time.time()-t0:.0f}s")
    print(f">> states (for a Swift CoreAI session): {states}")


if __name__ == "__main__":
    main()
