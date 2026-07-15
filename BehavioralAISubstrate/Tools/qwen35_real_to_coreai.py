#!/usr/bin/env python3
"""REAL-DIMS Qwen3.5-4B hybrid (GatedDeltaNet + full-attn) decode-step → CoreAI convertibility + size probe.

M2-step-1 of the CoreAI-conversion direction: upgrades the toy probe to the REAL Qwen3.5-4B structure
(from config.json text_config) to prove real-STRUCTURE convertibility and measure the real per-layer asset size
vs the ~2GB single-asset wall. Weights-free (random); op-type + size, not numerics.

Real dims: hidden 2560, GDN linear_num_value_heads=32 / linear_num_key_heads=16 (GQA) / head_dim 128,
full-attn 16 heads / 4 kv (GQA) / head_dim 256, MLP intermediate 9216 (SwiGLU), full_attention_interval=4.
(conv1d k=4 omitted here — a trivially-supported op; the GDN recurrence + GQA + attn + SwiGLU are the point.)
Vocab reduced to 4096 for the probe (real 248320 embed+head ≈636M, standard-convertible, sized analytically).
"""
from __future__ import annotations
import shutil, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
import coreai_torch

D = 2560; L = 8; FA_INT = 4
GV, GK, GHD = 32, 16, 128         # GDN: value heads, key heads (GQA), head dim
AH, AKV, AHD = 16, 4, 256         # full-attn: heads, kv heads (GQA), head dim
IMED = 9216; W = 16; VOCAB = 4096
GDN_S = GV * GHD * GHD                       # GDN recurrence state
FA_S = W * AKV * AHD + W * AKV * AHD         # windowed GQA KV
ROW = max(GDN_S, FA_S)


def is_lin(i): return (i + 1) % FA_INT != 0
def rms(x, w, e=1e-6): return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + e) * w
def swiglu(x, wg, wu, wd): return (F.silu(x @ wg.t()) * (x @ wu.t())) @ wd.t()


class GDN(nn.Module):
    def __init__(s):
        super().__init__()
        s.q = nn.Linear(D, GK * GHD, bias=False); s.k = nn.Linear(D, GK * GHD, bias=False)
        s.v = nn.Linear(D, GV * GHD, bias=False); s.g = nn.Linear(D, GV, bias=False)
        s.b = nn.Linear(D, GV, bias=False); s.z = nn.Linear(D, GV * GHD, bias=False)
        s.o = nn.Linear(GV * GHD, D, bias=False); s.nw = nn.Parameter(torch.ones(GV * GHD))
        s.wg = nn.Parameter(torch.randn(IMED, D) * .02); s.wu = nn.Parameter(torch.randn(IMED, D) * .02)
        s.wd = nn.Parameter(torch.randn(D, IMED) * .02); s.ln = nn.Parameter(torch.ones(D))

    def forward(s, x, state):                         # state [GV,GHD,GHD]
        q = s.q(x).view(GK, GHD); k = s.k(x).view(GK, GHD); v = s.v(x).view(GV, GHD)
        q = q.repeat_interleave(GV // GK, 0); k = k.repeat_interleave(GV // GK, 0)   # GQA repeat to GV heads
        decay = torch.exp(-F.softplus(s.g(x))).view(GV, 1, 1); beta = torch.sigmoid(s.b(x)).view(GV, 1)
        z = s.z(x).view(GV, GHD)
        state = state * decay
        kv = (state * k.view(GV, 1, GHD)).sum(-1)
        delta = (v - kv) * beta
        state = state + k.view(GV, 1, GHD) * delta.view(GV, GHD, 1)
        y = (state * q.view(GV, 1, GHD)).sum(-1)
        y = rms(y.reshape(GV * GHD), s.nw)
        h = x + s.o(y * F.silu(z.reshape(GV * GHD)))
        return h + swiglu(rms(h, s.ln), s.wg, s.wu, s.wd), state


class FA(nn.Module):
    def __init__(s):
        super().__init__()
        s.q = nn.Linear(D, AH * AHD, bias=False); s.k = nn.Linear(D, AKV * AHD, bias=False)
        s.v = nn.Linear(D, AKV * AHD, bias=False); s.o = nn.Linear(AH * AHD, D, bias=False)
        s.nw = nn.Parameter(torch.ones(AH * AHD))
        s.wg = nn.Parameter(torch.randn(IMED, D) * .02); s.wu = nn.Parameter(torch.randn(IMED, D) * .02)
        s.wd = nn.Parameter(torch.randn(D, IMED) * .02); s.ln = nn.Parameter(torch.ones(D))

    def forward(s, x, kbuf, vbuf):                    # kbuf/vbuf [W,AKV,AHD]
        q = s.q(x).view(AH, AHD); k = s.k(x).view(AKV, AHD); v = s.v(x).view(AKV, AHD)
        kbuf = torch.cat([kbuf[1:], k.view(1, AKV, AHD)], 0); vbuf = torch.cat([vbuf[1:], v.view(1, AKV, AHD)], 0)
        kk = kbuf.repeat_interleave(AH // AKV, 1); vv = vbuf.repeat_interleave(AH // AKV, 1)   # GQA
        sc = (q.view(1, AH, AHD) * kk).sum(-1) / (AHD ** 0.5)
        a = torch.softmax(sc, 0)
        out = (a.view(W, AH, 1) * vv).sum(0)
        out = rms(out.reshape(AH * AHD), s.nw)
        h = x + s.o(out)
        return h + swiglu(rms(h, s.ln), s.wg, s.wu, s.wd), kbuf, vbuf


class Model(nn.Module):
    def __init__(s):
        super().__init__()
        s.emb = nn.Embedding(VOCAB, D)
        s.layers = nn.ModuleList([GDN() if is_lin(i) else FA() for i in range(L)])
        s.fw = nn.Parameter(torch.ones(D)); s.register_buffer("state_all", torch.zeros(L, ROW))

    def forward(s, input_id):
        ew = s.emb.weight; x = F.embedding(input_id, ew).view(D); new = []
        for i, lyr in enumerate(s.layers):
            r = s.state_all[i]
            if is_lin(i):
                x, st = lyr(x, r[:GDN_S].reshape(GV, GHD, GHD)); new.append(F.pad(st.reshape(-1), (0, ROW - GDN_S)))
            else:
                kb = r[:W * AKV * AHD].reshape(W, AKV, AHD); vb = r[W * AKV * AHD:FA_S].reshape(W, AKV, AHD)
                x, k2, v2 = lyr(x, kb, vb); new.append(F.pad(torch.cat([k2.reshape(-1), v2.reshape(-1)]), (0, ROW - FA_S)))
        s.state_all[:] = torch.stack(new, 0); x = rms(x, s.fw)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main():
    torch.manual_seed(0)
    g = sum(is_lin(i) for i in range(L))
    m = Model().eval().half()
    p = sum(t.numel() for t in m.parameters())
    print(f"=== REAL-DIMS Qwen3.5 hybrid probe (L={L}: {g} GDN + {L-g} FA; hidden {D}; GDN 32v/16k/128; MLP {IMED}) ===")
    print(f"    params (L={L}, vocab {VOCAB}): {p/1e6:.0f}M  |  per-layer ~{(p - VOCAB*D)/L/1e6:.0f}M")
    print(f"    → real 24 GDN+8 FA @ ~{(p-VOCAB*D)/L/1e6:.0f}M/layer: 12L asset ≈ {(p-VOCAB*D)/L*12/1e9:.2f}B params → int8 ≈ {(p-VOCAB*D)/L*12/1e9:.2f}GB (wall=2GB)")
    out = m(torch.zeros(1, 1, dtype=torch.long)); print(f"    torch forward OK, logits {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    export+decomp OK; {len(states)} fused state(s): {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    OUT = "/tmp/gdn_coreai/Qwen35Real_probe.aimodel"
    if Path(OUT).exists(): shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True); prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ REAL-STRUCTURE HYBRID CONVERTED  main.mlirb={sz/1e6:.1f} MB  in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
