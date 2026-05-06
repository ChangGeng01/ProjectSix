#!/usr/bin/env python3
"""M759 chapter 二百二 — A/B compare two .mlpackage on same eval corpus.

Closes the operator UX gap "should I ship v0.5 vs v0.4?". Loads
both models + same labeled JSONL → predicts on each → reports
per-head accuracy / MAE / MACE diff → verdict.

Doctrine: comparison is OBSERVABILITY only. Doesn't bundle the
winner. Verdict drives operator decision: "ship v0.5" / "stay
on v0.4" / "investigate per-stratum bias".

Usage:
    python3 scripts/compare_mlpackages.py \\
        --baseline /path/to/v0.4.mlpackage \\
        --candidate /path/to/v0.5.mlpackage \\
        --eval-corpus /path/to/labeled-jsonl/
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from glob import glob
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from chenglu_feature_schema import (  # noqa: E402
    featurize_row, label_afm_ok, label_block,
    label_body_length, label_duration_ms,
    label_verbosity_class, FEATURE_COUNT,
)


def load_jsonl(eval_dir: str) -> list[dict]:
    rows = []
    for shard in sorted(glob(f"{eval_dir}/*.jsonl")):
        with open(shard) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        rows.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    return rows


def predict_corpus(
    model, rows: list[dict]
) -> dict[str, list[float]]:
    """Run model.predict on each row's featurized signature.
    Returns dict mapping output name → list of predictions."""
    import numpy as np
    out: dict[str, list[float]] = defaultdict(list)
    spec = model.get_spec()
    output_names = [o.name for o in spec.description.output]
    for row in rows:
        try:
            features = featurize_row(row)
        except RuntimeError:
            continue
        if len(features) != FEATURE_COUNT:
            continue
        feat_arr = np.array(features, dtype=np.float32)\
            .reshape(1, FEATURE_COUNT)
        try:
            preds = model.predict({"features": feat_arr})
        except Exception:
            continue
        for name in output_names:
            val = preds.get(name)
            if val is None:
                out[name].append(0.0)
            elif hasattr(val, "flatten"):
                out[name].append(float(val.flatten()[0]))
            else:
                out[name].append(float(val))
    return dict(out)


def binary_accuracy(probs: list[float], labels: list[int],
                    threshold: float = 0.5) -> float:
    if not probs:
        return 0.0
    correct = sum(
        1 for p, l in zip(probs, labels)
        if (p >= threshold) == bool(l))
    return correct / len(probs)


def regression_mae(preds: list[float],
                   labels: list[float]) -> float:
    if not preds:
        return 0.0
    return sum(abs(p - l) for p, l in zip(preds, labels)) \
        / len(preds)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True,
        help="Baseline .mlpackage (e.g. v0.4 production)")
    parser.add_argument("--candidate", required=True,
        help="Candidate .mlpackage (e.g. v0.5_real)")
    parser.add_argument("--eval-corpus", required=True,
        help="Directory of labeled JSONL rows")
    args = parser.parse_args()

    for p in [args.baseline, args.candidate]:
        if not Path(p).exists():
            print(f"ERROR: not found: {p}", file=sys.stderr)
            return 1

    print(f"=== compare_mlpackages ===")
    print(f"  baseline:  {Path(args.baseline).name}")
    print(f"  candidate: {Path(args.candidate).name}")
    print(f"  eval:      {args.eval_corpus}")

    try:
        import coremltools as ct  # noqa: F401
    except ImportError:
        print("ERROR: coremltools required",
              file=sys.stderr)
        return 1

    rows = load_jsonl(args.eval_corpus)
    print(f"\n  loaded {len(rows)} eval rows")
    if len(rows) < 50:
        print(f"  WARN: < 50 rows; comparison noise high")

    print("\nStep 1 — load both models…")
    baseline = ct.models.MLModel(args.baseline)
    candidate = ct.models.MLModel(args.candidate)

    print("\nStep 2 — predict baseline…")
    base_preds = predict_corpus(baseline, rows)
    print(f"  predicted {len(next(iter(base_preds.values()), []))} rows")

    print("\nStep 3 — predict candidate…")
    cand_preds = predict_corpus(candidate, rows)
    print(f"  predicted {len(next(iter(cand_preds.values()), []))} rows")

    print("\nStep 4 — compute metrics + diffs…")
    afm_labels = [label_afm_ok(r) for r in rows]
    block_labels = [label_block(r) for r in rows]
    length_labels = [label_body_length(r) for r in rows]
    duration_labels = [label_duration_ms(r) for r in rows]
    verb_labels = [label_verbosity_class(r) for r in rows]

    metrics = []

    if "afm_success_prob" in base_preds and \
       "afm_success_prob" in cand_preds:
        base_acc = binary_accuracy(
            base_preds["afm_success_prob"], afm_labels)
        cand_acc = binary_accuracy(
            cand_preds["afm_success_prob"], afm_labels)
        metrics.append(("AFM acc", base_acc, cand_acc, "higher"))

    if "block_prob" in base_preds and \
       "block_prob" in cand_preds:
        base_acc = binary_accuracy(
            base_preds["block_prob"], block_labels)
        cand_acc = binary_accuracy(
            cand_preds["block_prob"], block_labels)
        metrics.append(("Block acc", base_acc, cand_acc, "higher"))

    if "verbosity_prob" in base_preds and \
       "verbosity_prob" in cand_preds:
        base_acc = binary_accuracy(
            base_preds["verbosity_prob"], verb_labels)
        cand_acc = binary_accuracy(
            cand_preds["verbosity_prob"], verb_labels)
        metrics.append(("Verbosity acc", base_acc, cand_acc, "higher"))

    # M781 chapter 二百七 — DEEP-REVIEW FIX CRITICAL: train script
    # uses z-score normalization (`(y - mean) / std`), NOT
    # `y / 3000`. mean/std are baked into `short_description`,
    # not `user_defined_metadata`. Multiplying z-score by 3000
    # produces nonsense MAE. Honest fix: report relative MAE in
    # z-space (each model's own normalization). Absolute chars/ms
    # MAE requires reading each model's mean/std from description
    # (deferred to chapter 208+). For ship/no-ship A/B comparison,
    # z-space delta is sufficient signal — both ends emit z-scores
    # so candidate's z-MAE < baseline's z-MAE means candidate
    # is closer to its OWN mean (lower variance prediction).
    # Caveat: if baseline + candidate were trained on different
    # corpora, their z-spaces use different (mean, std) — z-MAE
    # delta is qualitative not absolute.
    if "length_norm" in base_preds and \
       "length_norm" in cand_preds:
        # Z-space MAE: each model emits its own z-score; we
        # compare prediction VARIANCE relative to label.
        # Convert label to z via (label - mean(labels)) / std(labels)
        # so both prediction and label are in same z-space per
        # eval corpus. (This is approximate; real fix reads each
        # model's metadata.)
        import statistics
        if length_labels:
            label_mean = statistics.mean(length_labels)
            label_std = statistics.stdev(length_labels) \
                if len(length_labels) > 1 else 1.0
            label_std = max(label_std, 1.0)  # avoid div-by-zero
            label_z = [(l - label_mean) / label_std
                       for l in length_labels]
            base_mae = regression_mae(
                base_preds["length_norm"], label_z)
            cand_mae = regression_mae(
                cand_preds["length_norm"], label_z)
            metrics.append(("Length MAE (z-space, eval-corpus)",
                            base_mae, cand_mae, "lower"))

    if "latency_norm" in base_preds and \
       "latency_norm" in cand_preds:
        if duration_labels:
            import statistics
            label_mean = statistics.mean(duration_labels)
            label_std = statistics.stdev(duration_labels) \
                if len(duration_labels) > 1 else 1.0
            label_std = max(label_std, 1.0)
            label_z = [(l - label_mean) / label_std
                       for l in duration_labels]
            base_mae = regression_mae(
                base_preds["latency_norm"], label_z)
            cand_mae = regression_mae(
                cand_preds["latency_norm"], label_z)
            metrics.append(("Latency MAE (z-space, eval-corpus)",
                            base_mae, cand_mae, "lower"))

    print()
    print(f"  {'Metric':<22} {'Baseline':>10} {'Candidate':>10} "
          f"{'Δ':>10}  Verdict")
    print(f"  {'-' * 22} {'-' * 10} {'-' * 10} "
          f"{'-' * 10}  -------")
    wins = 0
    losses = 0
    for name, base, cand, direction in metrics:
        delta = cand - base
        if direction == "higher":
            verdict = "WIN" if delta > 0 else \
                ("LOSS" if delta < 0 else "TIE")
        else:  # lower
            verdict = "WIN" if delta < 0 else \
                ("LOSS" if delta > 0 else "TIE")
        if verdict == "WIN":
            wins += 1
        elif verdict == "LOSS":
            losses += 1
        sign = "+" if delta >= 0 else ""
        print(f"  {name:<22} {base:>10.4f} {cand:>10.4f} "
              f"{sign}{delta:>9.4f}  {verdict}")

    print()
    print(f"=== VERDICT ===")
    print(f"  WINS: {wins} / LOSSES: {losses} / "
          f"TIES: {len(metrics) - wins - losses}")
    print(f"  Decision rule:")
    print(f"    wins ≥ 3 AND losses == 0    → ship candidate")
    print(f"    wins ≥ 2 AND losses ≤ 1     → consider canary")
    print(f"    losses ≥ 2                  → stay on baseline")
    print(f"  This run: {wins}W/{losses}L/"
          f"{len(metrics) - wins - losses}T")
    if wins >= 3 and losses == 0:
        print(f"  → SHIP CANDIDATE")
    elif wins >= 2 and losses <= 1:
        print(f"  → CONSIDER CANARY (shadow predict in app)")
    elif losses >= 2:
        print(f"  → STAY ON BASELINE")
    else:
        print(f"  → AMBIGUOUS — investigate per-stratum")
    return 0


if __name__ == "__main__":
    sys.exit(main())
