"""DUET full-handoff fidelity test (route step: the real prefill→decode seam).

The state-fidelity kill-switch (addendum 17) used step_ref for BOTH prefill and decode, isolating serialization. This
tests the ACTUAL DUET: the CHUNKED-SCAN prefill (M.prefill / Lyr.prefill_state) must emit the decode-compatible 4-state
that the per-token step_ref decode resumes from. PARITY-A only covered the ssm state; this covers the FULL handoff
(angle, ssm, kprev=Brot, vprev=x_mimo) end-to-end.

(A) Direct handoff PARITY: chunked-prefill boundary 4-state vs a step_ref-loop boundary 4-state over the same prompt.
(B) End-to-end: monolithic step_ref over [prompt+cont]  vs  prefill(prompt)→serialize→step_ref-decode(cont). fp32/fp16/int8.

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_duet_handoff.py    Env: LAYERS(24) PROMPT(64) CONT(128) SEED(0)
"""
from __future__ import annotations

import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

H, P_, N, R = MT.H, MT.P, MT.N, MT.R
LAYERS = int(os.environ.get("LAYERS", "24"))
PROMPT = int(os.environ.get("PROMPT", "64"))
CONT = int(os.environ.get("CONT", "128"))
VOCAB = 4096


def stepref_prompt_state(m, toks):
    """Monolithic per-token step_ref over the prompt → the boundary 4-state per layer (the ground-truth handoff)."""
    st = [[torch.zeros(H, N // 2), torch.zeros(H, P_, N), torch.zeros(H, R, N), torch.zeros(H, P_, R)] for _ in m.layers]
    ew = m.embedding.weight
    for t in toks.tolist():
        x = ew[t]
        for li, l in enumerate(m.layers):
            x, a, sm, k, v = l.step_ref(x, *st[li])
            st[li] = [a, sm, k, v]
    return st


def qd(t, bits):
    if bits >= 32:
        return t
    if bits == 16:
        return t.to(torch.float16).to(torch.float32)
    qmax = (1 << (bits - 1)) - 1
    scale = t.abs().max().clamp_min(1e-12) / qmax
    return torch.round(t / scale).clamp(-qmax, qmax) * scale


def relerr(a, b):
    return ((a - b).pow(2).sum().sqrt() / b.pow(2).sum().sqrt().clamp_min(1e-12)).item()


def main() -> None:
    torch.manual_seed(int(os.environ.get("SEED", "0")))
    m = MT.M(VOCAB, LAYERS).float().eval()
    seq = torch.randint(0, VOCAB, (PROMPT + CONT,))
    with torch.no_grad():
        # (A) direct handoff parity: chunked-prefill 4-state vs step_ref-prefill 4-state
        ref_st = stepref_prompt_state(m, seq[:PROMPT])
        _, chunk_st = m.prefill(seq[:PROMPT])
        names = ["angle", "ssm", "kprev", "vprev"]
        errs = {n: max(relerr(chunk_st[li][j], ref_st[li][j]) for li in range(LAYERS)) for j, n in enumerate(names)}
        print(f"(A) chunked-prefill vs step_ref 4-state handoff PARITY (max rel-err over {LAYERS} layers):")
        for n in names:
            print(f"      {n:>6}: {errs[n]:.2e}")
        worst = max(errs.values())
        print(f"      → handoff parity {'PASS' if worst < 1e-3 else 'FAIL'} (worst {worst:.2e}; PARITY-A ssm ~1e-8 baseline)")
        # (B) end-to-end DUET decode vs monolithic, across cache precisions
        mono, _ = m.run_ref(seq)
        ref_cont = mono[PROMPT:]; ref_arg = ref_cont.argmax(-1)
        print(f"\n(B) end-to-end DUET (chunked-prefill→serialize→step_ref-decode) vs monolithic | prompt={PROMPT} cont={CONT}")
        print(f"{'cache':>6} | {'cont logit max-err':>18} | {'argmax agree':>12} | first-div@")
        for bits, nm in [(32, "fp32"), (16, "fp16"), (8, "int8")]:
            st = [[qd(x, bits) for x in s] for s in chunk_st]
            dec, _ = m.run_ref(seq[PROMPT:], init=st)
            le = (dec - ref_cont).abs().max().item()
            ag = (dec.argmax(-1) == ref_arg).float().mean().item()
            dv = next((i for i in range(CONT) if dec[i].argmax() != ref_arg[i]), CONT)
            print(f"{nm:>6} | {le:18.2e} | {ag:11.1%} | {dv if dv < CONT else 'none'}/{CONT}")
    print("\nREAD: (A) all 4 states must match step_ref (~PARITY-A) — esp. kprev/vprev/angle, never tested before. "
          "(B) fp32 ~exact = the chunked-prefill→decode seam is sound; fp16/int8 = the cached-state DUET.")


if __name__ == "__main__":
    main()
