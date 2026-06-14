#!/usr/bin/env python3
"""Q4 — Llamba-1B DRAFT acceptance rate vs a real Llama-3.2-3B TARGET (greedy spec-decode).

This is the genuinely-open risk: we proved Llamba's .aimodel matches the fp32 REFERENCE 24/24,
but never measured how often its proposed tokens are ACCEPTED by the actual 3B target — and
acceptance (block efficiency tau = committed tokens / target forwards) is the entire speedup lever.

Draft : LlambaDecode (fp32, real Cartesia weights — the faithful port), recurrent state snapshot/
        restored on partial accept (exact rewind).
Target: unsloth/Llama-3.2-3B-Instruct (bf16, MPS) — same Llama-3 tokenizer / vocab 128256.
        Full-forward argmax verification each round (robust; no KV-cache cropping API risk).
Greedy (temp-0): accept draft token i iff it equals the target's greedy argmax at position i;
on first mismatch take the target's correction (bonus). The committed sequence == the target's
own greedy decode by construction (ADR-039 / red line 7 byte-identity).

Run from /tmp:  cd /tmp && /tmp/coreai-cv/bin/python /tmp/llamba_q4_acceptance.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import torch

TOOLS = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools"
sys.path.insert(0, TOOLS)
import llamba_to_coreai as L  # LlambaDecode, cfg_from_json, load_real_weights

TARGET_ID = "unsloth/Llama-3.2-3B-Instruct"
K = 4          # draft block size
N_GEN = 64     # tokens to generate per prompt
PROMPTS = [
    "The capital of France is",
    "Once upon a time, in a small village",
    "The three primary colors are red, blue, and",
    "To make a cup of tea, first you",
    "The largest planet in our solar system is",
    "In 1969, the first humans landed on the",
    "Water is composed of hydrogen and",
    "The quick brown fox jumps over the lazy",
    "Photosynthesis is the process by which plants",
    "The opposite of hot is",
    "import numpy as np\ndef softmax(x):\n    return",
    "def fibonacci(n):\n    if n <= 1:\n        return n\n    return",
    "The Great Wall of China was built to",
    "Albert Einstein is best known for his theory of",
    "A balanced diet should include proteins, carbohydrates, and",
    "The first president of the United States was",
    "Machine learning models are trained on large amounts of",
    "The boiling point of water at sea level is",
    "She opened the old wooden door and found",
    "The mitochondria is the powerhouse of the",
    "Two plus two equals",
    "The capital of Japan is Tokyo, and the capital of South Korea is",
    "Climate change is primarily caused by the emission of",
    "He picked up the phone and dialed the number, hoping that",
]


def main() -> None:
    from huggingface_hub import hf_hub_download
    from safetensors.torch import load_file
    from transformers import AutoModelForCausalLM, AutoTokenizer

    torch.manual_seed(0)
    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"=== Q4 acceptance: Llamba-1B draft  vs  {TARGET_ID} (bf16/{dev})  K={K} N_GEN={N_GEN} ===")

    # ---- draft (faithful fp32 port) ----
    cfg = L.cfg_from_json(json.load(open(hf_hub_download(L.HF_ID, "config.json"))))
    state = load_file(hf_hub_download(L.HF_ID, "model.safetensors"))
    draft = L.LlambaDecode(cfg).eval()
    L.load_real_weights(draft, state)
    tok = AutoTokenizer.from_pretrained(L.TOK_ID)

    # ---- target ----
    t0 = time.time()
    target = AutoModelForCausalLM.from_pretrained(TARGET_ID, torch_dtype=torch.bfloat16).to(dev).eval()
    print(f"    target loaded in {time.time()-t0:.1f}s")

    def draft_feed(t: int) -> int:
        with torch.no_grad():
            return int(draft(torch.tensor([[t]], dtype=torch.long)).view(-1).argmax())

    @torch.no_grad()
    def target_argmax(seq: list[int], base: int, n: int) -> list[int]:
        out = target(input_ids=torch.tensor([seq], device=dev), use_cache=False)
        lg = out.logits[0]
        return [int(lg[base + j].argmax()) for j in range(n)]

    tot_gen = tot_fwd = tot_acc = 0
    pos_hits = [0] * K
    pos_reach = [0] * K
    round_tokens: list[int] = []

    for pi, prompt in enumerate(PROMPTS):
        ids = tok(prompt, return_tensors="pt").input_ids[0].tolist()
        draft.conv_all.zero_(); draft.ssm_all.zero_()
        for t in ids[:-1]:
            draft_feed(t)                              # prime draft state to before last token
        committed = list(ids)
        last = committed[-1]
        gen = 0
        while gen < N_GEN:
            snap = (draft.conv_all.clone(), draft.ssm_all.clone())
            props: list[int] = []
            cur = last
            for _ in range(K):
                cur = draft_feed(cur)
                props.append(cur)
            base = len(committed) - 1                  # logits at `base` predict props[0]'s slot
            targ = target_argmax(committed + props, base, K + 1)
            tot_fwd += 1
            a = 0
            for i in range(K):
                pos_reach[i] += 1
                if props[i] == targ[i]:
                    pos_hits[i] += 1
                    a += 1
                else:
                    break
            bonus = targ[a]
            new = props[:a] + [bonus]
            committed += new
            gen += len(new)
            tot_gen += len(new)
            tot_acc += a
            round_tokens.append(len(new))
            # exact draft rewind: restore snapshot, replay last + accepted props (NOT bonus)
            draft.conv_all.copy_(snap[0]); draft.ssm_all.copy_(snap[1])
            draft_feed(last)
            for p in props[:a]:
                draft_feed(p)
            last = bonus
        if (pi + 1) % 4 == 0 or pi == len(PROMPTS) - 1:
            tau = tot_gen / max(1, tot_fwd)
            print(f"    [{pi+1:2d}/{len(PROMPTS)}] running tau={tau:.3f}  "
                  f"accept_rate={sum(pos_hits)/max(1,sum(pos_reach)):.3f}")

    tau = tot_gen / max(1, tot_fwd)
    acc_rate = sum(pos_hits) / max(1, sum(pos_reach))
    mean_acc = tot_acc / max(1, tot_fwd)
    print("\n================ Q4 RESULT ================")
    print(f"  block efficiency  tau = {tau:.3f}  tokens / target-forward  (K={K}; ceiling K+1={K+1})")
    print(f"  mean accepted draft tokens / round (excl. bonus) = {mean_acc:.3f} / {K}")
    print(f"  overall draft token acceptance rate = {acc_rate:.3f}")
    print(f"  per-position acceptance (given reached):")
    for i in range(K):
        print(f"     d[{i}] = {pos_hits[i]/max(1,pos_reach[i]):.3f}   ({pos_hits[i]}/{pos_reach[i]})")
    print(f"  prompts={len(PROMPTS)}  total_committed={tot_gen}  total_target_forwards={tot_fwd}")
    print(f"  NOTE: bf16 transformers target = architectural upper bound; the production MLX 4-bit")
    print(f"        target would be marginally lower. Free-form continuation (no chat template).")
    print("===========================================")


if __name__ == "__main__":
    main()
