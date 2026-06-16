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

import torch
import torch.nn as nn
import torch.nn.functional as F

from mamba3_trainable import D_FF, D_MODEL, rms

H_ATTN = 16
D_HEAD = D_MODEL // H_ATTN                                  # 64; H_ATTN*D_HEAD = 1024
D_LATENT = 128                                             # cached per token; full KV = 2*H*D_HEAD = 2048 -> ~16x cut


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

    def forward_seq(self, x_seq):
        """Prefill/training: causal MLA over [T,D]. Returns (block out [T,D], latent cache c_kv [T,D_LATENT])."""
        T = x_seq.shape[0]
        h = rms(x_seq, self.attn_norm)
        q = self.q_proj(h).view(T, self.h, self.dh)
        c_kv = self.kv_down(h)                                            # [T, dc] = the cache
        k = self.k_up(c_kv).view(T, self.h, self.dh)
        v = self.v_up(c_kv).view(T, self.h, self.dh)
        scores = torch.einsum("thd,shd->hts", q, k) * self.scale          # [h,T,T]
        mask = torch.triu(torch.ones(T, T, dtype=torch.bool, device=x_seq.device), 1)
        a = scores.masked_fill(mask.unsqueeze(0), float("-inf")).softmax(-1)
        o = torch.einsum("hts,shd->thd", a, v).reshape(T, self.h * self.dh)
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
