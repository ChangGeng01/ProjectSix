"""DUET handoff fidelity KILL-SWITCH (route step 1).

The flagship "State-Cache Reader" lives or dies on one question: if you PREFILL a prompt, SERIALIZE the recurrent
state (the cache artifact), then REHYDRATE it and DECODE a continuation — do you get the SAME continuation a monolithic
run would? The state seeds the recurrence at t=0 where error compounds, and the state is a lossy learned summary, so
this is NOT obvious. If it drifts, prefill-once-reuse-many is dead — and we learn it in an afternoon, host-side, no
training, before building any prefill/DUET/cloud machinery.

Design (isolates the ONE open variable = state serialization precision):
  - BOTH prefill and decode use the SAME per-token path (step_ref) → the chunked-scan-vs-sequential question (already
    PARITY-A proven ~1e-8) is OUT of scope here; weights stay fp32 → weight-quant (PARITY-B) is OUT of scope.
  - The ONLY thing varied is the precision the boundary 4-state (angle/ssm/kprev/vprev per layer) is cached at:
    fp32 (control, must be ~exact), fp16 (the deploy state precision), int8 (a compressed cache).
  - Metrics are CONTINUOUS (state rel-err, logit max-err over the continuation) → weight-quality-independent, so random
    weights are valid; argmax-agreement reported as a secondary (confidence-dependent) signal.

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_state_fidelity.py    Env: LAYERS(24) PROMPT(64) CONT(64) SEED(0)
"""
from __future__ import annotations

import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

DEV = "cpu"                                                   # fp32 reference math — CPU is exact + plenty fast here
H, P_, N, R, D = MT.H, MT.P, MT.N, MT.R, MT.D_MODEL
LAYERS = int(os.environ.get("LAYERS", "24"))
PROMPT = int(os.environ.get("PROMPT", "64"))
CONT = int(os.environ.get("CONT", "64"))
VOCAB = 4096                                                 # small toy vocab — fidelity metrics are weight-independent


def zero_states(L):
    return [[torch.zeros(H, N // 2), torch.zeros(H, P_, N), torch.zeros(H, R, N), torch.zeros(H, P_, R)] for _ in range(L)]


def run_steps(m, tokens, states):
    """Step each token through all layers' per-token step_ref, carrying the per-layer 4-state. Returns (logits, states)."""
    states = [list(s) for s in states]
    logits = []
    ew = m.embedding.weight
    for t in tokens.tolist():
        x = ew[t]
        for i, l in enumerate(m.layers):
            a, sm, k, v = states[i]
            x, a, sm, k, v = l.step_ref(x, a, sm, k, v)
            states[i] = [a, sm, k, v]
        logits.append(MT.rms(x, m.fw) @ ew.t())
    return torch.stack(logits), states


def quant_dequant(t, bits):
    if bits >= 32:
        return t
    if bits == 16:
        return t.to(torch.float16).to(torch.float32)
    qmax = (1 << (bits - 1)) - 1                             # int8 per-tensor symmetric round-trip (cache compression)
    scale = t.abs().max().clamp_min(1e-12) / qmax
    return (torch.round(t / scale).clamp(-qmax, qmax) * scale)


def serialize_states(states, bits):
    return [[quant_dequant(x, bits) for x in s] for s in states]


def main() -> None:
    torch.manual_seed(int(os.environ.get("SEED", "0")))
    m = MT.M(VOCAB, LAYERS).to(DEV).float().eval()
    seq = torch.randint(0, VOCAB, (PROMPT + CONT,))
    with torch.no_grad():
        # MONOLITHIC reference: one run over prompt+continuation, fp32, no serialization
        mono_logits, _ = run_steps(m, seq, zero_states(LAYERS))
        ref_cont = mono_logits[PROMPT:]
        ref_arg = ref_cont.argmax(-1)
        # PREFILL the prompt → boundary state (fp32)
        _, boundary = run_steps(m, seq[:PROMPT], zero_states(LAYERS))
        print(f"DUET state-fidelity | L={LAYERS} prompt={PROMPT} cont={CONT} | state≈"
              f"{sum(x.numel() for s in boundary for x in s) * 2 / 1e6:.1f} MB fp16/layer-set")
        print(f"{'cache prec':>10} | {'state rel-err':>13} | {'cont logit max-err':>18} | {'argmax agree':>12} | first-divergence@")
        for bits, name in [(32, "fp32"), (16, "fp16"), (8, "int8")]:
            rehyd = serialize_states(boundary, bits)
            serr = (sum(((q - o) ** 2).sum() for s, r in zip(boundary, rehyd) for o, q in zip(s, r)).sqrt()
                    / sum((o ** 2).sum() for s in boundary for o in s).sqrt()).item()
            dec_logits, _ = run_steps(m, seq[PROMPT:], rehyd)
            logit_err = (dec_logits - ref_cont).abs().max().item()
            agree = (dec_logits.argmax(-1) == ref_arg).float().mean().item()
            div = next((i for i in range(CONT) if dec_logits[i].argmax() != ref_arg[i]), CONT)
            print(f"{name:>10} | {serr:13.2e} | {logit_err:18.2e} | {agree:11.1%} | {div if div < CONT else 'none'}/{CONT}")
    print("\nREAD: fp32 must be ~0 (sanity). fp16 = the deploy state precision — small drift = cache OK. "
          "int8 = compressed cache — if argmax holds, the cache can be int8 (half size); if it drifts, keep fp16.")


if __name__ == "__main__":
    main()
