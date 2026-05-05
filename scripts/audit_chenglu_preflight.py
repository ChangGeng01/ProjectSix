#!/usr/bin/env python3
"""
Chapter 一百七十七 全面 CoreML 严查 — comprehensive audit:

1. K-fold cross-validation: verify 92.53% is stable (not lucky split)
2. Distribution analysis: train/test feature distribution shift?
3. Feature ablation: which features matter most?
4. Adding extra features: prompt length, ordinal stake, etc.
5. Per-tone confusion matrix
6. Calibration check: are predicted probabilities reliable?
7. Confidence threshold optimization (data-driven)
"""

from __future__ import annotations
import json
import os
import sys
from glob import glob
from pathlib import Path
from collections import Counter

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    roc_auc_score,
    brier_score_loss,
    log_loss,
)
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.calibration import calibration_curve

sys.path.insert(0, os.path.dirname(__file__))
from train_chenglu_preflight_v0 import (
    featurize_row, label_row, load_jsonl_dir, FEATURE_NAMES,
)
from train_chenglu_preflight_v0_1 import MLPRouter


def train_fold(X_train, y_train, X_test, y_test, n_features,
               epochs=200, lr=1e-3, batch=64, seed=42):
    torch.manual_seed(seed)
    np.random.seed(seed)
    model = MLPRouter(n_features)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr,
                                  weight_decay=1e-4)
    loss_fn = nn.BCELoss(reduction="none")
    cw = torch.tensor([(1.0/0.203), (1.0/0.797)], dtype=torch.float32)
    Xtr = torch.tensor(X_train, dtype=torch.float32)
    ytr = torch.tensor(y_train, dtype=torch.float32).view(-1, 1)
    Xte = torch.tensor(X_test, dtype=torch.float32)
    yte = torch.tensor(y_test, dtype=torch.float32).view(-1, 1)
    n = len(Xtr)
    for epoch in range(epochs):
        idx = torch.randperm(n)
        Xs, ys = Xtr[idx], ytr[idx]
        for i in range(0, n, batch):
            xb = Xs[i:i+batch]
            yb = ys[i:i+batch]
            optimizer.zero_grad()
            pred = model(xb)
            losses = loss_fn(pred, yb)
            w = torch.where(yb == 1.0, cw[1], cw[0])
            (losses * w).mean().backward()
            optimizer.step()
    model.eval()
    with torch.no_grad():
        proba = model(Xte).numpy().flatten()
    pred = (proba >= 0.5).astype(int)
    return {
        "acc": accuracy_score(y_test, pred),
        "auc": roc_auc_score(y_test, proba),
        "brier": brier_score_loss(y_test, proba),
        "logloss": log_loss(y_test, proba, labels=[0, 1]),
        "proba": proba,
        "pred": pred,
        "y": y_test,
    }


def main():
    rows = load_jsonl_dir("/tmp/iphone-afm-bench-final-pull")
    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y = np.array([label_row(r) for r in rows], dtype=np.int32)
    n_features = X.shape[1]
    print(f"Loaded {len(rows)} rows, {n_features} features")
    print(f"Class balance: ok={int((y==1).sum())} / "
          f"guard={int((y==0).sum())}")

    # === Phase 1: K-fold stability check ===
    print("\n=== PHASE 1: 5-fold cross-validation ===")
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    fold_metrics = []
    for fold, (tr_idx, te_idx) in enumerate(skf.split(X, y)):
        m = train_fold(
            X[tr_idx], y[tr_idx], X[te_idx], y[te_idx],
            n_features, epochs=100)
        print(f"  Fold {fold+1}: acc={m['acc']:.4f} "
              f"auc={m['auc']:.4f} brier={m['brier']:.4f} "
              f"logloss={m['logloss']:.4f}")
        fold_metrics.append(m)
    accs = [m["acc"] for m in fold_metrics]
    aucs = [m["auc"] for m in fold_metrics]
    print(f"\n  Mean ± std: acc={np.mean(accs):.4f} ± {np.std(accs):.4f}")
    print(f"  Mean ± std: auc={np.mean(aucs):.4f} ± {np.std(aucs):.4f}")
    print(f"  Range:      acc=[{min(accs):.4f}, {max(accs):.4f}] "
          f"(spread {max(accs)-min(accs):.4f})")

    # === Phase 2: Distribution analysis (per-tone) ===
    print("\n=== PHASE 2: Per-tone class distribution ===")
    from train_chenglu_preflight_v0 import TONES
    tone_class = {}
    for r in rows:
        tone = (r.get("signature") or {}).get("tone", "?")
        ok = label_row(r)
        tone_class.setdefault(tone, {"ok": 0, "guard": 0})
        if ok:
            tone_class[tone]["ok"] += 1
        else:
            tone_class[tone]["guard"] += 1
    print(f"  {'tone':14s} {'ok':>6s} {'guard':>6s} {'guard%':>8s}")
    for t in TONES:
        c = tone_class.get(t, {"ok": 0, "guard": 0})
        total = c["ok"] + c["guard"]
        gp = c["guard"]/total if total else 0
        print(f"  {t:14s} {c['ok']:>6d} {c['guard']:>6d} {gp:>8.2%}")

    # === Phase 3: Feature ablation ===
    # Train 7 versions, each with one feature group masked out
    print("\n=== PHASE 3: Feature group ablation (single split) ===")
    Xtr, Xte, ytr, yte = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y)
    groups = {
        "all (baseline)": list(range(43)),
        "no tone (8)": [i for i in range(43) if not (0 <= i < 8)],
        "no domain (10)": [i for i in range(43) if not (8 <= i < 18)],
        "no stake (6)": [i for i in range(43) if not (18 <= i < 24)],
        "no timeframe (7)": [i for i in range(43) if not (24 <= i < 31)],
        "no confidant (4)": [i for i in range(43) if not (31 <= i < 35)],
        "no askshape (3)": [i for i in range(43) if not (35 <= i < 38)],
        "no mutation (5)": [i for i in range(43) if not (38 <= i < 43)],
    }
    for name, cols in groups.items():
        Xtr_a = Xtr[:, cols]
        Xte_a = Xte[:, cols]
        m = train_fold(Xtr_a, ytr, Xte_a, yte, len(cols), epochs=100)
        print(f"  {name:25s} acc={m['acc']:.4f} auc={m['auc']:.4f}")

    # === Phase 4: Calibration check ===
    print("\n=== PHASE 4: Calibration (reliability) ===")
    full = train_fold(Xtr, ytr, Xte, yte, n_features, epochs=200)
    fop, mpv = calibration_curve(yte, full["proba"], n_bins=10,
                                  strategy="quantile")
    print(f"  Mean predicted prob → fraction of positives:")
    for p, f in zip(mpv, fop):
        print(f"    p={p:.3f} → fraction={f:.3f} (delta {f-p:+.3f})")
    print(f"  Brier: {full['brier']:.4f} (lower is better; max ~0.25)")

    # === Phase 5: Confidence zone analysis (data-driven) ===
    print("\n=== PHASE 5: Confidence zone analysis ===")
    proba = full["proba"]
    y_test = full["y"]
    for low, high in [(0.40, 0.60), (0.45, 0.55), (0.42, 0.58),
                      (0.48, 0.52), (0.30, 0.70)]:
        mask = (proba >= low) & (proba <= high)
        n_in = mask.sum()
        if n_in == 0:
            continue
        zone_acc = accuracy_score(
            y_test[mask], (proba[mask] >= 0.5).astype(int))
        guardrail_in_zone = (y_test[mask] == 0).sum()
        ok_in_zone = (y_test[mask] == 1).sum()
        print(f"  zone [{low:.2f}, {high:.2f}]: n={n_in:>3d} "
              f"({100*n_in/len(y_test):>5.1f}%)  "
              f"acc={zone_acc:.3f}  ok={ok_in_zone} guard={guardrail_in_zone}")

    # === Phase 6: Per-tone confusion (best model) ===
    print("\n=== PHASE 6: Per-tone errors (full split) ===")
    test_idx = [i for i, _ in enumerate(rows)]
    _, test_idx_arr, _, _ = train_test_split(
        np.arange(len(rows)), y, test_size=0.2, random_state=42, stratify=y)
    test_rows = [rows[i] for i in test_idx_arr]
    pred_te = full["pred"]
    y_te = full["y"]
    print(f"  {'tone':14s} {'ok->guard':>10s} {'guard->ok':>10s} {'total':>6s}")
    for tone in TONES:
        miss_o2g = 0
        miss_g2o = 0
        total = 0
        for r, p, t in zip(test_rows, pred_te, y_te):
            sig = r.get("signature") or {}
            if sig.get("tone") != tone:
                continue
            total += 1
            if t == 1 and p == 0: miss_o2g += 1
            elif t == 0 and p == 1: miss_g2o += 1
        print(f"  {tone:14s} {miss_o2g:>10d} {miss_g2o:>10d} {total:>6d}")


if __name__ == "__main__":
    main()
