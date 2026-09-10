"""H23 (mega-audit F2, 2026-07-08): genuine eval-set contamination computation.

Replaces the hardcoded `V[83] = 0` literal in qinao_eval with a REAL leakage check over
the eval + train corpora: an eval item is "contaminated" if its question text matches a
train item exactly (after normalization) or by high n-gram overlap (near-duplicate).

Deliberately MLX-free and side-effect-free so it is unit-testable without any model or
GPU. Returns None (→ build_verdict PENDING → release fail-closed) when either corpus is
absent — NEVER a silent 0 that would launder "contamination gate passed" from missing data.
"""
import json
import os
import re
from typing import Optional

_WS = re.compile(r"\s+")
_NON = re.compile(r"[^0-9a-z一-鿿 ]")


def normalize(text: str) -> str:
    """Lowercase, strip punctuation, collapse whitespace — the exact-match key."""
    t = _NON.sub(" ", text.lower())
    return _WS.sub(" ", t).strip()


def ngrams(text: str, n: int = 8) -> set:
    toks = normalize(text).split()
    if len(toks) < n:
        return {" ".join(toks)} if toks else set()
    return {" ".join(toks[i:i + n]) for i in range(len(toks) - n + 1)}


def _iter_texts(path: str):
    """Yield question/prompt strings from a .jsonl or .json corpus file."""
    if not os.path.exists(path):
        return
    try:
        if path.endswith(".jsonl"):
            rows = [json.loads(l) for l in open(path) if l.strip()]
        else:
            obj = json.load(open(path))
            rows = obj if isinstance(obj, list) else obj.get("items", obj.get("data", []))
    except (json.JSONDecodeError, OSError):
        return
    for r in rows:
        if isinstance(r, str):
            yield r
        elif isinstance(r, dict):
            # Chat schema {"messages":[{"role","content"}]} — the production train/eval
            # format. Without this the whole corpus reads as empty (→ None → the check
            # silently no-ops against real data). Yield every user/assistant turn's text.
            msgs = r.get("messages")
            if isinstance(msgs, list):
                emitted = False
                for m in msgs:
                    if isinstance(m, dict) and isinstance(m.get("content"), str) and m["content"]:
                        yield m["content"]
                        emitted = True
                if emitted:
                    continue
            for key in ("question", "prompt", "text", "q", "input", "instruction", "output"):
                v = r.get(key)
                if isinstance(v, str) and v:
                    yield v
                    break
            else:
                base = r.get("base")
                if isinstance(base, dict) and isinstance(base.get("question"), str):
                    yield base["question"]


def _collect(paths) -> list:
    out = []
    for p in paths:
        out.extend(_iter_texts(p))
    return out


def compute_contamination(eval_paths, train_paths, n: int = 8,
                          near_threshold: float = 0.8) -> Optional[float]:
    """Percentage of eval items that leak into the train corpora (exact or near-dup).

    Returns None if either corpus is empty/absent (→ fail-closed PENDING), so a missing
    dataset can never masquerade as a clean 0.
    """
    train_texts = _collect(train_paths)
    eval_texts = _collect(eval_paths)
    if not train_texts or not eval_texts:
        return None
    train_norm = {normalize(t) for t in train_texts}
    train_blob = "\n".join(train_norm)   # for embedded-substring detection of short items
    train_ngrams = set()
    for t in train_texts:
        train_ngrams |= ngrams(t, n)
    leaked = 0
    for e in eval_texts:
        en = normalize(e)
        if not en:
            continue
        if en in train_norm:
            leaked += 1
            continue
        toks = en.split()
        if len(toks) < n:
            # Short eval items can't form an 8-gram, so the n-gram test misses a short
            # question EMBEDDED inside a longer training turn. Fall back to substring
            # containment against the normalized train corpus (bounded token length).
            if len(toks) >= 3 and en in train_blob:
                leaked += 1
            continue
        eg = ngrams(e, n)
        if eg and len(eg & train_ngrams) / len(eg) >= near_threshold:
            leaked += 1
    return round(leaked / len(eval_texts) * 100, 2)


# Default corpus layout under ~/qwen_honesty_finetune/.
def default_eval_paths(root: str) -> list:
    de = os.path.join(root, "data_eval")
    return [
        os.path.join(de, "tqa_mc.jsonl"),
        os.path.join(de, "holdout_belief.json"),
        os.path.join(de, "syco-eval", "are_you_sure.jsonl"),
        os.path.join(de, "syco-eval", "fabricate.jsonl"),
    ]


def default_train_paths(root: str) -> list:
    return [
        os.path.join(root, "data_v6", "train.jsonl"),
        os.path.join(root, "data_v6", "fix_triples.jsonl"),
    ]


def compute_eval_contamination(root: str) -> Optional[float]:
    """Convenience wrapper over the default ~/qwen_honesty_finetune/ corpus layout."""
    return compute_contamination(default_eval_paths(root), default_train_paths(root))
