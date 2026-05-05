#!/usr/bin/env python3
"""M704 chapter 一百九十 — bench-to-train pipeline.

Closes the user's stated vision (chapter 一百九十 始):
"next time I run 8 hours, the data trains the model itself
stronger and stronger, fitting actual state, different
scenarios / pressures / assumptions all handled".

Pipeline:
1. Read all hybrid-bench JSONL output (chapter 178+ schema v7
   includes pressure context: thermalState / batteryLevel /
   lowPowerMode / hourOfDay).
2. Reconstruct (signature, label) training pairs from each
   row's actual outcome — what the bench observed substrate
   doing, what the LLM produced.
3. Augment the chapter 175/176 5,088-row adversarial corpus
   with bench observations stratified by pressure.
4. Retrain `ChengluMultiHead` (chapter 一百八十一+) with the
   augmented dataset, output `ChengluMultiHead_v0.2.mlpackage`
   ready to bundle.
5. Diff report v0.2 vs v0.1 across 5 heads (AFM / block /
   length / latency / verbosity).

This is the **self-improvement loop** infrastructure — bench
data isn't just observability; it's training fuel.

Usage:
    /tmp/coreml-py312/bin/python3 scripts/bench_to_train.py \\
        --bench /path/to/iphone-hybrid-bench/ \\
        --base-corpus /tmp/iphone-afm-bench-final-pull/ \\
        --output SampleHost/ChengluMultiHead_v0.2.mlpackage

Honest scope limit: this is a SKELETON pipeline. Production
deployment of v0.2 requires (a) holdout validation on a separate
bench / (b) calibration check (chapter 一百八十四 lessons) /
(c) production canary before swapping the bundled .mlpackage.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from collections import Counter, defaultdict
from glob import glob
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from chenglu_feature_schema import (  # noqa: E402
    featurize_row,
    label_afm_ok,
    label_block,
    label_body_length,
    label_duration_ms,
    label_verbosity_class,
    VERBOSITY_THRESHOLD_CHARS,
    FEATURE_NAMES,
    FEATURE_COUNT,
)
from train_chenglu_preflight_v0 import load_jsonl_dir  # noqa: E402

EXPECTED_BENCH_SCHEMA_VERSION = "7"


# ============================================================
# Step 1: extract bench observations into train-script format
# ============================================================

def bench_row_to_train_row(bench_row: dict) -> dict | None:
    """Convert one chapter-189 bench JSONL row into the chapter-
    176 corpus row shape used by all train scripts.

    Returns None if the row is not usable for training (e.g.
    skip rows where substrate gave canned response — no LLM
    signal to learn from).
    """
    # Skip iters (substrate bypassed LLM) have no LLM-outcome
    # signal — exclude from training.
    if bench_row.get("llmSkipped") is True:
        return None
    # Rows where firstBody is empty AND fallbackBody is empty
    # have no served LLM output to train on.
    first_body = bench_row.get("firstTriedBody") or ""
    fallback_body = bench_row.get("fallbackBody") or ""
    served_body = first_body if first_body else fallback_body
    if not served_body:
        return None
    sig = bench_row.get("signature")
    if not isinstance(sig, dict):
        return None
    train_row = {
        "signature": sig,
        "mutationSeed": bench_row.get("mutationSeed", 0),
        "permitMode": bench_row.get("permitMode", "unknown"),
        "afmStatus": bench_row.get("firstTriedStatus", "unknown"),
        "afmBodyLength": len(served_body),
        "afmDurationMs": (
            bench_row.get("firstTriedDurationMs")
            or bench_row.get("fallbackDurationMs")
            or 0.0
        ),
        # M704 chapter 一百九十 NEW: pressure context preserved
        # so future stratified retrain can weight scenarios.
        "thermalState": bench_row.get("thermalState"),
        "batteryLevel": bench_row.get("batteryLevel"),
        "lowPowerMode": bench_row.get("lowPowerMode"),
        "hourOfDay": bench_row.get("hourOfDay"),
    }
    return train_row


def load_bench_corpus(bench_dir: str) -> list[dict]:
    """Load bench JSONL + project to train-row shape."""
    raw = load_jsonl_dir(bench_dir)
    print(
        f"  bench raw rows: {len(raw)}",
        file=sys.stderr,
    )
    converted: list[dict] = []
    schema_versions: Counter = Counter()
    for r in raw:
        schema_versions[r.get("schemaVersion")] += 1
        train_row = bench_row_to_train_row(r)
        if train_row is not None:
            converted.append(train_row)
    print(
        f"  bench train-usable: {len(converted)} "
        f"({100 * len(converted) / max(len(raw), 1):.1f}%)",
        file=sys.stderr,
    )
    print(
        f"  schema version mix: {dict(schema_versions)}",
        file=sys.stderr,
    )
    if (None in schema_versions or "" in schema_versions
            or any(v not in (None, EXPECTED_BENCH_SCHEMA_VERSION)
                   for v in schema_versions
                   if v is not None)):
        print(
            f"  WARN: bench data has mixed schemas; "
            f"expected v{EXPECTED_BENCH_SCHEMA_VERSION}",
            file=sys.stderr,
        )
    return converted


# ============================================================
# Step 2: pressure-stratified augmentation
# ============================================================

def stratify_by_pressure(rows: list[dict]) -> dict[str, list[dict]]:
    """Group rows by pressure bucket. Helps retrain understand
    which scenarios the model is mis-calibrated on."""
    buckets: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        thermal = r.get("thermalState") or "unknown"
        low_power = r.get("lowPowerMode")
        hour = r.get("hourOfDay")
        time_bucket = (
            "morning" if hour is not None and 5 <= hour < 12
            else "afternoon" if hour is not None and 12 <= hour < 18
            else "evening" if hour is not None and 18 <= hour < 22
            else "night" if hour is not None
            else "unknown"
        )
        key = (
            f"thermal={thermal}/"
            f"lp={'y' if low_power else 'n'}/"
            f"time={time_bucket}"
        )
        buckets[key].append(r)
    return buckets


def augmented_corpus_summary(
    base_rows: list[dict],
    bench_rows: list[dict],
) -> str:
    """Diagnostic — what does the augmented training set look
    like vs base alone?"""
    base_block = sum(1 for r in base_rows if label_block(r))
    bench_block = sum(1 for r in bench_rows if label_block(r))
    base_ok = sum(1 for r in base_rows if label_afm_ok(r))
    bench_ok = sum(1 for r in bench_rows if label_afm_ok(r))
    base_long = sum(
        1 for r in base_rows if label_verbosity_class(r))
    bench_long = sum(
        1 for r in bench_rows if label_verbosity_class(r))
    pressure = stratify_by_pressure(bench_rows)
    lines = [
        f"Augmented corpus = {len(base_rows)} base "
        f"+ {len(bench_rows)} bench-derived",
        f"  block: base {base_block} + bench {bench_block} = "
        f"{base_block + bench_block} "
        f"(/total {len(base_rows) + len(bench_rows)})",
        f"  afm-ok: base {base_ok} + bench {bench_ok} = "
        f"{base_ok + bench_ok}",
        f"  long(>{VERBOSITY_THRESHOLD_CHARS}): "
        f"base {base_long} + bench {bench_long} = "
        f"{base_long + bench_long}",
        "Pressure stratification (bench rows):",
    ]
    for key, group in sorted(
        pressure.items(), key=lambda kv: -len(kv[1])
    ):
        lines.append(f"  {key}: {len(group)} rows")
    return "\n".join(lines)


# ============================================================
# Step 3: retrain MultiHead with augmented corpus
# ============================================================

def retrain_multihead(
    augmented_rows: list[dict],
    output_path: str,
    seed: int,
) -> dict:
    """Retrain ChengluMultiHead on augmented data. Imports
    chapter 一百八十三 train script logic directly to avoid
    duplication."""
    import numpy as np
    from sklearn.metrics import (
        accuracy_score, mean_absolute_error,
        r2_score, roc_auc_score,
    )
    from sklearn.model_selection import train_test_split
    import torch
    import coremltools as ct
    from train_chenglu_multihead_v0 import (
        MultiHeadModel, train_multihead,
    )

    X = np.array(
        [featurize_row(r) for r in augmented_rows],
        dtype=np.float32,
    )
    y_afm = np.array(
        [label_afm_ok(r) for r in augmented_rows],
        dtype=np.float32,
    )
    y_block = np.array(
        [label_block(r) for r in augmented_rows],
        dtype=np.float32,
    )
    y_length = np.array(
        [label_body_length(r) for r in augmented_rows],
        dtype=np.float32,
    )
    y_latency = np.array(
        [label_duration_ms(r) for r in augmented_rows],
        dtype=np.float32,
    )
    y_verbosity = np.array(
        [label_verbosity_class(r) for r in augmented_rows],
        dtype=np.float32,
    )

    n = len(augmented_rows)
    Xtr, Xte, idx_tr, idx_te = train_test_split(
        X, np.arange(n), test_size=0.2, random_state=seed)
    y_afm_tr, y_afm_te = y_afm[idx_tr], y_afm[idx_te]
    y_block_tr, y_block_te = y_block[idx_tr], y_block[idx_te]
    y_length_tr, y_length_te = y_length[idx_tr], y_length[idx_te]
    y_latency_tr, y_latency_te = (
        y_latency[idx_tr], y_latency[idx_te])
    y_verbosity_tr, y_verbosity_te = (
        y_verbosity[idx_tr], y_verbosity[idx_te])

    length_mean = float(y_length_tr.mean())
    length_std_raw = float(y_length_tr.std())
    latency_mean = float(y_latency_tr.mean())
    latency_std_raw = float(y_latency_tr.std())
    if length_std_raw == 0 or latency_std_raw == 0:
        raise ValueError(
            f"Cannot z-normalize: zero variance "
            f"(length={length_std_raw}, latency={latency_std_raw})"
        )
    length_std = length_std_raw
    latency_std = latency_std_raw
    y_length_norm_tr = (y_length_tr - length_mean) / length_std
    y_latency_norm_tr = (y_latency_tr - latency_mean) / latency_std

    print(
        f"Training MultiHead v0.2 on augmented corpus "
        f"({len(Xtr)} train / {len(Xte)} test)…",
        file=sys.stderr,
    )
    model = train_multihead(
        Xtr=Xtr, y_afm_tr=y_afm_tr, y_block_tr=y_block_tr,
        y_length_norm_tr=y_length_norm_tr,
        y_latency_norm_tr=y_latency_norm_tr,
        y_verbosity_tr=y_verbosity_tr,
        epochs=200, seed=seed,
    )
    model.eval()

    # Test metrics
    with torch.no_grad():
        Xte_t = torch.tensor(Xte, dtype=torch.float32)
        (pred_afm, pred_block,
         pred_length_norm, pred_latency_norm,
         pred_verbosity) = model(Xte_t)
        pred_afm_np = pred_afm.numpy().flatten()
        pred_block_np = pred_block.numpy().flatten()
        pred_length_np = (
            pred_length_norm.numpy().flatten() * length_std
            + length_mean
        )
        pred_latency_np = (
            pred_latency_norm.numpy().flatten() * latency_std
            + latency_mean
        )
        pred_verbosity_np = pred_verbosity.numpy().flatten()

    afm_acc = accuracy_score(
        y_afm_te.astype(int),
        (pred_afm_np >= 0.5).astype(int))
    afm_auc = roc_auc_score(y_afm_te.astype(int), pred_afm_np)
    block_acc = accuracy_score(
        y_block_te.astype(int),
        (pred_block_np >= 0.5).astype(int))
    block_auc = roc_auc_score(
        y_block_te.astype(int), pred_block_np)
    length_mae = mean_absolute_error(y_length_te, pred_length_np)
    length_r2 = r2_score(y_length_te, pred_length_np)
    latency_mae = mean_absolute_error(y_latency_te, pred_latency_np)
    latency_r2 = r2_score(y_latency_te, pred_latency_np)
    verb_acc = accuracy_score(
        y_verbosity_te.astype(int),
        (pred_verbosity_np >= 0.5).astype(int))
    verb_auc = roc_auc_score(
        y_verbosity_te.astype(int), pred_verbosity_np)

    metrics = {
        "afm_acc": afm_acc, "afm_auc": afm_auc,
        "block_acc": block_acc, "block_auc": block_auc,
        "length_mae": length_mae, "length_r2": length_r2,
        "latency_mae": latency_mae, "latency_r2": latency_r2,
        "verbosity_acc": verb_acc, "verbosity_auc": verb_auc,
        "n_train": len(Xtr), "n_test": len(Xte),
        "length_mean": length_mean, "length_std": length_std,
        "latency_mean": latency_mean, "latency_std": latency_std,
    }

    # Convert to CoreML
    n_features = X.shape[1]
    example = torch.zeros((1, n_features), dtype=torch.float32)
    traced = torch.jit.trace(model, example)
    cml = ct.convert(
        traced,
        inputs=[ct.TensorType(
            name="features", shape=(1, n_features),
            dtype=np.float32)],
        outputs=[
            ct.TensorType(name="afm_success_prob", dtype=np.float32),
            ct.TensorType(name="block_prob", dtype=np.float32),
            ct.TensorType(name="length_norm", dtype=np.float32),
            ct.TensorType(name="latency_norm", dtype=np.float32),
            ct.TensorType(name="verbosity_prob", dtype=np.float32),
        ],
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )
    cml.short_description = (
        f"ChengluMultiHead v0.2 — retrained on augmented "
        f"corpus (chapter 175/176 base + bench observations). "
        f"5 outputs same as v0.1."
    )
    cml.author = (
        "Qinao Runtime SDK chapter 一百九十 — "
        "bench-to-train self-improvement loop"
    )
    cml.license = "Apache-2.0"
    cml.version = "0.2.0"
    cml.user_defined_metadata["length_mean"] = str(length_mean)
    cml.user_defined_metadata["length_std"] = str(length_std)
    cml.user_defined_metadata["latency_mean"] = str(latency_mean)
    cml.user_defined_metadata["latency_std"] = str(latency_std)
    cml.user_defined_metadata["verbosity_threshold_chars"] = (
        str(VERBOSITY_THRESHOLD_CHARS))
    cml.user_defined_metadata["training_corpus"] = (
        f"chapter175-176-base+bench-augmented-n{len(augmented_rows)}")

    if os.path.exists(output_path):
        import shutil
        if os.path.isdir(output_path):
            shutil.rmtree(output_path)
        else:
            os.remove(output_path)
    cml.save(output_path)
    return metrics


def diff_report(metrics_v02: dict) -> str:
    """v0.2 vs v0.1 metrics diff. v0.1 numbers from chapter 183
    M661 ship report (5,088 rows base only)."""
    v01_baseline = {
        "afm_acc": 0.9067, "afm_auc": 0.9625,
        "block_acc": 1.0, "block_auc": 1.0,
        "length_mae": 433.03, "length_r2": 0.5928,
        "latency_mae": 2220.19, "latency_r2": 0.1206,
        "verbosity_acc": 0.7731, "verbosity_auc": 0.8608,
    }
    lines = [
        "v0.2 (augmented) vs v0.1 (base only):",
        f"  AFM acc:    {metrics_v02['afm_acc']:.4f} "
        f"(v0.1: {v01_baseline['afm_acc']:.4f}, "
        f"Δ {metrics_v02['afm_acc'] - v01_baseline['afm_acc']:+.4f})",
        f"  Block acc:  {metrics_v02['block_acc']:.4f} "
        f"(v0.1: {v01_baseline['block_acc']:.4f})",
        f"  Length MAE: {metrics_v02['length_mae']:.0f} "
        f"(v0.1: {v01_baseline['length_mae']:.0f}, "
        f"Δ {metrics_v02['length_mae'] - v01_baseline['length_mae']:+.0f})",
        f"  Latency MAE: {metrics_v02['latency_mae']:.0f} "
        f"(v0.1: {v01_baseline['latency_mae']:.0f}, "
        f"Δ {metrics_v02['latency_mae'] - v01_baseline['latency_mae']:+.0f})",
        f"  Verbosity acc: {metrics_v02['verbosity_acc']:.4f} "
        f"(v0.1: {v01_baseline['verbosity_acc']:.4f}, "
        f"Δ {metrics_v02['verbosity_acc'] - v01_baseline['verbosity_acc']:+.4f})",
    ]
    return "\n".join(lines)


# ============================================================
# Main pipeline
# ============================================================

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bench", required=True,
        help="Directory of hybrid-bench JSONL output "
             "(chapter 178+ schema v7).")
    parser.add_argument(
        "--base-corpus", required=True,
        help="Directory of chapter 175/176 base AFM bench "
             "JSONL (5,088-row adversarial).")
    parser.add_argument(
        "--output", required=True,
        help="Output .mlpackage path "
             "(e.g. SampleHost/ChengluMultiHead_v0.2.mlpackage).")
    parser.add_argument(
        "--seed", type=int, default=42,
        help="Random seed for train/test split.")
    parser.add_argument(
        "--require-bench-rows", type=int, default=100,
        help="Minimum bench rows required to run retrain "
             "(default 100). Refuses to retrain on too little "
             "data — would just be re-fitting noise.")
    args = parser.parse_args()

    print("Step 1 — loading bench data…", file=sys.stderr)
    bench_rows = load_bench_corpus(args.bench)
    if len(bench_rows) < args.require_bench_rows:
        print(
            f"\nERROR: {len(bench_rows)} bench rows < required "
            f"{args.require_bench_rows}. Need more 8h bench data "
            f"before retrain is meaningful.",
            file=sys.stderr,
        )
        return 1

    print(
        "\nStep 2 — loading base corpus + augmenting…",
        file=sys.stderr,
    )
    base_rows = load_jsonl_dir(args.base_corpus)
    augmented = base_rows + bench_rows
    print(augmented_corpus_summary(base_rows, bench_rows))

    print(
        "\nStep 3 — retraining MultiHead v0.2…",
        file=sys.stderr,
    )
    metrics = retrain_multihead(
        augmented, args.output, args.seed)

    print(f"\n.mlpackage saved: {args.output}")
    print()
    print(diff_report(metrics))

    print(
        "\nDone. Honest next steps:",
        file=sys.stderr,
    )
    print(
        "  1. Validate on held-out bench (separate directory).",
        file=sys.stderr,
    )
    print(
        "  2. Calibration check (bins 0.0-1.0).",
        file=sys.stderr,
    )
    print(
        "  3. Production canary before bundle swap.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
