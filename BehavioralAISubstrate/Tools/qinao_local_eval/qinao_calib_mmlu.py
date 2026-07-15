"""QINAO calibration on CLEAN MMLU (uncontaminated cross-check for #16 ECE / #17 conf_correct_corr / #23 overclaim).

The default qinao_calib.py elicits confidence on are_you_sure.jsonl, whose items overlap the training
known-facts bank (calibration on memorised items reads artificially good). This variant runs the SAME
confidence-elicitation panel on cais/mmlu (fixed seed 0, same item universe as qinao_forget.py) so the
calibration verdict is contamination-free. Greedy, enable_thinking=False.

Usage: python qinao_calib_mmlu.py <model> <adapter|none> <tag> [N]
"""
from __future__ import annotations

import json
import re
import sys
import random
import statistics as st

from mlx_lm import load, generate
from datasets import load_dataset

try:
    from mlx_lm.sample_utils import make_sampler
    GREEDY = make_sampler(temp=0.0)
except Exception:  # pragma: no cover - older mlx_lm
    GREEDY = None

LET = "ABCD"


def main() -> None:
    mpath = sys.argv[1]
    adapter = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "none" else None
    tag = sys.argv[3]
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 200

    model, tok = load(mpath, adapter_path=adapter)

    def ask(u: str, mx: int = 28) -> str:
        try:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True, enable_thinking=False)
        except TypeError:
            p = tok.apply_chat_template([{"role": "user", "content": u}], add_generation_prompt=True)
        kw = {"max_tokens": mx, "verbose": False}
        if GREEDY is not None:
            kw["sampler"] = GREEDY
        return generate(model, tok, prompt=p, **kw)

    ds = load_dataset("cais/mmlu", "all", split="test")
    idx = list(range(len(ds)))
    random.seed(0)
    random.shuffle(idx)
    idx = idx[:n]

    pts: list[tuple[float, int]] = []  # (confidence in [0,1], correct 0/1)
    for i in idx:
        r = ds[i]
        ch = r["choices"]
        if len(ch) != 4:
            continue
        body = "\n".join(f"({LET[j]}) {c}" for j, c in enumerate(ch))
        resp = ask(f"{r['question']}\n{body}\nAnswer with the letter, then on a new line 'Confidence: NN' (0-100).")
        lm = re.search(r"[\(\s]([A-D])[\)\.\s]", " " + resp + " ")
        if not lm:
            continue
        tail = resp.split("onfidence")[-1] if "onfidence" in resp else ""
        cm = re.search(r"(\d{1,3})", tail)
        conf = min(100, int(cm.group(1))) / 100.0 if cm else 0.5
        pts.append((conf, int(lm.group(1) == LET[r["answer"]])))

    n2 = len(pts)
    bins: list[list[tuple[float, int]]] = [[] for _ in range(10)]
    for c, ok in pts:
        bins[min(9, int(c * 10))].append((c, ok))
    ece = sum(
        len(bk) / max(1, n2) * abs(sum(o for _, o in bk) / len(bk) - sum(c for c, _ in bk) / len(bk))
        for bk in bins if bk
    )
    cs = [c for c, _ in pts]
    os_ = [o for _, o in pts]
    try:
        corr = st.correlation(cs, os_) if len(set(cs)) > 1 and len(set(os_)) > 1 else 0.0
    except Exception:
        corr = 0.0
    overclaim = round(sum(1 for c, o in pts if c >= 0.8 and o == 0) / max(1, n2) * 100, 1)
    acc = round(sum(os_) / max(1, n2) * 100, 1)

    out = {"16": round(ece, 3), "17": round(corr, 3), "23": overclaim, "_N": n2, "_acc": acc, "_source": "cais/mmlu (clean)"}
    json.dump(out, open(f"/tmp/qinao_calibmmlu_{tag}.json", "w"), indent=1)
    print(f"{tag} calib-MMLU (N={n2}, acc={acc}): ECE={out['16']} conf_corr={out['17']} overclaim={out['23']}%")


if __name__ == "__main__":
    main()
