#!/usr/bin/env python3
"""M2 finish: assemble the FULL 32L real-weight Qwen3.5-4B port + verify last-token logits vs MLX.

Composes the fidelity-verified pieces: RealGDN (single-token, looped over T) + multi-token FA (RoPE base 1e7 /
dims 64 + causal GQA, verified) + tied embed/head + final norm. Run MLX first (freed) to avoid holding both.
"""
from __future__ import annotations
import sys, numpy as np, torch, torch.nn.functional as F
SD = "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/c3ffc755-9222-4370-81cc-7a004da44172/scratchpad"
sys.path.insert(0, SD)
from qwen35_realweights_to_coreai import load_st, lin, raw, rms, dequant, RealGDN, GV, GHD

D, AH, AKV, AHD, BASE, RD = 2560, 16, 4, 256, 1e7, 64
P = "language_model.model."
def is_lin(i): return (i + 1) % 4 != 0


class RealFA:
    def __init__(s, st, i):
        p = f"{P}layers.{i}."
        s.qp = lin(st, p + "self_attn.q_proj"); s.kp = lin(st, p + "self_attn.k_proj")
        s.vp = lin(st, p + "self_attn.v_proj"); s.op = lin(st, p + "self_attn.o_proj")
        s.qn = raw(st, p + "self_attn.q_norm.weight").half(); s.kn = raw(st, p + "self_attn.k_norm.weight").half()
        s.iln = raw(st, p + "input_layernorm.weight").half(); s.pln = raw(st, p + "post_attention_layernorm.weight").half()
        s.gw = lin(st, p + "mlp.gate_proj"); s.uw = lin(st, p + "mlp.up_proj"); s.dw = lin(st, p + "mlp.down_proj")

    def rope(s, x, T):                                   # [T,H,256], rotate first RD (NeoX)
        xr, xp = x[..., :RD], x[..., RD:]; half = RD // 2
        inv = BASE ** (-torch.arange(0, RD, 2).float() / RD)
        ang = torch.arange(T).float()[:, None] * inv[None, :]
        cos, sin = ang.cos()[:, None, :].half(), ang.sin()[:, None, :].half()
        x1, x2 = xr[..., :half], xr[..., half:]
        return torch.cat([torch.cat([x1 * cos - x2 * sin, x1 * sin + x2 * cos], -1), xp], -1)

    def __call__(s, h):                                  # h [T,D] → [T,D]
        T = h.shape[0]; x = rms(h, s.iln)
        qpo = s.qp(x).view(T, AH, -1); q, g = qpo[..., :AHD], qpo[..., AHD:]; gate = g.reshape(T, -1)
        k = s.kp(x).view(T, AKV, AHD); v = s.vp(x).view(T, AKV, AHD)
        q = s.rope(rms(q, s.qn), T); k = s.rope(rms(k, s.kn), T)
        kk = k.repeat_interleave(AH // AKV, 1).transpose(0, 1); vv = v.repeat_interleave(AH // AKV, 1).transpose(0, 1)
        sc = (q.transpose(0, 1).float() @ kk.float().transpose(-1, -2)) * (AHD ** -0.5)
        sc = sc + torch.triu(torch.full((T, T), float("-inf")), 1)
        out = (F.softmax(sc, -1) @ vv.float()).transpose(0, 1).reshape(T, -1).half() * torch.sigmoid(gate)
        h = h + s.op(out)
        return h + s.dw(F.silu(s.gw(rms(h, s.pln))) * s.uw(rms(h, s.pln)))


def main():
    print(">> loading + dequantizing full model (32L + embed)...")
    st = load_st()
    embed = dequant(st, P + "embed_tokens").half()       # [248320,2560] tied head
    fnorm = raw(st, P + "norm.weight").half()
    layers = [RealGDN(st, i).eval().half() if is_lin(i) else RealFA(st, i) for i in range(32)]
    toks = np.load("/tmp/gdn_coreai/mlx_toks.npy"); T = len(toks)
    h = embed[torch.from_numpy(toks).long()]             # [T,2560]
    with torch.no_grad():
        for i, lyr in enumerate(layers):
            if is_lin(i):
                st_, cw = torch.zeros(GV, GHD, GHD, dtype=torch.float16), torch.zeros(3, 8192, dtype=torch.float16)
                outs = []
                for t in range(T):
                    o, st_, cw = lyr(h[t], st_, cw); outs.append(o)
                h = torch.stack(outs)
            else:
                h = lyr(h)
        h = rms(h, fnorm)
        logits = (h[-1] @ embed.t()).float()             # last-token [vocab]
    mlx = torch.from_numpy(np.load("/tmp/gdn_coreai/mlx_logits.npy"))
    cos = F.cosine_similarity(logits, mlx, dim=0).item()
    my5 = logits.topk(5).indices.tolist(); mx5 = mlx.topk(5).indices.tolist()
    ov = len(set(my5) & set(mx5))
    print(f">> FULL 32L PORT vs MLX last-token logits: cos={cos:.4f}  top1 mine={my5[0]} mlx={mx5[0]}  top5-overlap={ov}/5")
    print(f"   my top5={my5}  mlx top5={mx5}")
    print(">> " + ("✅ FULL PORT FAITHFUL" if (my5[0] == mx5[0] and cos > 0.99) else "⚠️ assembly diverges"))


if __name__ == "__main__":
    main()
