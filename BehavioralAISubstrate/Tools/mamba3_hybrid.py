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


def _sample(logit, temperature: float, top_p: float, gen=None) -> int:
    """Greedy (temperature=0) or nucleus sampling (temperature>0 + top_p). Used by HybridM.generate."""
    if temperature <= 0.0:
        return int(logit.argmax())
    probs = (logit.float() / temperature).softmax(-1)
    if top_p < 1.0:
        sp, idx = probs.sort(descending=True)
        keep = (sp.cumsum(-1) - sp) < top_p                # keep tokens whose cumulative mass (exclusive) < top_p; ≥1 token
        sp = torch.where(keep, sp, torch.zeros_like(sp))
        sp = sp / sp.sum()
        return int(idx[torch.multinomial(sp, 1, generator=gen)])
    return int(torch.multinomial(probs, 1, generator=gen))


def resolve_ckpt(default_vocab: int, layers: int):
    """Shared by the hybrid converters (云前audit fix): read the CKPT env → (vocab, state_dict|None). The checkpoint is
    AUTHORITATIVE on vocab — closes the 4096-vs-Granite-100352 mismatch (the cloud trains on the Granite tokenizer's vocab).
    No CKPT → (env VOCAB or default, None) = the random-weight op-graph/speed probe. Fail-closed on arch/layer mismatch."""
    import os
    p = os.environ.get("CKPT", "")
    if not p:
        if os.environ.get("FORCE_RANDOM") == "1":
            return int(os.environ.get("VOCAB", str(default_vocab))), None
        raise SystemExit("CKPT required for a real asset (refusing a silent random-weight export); "
                         "set CKPT=/path/ckpt_best.pt, or FORCE_RANDOM=1 for an op-graph/speed probe")
    c = torch.load(p, map_location="cpu")
    assert c.get("arch") == "hybrid", f"CKPT arch={c.get('arch')!r} is not 'hybrid' — wrong converter for this checkpoint"
    assert c.get("layers", layers) == layers, f"CKPT layers={c.get('layers')} != LAYERS={layers} — would deploy an incoherent graph"
    exp_mla = sorted(q for q in MLA_POSITIONS if q < layers)          # the placement HybridM(layers) will build
    got_mla = c.get("mla_positions")
    assert got_mla is None or list(got_mla) == exp_mla, \
        f"CKPT mla_positions={got_mla} != deploy {exp_mla} — MLA placement mismatch (incoherent graph)"
    exp_cfg = [MT.D_MODEL, MT.H, MT.P, MT.N, MT.R]
    cfg = c.get("config")
    assert cfg is None or list(cfg) == exp_cfg, \
        f"CKPT config={list(cfg) if cfg else cfg} != module {exp_cfg} — shape mismatch (rebuild would be incoherent)"
    assert not c.get("mla_rope", False), \
        "CKPT was trained with MLA_ROPE=1 but this converter is NoPE — deploying it would be SEMANTICALLY INCONSISTENT. " \
        "Implement the matching RoPE in mamba3_hybrid_decode_deploy.mla_step_fixed first (ARCH-3 deploy-side is gated)."
    return c.get("vocab", default_vocab), c["model"]


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

    def prefill(self, tokens, init=None):
        """DUET prefill: returns (final hidden seq [T,D], heterogeneous per-layer handoff state).
        RESUMABLE (PREFIX STATE REUSE): `init` = a prior prefill's per-layer handoff → prefill(suffix, init=prefill(prefix))
        == prefill(prefix+suffix). Each Mamba layer carries its O(1) 4-state; each MLA layer carries its O(ctx) latent cache."""
        x = self.embedding.weight[tokens]
        states = []
        for i, lyr in enumerate(self.layers):
            li = init[i][1] if init is not None else None
            if self._is_mla(i):
                x, cache = lyr.forward_seq(x, kv_init=li)
                states.append(("mla", cache))
            else:
                x, st = lyr.prefill_state(x, init=li)
                states.append(("mamba", st))
        return x, states

    def run_twin(self, tokens, collect_ssm: bool = False, return_hiddens: bool = False):
        """Parallel TRAINING forward over a sequence → (logits [T,V], extra). Mirrors MT.M.run_twin so the distill
        harness is arch-agnostic: Mamba layers via Lyr.forward_seq, MLA layers via MLABlock.forward_seq, then the tied head."""
        x = self.embedding.weight[tokens]
        extra = []
        for i, lyr in enumerate(self.layers):
            if self._is_mla(i):
                x, _ = lyr.forward_seq(x)
            else:
                x, ssm_seq, _ = lyr.forward_seq(x)
                if collect_ssm:
                    extra.append(ssm_seq)
            if return_hiddens:
                extra.append(x)
        return self.head(x), extra

    def generate(self, prompt, max_new, temperature: float = 0.0, top_p: float = 1.0, eos=None, gen=None):
        """完全闭环 free-running decode: prefill the prompt, then FEED EACH SAMPLED TOKEN BACK (not teacher-forced).
        temperature=0 → greedy argmax (deterministic); temperature>0 + top_p → nucleus sampling. Stops at `eos` or max_new."""
        with torch.no_grad():
            h, st = self.prefill(prompt)
            nxt = _sample(self.head(h[-1]), temperature, top_p, gen)
            out = [nxt]
            for _ in range(max_new - 1):
                if eos is not None and nxt == eos:
                    break
                x = self.embedding.weight[nxt]
                for i, lyr in enumerate(self.layers):
                    tag, s = st[i]
                    if tag == "mla":
                        x, nc = lyr.step(x, s); st[i] = ("mla", nc)
                    else:
                        x, a, sm, k, v = lyr.step_ref(x, *s); st[i] = ("mamba", (a, sm, k, v))
                nxt = _sample(self.head(x), temperature, top_p, gen)
                out.append(nxt)
            return out

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
