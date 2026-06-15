# FAITHFUL trapezoid Mamba-3 with 4 PROPER angle-first states (angle,ssm,kprev,vprev).
# The fix for the flat-state SIGSEGV: mamba3_to_coreai.py packs all carried state into ONE flat [L,148480]
# tensor sliced per layer — that flat-slice crashes the A19 ANE segmenter at load (device-confirmed L=2).
# This mirrors mamba3_full_ane.py's PROVEN structure (separate register_buffer states, angle registered FIRST,
# read-first, write-first) but extends it 2->4 states and adds the FAITHFUL trapezoid: learned A=-softplus,
# trapezoidal 3-term recurrence (alpha*ssm + beta*prev + gamma*cur), and the kprev/vprev rotated-delay term.
import shutil, sys
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear, QuantEmbed
L = int(sys.argv[1]) if len(sys.argv) > 1 else 2
D_MODEL, H, P, N, R, VOCAB = 2048, 32, 64, 64, 4, 128256
D_INNER, EPS = H * P, 1e-5
OUT = f"/tmp/draft_coreai/Mamba3F_L{L}_int8.aimodel"   # F = FAITHFUL trapezoid


def rms(x, w):
    xf = x.float(); return (xf * torch.rsqrt(xf.pow(2).mean(-1, keepdim=True) + EPS)).to(x.dtype) * w


def rope(t, cos, sin):
    h = t.shape[-1] // 2; t1, t2 = t[..., :h], t[..., h:]; c = cos.unsqueeze(1); s = sin.unsqueeze(1)
    return torch.cat([t1 * c - t2 * s, t2 * c + t1 * s], -1)


class Lyr(nn.Module):
    def __init__(s):
        super().__init__()
        s.po = D_INNER + D_INNER + 2 * H * R * N + 3 * H + H * (N // 2)   # z,xin,B,C,dt,A,trap,theta
        s.norm = nn.Parameter(torch.ones(D_MODEL)); s.in_proj = nn.Linear(D_MODEL, s.po, bias=False)
        s.dt_bias = nn.Parameter(torch.zeros(H)); s.D = nn.Parameter(torch.ones(H))
        s.bn_w = nn.Parameter(torch.ones(N))                            # B/C RMSNorm gamma
        s.mimo_x = nn.Parameter(torch.randn(H, P, R) * .02); s.mimo_o = nn.Parameter(torch.randn(H, R, P) * .02)
        s.out_proj = nn.Linear(D_INNER, D_MODEL, bias=False)

    def forward(s, x, angle, ssm, kprev, vprev):                        # angle FIRST
        h = rms(x, s.norm)
        z, xin, Br, Cr, dt_raw, A_raw, trap_raw, th = torch.split(
            s.in_proj(h), [D_INNER, D_INNER, H * R * N, H * R * N, H, H, H, H * (N // 2)], -1)
        xin = xin.view(H, P); B = Br.view(H, R, N); C = Cr.view(H, R, N)
        B = B * torch.rsqrt((B * B).mean(-1, keepdim=True) + EPS) * s.bn_w
        C = C * torch.rsqrt((C * C).mean(-1, keepdim=True) + EPS) * s.bn_w
        dt = F.softplus(dt_raw + s.dt_bias); A = -F.softplus(A_raw); lam = torch.sigmoid(trap_raw)
        alpha = torch.exp(dt * A).view(H, 1, 1)
        beta = ((1 - lam) * dt * torch.exp(dt * A)).view(H, 1, 1)
        gamma = (lam * dt).view(H, 1, 1)
        new_angle = angle + dt.view(H, 1) * th.view(H, N // 2)          # READ/WRITE angle FIRST
        cos = torch.cos(new_angle); sin = torch.sin(new_angle)
        Brot = rope(B, cos, sin); Crot = rope(C, cos, sin)
        x_mimo = xin.unsqueeze(-1) * s.mimo_x                           # [H,P,R]
        cur = torch.einsum("hpr,hrn->hpn", x_mimo, Brot)                # [H,P,N]
        prev = torch.einsum("hpr,hrn->hpn", vprev, kprev)              # [H,P,N] rotated delay
        new_ssm = alpha * ssm + beta * prev + gamma * cur              # trapezoidal 3-term
        y = torch.einsum("hrn,hpn->hpr", Crot, new_ssm)                # [H,P,R]
        y_out = torch.einsum("hpr,hrp->hp", y, s.mimo_o) + s.D.view(H, 1) * xin
        out = s.out_proj(y_out.reshape(D_INNER) * F.silu(z))
        return x + out, new_angle, new_ssm, Brot, x_mimo               # angle,ssm,kprev,vprev


class M(nn.Module):
    def __init__(s):
        super().__init__(); s.embedding = nn.Embedding(VOCAB, D_MODEL)
        s.layers = nn.ModuleList([Lyr() for _ in range(L)]); s.fw = nn.Parameter(torch.ones(D_MODEL))
        s.register_buffer("angle_all", torch.zeros(L, H, N // 2))      # state 1 (FIRST)
        s.register_buffer("ssm_all", torch.zeros(L, H, P, N))          # state 2
        s.register_buffer("kprev_all", torch.zeros(L, H, R, N))        # state 3
        s.register_buffer("vprev_all", torch.zeros(L, H, P, R))        # state 4

    def quantize(s):
        for l in s.layers:
            l.in_proj = QuantLinear(l.in_proj.weight, 8); l.out_proj = QuantLinear(l.out_proj.weight, 8)
        s.embedding = QuantEmbed(s.embedding.weight, 8); return s

    def forward(s, input_id):
        ew = s.embedding.weight_fp16(); x = F.embedding(input_id, ew).view(D_MODEL)
        na, ns, nk, nv = [], [], [], []
        for i, l in enumerate(s.layers):
            x, a, sm, k, v = l(x, s.angle_all[i], s.ssm_all[i], s.kprev_all[i], s.vprev_all[i])
            na.append(a); ns.append(sm); nk.append(k); nv.append(v)
        s.angle_all[:] = torch.stack(na, 0); s.ssm_all[:] = torch.stack(ns, 0)    # write angle FIRST
        s.kprev_all[:] = torch.stack(nk, 0); s.vprev_all[:] = torch.stack(nv, 0)
        x = rms(x, s.fw); return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


torch.manual_seed(0)
m = M().eval().quantize().half(); _ = m(torch.zeros(1, 1, dtype=torch.long))
ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
st = list(ep.graph_signature.buffers_to_mutate.values()); print("states:", st)
c = coreai_torch.TorchConverter().add_exported_program(
    ep, input_names=["input_id"], output_names=["logits"], state_names=st, entrypoint_name="main")
p = c.to_coreai(); p.optimize()
if Path(OUT).exists(): shutil.rmtree(OUT)
Path(OUT).parent.mkdir(parents=True, exist_ok=True); p.save_asset(Path(OUT))
print(f">> SAVED {OUT} states={st}")
print(f">> STATES env (angle;ssm;kprev;vprev): {L},{H},{N // 2};{L},{H},{P},{N};{L},{H},{R},{N};{L},{H},{P},{R}")
