#!/usr/bin/env python3
"""Q4b — τ(K) sweep: Llamba-1B draft acceptance vs Llama-3.2-3B target across draft block sizes.

K=4 gave tau=3.298 with per-position acceptance RISING (0.78->0.84), so K=4 is not optimal.
This sweeps K to find where tau plateaus (the Saguaro block-size knob) and the max block efficiency.
Loads draft+target ONCE, reuses across K. Same greedy spec-decode logic as llamba_q4_acceptance.py.

Run from /tmp:  cd /tmp && /tmp/coreai-cv/bin/python /tmp/llamba_q4_ksweep.py
"""
from __future__ import annotations

import json
import sys
import time

import torch

TOOLS = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools"
sys.path.insert(0, TOOLS)
import llamba_to_coreai as L
import llamba_q4_acceptance as Q4  # reuse PROMPTS, TARGET_ID, N_GEN

K_LIST = [2, 4, 6, 8, 12]


def main() -> None:
    from huggingface_hub import hf_hub_download
    from safetensors.torch import load_file
    from transformers import AutoModelForCausalLM, AutoTokenizer

    torch.manual_seed(0)
    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"=== Q4b tau(K) sweep: Llamba-1B vs {Q4.TARGET_ID} (bf16/{dev})  N_GEN={Q4.N_GEN}  K={K_LIST} ===")

    cfg = L.cfg_from_json(json.load(open(hf_hub_download(L.HF_ID, "config.json"))))
    state = load_file(hf_hub_download(L.HF_ID, "model.safetensors"))
    draft = L.LlambaDecode(cfg).eval()
    L.load_real_weights(draft, state)
    tok = AutoTokenizer.from_pretrained(L.TOK_ID)
    t0 = time.time()
    target = AutoModelForCausalLM.from_pretrained(Q4.TARGET_ID, dtype=torch.bfloat16).to(dev).eval()
    print(f"    models loaded in {time.time()-t0:.1f}s\n")

    def draft_feed(t: int) -> int:
        with torch.no_grad():
            return int(draft(torch.tensor([[t]], dtype=torch.long)).view(-1).argmax())

    @torch.no_grad()
    def target_argmax(seq, base, n):
        lg = target(input_ids=torch.tensor([seq], device=dev), use_cache=False).logits[0]
        return [int(lg[base + j].argmax()) for j in range(n)]

    def run_battery(K: int):
        tot_gen = tot_fwd = tot_acc = 0
        for prompt in Q4.PROMPTS:
            ids = tok(prompt, return_tensors="pt").input_ids[0].tolist()
            draft.conv_all.zero_(); draft.ssm_all.zero_()
            for t in ids[:-1]:
                draft_feed(t)
            committed = list(ids)
            last = committed[-1]
            gen = 0
            while gen < Q4.N_GEN:
                snap = (draft.conv_all.clone(), draft.ssm_all.clone())
                props, cur = [], last
                for _ in range(K):
                    cur = draft_feed(cur); props.append(cur)
                base = len(committed) - 1
                targ = target_argmax(committed + props, base, K + 1)
                tot_fwd += 1
                a = 0
                for i in range(K):
                    if props[i] == targ[i]:
                        a += 1
                    else:
                        break
                new = props[:a] + [targ[a]]
                committed += new; gen += len(new); tot_gen += len(new); tot_acc += a
                draft.conv_all.copy_(snap[0]); draft.ssm_all.copy_(snap[1])
                draft_feed(last)
                for p in props[:a]:
                    draft_feed(p)
                last = targ[a]
        return tot_gen / max(1, tot_fwd), tot_acc / max(1, tot_fwd), tot_fwd

    rows = []
    for K in K_LIST:
        t1 = time.time()
        tau, mean_acc, fwd = run_battery(K)
        rows.append((K, tau, mean_acc))
        print(f"    K={K:2d}  tau={tau:.3f}  mean_accepted={mean_acc:.2f}/{K}  "
              f"accept_rate={mean_acc/K:.3f}  forwards={fwd}  ({time.time()-t1:.0f}s)")

    print("\n================ Q4b tau(K) ================")
    print("   K | tau (tokens/target-forward) | mean accepted/round | accept-rate")
    for K, tau, mean_acc in rows:
        print(f"  {K:2d} | {tau:6.3f}                      | {mean_acc:5.2f} / {K:<2d}        | {mean_acc/K:.3f}")
    best = max(rows, key=lambda r: r[1])
    print(f"  best block efficiency: tau={best[1]:.3f} at K={best[0]}")
    print("  (bf16 target = architectural upper bound; MLX 4-bit slightly lower; free-form continuation)")
    print("============================================")


if __name__ == "__main__":
    main()
