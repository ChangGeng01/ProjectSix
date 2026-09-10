#!/usr/bin/env python3
"""ANE-crash bisection control: a SINGLE properly-shaped state (ssm_all [L,H,P,N]) — no flat-packing/slice, no
2nd state (so no segmenter ordering bug), op-for-op the proven Llamba SSD step (RMSNorm, A=-1, pre-divide x by
dt, broadcast outer via view). If THIS compiles on the A19 ANE -> the flat-state slice/reshape was the crasher
(a single proper state works) and the path forward is properly-shaped states. If it STILL crashes -> even the
simplest proper-state Llamba-form step from THIS converter pipeline crashes on ANE, i.e. the blocker is the
pipeline/structure (in_proj / tied head / setup), not the SSD ops, the state mechanism, or the Mamba-3 features.

Run: cd /tmp && /tmp/coreai-cv/bin/python /tmp/mamba3_1state.py [L]
"""
from __future__ import annotations

import shutil
import sys
import time
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

TOOLS = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools"
sys.path.insert(0, TOOLS)
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear, QuantEmbed

L = int(sys.argv[1]) if len(sys.argv) > 1 else 2
D_MODEL, H, P, N, R, VOCAB = 2048, 32, 64, 64, 4, 128256
D_INNER, EPS = H * P, 1e-5
OUT = f"/tmp/draft_coreai/Mamba31s_L{L}_int8.aimodel"


def rms(x, w):   # proven Llamba pure RMSNorm
    xf = x.float()
    return (xf * torch.rsqrt(xf.pow(2).mean(-1, keepdim=True) + EPS)).to(x.dtype) * w


class Layer(nn.Module):
    def __init__(self):
        super().__init__()
        self.po = D_INNER + D_INNER + 2 * H * R * N + 2 * H   # z,x,B,C,dt,A
        self.norm = nn.Parameter(torch.ones(D_MODEL))
        self.in_proj = nn.Linear(D_MODEL, self.po, bias=False)
        self.dt_bias = nn.Parameter(torch.zeros(H))
        self.D = nn.Parameter(torch.ones(H))
        self.out_proj = nn.Linear(D_INNER, D_MODEL, bias=False)

    def forward(self, x, ssm):   # ssm [H,P,N]
        h = rms(x, self.norm)
        z, xin, Braw, Craw, dt_raw, _A = torch.split(
            self.in_proj(h), [D_INNER, D_INNER, H * R * N, H * R * N, H, H], dim=-1)
        xin = xin.view(H, P)
        B = Braw.view(H, R, N); C = Craw.view(H, R, N)
        dt = F.softplus(dt_raw + self.dt_bias)
        dA = torch.exp(dt * (-1.0)).view(H, 1, 1)
        B0 = B.reshape(H, R * N)[:, :N]; C0 = C.reshape(H, R * N)[:, :N]   # view, no select
        x_ssm = xin / dt.unsqueeze(-1)
        dB = dt.unsqueeze(-1) * B0
        cur = x_ssm.unsqueeze(-1) * dB.unsqueeze(1)        # [H,P,N]
        new_ssm = dA * ssm + cur
        y_out = (new_ssm * C0.unsqueeze(1)).sum(-1) + self.D.view(H, 1) * xin
        out = self.out_proj(y_out.reshape(D_INNER) * F.silu(z))
        return x + out, new_ssm


class Model(nn.Module):
    def __init__(self):
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, D_MODEL)
        self.layers = nn.ModuleList([Layer() for _ in range(L)])
        self.final_w = nn.Parameter(torch.ones(D_MODEL))
        self.register_buffer("ssm_all", torch.zeros(L, H, P, N))   # ONE properly-shaped state

    def quantize(self):
        for lyr in self.layers:
            lyr.in_proj = QuantLinear(lyr.in_proj.weight, 8)
            lyr.out_proj = QuantLinear(lyr.out_proj.weight, 8)
        self.embedding = QuantEmbed(self.embedding.weight, 8)
        return self

    def forward(self, input_id):
        ew = self.embedding.weight_fp16()
        x = F.embedding(input_id, ew).view(D_MODEL)
        ns = []
        for i, lyr in enumerate(self.layers):
            x, s = lyr(x, self.ssm_all[i]); ns.append(s)
        self.ssm_all[:] = torch.stack(ns, 0)
        x = rms(x, self.final_w)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main():
    torch.manual_seed(0)
    print(f"=== Mamba-3 1-proper-state control (op-for-op Llamba) L={L} ===")
    m = Model().eval().quantize().half()
    _ = m(torch.zeros(1, 1, dtype=torch.long))
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    {len(states)} states: {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ SAVED {OUT}  main.mlirb={sz/1e9:.2f} GB  states={states}")
    print(f">> Swift session state: ssm_all [{L},{H},{P},{N}]  (BAS_COREAI_MAMBA3_STATES={L},{H},{P},{N})")


if __name__ == "__main__":
    main()
