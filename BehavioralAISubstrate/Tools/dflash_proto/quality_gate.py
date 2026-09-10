"""M2 quality gate — paired accuracy on the B2 verifiable-question set (147 Qs, known answers).

The 4-bit production trunk scored 0.660 on this exact set (BASDifficultyProbeCollectTests,
/tmp/gdn_coreai/probe_features.jsonl). Any candidate trunk (DWQ-3bit) is judged PAIRED on the
same questions: overall accuracy, per-family deltas, plus the 17-sheep reasoning-flip probe and
two prose samples for eyeball. Gate: candidate accuracy within ~5pp of the 4-bit baseline AND
17-sheep correct AND prose coherent — else the 3-bit cliff verdict stands.

Usage: quality_gate.py <model_path_or_id> [n_questions]
"""
import json
import re
import sys
import time

import mlx.core as mx
from mlx_lm import load
from mlx_lm.generate import stream_generate

FEATURES = "/tmp/gdn_coreai/probe_features.jsonl"
SHEEP = "A farmer has 17 sheep. All but 9 run away. How many sheep are left?"
PROSE = [
    "Describe a quiet morning in a mountain village.",
    "Explain what a tide pool is to a curious child.",
]


def answer(model, tok, q: str, max_tokens: int = 224) -> str:
    ids = tok.apply_chat_template(
        [{"role": "user", "content": q}], add_generation_prompt=True)
    text = ""
    for r in stream_generate(model, tok, prompt=ids, max_tokens=max_tokens):
        text += r.text
    # judge on the post-think tail when a think block closed; else the whole text
    return text.split("</think>")[-1] if "</think>" in text else text


def main() -> None:
    model_path = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 147
    rows = [json.loads(l) for l in open(FEATURES) if l.strip()][:n]
    model, tok = load(model_path)

    per_family: dict[str, list[int]] = {}
    correct = 0
    worse_flips = 0            # 4-bit RIGHT → candidate WRONG (the damage signal)
    better_flips = 0
    t0 = time.time()
    for i, r in enumerate(rows):
        text = answer(model, tok, r["q"])
        ok = re.search(rf"\b{re.escape(r['ans'])}\b", text) is not None
        correct += ok
        base_ok = r["label"] == 1                       # the 4-bit verdict on THIS question
        if base_ok and not ok:
            worse_flips += 1
        if ok and not base_ok:
            better_flips += 1
        per_family.setdefault(r["family"], []).append(int(ok))
        if (i + 1) % 20 == 0:
            print(f"[quality] {i+1}/{len(rows)} acc={correct/(i+1):.3f} ({time.time()-t0:.0f}s)")
    acc = correct / len(rows)
    base_acc = sum(r["label"] for r in rows) / len(rows)
    print(f"\n[quality] MODEL={model_path}")
    print(f"[quality] OVERALL acc={acc:.3f} vs 4-bit {base_acc:.3f} on the SAME questions "
          f"| paired flips: worse={worse_flips} better={better_flips}")
    for fam, v in sorted(per_family.items()):
        base = [r["label"] for r in rows if r["family"] == fam]
        print(f"[quality]   {fam}: {sum(v)}/{len(v)} = {sum(v)/len(v):.2f} (4-bit {sum(base)/len(base):.2f})")

    sheep = answer(model, tok, SHEEP)
    sheep_ok = re.search(r"\b9\b", sheep) is not None
    print(f"[quality] 17-sheep: {'PASS' if sheep_ok else 'FAIL'} | {sheep.strip()[:120]}")
    for p in PROSE:
        print(f"[quality] prose sample ({p[:30]}...): {answer(model, tok, p, 96).strip()[:200]}")


if __name__ == "__main__":
    main()
