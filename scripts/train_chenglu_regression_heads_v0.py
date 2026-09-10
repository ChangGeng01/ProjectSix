#!/usr/bin/env python3
"""M638-M639 chapter 一百八十 — train 2 regression heads.

ChengluLengthHead (predict afmBodyLength chars from signature)
ChengluLatencyHead (predict afmDurationMs from signature)

Both reuse the exact 43-dim signature one-hot from ChengluPreflight
v0.4 + ChengluPermitPredict v0. Same MLP(64,32) shape, mean-squared
loss instead of binary cross-entropy.

Why both: Length predicts AFM verbosity (UI pre-warm "this will be
~1400 chars"); Latency predicts time-to-first-byte (UI pre-warm
"this will take ~5s"). Together they let the user UI show a rough
preview before LLM call completes.

Honest empirical context (chapter 176 5,088 rows):
- afmBodyLength: mean 1354 chars, stdev 892, range 0-5032
  (bimodal: 0 for guardrailed prompts; ~1000-3000 for ok)
- afmDurationMs: mean 5638 ms, stdev 6264, range 116-365627
  (long tail; 1 outlier at 365s pulls stats)

Model accuracy expected: NOT 100% — these are real regression
problems with non-deterministic targets (AFM sampling, network
jitter, content variability). A baseline mean-predictor has MAE
~700 chars for length and ~5s for latency. We aim for MAE
comparable to or better than that.

Usage:
    /tmp/coreml-py312/bin/python3 \\
        scripts/train_chenglu_regression_heads_v0.py \\
        --iphone /tmp/iphone-afm-bench-final-pull \\
        --length-output SampleHost/ChengluLengthHead_v0.mlpackage \\
        --latency-output SampleHost/ChengluLatencyHead_v0.mlpackage
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Callable

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split

import coremltools as ct

sys.path.insert(0, os.path.dirname(__file__))
# M658 chapter 一百八十三 — featurize_row imported from shared
# schema (single-source); load_jsonl_dir from v0 (untouched).
from chenglu_feature_schema import featurize_row
from train_chenglu_preflight_v0 import load_jsonl_dir


class RegressionMLP(nn.Module):
    """MLP(64,32) regression head. Same body shape as v0.4 +
    PermitPredict — symmetric architecture for future shared-encoder
    refactor (chapter 一百八十一+).
    """

    def __init__(self, n_features: int):
        super().__init__()
        self.fc1 = nn.Linear(n_features, 64)
        self.fc2 = nn.Linear(64, 32)
        self.out = nn.Linear(32, 1)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return self.out(x)


def train_regression(
    X_train: np.ndarray,
    y_train: np.ndarray,
    n_features: int,
    epochs: int = 200,
    lr: float = 1e-3,
    batch: int = 64,
    seed: int = 42,
) -> RegressionMLP:
    torch.manual_seed(seed)
    np.random.seed(seed)
    model = RegressionMLP(n_features)
    optimizer = torch.optim.Adam(
        model.parameters(), lr=lr, weight_decay=1e-4
    )
    loss_fn = nn.MSELoss()
    Xtr = torch.tensor(X_train, dtype=torch.float32)
    ytr = torch.tensor(y_train, dtype=torch.float32).view(-1, 1)
    n = len(Xtr)
    for epoch in range(epochs):
        idx = torch.randperm(n)
        Xs, ys = Xtr[idx], ytr[idx]
        for i in range(0, n, batch):
            xb = Xs[i:i + batch]
            yb = ys[i:i + batch]
            optimizer.zero_grad()
            pred = model(xb)
            loss = loss_fn(pred, yb)
            loss.backward()
            optimizer.step()
    return model


# M658 chapter 一百八十三 — labels imported from shared schema.
from chenglu_feature_schema import (
    label_body_length as label_length,
    label_duration_ms as label_latency,
)


def train_and_export(
    rows: list,
    label_fn: Callable[[dict], float],
    output_path: str,
    head_name: str,
    output_key: str,
    description: str,
    test_size: float = 0.2,
    random_seed: int = 42,
) -> None:
    print(f"\n=== {head_name} ===")
    X = np.array(
        [featurize_row(r) for r in rows], dtype=np.float32
    )
    y = np.array([label_fn(r) for r in rows], dtype=np.float32)
    n_features = X.shape[1]

    print(
        f"  target stats: mean={y.mean():.2f} "
        f"stdev={y.std():.2f} min={y.min():.2f} "
        f"max={y.max():.2f}"
    )

    Xtr, Xte, ytr, yte = train_test_split(
        X, y, test_size=test_size, random_state=random_seed
    )

    print(f"  Training MLP(64,32) on {len(Xtr)} rows…")
    model = train_regression(
        Xtr, ytr, n_features, epochs=200, seed=random_seed
    )
    model.eval()

    # Test metrics
    with torch.no_grad():
        Xte_t = torch.tensor(Xte, dtype=torch.float32)
        pred = model(Xte_t).numpy().flatten()

    mae = mean_absolute_error(yte, pred)
    r2 = r2_score(yte, pred)
    # Baseline mean-predictor MAE
    mean_y = ytr.mean()
    baseline_pred = np.full_like(yte, fill_value=mean_y)
    baseline_mae = mean_absolute_error(yte, baseline_pred)

    print(f"  Test metrics:")
    print(f"    MAE:           {mae:.2f}")
    print(f"    R²:            {r2:.4f}")
    print(f"    Baseline MAE:  {baseline_mae:.2f} (mean predictor)")
    print(
        f"    Improvement:   "
        f"{100 * (1 - mae / max(baseline_mae, 1e-9)):.1f}% over baseline"
    )

    # Convert to CoreML
    print(f"  Converting to CoreML via PyTorch + MIL…")
    example = torch.zeros((1, n_features), dtype=torch.float32)
    traced = torch.jit.trace(model, example)
    cml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(
                name="features",
                shape=(1, n_features),
                dtype=np.float32,
            )
        ],
        outputs=[ct.TensorType(name=output_key, dtype=np.float32)],
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )
    cml.short_description = description
    cml.author = (
        f"Qinao Runtime SDK chapter 一百八十 — "
        f"{head_name} regression head"
    )
    cml.license = "Apache-2.0"
    cml.version = "0.0.1"
    cml.input_description["features"] = (
        "43-dim one-hot (same as ChengluPreflight v0.4 / "
        "ChengluPermitPredict v0): 8 tone + 10 domain + "
        "6 stake + 7 timeframe + 4 confidant + "
        "3 askshape + 5 mutationSeed."
    )
    cml.output_description[output_key] = (
        f"Regression head output for {head_name}. Honest "
        f"limit: trained on chapter 175/176 5,088-row "
        f"adversarial corpus only; generalizes poorly to "
        f"non-adversarial prompts."
    )

    if os.path.exists(output_path):
        import shutil
        if os.path.isdir(output_path):
            shutil.rmtree(output_path)
        else:
            os.remove(output_path)
    cml.save(output_path)
    if os.path.isdir(output_path):
        total = sum(
            os.path.getsize(os.path.join(dp, f))
            for dp, _, fs in os.walk(output_path)
            for f in fs
        )
        print(
            f"  .mlpackage saved: {output_path} "
            f"({total:,} bytes)"
        )

    # Sanity check
    print(f"  Sanity (first 3 rows):")
    loaded = ct.models.MLModel(output_path)
    for r in rows[:3]:
        feat = featurize_row(r)
        result = loaded.predict({
            "features": np.array([feat], dtype=np.float32)
        })
        prob = float(result[output_key].flatten()[0])
        actual = label_fn(r)
        sig = r.get("signature", {})
        print(
            f"    {sig.get('tone'):14s} "
            f"actual={actual:>8.1f} predicted={prob:>8.1f}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--iphone",
        default="/tmp/iphone-afm-bench-final-pull",
    )
    parser.add_argument(
        "--length-output",
        default="/tmp/ChengluLengthHead_v0.mlpackage",
    )
    parser.add_argument(
        "--latency-output",
        default="/tmp/ChengluLatencyHead_v0.mlpackage",
    )
    args = parser.parse_args()

    print(f"Loading bench rows from {args.iphone}…")
    rows = load_jsonl_dir(args.iphone)
    print(f"  → {len(rows)} rows")
    if not rows:
        print("ERROR: no rows", file=sys.stderr)
        sys.exit(1)

    # Train Length head
    train_and_export(
        rows=rows,
        label_fn=label_length,
        output_path=args.length_output,
        head_name="ChengluLengthHead v0",
        output_key="body_length",
        description=(
            "ChengluLengthHead v0 — MLP(64,32) regression "
            "predicting AFM body length (chars) from signature "
            "features. Trained on chapter 176 5,088 rows. UI "
            "pre-warm: 'this prompt likely produces N chars'."
        ),
    )

    # Train Latency head
    train_and_export(
        rows=rows,
        label_fn=label_latency,
        output_path=args.latency_output,
        head_name="ChengluLatencyHead v0",
        output_key="duration_ms",
        description=(
            "ChengluLatencyHead v0 — MLP(64,32) regression "
            "predicting AFM duration (ms) from signature "
            "features. Trained on chapter 176 5,088 rows. UI "
            "pre-warm: 'this prompt likely takes ~Ns'."
        ),
    )

    print("\n=== ALL DONE ===")


if __name__ == "__main__":
    main()
