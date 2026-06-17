"""Multi-head Latent Attention (MLA) block — the hybrid's DENSE-COVERAGE operator (4 of 24 layers @ L6/12/18/23).

WHY MLA (not full-MHA / sliding-window / NSA): the binding on-device constraint is KV memory. MLA caches a single
D_LATENT-wide LATENT per token (down-projected), re-expanding to per-head k,v only at compute -> ~16x smaller KV than full
MHA. NoPE (the Granite teacher applies no rotary on attention) gives the SIMPLEST MLA: down -> softmax -> up, with no
decoupled-rope dimension (d_rope=0). The 20 Mamba-3 layers stay O(1) state; these 4 MLA layers add a BOUNDED O(context) KV
for the dense token-mixing the SSM lacks.

Mirrors the Mamba `Lyr` interface so it drops into the hybrid M: pre-norm mixer -> residual -> SwiGLU MLP -> residual,
with `forward_seq` (prefill/training, returns the latent cache) and `step` (decode, attends over the cached latents).

CONTRACTIVITY NOTE: the Mamba state is contractive (quant errors DECAY — addendum 17). MLA decode is NOT — every cached
latent is re-read by softmax each step, so a latent-cache quant error never decays (though softmax convexity bounds it).
That is why the MLA latent-cache quant floor is tested on its own (test_p0_12_mla_kv.py).
"""
from __future__ import annotations

import math
import os

import torch
import torch.nn as nn
import torch.nn.functional as F

from mamba3_trainable import D_FF, D_MODEL, rms

H_ATTN = 16
D_HEAD = D_MODEL // H_ATTN                                  # 64; H_ATTN*D_HEAD = 1024
D_LATENT = 128                                             # cached per token; full KV = 2*H*D_HEAD = 2048 -> ~16x cut
ROPE_THETA = 10000.0


def _use_rope() -> bool:
    """ARCH-3: opt-in RoPE on MLA q/k (env MLA_ROPE=1). Default OFF = the audited NoPE (deploy + 349 tests unchanged).
    Read at call time (like LEAN_MLP) so it's togglable in tests. NOTE: enabling it for a SHIPPED ckpt also requires the
    matching RoPE in mamba3_hybrid_decode_deploy.mla_step_fixed — gated for an on-device A/B once it wins a cloud quality A/B."""
    return os.environ.get("MLA_ROPE") == "1"


def _rope_cos_sin(positions, dh: int, device, dtype):
    """Standard rotate-half RoPE tables for absolute `positions` [N] → (cos, sin) [N, dh]. Computed in fp32 for stability."""
    half = dh // 2
    inv_freq = 1.0 / (ROPE_THETA ** (torch.arange(0, half, device=device, dtype=torch.float32) / half))
    ang = positions.to(torch.float32).unsqueeze(-1) * inv_freq.unsqueeze(0)       # [N, half]
    cos = torch.cat([ang.cos(), ang.cos()], -1).to(dtype)                         # [N, dh]
    sin = torch.cat([ang.sin(), ang.sin()], -1).to(dtype)
    return cos, sin


def _rotate_half(x):
    half = x.shape[-1] // 2
    return torch.cat([-x[..., half:], x[..., :half]], -1)


def _apply_rope(x, cos, sin):
    """x [N, h, dh], cos/sin [N, dh] → rotate per position, broadcast over heads. Position-dependent at COMPUTE time, so
    the cached LATENT stays position-independent (MLA's compression is preserved)."""
    return x * cos.unsqueeze(1) + _rotate_half(x) * sin.unsqueeze(1)


class MLABlock(nn.Module):
    def __init__(self, d: int = D_MODEL, h: int = H_ATTN, dh: int = D_HEAD, dc: int = D_LATENT) -> None:
        super().__init__()
        self.h, self.dh, self.dc, self.scale = h, dh, dc, 1.0 / math.sqrt(dh)
        self.attn_norm = nn.Parameter(torch.ones(d))
        self.q_proj = nn.Linear(d, h * dh, bias=False)
        self.kv_down = nn.Linear(d, dc, bias=False)         # -> latent (the CACHED quantity)
        self.k_up = nn.Linear(dc, h * dh, bias=False)       # latent -> per-head keys
        self.v_up = nn.Linear(dc, h * dh, bias=False)       # latent -> per-head values
        self.o_proj = nn.Linear(h * dh, d, bias=False)
        self.mlp_norm = nn.Parameter(torch.ones(d))         # SwiGLU MLP (mirror Lyr.mlp)
        self.mlp_gate = nn.Linear(d, D_FF, bias=False)
        self.mlp_up = nn.Linear(d, D_FF, bias=False)
        self.mlp_down = nn.Linear(D_FF, d, bias=False)
        for m in (self.q_proj, self.kv_down, self.k_up, self.v_up, self.o_proj, self.mlp_gate, self.mlp_up, self.mlp_down):
            nn.init.normal_(m.weight, std=0.02)             # standard LM init (default kaiming overdrives the residual)

    def _mlp(self, x):
        hh = rms(x, self.mlp_norm)
        return self.mlp_down(F.silu(self.mlp_gate(hh)) * self.mlp_up(hh))

    def forward_seq(self, x_seq, kv_init=None):
        """Prefill/training: causal MLA over [Ts,D]. Returns (block out [Ts,D], FULL latent cache [Tp+Ts, D_LATENT]).
        RESUMABLE (PREFIX STATE REUSE): `kv_init` [Tp,dc] = a prefix's cached latents — the suffix attends over
        [prefix; suffix] (MLA is O(ctx), unlike the Mamba O(1) 4-state). kv_init=None reduces to plain causal attention."""
        Ts = x_seq.shape[0]
        h = rms(x_seq, self.attn_norm)
        q = self.q_proj(h).view(Ts, self.h, self.dh)                     # only the suffix queries
        c_kv_s = self.kv_down(h)                                          # [Ts, dc] suffix latents
        c_kv = c_kv_s if kv_init is None else torch.cat([kv_init, c_kv_s], 0)   # [Tp+Ts, dc] FULL cache
        S = c_kv.shape[0]
        Tp = S - Ts
        k = self.k_up(c_kv).view(S, self.h, self.dh)
        v = self.v_up(c_kv).view(S, self.h, self.dh)
        if _use_rope():                                                   # ARCH-3: rotate q by global pos, k by slot pos (cache stays raw latent)
            qc, qs = _rope_cos_sin(Tp + torch.arange(Ts, device=x_seq.device), self.dh, x_seq.device, q.dtype)
            kc, ks = _rope_cos_sin(torch.arange(S, device=x_seq.device), self.dh, x_seq.device, k.dtype)
            q, k = _apply_rope(q, qc, qs), _apply_rope(k, kc, ks)
        scores = torch.einsum("thd,shd->hts", q, k) * self.scale          # [h,Ts,S]
        keypos = torch.arange(S, device=x_seq.device).view(1, S)
        qpos = (Tp + torch.arange(Ts, device=x_seq.device)).view(Ts, 1)   # suffix query j is global position Tp+j
        mask = keypos > qpos                                              # causal: key s allowed iff s <= Tp+j
        a = scores.masked_fill(mask.unsqueeze(0), float("-inf")).softmax(-1)
        o = torch.einsum("hts,shd->thd", a, v).reshape(Ts, self.h * self.dh)
        x1 = x_seq + self.o_proj(o)
        return x1 + self._mlp(x1), c_kv

    def step(self, x_t, cache):
        """Decode: x_t [D], cache [S,dc] (prior latents) or None. Returns (block out [D], new cache [S+1,dc])."""
        h = rms(x_t.unsqueeze(0), self.attn_norm)                         # [1,D]
        q = self.q_proj(h).view(1, self.h, self.dh)
        c_t = self.kv_down(h)                                             # [1,dc]
        c_kv = c_t if cache is None else torch.cat([cache, c_t], 0)       # [S+1,dc]
        k = self.k_up(c_kv).view(-1, self.h, self.dh)
        v = self.v_up(c_kv).view(-1, self.h, self.dh)
        if _use_rope():                                                   # ARCH-3: q at the new token's pos, k at slot positions (≡ forward_seq)
            pos_q = 0 if cache is None else cache.shape[0]
            qc, qs = _rope_cos_sin(torch.tensor([pos_q], device=x_t.device), self.dh, x_t.device, q.dtype)
            kc, ks = _rope_cos_sin(torch.arange(c_kv.shape[0], device=x_t.device), self.dh, x_t.device, k.dtype)
            q, k = _apply_rope(q, qc, qs), _apply_rope(k, kc, ks)
        scores = torch.einsum("thd,shd->hts", q, k) * self.scale          # [h,1,S+1] — decode attends ALL (causal auto)
        a = scores.softmax(-1)
        o = torch.einsum("hts,shd->thd", a, v).reshape(1, self.h * self.dh)
        x1 = x_t + self.o_proj(o).squeeze(0)
        return x1 + self._mlp(x1.unsqueeze(0)).squeeze(0), c_kv


class MLAStack(nn.Module):
    """Pure-MLA test/eval model (embedding -> N MLABlocks -> final RMSNorm -> tied head). Stand-in for the hybrid's
    attention path; used by test_p0_12_mla_kv.py to measure the latent-cache quant floor end-to-end."""

    def __init__(self, vocab: int, layers: int) -> None:
        super().__init__()
        self.embedding = nn.Embedding(vocab, D_MODEL)
        self.layers = nn.ModuleList([MLABlock() for _ in range(layers)])
        self.fw = nn.Parameter(torch.ones(D_MODEL))
        nn.init.normal_(self.embedding.weight, std=0.02)

    def head(self, x):
        return rms(x, self.fw) @ self.embedding.weight.t()

    def forward_seq(self, tokens):
        x = self.embedding.weight[tokens]
        caches = []
        for lyr in self.layers:
            x, c = lyr.forward_seq(x)
            caches.append(c)
        return self.head(x), caches

    def prefill(self, tokens):
        """Returns (final hidden seq -> logits, per-layer latent KV cache) — the DUET prefill for the attention path."""
        return self.forward_seq(tokens)

    def decode(self, tokens, caches):
        """Decode `tokens` resuming from per-layer latent caches. Returns (logits [T,V], updated caches)."""
        cur = [c for c in caches]
        outs = []
        for tok in tokens.tolist():
            x = self.embedding.weight[tok]
            for li, lyr in enumerate(self.layers):
                x, cur[li] = lyr.step(x, cur[li])
            outs.append(self.head(x.unsqueeze(0))[0])
        return torch.stack(outs), cur
