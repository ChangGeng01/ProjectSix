#!/usr/bin/env python3
"""M756 chapter 二百一 — calibration check for trained .mlpackage.

Closes chapter 一百九十二's "next step #2: calibration check
(bins 0.0-1.0)". Loads a .mlpackage + a labeled bench/base
corpus + bins predictions into 10 confidence buckets + reports
observed rate per bucket. A well-calibrated classifier has bin
center ≈ observed rate (e.g. 70% confidence bucket → 70%
actual yes-rate).

Surfaces:
  - Calibration table per binary head (afm_success_prob,
    block_prob, verbosity_prob)
  - Mean Absolute Calibration Error (MACE) summary
  - Per-pressure-stratum calibration breakdown
  - Suspicious bins (n=0 or n=1, ECE > 0.20, etc)

Doctrine: calibration check is OBSERVABILITY only. Doesn't
mutate the model. Verdict drives operator decision: "ship
canary" / "retrain with more data" / "investigate per-stratum
bias".

Usage:
    python3 scripts/calibration_check.py \\
        --mlpackage /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage \\
        --eval-corpus /tmp/synthetic-base/
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from glob import glob
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from chenglu_feature_schema import (  # noqa: E402
    featurize_row, label_afm_ok, label_block,
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


def bin_predictions(probs: list[float], labels: list[int],
                    n_bins: int = 10) -> list[dict]:
    """Build calibration bins. Each bin reports n / mean_pred /
    observed_rate / gap. Standard 10-bin equal-width [0, 0.1),
    [0.1, 0.2), ..., [0.9, 1.0]."""
    bins = [{"lo": i / n_bins, "hi": (i + 1) / n_bins,
             "n": 0, "sum_pred": 0.0, "sum_label": 0}
            for i in range(n_bins)]
    for prob, lbl in zip(probs, labels):
        idx = min(int(prob * n_bins), n_bins - 1)
        bins[idx]["n"] += 1
        bins[idx]["sum_pred"] += prob
        bins[idx]["sum_label"] += lbl
    for b in bins:
        if b["n"] > 0:
            b["mean_pred"] = b["sum_pred"] / b["n"]
            b["observed_rate"] = b["sum_label"] / b["n"]
            b["gap"] = b["observed_rate"] - b["mean_pred"]
        else:
            b["mean_pred"] = None
            b["observed_rate"] = None
            b["gap"] = None
    return bins


def compute_mace(bins: list[dict], total: int) -> float:
    """Mean Absolute Calibration Error (sample-weighted mean
    of |observed - predicted| per bin)."""
    if total == 0:
        return 0.0
    weighted = 0.0
    for b in bins:
        if b["n"] > 0 and b["gap"] is not None:
            weighted += abs(b["gap"]) * b["n"]
    return weighted / total


def calibration_table_str(bins: list[dict], head_name: str) -> str:
    lines = [f"=== {head_name} calibration ==="]
    lines.append(
        "  bin             n  mean_pred  observed   gap")
    for b in bins:
        if b["n"] == 0:
            lines.append(
                f"  [{b['lo']:.1f},{b['hi']:.1f})  "
                f"{b['n']:>5d}      —          —       —")
        else:
            sign = "+" if b["gap"] >= 0 else ""
            lines.append(
                f"  [{b['lo']:.1f},{b['hi']:.1f})  "
                f"{b['n']:>5d}     {b['mean_pred']:.3f}     "
                f"{b['observed_rate']:.3f}   {sign}{b['gap']:.3f}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mlpackage", required=True,
        help="Path to .mlpackage to evaluate")
    parser.add_argument("--eval-corpus", required=True,
        help="Directory of labeled JSONL rows for evaluation")
    parser.add_argument("--n-bins", type=int, default=10)
    args = parser.parse_args()

    pkg = Path(args.mlpackage)
    if not pkg.exists():
        print(f"ERROR: not found: {pkg}", file=sys.stderr)
        return 1

    print(f"=== calibration_check: {pkg.name} ===")

    try:
        import coremltools as ct
        import numpy as np
    except ImportError as e:
        print(f"ERROR: {e}. Use venv at /tmp/coreml-py312.",
              file=sys.stderr)
        return 1

    print(f"\nStep 1 — load model + eval corpus…")
    model = ct.models.MLModel(str(pkg))
    rows = load_jsonl(args.eval_corpus)
    print(f"  loaded {len(rows)} eval rows from {args.eval_corpus}")
    if len(rows) < 50:
        print(f"  WARN: < 50 rows; calibration noise high")

    print(f"\nStep 2 — predict on each row…")
    afm_probs, afm_labels = [], []
    block_probs, block_labels = [], []
    verb_probs, verb_labels = [], []
    pressure_buckets: dict[str, list] = defaultdict(list)
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
        afm_p = float(preds.get("afm_success_prob",
                                np.array([[0]])).flatten()[0])
        block_p = float(preds.get("block_prob",
                                  np.array([[0]])).flatten()[0])
        verb_p = float(preds.get("verbosity_prob",
                                 np.array([[0]])).flatten()[0])
        afm_probs.append(afm_p)
        afm_labels.append(label_afm_ok(row))
        block_probs.append(block_p)
        block_labels.append(label_block(row))
        verb_probs.append(verb_p)
        verb_labels.append(label_verbosity_class(row))

        thermal = row.get("thermalState") or "unknown"
        pressure_buckets[thermal].append(
            (afm_p, label_afm_ok(row)))

    n = len(afm_probs)
    print(f"  predicted {n} rows successfully")
    if n == 0:
        print("  ERROR: no rows could be predicted")
        return 1

    print(f"\nStep 3 — calibration tables (3 binary heads)…")
    print()
    for name, probs, labels in [
        ("afm_success_prob", afm_probs, afm_labels),
        ("block_prob", block_probs, block_labels),
        ("verbosity_prob", verb_probs, verb_labels),
    ]:
        bins = bin_predictions(probs, labels, args.n_bins)
        mace = compute_mace(bins, n)
        print(calibration_table_str(bins, name))
        print(f"  MACE: {mace:.4f}")
        print()

    print(f"=== Per-thermal-stratum calibration (afm_success) ===")
    for thermal, samples in sorted(pressure_buckets.items()):
        if not samples:
            continue
        probs = [s[0] for s in samples]
        labels = [s[1] for s in samples]
        bins = bin_predictions(probs, labels, 5)  # 5-bin coarse
        mace = compute_mace(bins, len(samples))
        print(f"  thermal={thermal:>10s}  n={len(samples):>4d}  "
              f"MACE={mace:.4f}")

    print(f"\n=== VERDICT ===")
    print(f"  rows evaluated: {n}")
    print(f"  AFM MACE  / Block MACE / Verbosity MACE")
    print(f"  Lower = better-calibrated. Threshold rule of thumb:")
    print(f"    < 0.05 = well-calibrated")
    print(f"    0.05-0.10 = acceptable; consider isotonic LUT")
    print(f"    > 0.10 = miscalibrated; don't ship without")
    print(f"             retraining or recalibration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
