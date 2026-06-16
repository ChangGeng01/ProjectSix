"""Hybrid two-state DUET handoff — the route's integration test. Does the FULL 24L hybrid (20 Mamba-3 + 4 MLA) prefill→
decode reproduce the monolithic decode, AND survive int8 State-Cache serialization across BOTH state types at once?

(A) fp32 parity: prefill(prompt) → decode(cont) vs monolithic run_ref([prompt+cont])[prompt:]. raw + angle-wrapped (lossless).
(B) int8 State-Cache: serialize the heterogeneous handoff (Mamba 4-state, angle-wrapped + MLA latent) at int8 → decode.
    int8-nowrap included to show the wrap is free insurance (matters at long prompts where the angle grows).
Reports the cache size split (Mamba O(1) vs MLA O(context)).

Run: ~/.venvs/coreai-cv/bin/python Tools/test_hybrid_duet.py    Env: LAYERS(24) PROMPT(512) CONT(128) SEED(0)
"""
from __future__ import annotations

import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY
import mamba3_mla as MLA
from mamba3_trainable import H, N, P, R


def qd(t, bits):
    if bits >= 32:
        return t
    if bits == 16:
        return t.to(torch.float16).to(torch.float32)
    qmax = (1 << (bits - 1)) - 1
    scale = t.abs().max().clamp_min(1e-12) / qmax
    return torch.round(t / scale).clamp(-qmax, qmax) * scale


def quant_nowrap(state, bits):                              # quant every tensor incl. the RAW (unwrapped) angle
    out = []
    for tag, s in state:
        out.append((tag, tuple(qd(t, bits) for t in s)) if tag == "mamba" else ("mla", qd(s, bits)))
    return out


def main() -> None:
    torch.manual_seed(int(os.environ.get("SEED", "0")))
    V, L = 4096, int(os.environ.get("LAYERS", "24"))
    PROMPT, CONT = int(os.environ.get("PROMPT", "512")), int(os.environ.get("CONT", "128"))
    m = HY.HybridM(V, L).float().eval()
    seq = torch.randint(0, V, (PROMPT + CONT,))
    with torch.no_grad():
        mono = m.run_ref(seq)[PROMPT:]
        refarg = mono.argmax(-1)
        _, state = m.prefill(seq[:PROMPT])
        n_mla = len(m.mla_pos)
        mam_floats = (L - n_mla) * (H * (N // 2) + H * P * N + H * R * N + H * P * R)
        mla_floats = n_mla * MLA.D_LATENT * PROMPT
        print(f"Hybrid DUET ({L}L = {L - n_mla} Mamba + {n_mla} MLA @ {sorted(m.mla_pos)}; prompt={PROMPT} cont={CONT})")
        print(f"  int8 State-Cache size: Mamba O(1) {mam_floats / 1e6:.2f}MB + MLA O(ctx) {mla_floats / 1e6:.2f}MB "
              f"(@{PROMPT} tok) = {(mam_floats + mla_floats) / 1e6:.2f}MB total\n")
        print(f"{'config':>14} | {'logit max-err':>13} | {'argmax-agree':>12} | first-div@")
        configs = [
            ("fp32 raw", state),
            ("fp32 wrap", HY.cache_serialize_state_hybrid(state)),
            ("int8 wrap", HY.cache_serialize_state_hybrid(state, quant=lambda t: qd(t, 8))),
            ("int8 nowrap", quant_nowrap(state, 8)),
            ("int4 wrap", HY.cache_serialize_state_hybrid(state, quant=lambda t: qd(t, 4))),
        ]
        for name, st in configs:
            dec = m.run_ref(seq[PROMPT:], init=st)
            le = (dec - mono).abs().max().item()
            ag = (dec.argmax(-1) == refarg).float().mean().item()
            dv = next((i for i in range(CONT) if dec[i].argmax() != refarg[i]), CONT)
            print(f"{name:>14} | {le:13.2e} | {ag:11.0%} | {dv if dv < CONT else 'none'}/{CONT}")
    print("\nREAD: fp32 raw≈wrap≈exact = the two-state handoff composes (Mamba 4-state + MLA latent both reproduce monolithic). "
          "int8 wrap = the shippable flagship cache; it should beat int8 nowrap at long prompts. int4 expected to degrade "
          "(MLA non-contractive, addendum 21). The Mamba state is O(1) (prompt-independent); only the MLA latent grows with ctx.")


if __name__ == "__main__":
    main()
