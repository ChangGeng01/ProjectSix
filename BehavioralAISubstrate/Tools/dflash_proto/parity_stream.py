"""M1 tail-closure — DFlash prose-acceptance parity probe, Python half (OFFICIAL drafter).

Gate-b (Swift, LIVE) measured prose accept ~half of Gate-a (Python, LIVE). Two confounds were
folded together: (a) fp16(Swift) vs bf16(Python) activations diverge the two stacks' greedy
STREAMS on prose, so live acceptance was measured on DIFFERENT text; (b) a possible real
port/numerics gap. This probe separates them by teacher-forcing ONE fixed stream through both:

  1. gt = THIS stack's greedy continuation (the reference stream), dumped to JSON.
  2. Python teacher-forced accepts along gt with z-lab's OFFICIAL drafter, exact live block
     semantics: block=[anchor gt[j]]+15 masks, ctx = target hidden taps of positions < P,
     drafts predict gt[j+1..j+15], accept = prefix match. Fixed stride 16. Both bf16 and
     q4/g64 drafter arms (Swift runs q4).
  3. Swift half (BASDFlashParityTests) repeats 2 on the SAME gt. Swift ≈ Python here ⇒ port
     exonerated, Gate-b gap = stream divergence; a residual same-stream gap = real numerics.

Output: /tmp/gdn_coreai/dflash_parity_stream.json
"""
import json
import sys
from pathlib import Path

import mlx.core as mx
import mlx.nn as nn

sys.path.insert(0, "Tools/dflash_proto")
import zlab_model_mlx as Z
from gate_a import greedy_continuation
from gate_a_official import load_draft_local
from mlx_lm import load
from mlx_lm.models.cache import make_prompt_cache

BLOCK = 16
N_GT = 128
DRAFT_DIR = Path("/tmp/gdn_coreai/dflash_draft")
PROMPTS = [
    ("prose", "Describe a quiet morning in a mountain village."),
    ("prose", "Explain what a tide pool is to a curious child."),
    ("prose", "Write a short paragraph about why libraries matter."),
    ("reason", "How many prime numbers are there between 10 and 50? Think step by step."),
]


def teacher_forced_accepts(model, draft, ids, gt):
    """Per-block accepts along the fixed stream (live block semantics, stride 16)."""
    full = list(ids) + gt
    _ = model(mx.array([full]))          # hooks refill model._hidden_states per forward
    hidden_all = mx.concatenate(model._hidden_states, axis=-1)     # [1, T, 8*2560]
    mx.eval(hidden_all)
    mask_id = int(draft.config.mask_token_id)
    accepts = []
    for j in range(0, N_GT - BLOCK, BLOCK):
        P = len(ids) + j
        cache = make_prompt_cache(draft)                            # fresh ctx per block
        block = mx.array([[full[P]] + [mask_id] * (BLOCK - 1)])
        dl = draft(block, hidden_all[:, :P], cache, logits_start=1)
        ds = mx.argmax(dl, axis=-1)[0].tolist()                     # 15 drafts
        acc = 0
        for a, b in zip(ds, gt[j + 1:j + BLOCK]):
            if a != b:
                break
            acc += 1
        accepts.append(acc)
    return accepts


def main():
    model, tok = load("mlx-community/Qwen3.5-4B-4bit")
    Z._patch_model(model, load_draft_local(DRAFT_DIR).config.target_layer_ids)
    arms = {}
    for arm in ("bf16", "q4"):
        draft = load_draft_local(DRAFT_DIR)
        if arm == "q4":
            nn.quantize(draft, group_size=64, bits=4,
                        class_predicate=lambda _, m: isinstance(m, nn.Linear))
        mx.eval(draft.parameters())
        arms[arm] = draft.bind(model)
    out = []
    for tag, q in PROMPTS:
        ids = tok.apply_chat_template(
            [{"role": "user", "content": q}], add_generation_prompt=True)
        gt = greedy_continuation(model, ids, N_GT)
        rec = {"tag": tag, "prompt": q, "ids": list(ids), "gt": gt}
        for arm, draft in arms.items():
            acc = teacher_forced_accepts(model, draft, ids, gt)
            rec[f"py_accepts_{arm}"] = acc
            print(f"[parity-py] {tag:6s} {arm:4s} {q[:36]:36s} "
                  f"accept={sum(acc) / len(acc):.2f} blocks={acc}")
        out.append(rec)
    with open("/tmp/gdn_coreai/dflash_parity_stream.json", "w") as f:
        json.dump(out, f)
    print(f"[parity-py] wrote {len(out)} streams -> /tmp/gdn_coreai/dflash_parity_stream.json")


if __name__ == "__main__":
    main()
