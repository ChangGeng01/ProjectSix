#!/usr/bin/env python3
"""
Evolve ChengluPreflight v0 — try multiple model classes, find best,
threshold-tune for "no error" goal, output v1.

Chapter 一百七十七 §177.evolve — push 88.5% → ?, analyze where v0
fails, pick highest f1 / best precision-recall trade-off for
fallback-aware deployment.
"""

from __future__ import annotations

import json
import os
import sys
from glob import glob
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import (
    RandomForestClassifier,
    GradientBoostingClassifier,
)
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    precision_recall_curve,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

sys.path.insert(0, os.path.dirname(__file__))
from train_chenglu_preflight_v0 import (
    featurize_row, label_row, load_jsonl_dir,
    FEATURE_NAMES, TONES, DOMAINS, STAKES,
    TIMEFRAMES, CONFIDANTS, ASKSHAPES, MUTATIONS,
)


def main():
    iphone_dir = "/tmp/iphone-afm-bench-final-pull"
    rows = load_jsonl_dir(iphone_dir)
    print(f"Loaded {len(rows)} rows")

    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y = np.array([label_row(r) for r in rows], dtype=np.int32)
    print(f"X: {X.shape}, y: ok={int((y==1).sum())} guardrail={int((y==0).sum())}")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y)

    models = {
        "LogReg(balanced)": LogisticRegression(
            max_iter=2000, class_weight="balanced",
            random_state=42),
        "LogReg(C=10)": LogisticRegression(
            max_iter=2000, class_weight="balanced", C=10,
            random_state=42),
        "RandomForest(200,d=10)": RandomForestClassifier(
            n_estimators=200, max_depth=10,
            class_weight="balanced", random_state=42, n_jobs=-1),
        "RandomForest(500,d=20)": RandomForestClassifier(
            n_estimators=500, max_depth=20,
            class_weight="balanced", random_state=42, n_jobs=-1),
        "GradientBoosting(200)": GradientBoostingClassifier(
            n_estimators=200, max_depth=3, random_state=42),
        "GradientBoosting(500)": GradientBoostingClassifier(
            n_estimators=500, max_depth=4, random_state=42),
        "MLP(64,32)": MLPClassifier(
            hidden_layer_sizes=(64, 32), max_iter=500,
            random_state=42),
        "MLP(128,64,32)": MLPClassifier(
            hidden_layer_sizes=(128, 64, 32), max_iter=500,
            random_state=42),
    }

    print(f"\n{'Model':32s} {'Acc':>8s} {'F1':>8s} {'AUC':>8s} {'Prec(g)':>8s} {'Rec(g)':>8s}")
    print("-" * 80)
    results = {}
    for name, m in models.items():
        m.fit(X_train, y_train)
        pred = m.predict(X_test)
        acc = accuracy_score(y_test, pred)
        f1 = f1_score(y_test, pred, pos_label=1)
        try:
            proba = m.predict_proba(X_test)[:, 1]
            auc = roc_auc_score(y_test, proba)
        except Exception:
            auc = float("nan")
        cm = confusion_matrix(y_test, pred)
        prec_g = cm[0, 0] / max(1, cm[0, 0] + cm[1, 0])
        rec_g = cm[0, 0] / max(1, cm[0, 0] + cm[0, 1])
        results[name] = {
            "model": m, "acc": acc, "f1": f1,
            "auc": auc, "prec_guard": prec_g,
            "rec_guard": rec_g}
        print(f"{name:32s} {acc:>8.4f} {f1:>8.4f} {auc:>8.4f} {prec_g:>8.4f} {rec_g:>8.4f}")

    best_name = max(results.keys(), key=lambda n: results[n]["auc"])
    best = results[best_name]
    print(f"\nBest by AUC: {best_name} (AUC {best['auc']:.4f})")

    # Threshold tuning for the best model
    if hasattr(best["model"], "predict_proba"):
        proba = best["model"].predict_proba(X_test)[:, 1]
        prec, rec, thresh = precision_recall_curve(y_test, proba)
        f1s = 2 * prec * rec / (prec + rec + 1e-10)
        best_idx = int(np.argmax(f1s))
        opt_thresh = thresh[best_idx] if best_idx < len(thresh) else 0.5
        print(f"\nOptimal threshold (max F1): {opt_thresh:.4f} (vs default 0.5)")
        print(f"  At opt: precision={prec[best_idx]:.4f} recall={rec[best_idx]:.4f} f1={f1s[best_idx]:.4f}")

        # "No error" oriented threshold:
        # When the goal is fewest user-facing errors (with fallback
        # safety net), we want to MINIMIZE router-misses where the
        # router predicts AFM but AFM actually guardrails. That's
        # FALSE NEGATIVES on guardrail class. So threshold should
        # be HIGHER (more conservative, route more to gemma).
        # Find threshold where precision on guardrail >= 90%.
        targets = [0.8, 0.85, 0.9, 0.95]
        print("\nGuardrail-class precision targets (router conservative mode):")
        for tp in targets:
            # Find threshold where (predicted as guardrail = pred class 0) precision >= tp
            # Class 0 is guardrail. We want when we say "predicted guardrail" to be right.
            # So among rows where proba < t, fraction that are actually guardrail.
            for t in np.arange(0.95, 0.05, -0.05):
                pred_test = (proba >= t).astype(int)
                if (pred_test == 0).sum() == 0:
                    continue
                guard_prec = (
                    (pred_test == 0) & (y_test == 0)
                ).sum() / max(1, (pred_test == 0).sum())
                if guard_prec >= tp:
                    afm_recall = (
                        (pred_test == 1) & (y_test == 1)
                    ).sum() / max(1, (y_test == 1).sum())
                    coverage = (pred_test == 1).sum() / len(y_test)
                    print(f"  prec(guard) >= {tp:.2f} at threshold {t:.2f}: "
                          f"afm-coverage={coverage:.2%} afm-recall={afm_recall:.2%}")
                    break
            else:
                print(f"  prec(guard) >= {tp:.2f} not reachable")

    # Per-tone error analysis on best model
    print(f"\nPer-tone error analysis ({best_name}):")
    test_pred = best["model"].predict(X_test)
    test_idx = np.array(np.arange(len(rows)))[
        np.isin(np.arange(len(rows)), np.array([]))]  # dummy
    # Recompute proper test indices
    _, test_idx, _, _ = train_test_split(
        np.arange(len(rows)), y, test_size=0.2,
        random_state=42, stratify=y)
    print(f"  test set size: {len(test_idx)}")
    test_rows = [rows[i] for i in test_idx]
    error_rows = [
        (r, p) for r, p, t in zip(test_rows, test_pred, y_test)
        if p != t]
    print(f"  total errors: {len(error_rows)}")
    by_tone_err = {}
    by_tone_total = {}
    for r, p in error_rows:
        tone = (r.get("signature") or {}).get("tone", "?")
        by_tone_err[tone] = by_tone_err.get(tone, 0) + 1
    for r in test_rows:
        tone = (r.get("signature") or {}).get("tone", "?")
        by_tone_total[tone] = by_tone_total.get(tone, 0) + 1
    print(f"  {'tone':16s} {'err':>6s} {'total':>6s} {'rate':>6s}")
    for t in sorted(by_tone_total.keys()):
        e = by_tone_err.get(t, 0)
        n = by_tone_total[t]
        print(f"  {t:16s} {e:>6d} {n:>6d} {e/n:>6.2%}")


if __name__ == "__main__":
    main()
