#!/usr/bin/env python3
"""M645 chapter 一百八十一 — ChengluMultiHead v0.

The architectural shift chapter 一百七十七's plan called for:
shared encoder + multi-head joint training.

Pre-this-batch: 4 separate .mlpackage files (Preflight v0.4 +
PermitPredict v0 + LengthHead v0 + LatencyHead v0). Each head
has its own MLP body (43→64→32→1). 4 forward passes per turn,
4 model loads, 4 separate featurize calls — duplicated work.

Post-this-batch: ONE model with shared trunk:
  43 (one-hot input)
  → fc1: 43 → 64 (shared encoder layer 1, ReLU)
  → fc2: 64 → 32 (shared encoder layer 2, ReLU)
  → 4 output heads (each 32 → 1):
      out_afm_success: sigmoid → AFM success probability
      out_block:       sigmoid → block probability
      out_length:      linear → predicted body chars
      out_latency:     linear → predicted duration ms

Joint training: SUM of (BCE + BCE + MSE_norm + MSE_norm) per
batch. Regression targets normalized (z-score on training set)
to keep loss components on comparable scale. Inference path
denormalizes for human-readable prediction.

This is the meridian architecture from chapter 一百七十七 P0
plan: 1 TextEncoder + N task heads. The 4 heads still use the
same 43-dim signature one-hot rather than a true text embedding,
but the structural pattern is in place; chapter 一百八十二+ can
swap signature features for sentence-transformers embedding
without changing the head architecture.

Honest empirical context: joint training won't necessarily
improve any single head over the v0.x separate trainings.
Multi-task transfer can hurt or help. We measure all 4 head
metrics post-training and compare to chapter 一百七十九 +
一百八十's separate-head results. If joint hurts, we ship
anyway because the architectural change is what matters here
(eliminates featurize triplication, single MLModel load).

Usage:
    /tmp/coreml-py312/bin/python3 \\
        scripts/train_chenglu_multihead_v0.py \\
        --iphone /tmp/iphone-afm-bench-final-pull \\
        --output SampleHost/ChengluMultiHead_v0.mlpackage
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import (
    accuracy_score,
    mean_absolute_error,
    r2_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

import coremltools as ct

sys.path.insert(0, os.path.dirname(__file__))
# M658 chapter 一百八十三 — single-source via shared schema.
from chenglu_feature_schema import (
    featurize_row,
    label_afm_ok as label_row,
    label_block,
    label_body_length as label_length,
    label_duration_ms as label_latency,
    label_verbosity_class,
)
from train_chenglu_preflight_v0 import load_jsonl_dir


class MultiHeadModel(nn.Module):
    """Shared trunk + 5 task heads (M661 chapter 183 — added 5th).

    Trunk: 43 → 64 → 32 (ReLU). 5 heads each (32 → 1):
    - out_afm_success: sigmoid (binary)
    - out_block: sigmoid (binary)
    - out_length: linear (regression on z-normalized target)
    - out_latency: linear (regression on z-normalized target)
    - out_verbosity: sigmoid (binary, body > 1500 chars)

    The 5th head demonstrates the architectural promise of
    chapter 一百八十一: adding a head is now a single
    `head_X: 32 → 1` Linear layer + 1 forward-pass output, no
    new model loads, no new featurize duplication.
    """

    def __init__(self, n_features: int = 43):
        super().__init__()
        self.fc1 = nn.Linear(n_features, 64)
        self.fc2 = nn.Linear(64, 32)
        self.head_afm = nn.Linear(32, 1)
        self.head_block = nn.Linear(32, 1)
        self.head_length = nn.Linear(32, 1)
        self.head_latency = nn.Linear(32, 1)
        self.head_verbosity = nn.Linear(32, 1)

    def forward(self, x):
        h = torch.relu(self.fc1(x))
        h = torch.relu(self.fc2(h))
        afm = torch.sigmoid(self.head_afm(h))
        block = torch.sigmoid(self.head_block(h))
        length_norm = self.head_length(h)  # in z-space
        latency_norm = self.head_latency(h)  # in z-space
        verbosity = torch.sigmoid(self.head_verbosity(h))
        return afm, block, length_norm, latency_norm, verbosity


def train_multihead(
    Xtr: np.ndarray,
    y_afm_tr: np.ndarray,
    y_block_tr: np.ndarray,
    y_length_norm_tr: np.ndarray,
    y_latency_norm_tr: np.ndarray,
    y_verbosity_tr: np.ndarray,
    epochs: int = 200,
    lr: float = 1e-3,
    batch: int = 64,
    seed: int = 42,
    loss_weights: tuple = (1.0, 1.0, 0.5, 0.5, 1.0),
) -> MultiHeadModel:
    """Joint train all 5 heads with weighted sum loss.

    loss_weights: (afm_bce, block_bce, length_mse, latency_mse,
                   verbosity_bce). M661 chapter 183 — verbosity
    weight 1.0 to match the binary heads' gradient pressure.
    """
    torch.manual_seed(seed)
    np.random.seed(seed)
    model = MultiHeadModel()
    optimizer = torch.optim.Adam(
        model.parameters(), lr=lr, weight_decay=1e-4
    )
    bce = nn.BCELoss()
    mse = nn.MSELoss()
    Xt = torch.tensor(Xtr, dtype=torch.float32)
    y_afm_t = torch.tensor(y_afm_tr, dtype=torch.float32).view(-1, 1)
    y_block_t = torch.tensor(y_block_tr, dtype=torch.float32).view(-1, 1)
    y_len_t = torch.tensor(
        y_length_norm_tr, dtype=torch.float32
    ).view(-1, 1)
    y_lat_t = torch.tensor(
        y_latency_norm_tr, dtype=torch.float32
    ).view(-1, 1)
    y_verb_t = torch.tensor(
        y_verbosity_tr, dtype=torch.float32
    ).view(-1, 1)
    n = len(Xt)
    w_afm, w_block, w_length, w_latency, w_verbosity = loss_weights
    for epoch in range(epochs):
        idx = torch.randperm(n)
        Xs = Xt[idx]
        ys_afm = y_afm_t[idx]
        ys_block = y_block_t[idx]
        ys_length = y_len_t[idx]
        ys_latency = y_lat_t[idx]
        ys_verbosity = y_verb_t[idx]
        for i in range(0, n, batch):
            xb = Xs[i:i + batch]
            yb_afm = ys_afm[i:i + batch]
            yb_block = ys_block[i:i + batch]
            yb_length = ys_length[i:i + batch]
            yb_latency = ys_latency[i:i + batch]
            yb_verbosity = ys_verbosity[i:i + batch]
            optimizer.zero_grad()
            (
                pred_afm, pred_block,
                pred_length, pred_latency, pred_verbosity,
            ) = model(xb)
            loss = (
                w_afm * bce(pred_afm, yb_afm)
                + w_block * bce(pred_block, yb_block)
                + w_length * mse(pred_length, yb_length)
                + w_latency * mse(pred_latency, yb_latency)
                + w_verbosity * bce(pred_verbosity, yb_verbosity)
            )
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
        default="/tmp/ChengluMultiHead_v0.mlpackage",
    )
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--random-seed", type=int, default=42)
    args = parser.parse_args()

    print(f"Loading bench rows from {args.iphone}…")
    rows = load_jsonl_dir(args.iphone)
    print(f"  → {len(rows)} rows")
    if not rows:
        print("ERROR: no rows", file=sys.stderr)
        sys.exit(1)

    X = np.array([featurize_row(r) for r in rows], dtype=np.float32)
    y_afm = np.array([label_row(r) for r in rows], dtype=np.float32)
    y_block = np.array([label_block(r) for r in rows], dtype=np.float32)
    y_length = np.array(
        [label_length(r) for r in rows], dtype=np.float32
    )
    y_latency = np.array(
        [label_latency(r) for r in rows], dtype=np.float32
    )
    # M661 chapter 一百八十三 — 5th head label.
    y_verbosity = np.array(
        [label_verbosity_class(r) for r in rows], dtype=np.float32
    )

    print(f"  features:     {X.shape}")
    print(
        f"  afm balance:    ok={int((y_afm == 1).sum())} / "
        f"err={int((y_afm == 0).sum())}"
    )
    print(
        f"  block balance:  block={int((y_block == 1).sum())} / "
        f"non-block={int((y_block == 0).sum())}"
    )
    print(
        f"  length stats:   mean={y_length.mean():.1f} "
        f"stdev={y_length.std():.1f}"
    )
    print(
        f"  latency stats:  mean={y_latency.mean():.1f} "
        f"stdev={y_latency.std():.1f}"
    )
    print(
        f"  verbosity:      long(>1500)={int((y_verbosity == 1).sum())} / "
        f"short={int((y_verbosity == 0).sum())}"
    )

    # Single train/test split for ALL heads (so test set is consistent
    # across head metric reporting).
    Xtr, Xte, idx_tr, idx_te = train_test_split(
        X,
        np.arange(len(X)),
        test_size=args.test_size,
        random_state=args.random_seed,
    )
    y_afm_tr, y_afm_te = y_afm[idx_tr], y_afm[idx_te]
    y_block_tr, y_block_te = y_block[idx_tr], y_block[idx_te]
    y_length_tr, y_length_te = y_length[idx_tr], y_length[idx_te]
    y_latency_tr, y_latency_te = y_latency[idx_tr], y_latency[idx_te]
    y_verbosity_tr, y_verbosity_te = (
        y_verbosity[idx_tr], y_verbosity[idx_te]
    )

    # Z-normalize regression targets on training set
    length_mean = float(y_length_tr.mean())
    length_std = float(y_length_tr.std() + 1e-9)
    latency_mean = float(y_latency_tr.mean())
    latency_std = float(y_latency_tr.std() + 1e-9)
    y_length_norm_tr = (y_length_tr - length_mean) / length_std
    y_latency_norm_tr = (y_latency_tr - latency_mean) / latency_std

    print(
        f"\nNormalization (saved into model for denorm at inference):"
    )
    print(f"  length:  mean={length_mean:.2f} std={length_std:.2f}")
    print(f"  latency: mean={latency_mean:.2f} std={latency_std:.2f}")

    print(
        f"\nTraining MultiHead (43→64→32 trunk + 5 heads), "
        f"200 epochs, joint loss…"
    )
    model = train_multihead(
        Xtr=Xtr,
        y_afm_tr=y_afm_tr,
        y_block_tr=y_block_tr,
        y_length_norm_tr=y_length_norm_tr,
        y_latency_norm_tr=y_latency_norm_tr,
        y_verbosity_tr=y_verbosity_tr,
        epochs=200,
        seed=args.random_seed,
    )
    model.eval()

    # Test metrics — 5 heads now
    with torch.no_grad():
        Xte_t = torch.tensor(Xte, dtype=torch.float32)
        (
            pred_afm, pred_block,
            pred_length_norm, pred_latency_norm, pred_verbosity,
        ) = model(Xte_t)
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

    # AFM success head
    pred_afm_class = (pred_afm_np >= 0.5).astype(int)
    afm_acc = accuracy_score(y_afm_te.astype(int), pred_afm_class)
    afm_auc = roc_auc_score(y_afm_te.astype(int), pred_afm_np)
    print(f"\n=== AFM head (replaces ChengluPreflight v0.4) ===")
    print(f"  Accuracy: {afm_acc:.4f} (v0.4 was 92.96%)")
    print(f"  AUC:      {afm_auc:.4f} (v0.4 was 0.973)")

    # Block head
    pred_block_class = (pred_block_np >= 0.5).astype(int)
    block_acc = accuracy_score(y_block_te.astype(int), pred_block_class)
    block_auc = roc_auc_score(y_block_te.astype(int), pred_block_np)
    print(f"\n=== Block head (replaces ChengluPermitPredict v0) ===")
    print(f"  Accuracy: {block_acc:.4f} (PermitPredict was 100.0%)")
    print(f"  AUC:      {block_auc:.4f} (PermitPredict was 1.000)")

    # Length head
    length_mae = mean_absolute_error(y_length_te, pred_length_np)
    length_r2 = r2_score(y_length_te, pred_length_np)
    print(f"\n=== Length head (replaces ChengluLengthHead v0) ===")
    print(f"  MAE: {length_mae:.2f} chars (LengthHead was 479)")
    print(f"  R²:  {length_r2:.4f} (LengthHead was 0.545)")

    # Latency head
    latency_mae = mean_absolute_error(y_latency_te, pred_latency_np)
    latency_r2 = r2_score(y_latency_te, pred_latency_np)
    print(f"\n=== Latency head (replaces ChengluLatencyHead v0) ===")
    print(f"  MAE: {latency_mae:.2f} ms (LatencyHead was 2091)")
    print(f"  R²:  {latency_r2:.4f} (LatencyHead was 0.511)")

    # Verbosity head (M661 chapter 一百八十三 — NEW 5th head)
    pred_verbosity_class = (pred_verbosity_np >= 0.5).astype(int)
    verb_acc = accuracy_score(
        y_verbosity_te.astype(int), pred_verbosity_class
    )
    verb_auc = roc_auc_score(
        y_verbosity_te.astype(int), pred_verbosity_np
    )
    print(f"\n=== Verbosity head (NEW 5th — chapter 183) ===")
    print(f"  Accuracy: {verb_acc:.4f} (binary: body > 1500 chars)")
    print(f"  AUC:      {verb_auc:.4f}")

    # Convert to CoreML — single model with 5 outputs.
    print(f"\nConverting MultiHead to CoreML (5 outputs)…")
    n_features = X.shape[1]
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
        f"ChengluMultiHead v0.1 — shared encoder (43→64→32) + 5 task "
        f"heads. Chapter 一百八十三 added 5th head (verbosity_prob). "
        f"5 outputs: afm_success_prob (sigmoid), block_prob (sigmoid), "
        f"length_norm (z-space, denorm via length_mean={length_mean:.2f}, "
        f"length_std={length_std:.2f}), latency_norm (z-space, denorm "
        f"via latency_mean={latency_mean:.2f}, "
        f"latency_std={latency_std:.2f}), verbosity_prob (sigmoid, "
        f"P(body > 1500 chars))."
    )
    cml.author = (
        "Qinao Runtime SDK chapter 一百八十三 — "
        "5th head via shared encoder (verbosity_class)"
    )
    cml.license = "Apache-2.0"
    cml.version = "0.0.1"
    cml.input_description["features"] = (
        "43-dim signature one-hot: 8 tone + 10 domain + 6 stake + "
        "7 timeframe + 4 confidant + 3 askshape + 5 mutationSeed."
    )
    cml.output_description["afm_success_prob"] = (
        "Sigmoid output: probability AFM call returns 'ok' status. "
        "Threshold 0.5 → route to AFM, else Gemma."
    )
    cml.output_description["block_prob"] = (
        "Sigmoid output: probability substrate routes to .block. "
        "Threshold 0.5 → predicted block."
    )
    cml.output_description["length_norm"] = (
        "Z-normalized linear output. Denorm: "
        "predicted_chars = length_norm * length_std + length_mean. "
        "length_mean / length_std are saved in user_defined_metadata."
    )
    cml.output_description["latency_norm"] = (
        "Z-normalized linear output. Denorm: "
        "predicted_ms = latency_norm * latency_std + latency_mean."
    )
    cml.output_description["verbosity_prob"] = (
        "Sigmoid output: P(AFM body > 1500 chars). UI hint: "
        "long-response anticipation. Threshold 0.5 → 'long'."
    )
    # Save normalization constants in user_defined_metadata so
    # Swift inference helper can read them at load time.
    cml.user_defined_metadata["length_mean"] = str(length_mean)
    cml.user_defined_metadata["length_std"] = str(length_std)
    cml.user_defined_metadata["latency_mean"] = str(latency_mean)
    cml.user_defined_metadata["latency_std"] = str(latency_std)
    cml.user_defined_metadata["verbosity_threshold_chars"] = str(1500)

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
        print(
            f"  (vs sum of 4 separate models: "
            f"{14422 + 14599 + 14317 + 14307} = "
            f"{14422 + 14599 + 14317 + 14307:,} bytes)"
        )

    # Sanity check
    print(f"\nSanity (first 3 rows):")
    loaded = ct.models.MLModel(args.output)
    for r in rows[:3]:
        feat = featurize_row(r)
        result = loaded.predict({
            "features": np.array([feat], dtype=np.float32)
        })
        afm = float(result["afm_success_prob"].flatten()[0])
        blk = float(result["block_prob"].flatten()[0])
        ln = float(result["length_norm"].flatten()[0])
        lt = float(result["latency_norm"].flatten()[0])
        verb = float(result["verbosity_prob"].flatten()[0])
        # Denorm
        ln_chars = ln * length_std + length_mean
        lt_ms = lt * latency_std + latency_mean
        sig = r.get("signature", {})
        print(
            f"  {sig.get('tone'):14s} "
            f"afm={afm:.3f} block={blk:.3f} verb={verb:.3f} "
            f"len={ln_chars:>7.1f} lat={lt_ms:>8.1f}"
        )


if __name__ == "__main__":
    main()
