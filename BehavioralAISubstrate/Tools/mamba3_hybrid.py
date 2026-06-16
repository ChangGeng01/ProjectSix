"""Hybrid Mamba-3 + MLA model — the route's 24L backbone: 20 Mamba-3 (`MT.Lyr`) + 4 MLA (`MLA.MLABlock`) @ L6/12/18/23.

The 20 SSM layers carry O(1) recurrent state (ANE-friendly, contractive); the 4 MLA layers add bounded O(context) latent KV
for the dense token-mixing the SSM lacks (RAG recall). DUET prefill/decode is uniform across both: `prefill(prompt)` emits a
HETEROGENEOUS per-layer handoff (("mamba", 4-state) | ("mla", latent cache)); `run_ref(cont, init=state)` resumes it,
dispatching per layer type. The State-Cache stores this combined handoff (Mamba 4-state O(1) + MLA latent O(context)).

State-Cache floor (battery addenda 20/21): serialize via `cache_serialize_state_hybrid` — wrap each Mamba angle to (-pi,pi]
(lossless) and quantize at int8 (the MLA latent is non-contractive → int4 breaks it, so int8 is the unified floor).
"""
from __future__ import annotations

import torch
import torch.nn as nn

import mamba3_mla as MLA
import mamba3_trainable as MT
from mamba3_trainable import H, N, P, R, rms

MLA_POSITIONS = (6, 12, 18, 23)                            # 4 of 24; spaced so SSM blocks dominate between attn re-mixes


class HybridM(nn.Module):
    def __init__(self, vocab: int, layers: int = 24, mla_positions=MLA_POSITIONS) -> None:
        super().__init__()
        self.embedding = nn.Embedding(vocab, MT.D_MODEL)
        self.mla_pos = {p for p in mla_positions if p < layers}
        self.layers = nn.ModuleList([MLA.MLABlock() if i in self.mla_pos else MT.Lyr() for i in range(layers)])
        self.fw = nn.Parameter(torch.ones(MT.D_MODEL))
        self._init_weights(layers)

    def _is_mla(self, i: int) -> bool:
        return i in self.mla_pos

    def _init_weights(self, nl: int) -> None:
        for mod in self.modules():
            if isinstance(mod, (nn.Linear, nn.Embedding)):
                nn.init.normal_(mod.weight, 0.0, 0.02)
        with torch.no_grad():
            scale = 1.0 / (2 * nl) ** 0.5                  # GPT-2 residual scaling on residual-writing projections
            for i, lyr in enumerate(self.layers):
                (lyr.o_proj if self._is_mla(i) else lyr.out_proj).weight.mul_(scale)
                lyr.mlp_down.weight.mul_(scale)

    def head(self, x):
        return rms(x, self.fw) @ self.embedding.weight.t()

    def _zero_state(self):
        ew = self.embedding.weight                                       # inherit device/dtype (HALF=1/MPS fp16 baseline)
        z = lambda *s: torch.zeros(*s, device=ew.device, dtype=ew.dtype)
        out = []
        for i in range(len(self.layers)):
            if self._is_mla(i):
                out.append(("mla", None))
            else:
                out.append(("mamba", (z(H, N // 2), z(H, P, N), z(H, R, N), z(H, P, R))))
        return out

    def prefill(self, tokens):
        """DUET prefill: returns (final hidden seq [T,D], heterogeneous per-layer handoff state)."""
        x = self.embedding.weight[tokens]
        states = []
        for i, lyr in enumerate(self.layers):
            if self._is_mla(i):
                x, cache = lyr.forward_seq(x)
                states.append(("mla", cache))
            else:
                x, st = lyr.prefill_state(x)
                states.append(("mamba", st))
        return x, states

    def run_ref(self, tokens, init=None):
        """Per-token decode, resuming from `init` (heterogeneous handoff) or zero. Returns logits [T,V]."""
        st = [(tag, (list(s) if tag == "mamba" else s)) for tag, s in (init if init is not None else self._zero_state())]
        logits = []
        for tok in tokens.tolist():
            x = self.embedding.weight[tok]
            for i, lyr in enumerate(self.layers):
                tag, s = st[i]
                if tag == "mla":
                    x, newc = lyr.step(x, s)
                    st[i] = ("mla", newc)
                else:
                    x, a, ss, k, v = lyr.step_ref(x, *s)
                    st[i] = ("mamba", (a, ss, k, v))
            logits.append(self.head(x))
        return torch.stack(logits, 0)


def cache_serialize_state_hybrid(state, quant=None):
    """Canonical hybrid State-Cache serialize: wrap each Mamba angle to (-pi,pi] (lossless), pass MLA latents through.
    `quant(t)` (optional) is applied to every stored tensor AFTER the wrap (e.g. int8 quant-dequant). int8 is the floor."""
    q = quant if quant is not None else (lambda t: t)
    out = []
    for tag, s in state:
        if tag == "mamba":
            a, sm, k, v = s
            out.append(("mamba", (q(MT.cache_serialize_state([[a, sm, k, v]])[0][0]), q(sm), q(k), q(v))))
        else:
            out.append(("mla", q(s)))
    return out
