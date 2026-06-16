"""STEP 10 — verify[1,K] self-speculation equivalence (the 二象 draft↔target loop). Greedy speculative decode is EXACT iff
the target's BATCHED verify of K tokens produces the SAME per-position logits as K sequential decode steps. The hybrid
already expresses verify[1,K] as a RESUMED forward: `h, _ = m.prefill(K_toks, init=state); logits = m.head(h)` (prefill
returns the full hidden seq; STEP 5 made it resume from a decode state). This proves that batched verify == sequential
step_ref decode, so a ≤8L draft's K tokens can be verified by the 24L target in ONE pass with byte-identical greedy output.
Weight-independent (an algorithmic parity, like PARITY-A).

Run: ~/.venvs/coreai-cv/bin/python Tools/test_verify_kstep.py
"""
from __future__ import annotations

import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY


def main() -> None:
    torch.manual_seed(0)
    V, L, PROMPT, K = 4096, 24, 48, 16
    m = HY.HybridM(V, L).float().eval()
    seq = torch.randint(0, V, (PROMPT + K,))
    prompt, draft = seq[:PROMPT], seq[PROMPT:]                         # `draft` = the K tokens a draft model proposed
    with torch.no_grad():
        _, state = m.prefill(prompt)
        seq_logits = m.run_ref(draft, init=state)                     # (a) K SEQUENTIAL step_ref decodes from the state
        h, _ = m.prefill(draft, init=state)                           # (b) ONE batched verify[1,K] forward (resumed)
        ver_logits = m.head(h)
    err = (seq_logits - ver_logits).abs().max().item()
    agree = (seq_logits.argmax(-1) == ver_logits.argmax(-1)).float().mean().item()
    # greedy acceptance: longest prefix where the target's prediction matches the draft's next token
    tgt_pred = ver_logits.argmax(-1)
    accept = 0
    for j in range(K - 1):
        if tgt_pred[j].item() == draft[j + 1].item():
            accept += 1
        else:
            break
    ok = err < 1e-3 and agree > 0.999
    print(f"STEP-10 verify[1,K] self-spec (K={K}, {L}L hybrid, from a {PROMPT}-tok prefill state):")
    print(f"  batched verify vs K sequential step_ref: logit max-err {err:.2e}, argmax-agree {agree:.0%} -> {'PASS' if ok else 'FAIL'}")
    print(f"  (greedy acceptance of this random draft: {accept}/{K - 1} — accept count is weight/draft-dependent; the EQUALITY above is what makes spec EXACT)")
    print("READ: PASS = the target's batched verify[1,K] reproduces sequential decode → greedy speculative decode is byte-exact. "
          "The 二象 ≤8L-draft ∥ 24L-verify loop is algorithmically sound (acceptance RATE needs a trained dract+target to measure).")


if __name__ == "__main__":
    main()
