"""STEP 5 — resumable prefill (Context Compiler's PREFIX STATE REUSE). Proves prefill(suffix, init=prefill(prefix)) ==
prefill(prefix+suffix): a cached prefix's boundary handoff RESUMES exactly, so the StateLake router's "reuse N tokens,
prefill only the suffix" plan is EXECUTABLE (not just identifiable). Mamba layers carry the O(1) 4-state; MLA layers carry
the O(ctx) latent cache. Also checks backward-compat (init=None unchanged).

Run: ~/.venvs/coreai-cv/bin/python Tools/test_resumable_prefill.py
"""
from __future__ import annotations

import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY


def relerr(a, b):
    return ((a - b).pow(2).sum().sqrt() / b.pow(2).sum().sqrt().clamp_min(1e-12)).item()


def main() -> None:
    torch.manual_seed(0)
    V, L = 4096, int(os.environ.get("LAYERS", "24"))
    PRE, SUF, CONT = 48, 32, 24
    m = HY.HybridM(V, L).float().eval()
    seq = torch.randint(0, V, (PRE + SUF + CONT,))
    suffix, cont = seq[PRE:PRE + SUF], seq[PRE + SUF:]
    with torch.no_grad():
        _, full = m.prefill(seq[:PRE + SUF])                      # monolithic prefix+suffix (init=None — also the back-compat path)
        _, sp = m.prefill(seq[:PRE])                              # prefix only
        _, res = m.prefill(suffix, init=sp)                       # RESUME from the cached prefix state

        worst, where = 0.0, ""
        for i, ((tf, sf), (tr, sr)) in enumerate(zip(full, res)):
            if tf == "mamba":
                for nm, a, b in zip(("angle", "ssm", "kprev", "vprev"), sr, sf):
                    e = relerr(a, b)
                    if e > worst:
                        worst, where = e, f"L{i}.{nm}"
            else:
                e = relerr(sr, sf)                                # MLA full cache [PRE+SUF, dc]
                if e > worst:
                    worst, where = e, f"L{i}.mla(shape {tuple(sr.shape)} vs {tuple(sf.shape)})"
        af = m.run_ref(cont, init=full).argmax(-1)
        ar = m.run_ref(cont, init=res).argmax(-1)
        agree = (af == ar).float().mean().item()
    ok = worst < 1e-3 and agree > 0.999
    print(f"STEP-5 resumable prefill (PRE={PRE} SUF={SUF} CONT={CONT}, {L}L):")
    print(f"  boundary-state worst rel-err = {worst:.2e} @ {where}")
    print(f"  decode-from-resumed vs decode-from-monolithic argmax-agree = {agree:.0%}")
    print(f"  -> {'PASS' if ok else 'FAIL'}")
    print("READ: PASS = a cached prefix RESUMES exactly (Mamba 4-state + MLA latent) → the StateLake router's reuse plan is now EXECUTABLE; "
          "prefix-reuse / fork-and-extend / streaming prefill are unblocked.")


if __name__ == "__main__":
    main()
