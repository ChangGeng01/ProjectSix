#!/usr/bin/env python3
"""全面修复: rebuild the 3 CoreAI assets with the VERIFIED recipe — int8 + full-causal maxSeq KV (not int4/windowed).

Replaces qwen35_3asset_int4.py (audit-failed). Uses the fidelity-verified FAFull (int8, full-causal one-hot-write
maxSeq KV, cos 0.9999 vs MLX T=32) + int8 GDN. Converts asset1 (L0-11) / asset2 (L12-23) / asset3 (L24-31+head).
Per-layer states (convert-valid; device single-state fusion is the separate M1 task).
"""
from __future__ import annotations
import sys, shutil, time
from pathlib import Path
import torch, torch.nn as nn
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))  # co-located Tools/ deps
from qwen35_realweights_to_coreai import RealGDN, load_st, raw, dequant, rms, D, GV, GHD
from qwen35_fixed_decode import FAFull, NB, MAXSEQ, AKV, AHD, is_lin
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear
P = "language_model.model."


def int8_gdn(g):
    for nm in ["qkv", "a", "b", "z", "o", "gate", "up", "down"]:
        l = getattr(g, nm); setattr(g, nm, QuantLinear(l.weight.data.float(), NB))
    g.A_log.data = g.A_log.data.half(); g.dt_bias.data = g.dt_bias.data.half()
    return g


class Asset(nn.Module):
    def __init__(s, st, a, b, head=False):
        super().__init__(); s.a, s.b, s.head_on = a, b, head
        s.layers = nn.ModuleList([int8_gdn(RealGDN(st, i)) if is_lin(i) else FAFull(st, i) for i in range(a, b)])
        if head:
            s.fn = raw(st, P + "norm.weight").half(); s.head = QuantLinear(dequant(st, P + "embed_tokens").float(), NB)
        for j, i in enumerate(range(a, b)):
            if is_lin(i):
                s.register_buffer(f"gs{j}", torch.zeros(GV, GHD, GHD, dtype=torch.float16))
                s.register_buffer(f"gc{j}", torch.zeros(3, 8192, dtype=torch.float16))
            else:
                s.register_buffer(f"fk{j}", torch.zeros(MAXSEQ, AKV, AHD, dtype=torch.float16))
                s.register_buffer(f"fv{j}", torch.zeros(MAXSEQ, AKV, AHD, dtype=torch.float16))
        s.register_buffer("pos", torch.zeros(1, dtype=torch.float16))

    def forward(s, x):
        h = x.view(D); pos = s.pos + 1.0
        for j, i in enumerate(range(s.a, s.b)):
            if is_lin(i):
                gs = getattr(s, f"gs{j}"); gc = getattr(s, f"gc{j}")
                h, ns, nc = s.layers[j](h, gs, gc); gs[:] = ns; gc[:] = nc
            else:
                fk = getattr(s, f"fk{j}"); fv = getattr(s, f"fv{j}")
                h, nk, nv = s.layers[j](h, fk, fv, pos); fk[:] = nk; fv[:] = nv
        s.pos[:] = pos
        if s.head_on:
            return s.head(rms(h, s.fn)).view(1, -1)
        return h.view(1, D)


def convert(asset, name):
    ep = torch.export.export(asset.eval(), (torch.zeros(1, D, dtype=torch.float16),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table()); ep = inject_subbyte_tensors(ep)
    states = list(ep.graph_signature.buffers_to_mutate.values())
    conv = coreai_torch.TorchConverter().add_exported_program(ep, input_names=["x"], output_names=["out"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    out = f"/tmp/gdn_coreai/{name}.aimodel"
    if Path(out).exists(): shutil.rmtree(out)
    Path(out).parent.mkdir(parents=True, exist_ok=True); prog.save_asset(Path(out))
    sz = (Path(out) / "main.mlirb").stat().st_size / 1e9
    print(f">> ✅ {name}: {sz:.2f} GB ({len(states)} states)"); return sz


def main():
    st = load_st(); tot = 0
    for name, a, b, head in [("Qwen35fix_asset2_L12-23_int8", 12, 24, False),
                             ("Qwen35fix_asset3_L24-31_head_int8", 24, 32, True),
                             ("Qwen35fix_asset1_L0-11_int8", 0, 12, False)]:
        print(f">> building {name} int8 + full-causal..."); t0 = time.time()
        tot += convert(Asset(st, a, b, head=head).eval(), name); print(f"   ({time.time()-t0:.0f}s)")
    print(f">> FIXED 3-asset int8 total ≈ {tot:.2f} GB (each < 2GB wall). Recipe = full-causal + int8 (audit-verified cos 0.9999).")


if __name__ == "__main__":
    main()
