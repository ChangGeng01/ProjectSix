#!/usr/bin/env python3
"""M633 chapter 一百七十九 — Train ChengluPermitPredict v0.

The 2nd CoreML head added to the meridian network. Predicts which
permit mode substrate WILL issue from prompt features alone, using
the same 43-dim signature one-hot as ChengluPreflight v0.4.

Why this matters (re: 任督二脉 metaphor):
- ChengluPreflight v0.4 (the 1st head) sits at the gateway between
  substrate and LLM dispatch (predicts AFM-vs-Gemma).
- ChengluPermitPredict v0 (the 2nd head) sits parallel to substrate
  itself (predicts permit-mode delay-vs-block).
- Two CoreML heads. Two meridian points. 2/18 of the planned
  meridian network.

Doctrine pin: this prediction does NOT replace substrate's
authority. Substrate ALWAYS fires (red line: 不变量 #1 先醒再答).
The CoreML prediction runs alongside substrate, recording
agreement/disagreement for empirical analysis. Disagreements are
doctrine-drift signals, not authoritative overrides.

Training data: chapter 175/176 5,088 iPhone bench rows. The
empirical permit-mode distribution is ~50/50 delay-vs-block in
this adversarial corpus. Binary classifier suffices.

Honest scope limit: this model trained ONLY on adversarial corpus
(8 high-charge tones × 6 risk stakes × etc.). Generalization to
benign prompts is not validated. v0.x → v1 retrain on broader
corpus is roadmapped to chapter 一百八十+.

Usage:
    /tmp/coreml-py312/bin/python3 \\
        scripts/train_chenglu_permit_predict_v0.py \\
        --iphone /tmp/iphone-afm-bench-final-pull \\
        --output SampleHost/ChengluPermitPredict_v0.mlpackage
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from glob import glob

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

import coremltools as ct

# Reuse the proven featurize from v0.x — same 43-dim one-hot.
sys.path.insert(0, os.path.dirname(__file__))
from train_chenglu_preflight_v0 import (
    featurize_row,
    load_jsonl_dir,
    FEATURE_NAMES,
)


def label_permit_block(row: dict) -> int:
    """1 = substrate issued .block, 0 = .delay (or other non-block).

    Trained on chapter 176 corpus where distribution is ~50/50
    delay/block. For broader corpora future versions should
    multi-class over 9 BASActionPermitMode cases.
    """
    pm = row.get("permitMode", "")
    return 1 if pm == "block" else 0


class PermitMLP(nn.Module):
    """Same MLP(64,32) shape as ChengluPreflight v0.4 — keeps
    architecture symmetric across heads, lets future shared-encoder
    refactor lift this exact body unchanged.
    """

    def __init__(self, n_features: int):
        super().__init__()
        self.fc1 = nn.Linear(n_features, 64)
        self.fc2 = nn.Linear(64, 32)
        self.out = nn.Linear(32, 1)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return torch.sigmoid(self.out(x))


def train_mlp(
    X_train: np.ndarray,
    y_train: np.ndarray,
    n_features: int,
    epochs: int = 200,
    lr: float = 1e-3,
    batch: int = 64,
    seed: int = 42,
) -> PermitMLP:
    torch.manual_seed(seed)
    np.random.seed(seed)
    model = PermitMLP(n_features)
    optimizer = torch.optim.Adam(
        model.parameters(), lr=lr, weight_decay=1e-4
    )
    loss_fn = nn.BCELoss()
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--iphone",
        default="/tmp/iphone-afm-bench-final-pull",
    )
    parser.add_argument(
        "--output",
        default="/tmp/ChengluPermitPredict_v0.mlpackage",
    )
    parser.add_argument(
        "--test-size", type=float, default=0.2
    )
    parser.add_argument("--random-seed", type=int, default=42)
    args = parser.parse_args()

    print(f"Loading bench rows from {args.iphone}…")
    rows = load_jsonl_dir(args.iphone)
    print(f"  → {len(rows)} rows")
    if not rows:
        print("ERROR: no rows", file=sys.stderr)
        sys.exit(1)

    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y = np.array([label_permit_block(r) for r in rows], dtype=np.float32)

    print(f"  features shape: {X.shape}")
    print(
        f"  label balance: block={int((y == 1).sum())} / "
        f"non-block={int((y == 0).sum())} / "
        f"ratio={(y == 1).sum() / len(y):.3f}"
    )

    Xtr, Xte, ytr, yte = train_test_split(
        X,
        y,
        test_size=args.test_size,
        random_state=args.random_seed,
        stratify=y,
    )

    n_features = X.shape[1]
    print(f"\nTraining PermitMLP(64,32) on {len(Xtr)} rows, 200 epochs…")
    model = train_mlp(Xtr, ytr, n_features, epochs=200, seed=args.random_seed)
    model.eval()

    # Test metrics
    with torch.no_grad():
        Xte_t = torch.tensor(Xte, dtype=torch.float32)
        proba = model(Xte_t).numpy().flatten()
    pred = (proba >= 0.5).astype(int)
    yte_int = yte.astype(int)

    print(f"\n=== v0 permit-predict test metrics ===")
    print(f"Accuracy: {accuracy_score(yte_int, pred):.4f}")
    print(f"AUC:      {roc_auc_score(yte_int, proba):.4f}")
    print(classification_report(
        yte_int, pred, target_names=["non-block", "block"]
    ))
    cm = confusion_matrix(yte_int, pred)
    print(f"Confusion matrix (rows=true, cols=pred):")
    print(f"  non-block: {cm[0]}")
    print(f"  block:     {cm[1]}")

    # Convert to CoreML via PyTorch + MIL (same path as v0.4)
    print(f"\nConverting to CoreML via PyTorch + MIL…")
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
        outputs=[
            ct.TensorType(
                name="block_probability",
                dtype=np.float32,
            )
        ],
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )
    cml.short_description = (
        "ChengluPermitPredict v0 — MLP(64,32) binary classifier "
        "predicting whether substrate will issue .block (1) vs "
        ".delay/other (0) permit mode. Trained on chapter 176 "
        "5,088-row adversarial iPhone bench data. 2nd CoreML head "
        "in 14-layer meridian network — runs alongside substrate, "
        "never replaces (red line: 先醒再答 unchanged)."
    )
    cml.author = "Qinao Runtime SDK chapter 一百七十九 — 2nd meridian point"
    cml.license = "Apache-2.0"
    cml.version = "0.0.1"
    cml.input_description["features"] = (
        "43-dim one-hot (same as ChengluPreflight v0.4): "
        "8 tone + 10 domain + 6 stake + 7 timeframe + "
        "4 confidant + 3 askshape + 5 mutationSeed."
    )
    cml.output_description["block_probability"] = (
        "Probability substrate will route this prompt to "
        "BASActionPermitMode.block. Threshold 0.5 → predicted "
        "block; runtime records prediction-vs-actual agreement "
        "but does NOT preempt substrate (red line: substrate "
        "always fires first)."
    )

    if os.path.exists(args.output):
        import shutil
        if os.path.isdir(args.output):
            shutil.rmtree(args.output)
        else:
            os.remove(args.output)
    cml.save(args.output)
    if os.path.isdir(args.output):
        total = sum(
            os.path.getsize(os.path.join(dp, f))
            for dp, _, fs in os.walk(args.output)
            for f in fs
        )
        print(f".mlpackage saved: {args.output} ({total:,} bytes)")

    # Sanity check
    print(f"\nSanity check (first 5 rows raw → predicted):")
    loaded = ct.models.MLModel(args.output)
    for r in rows[:5]:
        feat = featurize_row(r)
        result = loaded.predict({
            "features": np.array([feat], dtype=np.float32)
        })
        prob = float(result["block_probability"].flatten()[0])
        actual = r.get("permitMode", "?")
        sig = r.get("signature", {})
        predicted = "block" if prob >= 0.5 else "non-block"
        print(
            f"  {sig.get('tone'):14s} "
            f"{sig.get('stake'):26s} "
            f"actual={actual:7s} prob={prob:.3f} → {predicted}"
        )


if __name__ == "__main__":
    main()
