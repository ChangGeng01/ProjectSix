#!/usr/bin/env python3
"""WEIGHTS-FREE Mamba-3 decode-step → CoreAI .aimodel convertibility + (later) ANE speed probe.

Goal: does the Mamba-3 op-graph (the NEW bits — real 2x2 rotation / data-dependent RoPE, trapezoidal 3-term
recurrence, MIMO rank-R einsums) lower through coreai_torch 0.4.0 as cleanly as Mamba-2 did? Random weights —
numerics are irrelevant; we test OP-TYPE convertibility + (on device) speed/footprint. No checkpoint, no training.

Structurally faithful to the paper (arXiv 2603.15569) / state-spaces mamba3.py step(): per layer the carried
state is 4 real tensors —
  ssm   (H,P,N)      the SSM state H_t
  kprev (H,R,N)      B~_{t-1}  (trapezoid 1-step delay, rotated)
  vprev (H,P,R)      x_mimo_{t-1}
  angle (H,N//2)     cumulative RoPE angle (data-dependent)
fused across layers → 4 CoreAI states. Recurrence (Eq. 6/11, real form):
  alpha=exp(dt*A); lam=sigmoid(trap); beta=(1-lam)*dt*alpha; gamma=lam*dt
  B~,C~ = RoPE(B,C; angle)             # 2x2 rotation, real (rotate-half + cos/sin)
  cur   = einsum(x_mimo, B~)           # MIMO rank-R: (H,P,R)x(H,R,N)->(H,P,N)
  prev  = einsum(vprev, kprev)
  ssm   = alpha*ssm + beta*prev + gamma*cur     # trapezoidal 3-term
  y     = einsum(C~, ssm) -> mimo_o combine + D*x ; out = out_proj(y * silu(z))
NO conv1d (trapezoid term subsumes it), NO complex dtype/exp/phase.

Run from /tmp:  cd /tmp && /tmp/coreai-cv/bin/python /tmp/mamba3_to_coreai.py [L]
"""
from __future__ import annotations

import os
import shutil
import sys
import time
from pathlib import Path

# ANE-crash bisection ablations (CPU + host run fine for ALL; we hunt the op the ANE compiler SIGSEGVs on):
#   full   — the real Mamba-3 step (rotation + trapezoid + MIMO einsums)
#   norope — skip the 2×2 rotation / RoPE
#   nomimo — collapse MIMO to rank-1 + replace einsums with broadcast+sum (no batched einsum)
#   mamba2 — ssm-only Mamba-2-style (no rotation, no MIMO einsum, no trapezoid delay) through the SAME flat state
ABL = os.environ.get("M3_ABL", "full")

import torch
import torch.nn as nn
import torch.nn.functional as F

TOOLS = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools"
sys.path.insert(0, TOOLS)
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear, QuantEmbed   # reuse the int8 machinery

# --- config (match Llamba-1B shape for apples-to-apples ANE compare; +MIMO R=4) ---
L = int(sys.argv[1]) if len(sys.argv) > 1 else 16
D_MODEL = 2048
H = 32          # nheads
P = 64          # headdim
N = 64          # d_state
R = 4           # mimo_rank
VOCAB = 128256  # Llama-3.1 tokenizer (Mamba-3 uses it)
D_INNER = H * P  # 2048
EPS = 1e-5
OUT = f"/tmp/draft_coreai/Mamba3_L{L}_{ABL}_int8.aimodel" if ABL!="full" else f"/tmp/draft_coreai/Mamba3_L{L}_int8.aimodel"


def ln(x, w, b):
    mu = x.mean(-1, keepdim=True)
    xc = x - mu
    var = (xc * xc).mean(-1, keepdim=True)
    return xc * torch.rsqrt(var + EPS) * w + b


def rope(t, cos, sin):
    """t [H,R,N], cos/sin [H,N//2] → rotate-half (real 2x2 rotation), broadcast over R."""
    half = t.shape[-1] // 2
    t1, t2 = t[..., :half], t[..., half:]
    c = cos.unsqueeze(1)  # [H,1,half]
    s = sin.unsqueeze(1)
    return torch.cat([t1 * c - t2 * s, t2 * c + t1 * s], dim=-1)


class Mamba3Layer(nn.Module):
    def __init__(self):
        super().__init__()
        # in_proj → [z(d_inner), x(d_inner), B(H*R*N), C(H*R*N), dt(H), A(H), trap(H), theta(H*N//2)]
        self.po = D_INNER + D_INNER + 2 * H * R * N + 3 * H + H * (N // 2)
        self.norm = nn.Parameter(torch.ones(D_MODEL))
        self.normb = nn.Parameter(torch.zeros(D_MODEL))
        self.in_proj = nn.Linear(D_MODEL, self.po, bias=False)
        self.dt_bias = nn.Parameter(torch.zeros(H))
        self.A = nn.Parameter(torch.zeros(H))
        self.D = nn.Parameter(torch.ones(H))
        self.bn_w = nn.Parameter(torch.ones(N))  # B/C RMSNorm gamma
        self.mimo_x = nn.Parameter(torch.randn(H, P, R) * 0.02)  # lift x→rank R
        self.mimo_o = nn.Parameter(torch.randn(H, R, P) * 0.02)  # combine rank R→P
        self.out_proj = nn.Linear(D_INNER, D_MODEL, bias=False)

    def forward(self, x, ssm, kprev, vprev, angle):
        # x [d_model]; ssm [H,P,N]; kprev [H,R,N]; vprev [H,P,R]; angle [H,N//2]
        h = ln(x, self.norm, self.normb)
        proj = self.in_proj(h)
        sizes = [D_INNER, D_INNER, H * R * N, H * R * N, H, H, H, H * (N // 2)]
        z, xin, Braw, Craw, dt_raw, A_raw, trap_raw, theta_raw = torch.split(proj, sizes, dim=-1)
        xin = xin.view(H, P)
        B = Braw.view(H, R, N)
        C = Craw.view(H, R, N)
        # B/C RMSNorm (over N)
        B = B * torch.rsqrt((B * B).mean(-1, keepdim=True) + EPS) * self.bn_w
        C = C * torch.rsqrt((C * C).mean(-1, keepdim=True) + EPS) * self.bn_w
        dt = F.softplus(dt_raw + self.dt_bias)                 # [H]
        A = -F.softplus(A_raw)                                 # [H] negative
        lam = torch.sigmoid(trap_raw)                          # [H]
        alpha = torch.exp(dt * A).view(H, 1, 1)                # [H,1,1]
        beta = ((1 - lam) * dt * torch.exp(dt * A)).view(H, 1, 1)
        gamma = (lam * dt).view(H, 1, 1)

        if ABL == "mamba2":
            # ssm-only Mamba-2 step through the flat state: rank-1 outer (broadcast, no einsum), no rotation/trapezoid.
            B0 = B[:, 0, :]; C0 = C[:, 0, :]                            # [H,N]
            cur = xin.unsqueeze(-1) * B0.unsqueeze(1)                   # [H,P,N] broadcast outer
            new_ssm = alpha * ssm + gamma * cur
            y_out = (new_ssm * C0.unsqueeze(1)).sum(-1) + self.D.view(H, 1) * xin  # [H,P] broadcast+sum
            out = self.out_proj(y_out.reshape(D_INNER) * F.silu(z))
            return x + out, new_ssm, kprev, vprev, angle               # carry kprev/vprev/angle unchanged

        # data-dependent RoPE: accumulate angle, rotate B,C (skip under norope)
        theta = theta_raw.view(H, N // 2)
        new_angle = angle + dt.view(H, 1) * theta              # [H,N//2]
        if ABL == "norope":
            Brot, Crot = B, C
        else:
            cos = torch.cos(new_angle); sin = torch.sin(new_angle)
            Brot = rope(B, cos, sin)                           # [H,R,N]
            Crot = rope(C, cos, sin)

        if ABL == "nomimo":
            # rank-1, broadcast outer + broadcast+sum (NO batched einsum)
            B0 = Brot[:, 0, :]; C0 = Crot[:, 0, :]                      # [H,N]
            cur = xin.unsqueeze(-1) * B0.unsqueeze(1)                   # [H,P,N]
            prev = vprev[:, :, 0] * 0 + (vprev[:, :, 0].unsqueeze(-1) * kprev[:, 0, :].unsqueeze(1))  # [H,P,N]
            new_ssm = alpha * ssm + beta * prev + gamma * cur
            y_out = (new_ssm * C0.unsqueeze(1)).sum(-1) + self.D.view(H, 1) * xin  # [H,P]
            out = self.out_proj(y_out.reshape(D_INNER) * F.silu(z))
            return x + out, new_ssm, Brot, xin.unsqueeze(-1) * 0 + xin.unsqueeze(-1).expand(H, P, R), new_angle

        # MIMO: lift x to rank R, outer with B~ (the full path)
        x_mimo = xin.unsqueeze(-1) * self.mimo_x                # [H,P,R]
        cur = torch.einsum("hpr,hrn->hpn", x_mimo, Brot)        # [H,P,N]
        prev = torch.einsum("hpr,hrn->hpn", vprev, kprev)       # [H,P,N]  (delay term)
        new_ssm = alpha * ssm + beta * prev + gamma * cur       # trapezoidal 3-term
        # output: y = C~ . ssm  → MIMO combine → +D*x
        y = torch.einsum("hrn,hpn->hpr", Crot, new_ssm)         # [H,P,R]
        y_out = torch.einsum("hpr,hrp->hp", y, self.mimo_o) + self.D.view(H, 1) * xin  # [H,P]
        y_out = y_out.reshape(D_INNER)
        out = self.out_proj(y_out * F.silu(z))
        return x + out, new_ssm, Brot, x_mimo, new_angle


class Mamba3(nn.Module):
    def __init__(self):
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, D_MODEL)
        self.layers = nn.ModuleList([Mamba3Layer() for _ in range(L)])
        self.final_w = nn.Parameter(torch.ones(D_MODEL))
        self.final_b = nn.Parameter(torch.zeros(D_MODEL))
        # SINGLE fused state buffer [L, S] — the device segmenter reorders state token-outputs vs handle-inputs
        # past 2 states ("order of token outputs does not match order of handle inputs" → ANE SIGSEGV); ONE state
        # has no ordering to mismatch. Per layer, S packs ssm|kprev|vprev|angle flattened (offsets o1..o4).
        self.o1 = H * P * N
        self.o2 = self.o1 + H * R * N
        self.o3 = self.o2 + H * P * R
        self.o4 = self.o3 + H * (N // 2)
        self.register_buffer("state_all", torch.zeros(L, self.o4))

    def quantize(self):
        for lyr in self.layers:
            lyr.in_proj = QuantLinear(lyr.in_proj.weight, 8)
            lyr.out_proj = QuantLinear(lyr.out_proj.weight, 8)
        self.embedding = QuantEmbed(self.embedding.weight, 8)
        return self

    def forward(self, input_id):
        ew = self.embedding.weight_fp16()
        x = F.embedding(input_id, ew).view(D_MODEL)
        o1, o2, o3, o4 = self.o1, self.o2, self.o3, self.o4
        new_rows = []
        for i, lyr in enumerate(self.layers):
            row = self.state_all[i]
            ssm = row[0:o1].reshape(H, P, N)
            kprev = row[o1:o2].reshape(H, R, N)
            vprev = row[o2:o3].reshape(H, P, R)
            angle = row[o3:o4].reshape(H, N // 2)
            x, s, k, v, a = lyr(x, ssm, kprev, vprev, angle)
            new_rows.append(torch.cat([s.reshape(-1), k.reshape(-1), v.reshape(-1), a.reshape(-1)], 0))
        self.state_all[:] = torch.stack(new_rows, 0)   # single state output → no input/output ordering mismatch
        x = ln(x, self.final_w, self.final_b)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main():
    torch.manual_seed(0)
    print(f"=== Mamba-3 weights-free convertibility probe (L={L} d={D_MODEL} H={H} P={P} N={N} R={R}) ===")
    m = Mamba3().eval()
    m.quantize()
    m = m.half()
    print("    quantized int8")
    # sanity: torch forward runs (op-graph valid) on the quantized model
    out = m(torch.zeros(1, 1, dtype=torch.long))
    print(f"    torch forward OK, logits {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    ep = inject_subbyte_tensors(ep)
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    exported OK; {len(states)} states: {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ CONVERTED + SAVED {OUT}  main.mlirb={sz/1e9:.2f} GB  in {time.time()-t0:.0f}s")
    print(f">> states (for the Swift session): {states}")
    print(f">> {'under 2GB — loads on A19' if sz < 2_000_000_000 else '≥2GB — would hit the load wall'}")


if __name__ == "__main__":
    main()
