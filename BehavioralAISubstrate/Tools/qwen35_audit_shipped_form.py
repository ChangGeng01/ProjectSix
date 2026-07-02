#!/usr/bin/env python3
"""AUDIT: does the SHIPPED form (int4 layers + windowed-KV W=8 FA decode) match MLX on T=16 (> window)?

The fidelity I claimed was fp16 + full-causal. The 3 shipped assets use int4 + windowed KV. This runs the actual
shipped-form decode (int4 QuantLinear layers, FA single-token windowed-KV+RoPE, GDN single-token loop) on a 16-token
sequence (exceeds W=8, so windowing bites) and compares last-token logits to MLX full-causal. If top-1 diverges,
"shipped assets are faithful" was OVERSTATED.
"""
from __future__ import annotations
import sys, numpy as np, torch, torch.nn.functional as F
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))  # co-located Tools/ deps
from qwen35_realweights_to_coreai import RealGDN, load_st, raw, rms, dequant, D, GV, GHD
from qwen35_3asset_int4 import FA, q4, is_lin, W
P = "language_model.model."


def main():
    st = load_st()
    embed = dequant(st, P + "embed_tokens").half()
    fnorm = raw(st, P + "norm.weight").half()
    layers = []
    for i in range(32):
        if is_lin(i):
            g = q4(RealGDN(st, i)); g.A_log.data = g.A_log.data.half(); g.dt_bias.data = g.dt_bias.data.half()
        else:
            g = FA(st, i)                                 # int4 (QuantLinear) + windowed + RoPE
        layers.append(g.eval())
    toks = np.load("/tmp/gdn_coreai/mlx_toks16.npy"); T = len(toks)
    gs = {i: torch.zeros(GV, GHD, GHD, dtype=torch.float16) for i in range(32) if is_lin(i)}
    gc = {i: torch.zeros(3, 8192, dtype=torch.float16) for i in range(32) if is_lin(i)}
    fk = {i: torch.zeros(W, 4, 256, dtype=torch.float16) for i in range(32) if not is_lin(i)}
    fv = {i: torch.zeros(W, 4, 256, dtype=torch.float16) for i in range(32) if not is_lin(i)}
    logits = None
    with torch.no_grad():
        for t in range(T):
            h = embed[int(toks[t])]
            for i, lyr in enumerate(layers):
                if is_lin(i):
                    h, s, c = lyr(h, gs[i], gc[i]); gs[i], gc[i] = s, c
                else:
                    h, k, v = lyr(h, fk[i], fv[i], torch.tensor([float(t)], dtype=torch.float16)); fk[i], fv[i] = k, v
            if t == T - 1:
                logits = (rms(h, fnorm) @ embed.t()).float()
    mlx = torch.from_numpy(np.load("/tmp/gdn_coreai/mlx_logits16.npy"))
    cos = F.cosine_similarity(logits, mlx, dim=0).item()
    my5 = logits.topk(5).indices.tolist(); mx5 = mlx.topk(5).indices.tolist()
    ov = len(set(my5) & set(mx5))
    print(f">> SHIPPED-FORM (int4 + windowed-KV W={W}) vs MLX (T={T}): cos={cos:.4f}  top1 mine={my5[0]} mlx={mx5[0]}  top5-ov={ov}/5")
    print(f"   my top5={my5}  mlx top5={mx5}")
    print(">> " + ("✅ shipped form HOLDS (top-1 match)" if my5[0] == mx5[0] else "⚠️ shipped form DIVERGES — fp16/full-KV fidelity did NOT transfer to int4/windowed"))


if __name__ == "__main__":
    main()
