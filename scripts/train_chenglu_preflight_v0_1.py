#!/usr/bin/env python3
"""
ChengluPreflight v0.1 — train MLP(64, 32) in PyTorch directly,
convert to CoreML. Best by AUC in evolve_chenglu_preflight.py
comparison (0.9681 vs v0 LogReg 0.9549, +3.5% acc).

Output: /tmp/ChengluPreflight_v0_1.mlpackage
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from glob import glob
from pathlib import Path

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

sys.path.insert(0, os.path.dirname(__file__))
from train_chenglu_preflight_v0 import (
    featurize_row, label_row, load_jsonl_dir, FEATURE_NAMES,
)


class MLPRouter(nn.Module):
    def __init__(self, n_features: int):
        super().__init__()
        self.fc1 = nn.Linear(n_features, 64)
        self.fc2 = nn.Linear(64, 32)
        self.out = nn.Linear(32, 1)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return torch.sigmoid(self.out(x))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--iphone", default="/tmp/iphone-afm-bench-final-pull")
    parser.add_argument(
        "--output", default="/tmp/ChengluPreflight_v0_1.mlpackage")
    parser.add_argument("--epochs", type=int, default=200)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rows = load_jsonl_dir(args.iphone)
    print(f"Loaded {len(rows)} rows")
    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y = np.array([label_row(r) for r in rows], dtype=np.float32)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=args.seed, stratify=y)
    print(f"Train: {X_train.shape}, Test: {X_test.shape}")

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    n_features = X.shape[1]
    model = MLPRouter(n_features)
    optimizer = torch.optim.Adam(
        model.parameters(), lr=args.lr, weight_decay=1e-4)
    loss_fn = nn.BCELoss(reduction="none")

    # Class weights for imbalance (ok=4056, guardrail=1032 → ~0.797:0.203)
    class_balanced_weights = torch.tensor(
        [(1.0 / 0.203), (1.0 / 0.797)], dtype=torch.float32)
    print(f"Class weights: guardrail={class_balanced_weights[0]:.3f} "
          f"ok={class_balanced_weights[1]:.3f}")

    X_train_t = torch.tensor(X_train, dtype=torch.float32)
    y_train_t = torch.tensor(y_train, dtype=torch.float32).view(-1, 1)
    X_test_t = torch.tensor(X_test, dtype=torch.float32)
    y_test_t = torch.tensor(y_test, dtype=torch.float32).view(-1, 1)

    n_train = len(X_train_t)
    print(f"\nTraining MLP(64, 32) for {args.epochs} epochs…")
    for epoch in range(args.epochs):
        # Shuffle
        idx = torch.randperm(n_train)
        X_shuf = X_train_t[idx]
        y_shuf = y_train_t[idx]
        running_loss = 0.0
        n_batches = 0
        for i in range(0, n_train, args.batch_size):
            xb = X_shuf[i:i + args.batch_size]
            yb = y_shuf[i:i + args.batch_size]
            optimizer.zero_grad()
            pred = model(xb)
            losses = loss_fn(pred, yb)
            # weight per sample by class
            weights = torch.where(
                yb == 1.0,
                class_balanced_weights[1],
                class_balanced_weights[0])
            loss = (losses * weights).mean()
            loss.backward()
            optimizer.step()
            running_loss += loss.item()
            n_batches += 1
        if (epoch + 1) % 25 == 0 or epoch == 0:
            model.eval()
            with torch.no_grad():
                test_pred_prob = model(X_test_t).numpy().flatten()
            test_pred = (test_pred_prob >= 0.5).astype(np.int32)
            y_test_np = y_test_t.numpy().flatten().astype(np.int32)
            acc = accuracy_score(y_test_np, test_pred)
            auc = roc_auc_score(y_test_np, test_pred_prob)
            print(f"  epoch {epoch+1:3d} loss {running_loss/n_batches:.4f} "
                  f"test acc {acc:.4f} auc {auc:.4f}")
            model.train()

    # Final eval
    model.eval()
    with torch.no_grad():
        test_pred_prob = model(X_test_t).numpy().flatten()
    test_pred = (test_pred_prob >= 0.5).astype(np.int32)
    y_test_np = y_test_t.numpy().flatten().astype(np.int32)
    print(f"\n=== Final v0.1 metrics ===")
    print(f"Accuracy: {accuracy_score(y_test_np, test_pred):.4f}")
    print(f"AUC:      {roc_auc_score(y_test_np, test_pred_prob):.4f}")
    print(classification_report(
        y_test_np, test_pred,
        target_names=["guardrail", "ok"]))
    print(f"Confusion matrix:")
    cm = confusion_matrix(y_test_np, test_pred)
    print(f"  guardrail: {cm[0]}")
    print(f"  ok:        {cm[1]}")

    # Threshold tuning for "no error" goal
    # Target: minimize "router predicted AFM but AFM actually
    # guardrails" (FN on guardrail class). Move threshold UP →
    # route more to Gemma (conservative).
    print(f"\nThreshold scan (router conservative mode):")
    for t in np.arange(0.30, 0.71, 0.05):
        pred_t = (test_pred_prob >= t).astype(np.int32)
        # Confusion at this threshold
        tn = ((pred_t == 0) & (y_test_np == 0)).sum()
        fp = ((pred_t == 1) & (y_test_np == 0)).sum()
        fn = ((pred_t == 0) & (y_test_np == 1)).sum()
        tp = ((pred_t == 1) & (y_test_np == 1)).sum()
        afm_routed = (pred_t == 1).sum()
        afm_correct = tp / max(1, afm_routed)  # of those routed AFM, were they really ok?
        gemma_routed = (pred_t == 0).sum()
        gemma_correct = tn / max(1, gemma_routed)
        # Missed-AFM-guardrail = router said AFM but should've said Gemma
        missed_guardrail = fp
        miss_rate = missed_guardrail / max(1, len(y_test_np))
        print(f"  t={t:.2f} afm-coverage={afm_routed/len(y_test_np):.2%} "
              f"afm-correct={afm_correct:.3f} "
              f"gemma-correct={gemma_correct:.3f} "
              f"missed-guardrail-rate={miss_rate:.3%}")

    # Trace + convert to CoreML
    print(f"\nConverting to CoreML…")
    example = torch.zeros((1, n_features), dtype=torch.float32)
    traced = torch.jit.trace(model, example)
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

    coreml_model.short_description = (
        "ChengluPreflight v0.1 — MLP(64,32) trained on chapter 176 "
        "5,088-row iPhone bench. Test acc 92.04% (v0 LogReg was "
        "88.51%). Threshold default 0.5, conservative mode at 0.55+ "
        "(see threshold scan). Output >= threshold → route AFM, "
        "else → route Gemma.")
    coreml_model.author = (
        "Qinao Runtime SDK chapter 一百七十七 evolve v0.1")
    coreml_model.license = "Apache-2.0"
    coreml_model.version = "0.1.0"

    coreml_model.input_description["features"] = (
        "43-dim one-hot feature vector: 8 tone + 10 domain + "
        "6 stake + 7 timeframe + 4 confidant + 3 askshape + "
        "5 mutationSeed (in this exact order).")
    coreml_model.output_description["afm_success_probability"] = (
        "MLP(64,32) sigmoid output. Threshold 0.5 = balanced; "
        "0.55-0.60 = conservative (route more to Gemma).")

    if os.path.exists(args.output):
        import shutil
        shutil.rmtree(args.output) if os.path.isdir(args.output) \
            else os.remove(args.output)
    coreml_model.save(args.output)
    if os.path.isdir(args.output):
        total = sum(
            os.path.getsize(os.path.join(dp, f))
            for dp, _, fs in os.walk(args.output) for f in fs)
        print(f".mlpackage saved: {args.output} ({total:,} bytes)")

    # Sanity check
    print(f"\nSanity check — load + predict 5 examples:")
    loaded = ct.models.MLModel(args.output)
    for sample in rows[:5]:
        feat = featurize_row(sample)
        result = loaded.predict({
            "features": np.array([feat], dtype=np.float32)
        })
        prob = float(result["afm_success_probability"].flatten()[0])
        actual = sample.get("afmStatus")
        choice = "afm" if prob >= 0.5 else "gemma"
        sig = sample.get("signature", {})
        print(f"  {sig.get('tone'):14s} {sig.get('stake'):26s} "
              f"actual={actual:14s} → prob={prob:.4f} → {choice}")


if __name__ == "__main__":
    main()
