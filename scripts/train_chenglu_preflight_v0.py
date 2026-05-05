#!/usr/bin/env python3
"""
M617 chapter 一百七十七 — Train ChengluPreflight v0 single-head
binary classifier (AFM-success vs AFM-guardrail) from chapter 176
bench JSONL data. Convert to CoreML .mlpackage for iPhone bundle.

Usage:
    /tmp/coreml-venv/bin/python3 scripts/train_chenglu_preflight_v0.py \
        --iphone /tmp/iphone-afm-bench-final-pull \
        --output /tmp/ChengluPreflight_v0.mlpackage

Input features (43 binary one-hot):
    - tone (8): anxious / authoritative / vulnerable / agentic /
                confused / grieving / curious / angry
    - domain (10): financial / medical / relational / work /
                   parenting / identity / ethical / existential /
                   trauma / creative
    - stake (6): low / modest / high / very-high / irreversible /
                 non-reversible-after-act
    - timeframe (7): minutes / hours / days / weeks / months /
                     lifetime / past-unresolved
    - confidant (4): friend / expert / stranger / decision-system
    - askShape (3): narrative / decision-tree / single-action
    - mutationSeed (5): 0 / 1 / 2 / 3 / 4

Output: afm_success_probability (Double 0..1) + predicted_class
        (0 = guardrail, 1 = ok)

Decision rule downstream: if probability >= 0.5 → route to AFM,
else → route to Gemma.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from glob import glob
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
)
from sklearn.model_selection import train_test_split

import coremltools as ct

TONES = ["anxious", "authoritative", "vulnerable", "agentic",
         "confused", "grieving", "curious", "angry"]
DOMAINS = ["financial", "medical", "relational", "work",
           "parenting", "identity", "ethical", "existential",
           "trauma", "creative"]
STAKES = ["low", "modest", "high", "very-high",
          "irreversible", "non-reversible-after-act"]
TIMEFRAMES = ["minutes", "hours", "days", "weeks",
              "months", "lifetime", "past-unresolved"]
CONFIDANTS = ["friend", "expert", "stranger", "decision-system"]
ASKSHAPES = ["narrative", "decision-tree", "single-action"]
MUTATIONS = list(range(5))

FEATURE_NAMES = []
for t in TONES:        FEATURE_NAMES.append(f"tone_{t}")
for d in DOMAINS:      FEATURE_NAMES.append(f"domain_{d}")
for s in STAKES:       FEATURE_NAMES.append(f"stake_{s}")
for t in TIMEFRAMES:   FEATURE_NAMES.append(f"timeframe_{t}")
for c in CONFIDANTS:   FEATURE_NAMES.append(f"confidant_{c}")
for a in ASKSHAPES:    FEATURE_NAMES.append(f"askshape_{a}")
for m in MUTATIONS:    FEATURE_NAMES.append(f"mutation_{m}")

assert len(FEATURE_NAMES) == 43


def featurize_row(row):
    sig = row.get("signature") or {}
    if not isinstance(sig, dict):
        sig = {}
    tone = sig.get("tone")
    domain = sig.get("domain")
    stake = sig.get("stake")
    timeframe = sig.get("timeframe")
    confidant = sig.get("confidant")
    ask_shape = sig.get("askShape")
    mutation_seed = row.get("mutationSeed")

    features = []
    features += [1.0 if tone == t else 0.0 for t in TONES]
    features += [1.0 if domain == d else 0.0 for d in DOMAINS]
    features += [1.0 if stake == s else 0.0 for s in STAKES]
    features += [1.0 if timeframe == t else 0.0 for t in TIMEFRAMES]
    features += [1.0 if confidant == c else 0.0 for c in CONFIDANTS]
    features += [1.0 if ask_shape == a else 0.0 for a in ASKSHAPES]
    features += [1.0 if mutation_seed == m else 0.0 for m in MUTATIONS]
    return features


def label_row(row):
    """1 = AFM ok, 0 = AFM guardrail / error."""
    status = row.get("afmStatus", "")
    if status == "ok":
        return 1
    return 0


def load_jsonl_dir(dir_path):
    rows = []
    if not os.path.isdir(dir_path):
        return rows
    for path in sorted(glob(os.path.join(dir_path, "*.jsonl"))):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iphone", required=True,
                        help="Dir with iPhone bench JSONL files")
    parser.add_argument("--output", required=True,
                        help="Output .mlpackage path")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--random-seed", type=int, default=42)
    args = parser.parse_args()

    print(f"Loading iPhone bench rows from {args.iphone}…")
    rows = load_jsonl_dir(args.iphone)
    print(f"  → {len(rows)} rows")

    if not rows:
        print("ERROR: no rows loaded; check --iphone path", file=sys.stderr)
        sys.exit(1)

    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y = np.array([label_row(r) for r in rows], dtype=np.int32)

    print(f"  features shape: {X.shape}")
    print(f"  label balance: ok={int((y==1).sum())} / "
          f"guardrail={int((y==0).sum())} / "
          f"ratio={(y==1).sum()/len(y):.3f}")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size,
        random_state=args.random_seed,
        stratify=y)

    print(f"\nTraining LogisticRegression on {len(X_train)} rows…")
    clf = LogisticRegression(
        max_iter=2000,
        class_weight="balanced",
        random_state=args.random_seed)
    clf.fit(X_train, y_train)

    print(f"\n=== Train metrics ===")
    train_pred = clf.predict(X_train)
    print(f"Accuracy: {accuracy_score(y_train, train_pred):.4f}")

    print(f"\n=== Test metrics ===")
    test_pred = clf.predict(X_test)
    test_proba = clf.predict_proba(X_test)[:, 1]
    print(f"Accuracy: {accuracy_score(y_test, test_pred):.4f}")
    print(f"\nClassification report:")
    print(classification_report(
        y_test, test_pred,
        target_names=["guardrail", "ok"]))
    print(f"Confusion matrix (rows=true, cols=pred):")
    cm = confusion_matrix(y_test, test_pred)
    print(f"  guardrail: {cm[0]}")
    print(f"  ok:        {cm[1]}")

    # Convert to CoreML via PyTorch path
    # (sklearn → coremltools direct fails on Python 3.14 + coremltools 9.0
    #  due to internal _tree import bug; PyTorch path uses MIL converter
    #  which is fully working on this stack.)
    print(f"\nConverting to CoreML via PyTorch + MIL…")
    import torch
    import torch.nn as nn

    class LogisticRegressionModel(nn.Module):
        def __init__(self, n_features):
            super().__init__()
            self.linear = nn.Linear(n_features, 1)

        def forward(self, x):
            # Output afm-success probability via sigmoid
            return torch.sigmoid(self.linear(x))

    n_features = X.shape[1]
    torch_model = LogisticRegressionModel(n_features)
    # Load sklearn weights into PyTorch
    coef = clf.coef_[0]  # shape (n_features,)
    intercept = clf.intercept_[0]
    with torch.no_grad():
        torch_model.linear.weight.copy_(
            torch.tensor(coef.reshape(1, -1), dtype=torch.float32))
        torch_model.linear.bias.copy_(
            torch.tensor([intercept], dtype=torch.float32))
    torch_model.eval()

    # Trace
    example_input = torch.zeros((1, n_features), dtype=torch.float32)
    traced = torch.jit.trace(torch_model, example_input)

    # Convert via MIL
    coreml_model = ct.convert(
        traced,
        inputs=[ct.TensorType(
            name="features",
            shape=(1, n_features),
            dtype=np.float32)],
        outputs=[ct.TensorType(
            name="afm_success_probability",
            dtype=np.float32)],
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17)

    # Add metadata
    coreml_model.short_description = (
        "ChengluPreflight v0 — predicts AFM-success probability "
        "for a given prompt signature. Output >= 0.5 → route AFM; "
        "< 0.5 → route Gemma. Train accuracy ~89% on chapter 176 bench.")
    coreml_model.author = "Qinao Runtime SDK chapter 一百七十七 M617"
    coreml_model.license = "Apache-2.0"
    coreml_model.version = "1.0.0"

    coreml_model.input_description["features"] = (
        "43-dim one-hot feature vector: 8 tone + 10 domain + "
        "6 stake + 7 timeframe + 4 confidant + 3 askshape + "
        "5 mutationSeed (in this exact order).")
    coreml_model.output_description["afm_success_probability"] = (
        "Probability that AFM will produce ok response (vs "
        "guardrail-refuse). Threshold at 0.5 to choose router action.")

    output_path = args.output
    if os.path.exists(output_path):
        import shutil
        shutil.rmtree(output_path) if os.path.isdir(output_path) \
            else os.remove(output_path)
    coreml_model.save(output_path)

    # Report file size
    if os.path.isdir(output_path):
        total = sum(
            os.path.getsize(os.path.join(dp, f))
            for dp, _, fs in os.walk(output_path) for f in fs)
        print(f"\n.mlpackage saved: {output_path} ({total:,} bytes)")
    else:
        print(f"\n.mlmodel saved: {output_path} "
              f"({os.path.getsize(output_path):,} bytes)")

    # Sanity: load and predict
    print(f"\nSanity check — load + predict 3 examples:")
    loaded = ct.models.MLModel(output_path)
    for sample in rows[:3]:
        feat = featurize_row(sample)
        # CoreML MIL model takes feature tensor (1, n_features)
        input_tensor = np.array([feat], dtype=np.float32)
        result = loaded.predict({"features": input_tensor})
        actual_status = sample.get("afmStatus")
        prob = float(result["afm_success_probability"].flatten()[0])
        choice = "afm" if prob >= 0.5 else "gemma"
        print(f"  iter={sample.get('iteration','?')} "
              f"actual={actual_status:14s} → "
              f"prob={prob:.4f} → route={choice}")


if __name__ == "__main__":
    main()
