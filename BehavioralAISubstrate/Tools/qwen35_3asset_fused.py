#!/usr/bin/env python3
"""DEVICE-READY build: 3 int8 + full-causal assets with a SINGLE fused state each (ANE-segmenter-safe).

The ANE segmenter mis-orders >2 states (mamba3 finding: token-output vs handle-input ordering → SIGSEGV), so each
asset packs ALL its per-layer states into ONE buffer `state_all [rows, ROWMAX]`: GDN row = gs(32*128*128) ‖
gc(3*8192); FA row = fk ‖ fv (2*64*4*256); last row holds pos at [0]. Same verified compute (int8 + full-causal,
M3-host cos 0.9998) — only the state packing changes. Torch fidelity is re-verified here anyway (audit lesson:
never trust "by construction"): --verify runs the fused chain in torch on the T=32 golden and compares to MLX.
"""
from __future__ import annotations
import sys, shutil, time
from pathlib import Path
import numpy as np, torch, torch.nn as nn
SD = "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/c3ffc755-9222-4370-81cc-7a004da44172/scratchpad"
sys.path.insert(0, SD); sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import RealGDN, load_st, raw, dequant, rms, D, GV, GHD
from qwen35_fixed_decode import FAFull, NB, MAXSEQ, AKV, AHD, is_lin
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear

P = "language_model.model."
GDN_S = GV * GHD * GHD            # 524288
GDN_C = 3 * 8192                  # 24576
FA_S = 2 * MAXSEQ * AKV * AHD     # 131072
ROW = GDN_S + GDN_C               # 548864 (max row)


def int8_gdn(g):
    for nm in ["qkv", "a", "b", "z", "o", "gate", "up", "down"]:
        l = getattr(g, nm); setattr(g, nm, QuantLinear(l.weight.data.float(), NB))
    g.A_log.data = g.A_log.data.half(); g.dt_bias.data = g.dt_bias.data.half()
    return g


class FusedAsset(nn.Module):
    def __init__(s, st, a, b, head=False):
        super().__init__(); s.a, s.b, s.head_on = a, b, head
        s.layers = nn.ModuleList([int8_gdn(RealGDN(st, i)) if is_lin(i) else FAFull(st, i) for i in range(a, b)])
        if head:
            s.fn = raw(st, P + "norm.weight").half(); s.head = QuantLinear(dequant(st, P + "embed_tokens").float(), NB)
        n = b - a
        s.register_buffer("state_all", torch.zeros(n + 1, ROW, dtype=torch.float16))   # ONE state; last row = pos

    def forward(s, x):
        h = x.view(D)
        pos = s.state_all[s.b - s.a, 0] + 1.0
        rows = []
        for j, i in enumerate(range(s.a, s.b)):
            r = s.state_all[j]
            if is_lin(i):
                gs = r[:GDN_S].reshape(GV, GHD, GHD); gc = r[GDN_S:GDN_S + GDN_C].reshape(3, 8192)
                h, ns, nc = s.layers[j](h, gs, gc)
                rows.append(torch.cat([ns.reshape(-1), nc.reshape(-1)]))
            else:
                half = MAXSEQ * AKV * AHD
                fk = r[:half].reshape(MAXSEQ, AKV, AHD); fv = r[half:FA_S].reshape(MAXSEQ, AKV, AHD)
                h, nk, nv = s.layers[j](h, fk, fv, pos.view(1))
                rows.append(torch.nn.functional.pad(torch.cat([nk.reshape(-1), nv.reshape(-1)]), (0, ROW - FA_S)))
        posrow = torch.nn.functional.pad(pos.view(1), (0, ROW - 1))
        s.state_all[:] = torch.stack(rows + [posrow], 0)
        if s.head_on:
            return s.head(rms(h, s.fn)).view(1, -1)
        return h.view(1, D)


SPLITS = [("Qwen35fused_asset1_L0-11_int8", 0, 12, False),
          ("Qwen35fused_asset2_L12-23_int8", 12, 24, False),
          ("Qwen35fused_asset3_L24-31_head_int8", 24, 32, True)]


def verify(st):
    embed = dequant(st, P + "embed_tokens").half()
    assets = [FusedAsset(st, a, b, head=hd).eval() for _, a, b, hd in SPLITS]
    toks = np.load("/tmp/gdn_coreai/mlx_toks32.npy")
    out = None
    with torch.no_grad():
        for t in range(len(toks)):
            h = embed[int(toks[t])].view(1, D)
            for A in assets:
                h = A(h)
            out = h
    logits = out.view(-1).float()
    mlx = torch.from_numpy(np.load("/tmp/gdn_coreai/mlx_logits32.npy"))
    cos = torch.nn.functional.cosine_similarity(logits, mlx, dim=0).item()
    my5 = logits.topk(5).indices.tolist(); mx5 = mlx.topk(5).indices.tolist()
    print(f">> FUSED torch chain vs MLX T=32: cos={cos:.4f} top5-ov={len(set(my5)&set(mx5))}/5")
    assert cos > 0.995 and len(set(my5) & set(mx5)) >= 4, "fused packing broke fidelity"
    print(">> ✅ fused packing preserves fidelity")


def convert_all(st):
    tot = 0
    for name, a, b, hd in SPLITS:
        print(f">> building {name} (single fused state)..."); t0 = time.time()
        m = FusedAsset(st, a, b, head=hd).eval()
        ep = torch.export.export(m, (torch.zeros(1, D, dtype=torch.float16),))
        ep = ep.run_decompositions(coreai_torch.get_decomp_table()); ep = inject_subbyte_tensors(ep)
        states = list(ep.graph_signature.buffers_to_mutate.values())
        assert states == ["state_all"], f"expected single fused state, got {states}"
        conv = coreai_torch.TorchConverter().add_exported_program(ep, input_names=["x"], output_names=["out"], state_names=states, entrypoint_name="main")
        prog = conv.to_coreai(); prog.optimize()
        out = f"/tmp/gdn_coreai/{name}.aimodel"
        if Path(out).exists(): shutil.rmtree(out)
        prog.save_asset(Path(out))
        sz = (Path(out) / "main.mlirb").stat().st_size / 1e9; tot += sz
        print(f">> ✅ {name}: {sz:.2f} GB (states={states})  ({time.time()-t0:.0f}s)")
    print(f">> FUSED 3-asset total ≈ {tot:.2f} GB — each ONE state (ANE-segmenter-safe), int8 + full-causal")


if __name__ == "__main__":
    st = load_st()
    if "--convert-only" not in sys.argv:
        verify(st)
    convert_all(st)
