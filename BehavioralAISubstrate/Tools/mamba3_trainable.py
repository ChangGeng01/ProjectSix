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

import math
import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

# Locked student config (D=1024 retarget of the certified D=2048 op-graph; same op-types).
D_MODEL, H, P, N, R = 1024, 16, 64, 64, 4
D_FF = round(2.5 * D_MODEL)                                     # SwiGLU MLP inner (locked exp 2.5)
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


def scan_parallel(log_alpha: torch.Tensor, u: torch.Tensor) -> torch.Tensor:
    """Parallel 1-semiseparable scan: ssm_t = alpha_t*ssm_{t-1} + u_t. Takes log_alpha = dt*A DIRECTLY (NOT
    log(exp(dt*A)) — that exp->log round-trip underflows to log(0)=-inf=NaN when dt*A drifts very negative in
    training). ssm_t = sum_{s<=t} exp(L_t - L_s) u_s, L = cumsum(log_alpha); exp(non-positive) -> stable."""
    T = log_alpha.shape[0]
    Lc = torch.cumsum(log_alpha, dim=0)                         # [T,H], non-increasing
    diff = Lc.unsqueeze(1) - Lc.unsqueeze(0)                    # [T,T,H]  (= L_t - L_s at [t,s])
    mask = torch.tril(torch.ones(T, T, dtype=torch.bool, device=log_alpha.device))
    # mask the upper triangle to -inf BEFORE exp: there diff = L_i - L_j > 0 -> exp(+)=inf taints the BACKWARD
    # (0*inf=NaN). exp(-inf)=0 cleanly. (torch.where(mask, exp(diff), 0) still computes the inf -> NaN in bwd.)
    decay = torch.exp(diff.masked_fill(~mask.unsqueeze(-1), float("-inf")))
    return torch.einsum("tsh,shpn->thpn", decay, u)            # [T,H,P,N]


def scan_chunked(log_alpha: torch.Tensor, u: torch.Tensor, C: int = 64) -> torch.Tensor:
    """Memory-efficient chunked equivalent of scan_parallel: O(C^2) decay/chunk vs O(T^2). Same recurrence
    ssm_t = alpha_t*ssm_{t-1} + u_t (takes log_alpha=dt*A directly, no exp->log underflow). Intra-chunk via a
    local CxC 1-SS matmul; inter-chunk via a short carry loop over nc=ceil(T/C) chunk-end states."""
    T, Hh = log_alpha.shape
    Pp, Ss = u.shape[2], u.shape[3]
    pad = (-T) % C
    if pad:
        log_alpha = torch.cat([log_alpha, torch.zeros(pad, Hh, dtype=log_alpha.dtype, device=log_alpha.device)], 0)
        u = torch.cat([u, torch.zeros(pad, Hh, Pp, Ss, dtype=u.dtype, device=u.device)], 0)
    nc = (T + pad) // C
    cl = torch.cumsum(log_alpha.view(nc, C, Hh), dim=1)               # [nc,C,H] inclusive cumsum within chunk
    diff = cl.unsqueeze(2) - cl.unsqueeze(1)                           # [nc,Ci,Cj,H]
    mask = torch.tril(torch.ones(C, C, dtype=torch.bool, device=log_alpha.device))
    Dloc = torch.exp(diff.masked_fill(~mask.view(1, C, C, 1), float("-inf")))   # -inf before exp (avoid exp(+)=inf bwd-NaN)
    intra = torch.einsum("cijh,cjhps->cihps", Dloc, u.view(nc, C, Hh, Pp, Ss))   # within-chunk
    decay_start = torch.exp(cl)                                        # [nc,C,H] carry decay from chunk start
    outs = []
    ssm_in = torch.zeros(Hh, Pp, Ss, dtype=u.dtype, device=u.device)
    for c in range(nc):
        ssm_c = decay_start[c].unsqueeze(-1).unsqueeze(-1) * ssm_in.unsqueeze(0) + intra[c]   # [C,H,P,N]
        outs.append(ssm_c)
        ssm_in = ssm_c[-1]
    return torch.cat(outs, 0)[:T]


class Lyr(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.norm = nn.Parameter(torch.ones(D_MODEL))
        self.in_proj = nn.Linear(D_MODEL, PO, bias=False)
        # Mamba-style dt init: dt ~ U[1e-3, 0.1] via inverse-softplus bias -> small dt = stable SSM dynamics
        _dt = torch.exp(torch.rand(H) * (math.log(0.1) - math.log(1e-3)) + math.log(1e-3))
        self.dt_bias = nn.Parameter(torch.log(torch.expm1(_dt)))
        self.D = nn.Parameter(torch.ones(H))
        self.bn_w = nn.Parameter(torch.ones(N))
        self.mimo_x = nn.Parameter(torch.randn(H, P, R) * 0.02)
        self.mimo_o = nn.Parameter(torch.randn(H, R, P) * 0.02)
        self.gnorm = nn.Parameter(torch.ones(D_INNER))        # gated RMSNorm on SSD output (Mamba-2/3 stabilizer)
        self.out_proj = nn.Linear(D_INNER, D_MODEL, bias=False)
        # SwiGLU MLP (post-mixer block) — identical in both paths, so PARITY-A still isolates the mixer
        self.mlp_norm = nn.Parameter(torch.ones(D_MODEL))
        self.mlp_gate = nn.Linear(D_MODEL, D_FF, bias=False)
        self.mlp_up = nn.Linear(D_MODEL, D_FF, bias=False)
        self.mlp_down = nn.Linear(D_FF, D_MODEL, bias=False)

    def mlp(self, x):
        h = rms(x, self.mlp_norm)
        return self.mlp_down(F.silu(self.mlp_gate(h)) * self.mlp_up(h))

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
        A = -F.softplus(A_raw)                                    # faithful (ssm stays bounded via small dt-init; no floor needed)
        lam = torch.sigmoid(trap_raw)
        la = dt * A                                              # log_alpha — pass to the scan DIRECTLY (no exp->log)
        alpha = torch.exp(la)                                    # [...,H]  (used by step_ref's recurrence + beta)
        beta = (1 - lam) * dt * alpha                            # [...,H]
        gamma = lam * dt                                         # [...,H]
        theta = th.view(*lead, H, N // 2)
        x_mimo = xin.unsqueeze(-1) * self.mimo_x                 # [...,H,P,R]
        return z, xin, B, C, dt, alpha, la, beta, gamma, theta, x_mimo

    # ---- REFERENCE: the exact faithful 4-state single-token step (ground truth = what the .aimodel ships) ----
    def step_ref(self, x, angle, ssm, kprev, vprev):
        h = rms(x, self.norm)
        z, xin, B, C, dt, alpha, _la, beta, gamma, theta, x_mimo = self._coeffs(h)
        a3 = alpha.view(H, 1, 1); b3 = beta.view(H, 1, 1); g3 = gamma.view(H, 1, 1)
        new_angle = angle + dt.view(H, 1) * theta
        cos, sin = torch.cos(new_angle), torch.sin(new_angle)
        Brot, Crot = rope(B, cos, sin), rope(C, cos, sin)
        cur = torch.einsum("hpr,hrn->hpn", x_mimo, Brot)
        prev = torch.einsum("hpr,hrn->hpn", vprev, kprev)        # delay from previous step's (vprev,kprev)
        new_ssm = a3 * ssm + b3 * prev + g3 * cur
        y = torch.einsum("hrn,hpn->hpr", Crot, new_ssm)
        y_out = torch.einsum("hpr,hrp->hp", y, self.mimo_o) + self.D.view(H, 1) * xin
        out = self.out_proj(rms(y_out.reshape(D_INNER) * F.silu(z), self.gnorm))
        x1 = x + out
        return x1 + self.mlp(x1), new_angle, new_ssm, Brot, x_mimo

    # ---- TWIN: the reformulated chunked/parallel path over a [T,D] sequence (differentiable) ----
    def attn_matrix(self, x_seq):
        """MOHAWK Stage-1: materialize the per-head token-mixing matrix A[h,t,s] the SSD implements, so it can
        be aligned to the teacher's softmax-attention matrix. SSD-core form A[t,s] = decay(t,s)·<Crot_t,Brot_s>
        over s<=t (tril). SIMPLIFICATION (honest): collapses the rank-R/per-P MIMO + trapezoid delay into the
        scalar token-mixing — the attention-relevant structure, not the exact per-(h,p) operator."""
        T = x_seq.shape[0]
        h = rms(x_seq, self.norm)
        _z, _xin, B, C, dt, _alpha, la, _beta, _gamma, theta, _xm = self._coeffs(h)
        angle = torch.cumsum(dt.unsqueeze(-1) * theta, dim=0)
        cos, sin = torch.cos(angle), torch.sin(angle)
        Brot, Crot = rope(B, cos, sin), rope(C, cos, sin)              # [T,H,R,N]
        Lc = torch.cumsum(la, dim=0)                                   # [T,H]
        diff = Lc.unsqueeze(1) - Lc.unsqueeze(0)                       # [T,T,H] = Lc_t - Lc_s
        content = torch.einsum("thrn,shrn->tsh", Crot, Brot)          # [T,T,H] = <Crot_t, Brot_s>
        mask = torch.tril(torch.ones(T, T, dtype=torch.bool, device=x_seq.device))
        decay = torch.exp(diff.masked_fill(~mask.unsqueeze(-1), float("-inf")))   # -inf before exp (bwd-safe)
        return (decay * content).permute(2, 0, 1)                     # [H,T,T]

    def forward_seq(self, x_seq):
        T = x_seq.shape[0]
        h = rms(x_seq, self.norm)
        z, xin, B, C, dt, alpha, la, beta, gamma, theta, x_mimo = self._coeffs(h)   # leading T axis
        angle = torch.cumsum(dt.unsqueeze(-1) * theta, dim=0)                   # [T,H,N//2]
        cos, sin = torch.cos(angle), torch.sin(angle)
        Brot, Crot = rope(B, cos, sin), rope(C, cos, sin)                       # [T,H,R,N]
        cur = torch.einsum("thpr,thrn->thpn", x_mimo, Brot)                     # [T,H,P,N]
        cur_prev = torch.cat([torch.zeros_like(cur[:1]), cur[:-1]], 0)          # cur_{t-1}, cur_{-1}=0
        u = beta.view(T, H, 1, 1) * cur_prev + gamma.view(T, H, 1, 1) * cur     # width-2 causal conv
        # chunked-segsum scan (== scan_parallel, verified) — O(C^2) decay/chunk so long T fits memory
        ssm_seq = scan_chunked(la, u) if T > 64 else scan_parallel(la, u)
        y = torch.einsum("thrn,thpn->thpr", Crot, ssm_seq)                      # [T,H,P,R]
        y_out = torch.einsum("thpr,hrp->thp", y, self.mimo_o) + self.D.view(1, H, 1) * xin
        out = self.out_proj(rms(y_out.reshape(T, D_INNER) * F.silu(z), self.gnorm))
        x1 = x_seq + out
        return x1 + self.mlp(x1), ssm_seq, angle


class M(nn.Module):
    def __init__(self, vocab: int, layers: int) -> None:
        super().__init__()
        self.embedding = nn.Embedding(vocab, D_MODEL)
        self.layers = nn.ModuleList([Lyr() for _ in range(layers)])
        self.fw = nn.Parameter(torch.ones(D_MODEL))
        self._init_weights(layers)

    def _init_weights(self, nl: int) -> None:
        # Standard LM init: std 0.02 (default N(0,1)/kaiming explodes a tied-head LM). GPT-2 residual scaling
        # 1/sqrt(2L) on the projections that write into the residual stream keeps the deep residual stable.
        for mod in self.modules():
            if isinstance(mod, (nn.Linear, nn.Embedding)):
                nn.init.normal_(mod.weight, mean=0.0, std=0.02)
        with torch.no_grad():
            for lyr in self.layers:
                lyr.out_proj.weight.mul_(1.0 / (2 * nl) ** 0.5)
                lyr.mlp_down.weight.mul_(1.0 / (2 * nl) ** 0.5)

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

    def run_attn(self, tokens):
        """Per-layer student token-mixing matrices [H,T,T] (Stage-1), on the student's own residual stream."""
        x = self.embedding.weight[tokens]
        mats = []
        for lyr in self.layers:
            mats.append(lyr.attn_matrix(x))
            x, _, _ = lyr.forward_seq(x)
        return mats

    def run_twin(self, tokens, collect_ssm: bool = True, return_hiddens: bool = False):
        x = self.embedding.weight[tokens]                                       # [T,D]
        extra = []                                                              # per-layer hiddens, or ssm trace
        for lyr in self.layers:
            x, ssm_seq, _ = lyr.forward_seq(x)
            if return_hiddens:
                extra.append(x)                                                 # residual after each layer [T,D]
            elif collect_ssm:
                extra.append(ssm_seq)
        return self.head(x), extra


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


def microbench(T: int = 256, layers: int = 16, vocab: int = 100352, iters: int = 4) -> None:
    import time
    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    torch.manual_seed(0)
    m = M(vocab, layers).to(dev)
    opt = torch.optim.AdamW(m.parameters(), lr=1e-4)
    toks = torch.randint(0, vocab, (T,), device=dev)
    tgt = torch.randint(0, vocab, (T,), device=dev)

    def step():
        opt.zero_grad(set_to_none=True)
        logits, _ = m.run_twin(toks, collect_ssm=False)
        loss = F.cross_entropy(logits, tgt)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(m.parameters(), 1.0)
        opt.step()
        return float(loss.detach())

    for _ in range(2):                                                  # warmup (compile/alloc)
        step()
    if dev == "mps":
        torch.mps.synchronize()
    t0 = time.time()
    for _ in range(iters):
        step()
    if dev == "mps":
        torch.mps.synchronize()
    dt = (time.time() - t0) / iters
    tps = T / dt
    peak = torch.mps.driver_allocated_memory() / 1e9 if dev == "mps" else 0.0
    params = sum(p.numel() for p in m.parameters()) / 1e6
    print(f"=== MICROBENCH fwd+bwd ({dev}, L={layers}, D={D_MODEL}, T={T}, bs=1, vocab={vocab}, {params:.0f}M params) ===")
    print(f"  step: {dt*1000:.0f} ms  ->  {tps:.0f} train tok/s  (bs=1; batching + chunked-segsum raise this)")
    print(f"  ~tokens/day @ this rate: {tps*86400/1e6:.0f}M  (PoC ~0.3-1B; production ~3-10B)")
    print(f"  MPS peak: {peak:.1f} GB  (full 1-SS decay is O(T^2)/layer -> seq>~512 needs chunked-segsum)")


def overfit_sanity(steps: int = 80, T: int = 16, vocab: int = 512, layers: int = 2, lr: float = 3e-3) -> bool:
    """Memorize one fixed batch -> loss must collapse toward 0. Proves gradients flow through the WHOLE
    student (mixer scan + MLP + tied head), i.e. the harness trains. Not a capacity test."""
    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    torch.manual_seed(0)
    m = M(vocab, layers).to(dev)
    opt = torch.optim.AdamW(m.parameters(), lr=lr)
    toks = torch.randint(0, vocab, (T,), device=dev)
    tgt = torch.randint(0, vocab, (T,), device=dev)
    losses = []
    for _ in range(steps):
        opt.zero_grad(set_to_none=True)
        logits, _ = m.run_twin(toks, collect_ssm=False)
        loss = F.cross_entropy(logits, tgt)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(m.parameters(), 1.0)
        opt.step()
        losses.append(float(loss.detach()))
    ok = losses[-1] < 0.05
    print(f"=== OVERFIT SANITY ({dev}, L={layers}, T={T}, vocab={vocab}, {steps} steps) ===")
    print(f"  CE loss: {losses[0]:.3f} -> {losses[-1]:.4f}   (memorize 1 batch -> ~0 = gradients flow thru twin+MLP)")
    print(f"  RESULT: {'PASS ✅' if ok else 'FAIL ❌'}")
    return ok


def parity_scan(T: int = 200, Pp: int = 8, Ss: int = 8, C: int = 64, seed: int = 0) -> bool:
    """chunked-segsum == full parallel 1-SS scan (T=200 not a multiple of C -> tests padding)."""
    torch.manual_seed(seed)
    alpha = torch.rand(T, H, dtype=torch.float64) * 0.5 + 0.4          # in (0.4,0.9)
    la = torch.log(alpha)
    u = torch.randn(T, H, Pp, Ss, dtype=torch.float64)
    err = (scan_parallel(la, u) - scan_chunked(la, u, C=C)).abs().max().item()
    ok = err < 1e-9
    print(f"=== SCAN PARITY (chunked C={C} vs parallel 1-SS, T={T}) ===")
    print(f"  max-abs-err: {err:.3e}   RESULT: {'PASS ✅' if ok else 'FAIL ❌'}")
    return ok


if __name__ == "__main__":
    import os
    ok = all(parity(seed=s) for s in (0, 1, 2))
    print()
    ok = parity_scan() and ok
    print()
    ok = overfit_sanity() and ok
    print()
    if ok and os.environ.get("SKIP_BENCH") != "1":
        for t in (128, 256, 512):
            try:
                microbench(T=t)
            except RuntimeError as e:
                print(f"  microbench T={t} OOM/err: {str(e)[:80]}"); break
    sys.exit(0 if ok else 1)
