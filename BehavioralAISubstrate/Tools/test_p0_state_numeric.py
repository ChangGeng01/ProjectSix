"""P0-2/3/4 (battery): the State-Cache Reader's precision floor at LONG T — does the cached 4-state survive fp16/int8/int4?

The carried angle is `new_angle = angle + dt*theta`, UNWRAPPED — it grows ~linearly with prompt length. cos/sin are 2pi-
periodic so fp32 is fine, BUT:
  P0-4: fp16 storage of a large unwrapped angle loses angular resolution (10-bit mantissa over a value ~O(100 rad)).
  P0-2/3: int8/int4 quant of a [0, ~100 rad] angle gives steps >> 2pi/256 -> cos/sin destroyed.
HYPOTHESIS + FIX under test: wrapping the stored angle to (-pi,pi] before quant is EXACTLY equivalent (cos/sin invariant
under 2pi shifts, and the next step's angle stays small) -> should recover int-quant. This sweeps precision x scope x wrap
over T to (a) find the floor, (b) prove the angle is the culprit, (c) prove the wrap fixes it. Reuses the verified DUET
path: M.prefill(prompt) -> serialize/quant -> M.run_ref(cont, init=state).

Run: ~/.venvs/coreai-cv/bin/python Tools/test_p0_state_numeric.py    Env: LAYERS(24) CONT(128) SEED(0)
"""
from __future__ import annotations

import math
import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

H, P_, N, R = MT.H, MT.P, MT.N, MT.R
LAYERS = int(os.environ.get("LAYERS", "24"))
CONT = int(os.environ.get("CONT", "128"))
VOCAB = 4096
TWO_PI = 2 * math.pi


def qd(t, bits):                                              # per-tensor symmetric quant-dequant
    if bits >= 32:
        return t
    if bits == 16:
        return t.to(torch.float16).to(torch.float32)
    qmax = (1 << (bits - 1)) - 1
    scale = t.abs().max().clamp_min(1e-12) / qmax
    return torch.round(t / scale).clamp(-qmax, qmax) * scale


def wrap(a):                                                  # (-pi, pi] — cos/sin invariant, kills unwrapped growth
    return (a + math.pi) % TWO_PI - math.pi


def quant_state(state, bits, scope):
    """scope: all | ang(only angle) | ang_wrap | all_wrap (wrap angle before quant)."""
    out = []
    for a, sm, k, v in state:                                # a=angle, sm=ssm, k=kprev(Brot), v=vprev(x_mimo)
        if scope == "ang":
            out.append([qd(a, bits), sm, k, v])
        elif scope == "ang_wrap":
            out.append([qd(wrap(a), bits), sm, k, v])
        elif scope == "all_wrap":
            out.append([qd(wrap(a), bits), qd(sm, bits), qd(k, bits), qd(v, bits)])
        else:                                                # all (angle unwrapped)
            out.append([qd(a, bits), qd(sm, bits), qd(k, bits), qd(v, bits)])
    return out


def main() -> None:
    torch.manual_seed(int(os.environ.get("SEED", "0")))
    m = MT.M(VOCAB, LAYERS).float().eval()
    cfgs = [(16, "all"), (8, "all"), (4, "all"), (8, "ang"), (8, "ang_wrap"), (4, "ang_wrap"), (8, "all_wrap"), (4, "all_wrap")]
    print(f"P0-2/3/4 — cached-state precision floor at long T (L={LAYERS}, cont={CONT}, argmax-agree vs fp32 monolithic):")
    for T in (512, 1024, 2048, 4096):
        seq = torch.randint(0, VOCAB, (T,))
        prompt, cont = seq[: T - CONT], seq[T - CONT:]
        with torch.no_grad():
            ref = m.run_ref(seq)[0][T - CONT:].argmax(-1)
            _, state = m.prefill(prompt)
            max_ang = max(s[0].abs().max().item() for s in state)
            row = {}
            for bits, scope in cfgs:
                dec = m.run_ref(cont, init=quant_state(state, bits, scope))[0]
                row[(bits, scope)] = (dec.argmax(-1) == ref).float().mean().item()
        print(f"\n  T={T:>4}  prompt={T - CONT}  max|angle|={max_ang:6.1f} rad  (= {max_ang / TWO_PI:.1f} turns; fp16 res ~{max_ang / 1024:.3f} rad)")
        print("        " + "  ".join(f"{b}b/{s}={row[(b, s)]:.0%}" for b, s in cfgs))
    print("\nREAD: 'all' (unwrapped) should DEGRADE as T grows / bits drop (esp. int8/int4); 'ang' isolates the angle as the "
          "culprit; '*_wrap' should RECOVER -> the State-Cache must wrap angle to (-pi,pi] before quant. fp16/all that holds "
          "at all T = the fp16 cache is safe regardless; if it degrades, fp16 needs the wrap too.")


if __name__ == "__main__":
    main()
