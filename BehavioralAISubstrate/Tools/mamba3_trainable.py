"""Trainable twin of the certified faithful Mamba-3 (mamba3_faithful_ane.py) + PARITY-A gate.

The certified converter is INFERENCE-only: a per-token 4-state step (angle,ssm,kprev,vprev) with QuantLinear.
To distill we need a DIFFERENTIABLE version that computes the SAME function over a whole sequence, in pure torch
(MPS-friendly; mamba_ssm's CUDA scan is unavailable and unnecessary).

KEY REFORMULATION (the whole reason a clean scan exists): the converter writes kprev:=Brot_t and vprev:=x_mimo_t
WRITE-FIRST, so at step t the delay term  prev_t = einsum(vprev_t, kprev_t) = einsum(x_mimo_{t-1}, Brot_{t-1})
== cur_{t-1}  EXACTLY. So the "rotated delay" is NOT a separate scan state — it is a width-2 causal conv on the
precomputable `cur` sequence. The 4-state recurrence collapses to a single 1st-order linear recurrence:
    cur_t  = einsum(x_mimo_t, Brot_t)
    u_t    = beta_t * cur_{t-1} + gamma_t * cur_t          # width-2 causal conv
    ssm_t  = alpha_t * ssm_{t-1} + u_t                     # alpha=exp(dt*A), A=-softplus<0  -> stable scan
    angle_t = cumsum_t(dt_t * theta_t)                     # RoPE phase
PARITY-A asserts this reformulation (chunked twin) == the faithful 4-state sequential step, on identical random
weights: per-step max-abs-err on ssm AND angle < 1e-4 AND token-identical argmax over a 24-window. Mixer-only
(matches the certified asset; the SwiGLU MLP is a both-sides addition tracked separately).

Run:  ~/.venvs/coreai-cv/bin/python Tools/mamba3_trainable.py
"""
from __future__ import annotations

import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

# Locked student config (D=1024 retarget of the certified D=2048 op-graph; same op-types).
D_MODEL, H, P, N, R = 1024, 16, 64, 64, 4
D_INNER, EPS = H * P, 1e-5
PO = D_INNER + D_INNER + 2 * H * R * N + 3 * H + H * (N // 2)   # z,xin,B,C,dt,A,trap,theta


def rms(x: torch.Tensor, w: torch.Tensor) -> torch.Tensor:
    xf = x.float()
    return (xf * torch.rsqrt(xf.pow(2).mean(-1, keepdim=True) + EPS)).to(x.dtype) * w


def rope(t: torch.Tensor, cos: torch.Tensor, sin: torch.Tensor) -> torch.Tensor:
    # t [...,R,N], cos/sin [...,N//2] -> broadcast over the R dim (-2)
    h = t.shape[-1] // 2
    t1, t2 = t[..., :h], t[..., h:]
    c, s = cos.unsqueeze(-2), sin.unsqueeze(-2)
    return torch.cat([t1 * c - t2 * s, t2 * c + t1 * s], -1)


class Lyr(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.norm = nn.Parameter(torch.ones(D_MODEL))
        self.in_proj = nn.Linear(D_MODEL, PO, bias=False)
        self.dt_bias = nn.Parameter(torch.zeros(H))
        self.D = nn.Parameter(torch.ones(H))
        self.bn_w = nn.Parameter(torch.ones(N))
        self.mimo_x = nn.Parameter(torch.randn(H, P, R) * 0.02)
        self.mimo_o = nn.Parameter(torch.randn(H, R, P) * 0.02)
        self.out_proj = nn.Linear(D_INNER, D_MODEL, bias=False)

    # ---- per-token coefficients shared by both paths (keeps the two numerically identical by construction) ----
    def _coeffs(self, h_in: torch.Tensor):
        # h_in: [..., D_MODEL]  ->  returns coeff tensors with a leading [...] (token) axis
        z, xin, Br, Cr, dt_raw, A_raw, trap_raw, th = torch.split(
            self.in_proj(h_in), [D_INNER, D_INNER, H * R * N, H * R * N, H, H, H, H * (N // 2)], -1)
        lead = h_in.shape[:-1]
        xin = xin.view(*lead, H, P)
        B = Br.view(*lead, H, R, N)
        C = Cr.view(*lead, H, R, N)
        B = B * torch.rsqrt((B * B).mean(-1, keepdim=True) + EPS) * self.bn_w
        C = C * torch.rsqrt((C * C).mean(-1, keepdim=True) + EPS) * self.bn_w
        dt = F.softplus(dt_raw + self.dt_bias)
        A = -F.softplus(A_raw)
        lam = torch.sigmoid(trap_raw)
        alpha = torch.exp(dt * A)                                # [...,H]
        beta = (1 - lam) * dt * torch.exp(dt * A)                # [...,H]
        gamma = lam * dt                                         # [...,H]
        theta = th.view(*lead, H, N // 2)
        x_mimo = xin.unsqueeze(-1) * self.mimo_x                 # [...,H,P,R]
        return z, xin, B, C, dt, alpha, beta, gamma, theta, x_mimo

    # ---- REFERENCE: the exact faithful 4-state single-token step (ground truth = what the .aimodel ships) ----
    def step_ref(self, x, angle, ssm, kprev, vprev):
        h = rms(x, self.norm)
        z, xin, B, C, dt, alpha, beta, gamma, theta, x_mimo = self._coeffs(h)
        a3 = alpha.view(H, 1, 1); b3 = beta.view(H, 1, 1); g3 = gamma.view(H, 1, 1)
        new_angle = angle + dt.view(H, 1) * theta
        cos, sin = torch.cos(new_angle), torch.sin(new_angle)
        Brot, Crot = rope(B, cos, sin), rope(C, cos, sin)
        cur = torch.einsum("hpr,hrn->hpn", x_mimo, Brot)
        prev = torch.einsum("hpr,hrn->hpn", vprev, kprev)        # delay from previous step's (vprev,kprev)
        new_ssm = a3 * ssm + b3 * prev + g3 * cur
        y = torch.einsum("hrn,hpn->hpr", Crot, new_ssm)
        y_out = torch.einsum("hpr,hrp->hp", y, self.mimo_o) + self.D.view(H, 1) * xin
        out = self.out_proj(y_out.reshape(D_INNER) * F.silu(z))
        return x + out, new_angle, new_ssm, Brot, x_mimo

    # ---- TWIN: the reformulated chunked/parallel path over a [T,D] sequence (differentiable) ----
    def forward_seq(self, x_seq):
        T = x_seq.shape[0]
        h = rms(x_seq, self.norm)
        z, xin, B, C, dt, alpha, beta, gamma, theta, x_mimo = self._coeffs(h)   # leading T axis
        angle = torch.cumsum(dt.unsqueeze(-1) * theta, dim=0)                   # [T,H,N//2]
        cos, sin = torch.cos(angle), torch.sin(angle)
        Brot, Crot = rope(B, cos, sin), rope(C, cos, sin)                       # [T,H,R,N]
        cur = torch.einsum("thpr,thrn->thpn", x_mimo, Brot)                     # [T,H,P,N]
        cur_prev = torch.cat([torch.zeros_like(cur[:1]), cur[:-1]], 0)          # cur_{t-1}, cur_{-1}=0
        u = beta.view(T, H, 1, 1) * cur_prev + gamma.view(T, H, 1, 1) * cur     # width-2 causal conv
        # scan ssm_t = alpha_t*ssm_{t-1} + u_t  (sequential here; segsum/chunked is a drop-in speed swap, eq by const)
        ssm = torch.zeros(H, P, N, dtype=x_seq.dtype, device=x_seq.device)
        outs = []
        for t in range(T):
            ssm = alpha[t].view(H, 1, 1) * ssm + u[t]
            outs.append(ssm)
        ssm_seq = torch.stack(outs, 0)                                          # [T,H,P,N]
        y = torch.einsum("thrn,thpn->thpr", Crot, ssm_seq)                      # [T,H,P,R]
        y_out = torch.einsum("thpr,hrp->thp", y, self.mimo_o) + self.D.view(1, H, 1) * xin
        out = self.out_proj(y_out.reshape(T, D_INNER) * F.silu(z))
        return x_seq + out, ssm_seq, angle


class M(nn.Module):
    def __init__(self, vocab: int, layers: int) -> None:
        super().__init__()
        self.embedding = nn.Embedding(vocab, D_MODEL)
        self.layers = nn.ModuleList([Lyr() for _ in range(layers)])
        self.fw = nn.Parameter(torch.ones(D_MODEL))

    def head(self, x):
        return rms(x, self.fw) @ self.embedding.weight.t()

    def run_ref(self, tokens):
        st = [(torch.zeros(H, N // 2), torch.zeros(H, P, N), torch.zeros(H, R, N), torch.zeros(H, P, R))
              for _ in self.layers]
        logits, ssm_tr = [], [[] for _ in self.layers]
        for tok in tokens:
            x = self.embedding.weight[tok]
            for li, lyr in enumerate(self.layers):
                x, a, ss, k, v = lyr.step_ref(x, *st[li])
                st[li] = (a, ss, k, v); ssm_tr[li].append(ss)
            logits.append(self.head(x))
        return torch.stack(logits, 0), [torch.stack(s, 0) for s in ssm_tr]

    def run_twin(self, tokens):
        x = self.embedding.weight[tokens]                                       # [T,D]
        ssm_tr = []
        for lyr in self.layers:
            x, ssm_seq, _ = lyr.forward_seq(x)
            ssm_tr.append(ssm_seq)
        return self.head(x), ssm_tr


def parity(seed: int = 0, T: int = 24, vocab: int = 2048, layers: int = 4) -> bool:
    torch.manual_seed(seed)
    m = M(vocab, layers).double().eval()                                        # fp64 for a clean numeric verdict
    toks = torch.randint(0, vocab, (T,))
    with torch.no_grad():
        lref, sref = m.run_ref(toks)
        ltwin, stwin = m.run_twin(toks)
    ssm_err = max((sr - st).abs().max().item() for sr, st in zip(sref, stwin))
    log_err = (lref - ltwin).abs().max().item()
    argmax_match = int((lref.argmax(-1) == ltwin.argmax(-1)).sum().item())
    print(f"=== PARITY-A  (T={T}, layers={layers}, D={D_MODEL}/H={H}/P={P}/N={N}/R={R}) ===")
    print(f"  per-step ssm max-abs-err : {ssm_err:.3e}")
    print(f"  logits     max-abs-err   : {log_err:.3e}")
    print(f"  argmax-identical         : {argmax_match}/{T}")
    ok = ssm_err < 1e-4 and argmax_match == T
    print(f"  RESULT: {'PASS ✅' if ok else 'FAIL ❌'}  (gate: ssm<1e-4 AND argmax {T}/{T})")
    return ok


if __name__ == "__main__":
    ok = all(parity(seed=s) for s in (0, 1, 2))
    sys.exit(0 if ok else 1)
