#!/usr/bin/env python3
# MARK: - train.py — PyTorch context classifier training
# chapter 七百三十六 / M2250 — Phase B-1 PyTorch training script
#
# Trains a TINY context classifier on the hand-labeled corpus
# in `corpus.jsonl`。 Output: `context_classifier.pt` PyTorch
# checkpoint which `convert.py` then converts to .mlpackage。
#
# ## Architecture (tiny by design)
#
#   text → hash-bucket bag-of-tokens (256 buckets)
#   → linear (256 → 64)
#   → ReLU
#   → linear (64 → 7 classes)
#
# Approx 18K parameters。 Fits in <100KB .mlpackage。 Training
# converges in seconds on a CPU。 Accuracy on 105-example
# corpus is expected ~60-80% (TINY model + TINY data — this
# is Phase B-1 unblocking, not production quality)。
#
# ## Usage
#
#     pip install torch  # if not already
#     python3 train.py
#     # → produces context_classifier.pt + label_index.json
#
# ## Honest scope
#
# This is a SEED model. Phase B-2 will:
#   - Expand corpus to 1000+ examples per class
#   - Try larger architectures (small transformer encoder)
#   - Train with proper train/val/test split
#   - Track accuracy metrics over time

import json
import os
import sys
import hashlib
from pathlib import Path

try:
    import torch
    import torch.nn as nn
    from torch.utils.data import Dataset, DataLoader
except ImportError:
    print("ERROR: PyTorch not installed. Run:")
    print("  pip3 install torch")
    sys.exit(1)


SCRIPT_DIR = Path(__file__).parent
CORPUS_PATH = SCRIPT_DIR / "corpus.jsonl"
CHECKPOINT_PATH = SCRIPT_DIR / "context_classifier.pt"
LABEL_INDEX_PATH = SCRIPT_DIR / "label_index.json"

# Hyperparameters
NUM_BUCKETS = 256       # hash-bucket vocabulary size
HIDDEN = 64
EPOCHS = 200
LR = 0.01
BATCH_SIZE = 16
SEED = 42

# Deterministic training for replay byte-equality
torch.manual_seed(SEED)


def tokenize(text: str) -> list[str]:
    """Lowercase + whitespace split. Trivial tokenization
    (production version would use a real tokenizer)."""
    return text.lower().split()


def hash_bucket(token: str, num_buckets: int) -> int:
    """Deterministic token → bucket index via SHA256.
    Same algorithm must be reproduced in Swift at inference
    time (see BASContextClassifierInputEncoder in Phase B-3)."""
    h = hashlib.sha256(token.encode("utf-8")).digest()
    # First 4 bytes as big-endian uint32
    return int.from_bytes(h[:4], "big") % num_buckets


def encode_bag(text: str, num_buckets: int) -> torch.Tensor:
    """text → fixed-size bag-of-buckets float vector"""
    vec = torch.zeros(num_buckets, dtype=torch.float32)
    for tok in tokenize(text):
        vec[hash_bucket(tok, num_buckets)] += 1.0
    # Normalize by L2 to remove length bias
    norm = vec.norm()
    if norm > 0:
        vec = vec / norm
    return vec


class CorpusDataset(Dataset):
    def __init__(self, path: Path, label_to_index: dict):
        self.items = []
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                self.items.append({
                    "text": row["text"],
                    "label": label_to_index[row["taskType"]],
                })

    def __len__(self):
        return len(self.items)

    def __getitem__(self, idx):
        item = self.items[idx]
        return (
            encode_bag(item["text"], NUM_BUCKETS),
            item["label"],
        )


class ContextClassifier(nn.Module):
    def __init__(self, num_buckets: int, hidden: int,
                 num_classes: int):
        super().__init__()
        self.l1 = nn.Linear(num_buckets, hidden)
        self.relu = nn.ReLU()
        self.l2 = nn.Linear(hidden, num_classes)

    def forward(self, x):
        return self.l2(self.relu(self.l1(x)))


def collect_labels(path: Path) -> list[str]:
    """First pass: read all unique labels in stable order
    of first appearance."""
    seen = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            label = row["taskType"]
            if label not in seen:
                seen.append(label)
    return seen


def main():
    if not CORPUS_PATH.exists():
        print(f"ERROR: corpus not found at {CORPUS_PATH}")
        sys.exit(1)

    # 1. Collect labels + persist index for inference parity
    labels = collect_labels(CORPUS_PATH)
    label_to_index = {l: i for i, l in enumerate(labels)}
    print(f"Found {len(labels)} labels: {labels}")
    with open(LABEL_INDEX_PATH, "w") as f:
        json.dump(labels, f, indent=2)
    print(f"Wrote {LABEL_INDEX_PATH}")

    # 2. Load corpus
    dataset = CorpusDataset(CORPUS_PATH, label_to_index)
    print(f"Loaded {len(dataset)} examples")
    loader = DataLoader(
        dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        generator=torch.Generator().manual_seed(SEED),
    )

    # 3. Train
    model = ContextClassifier(
        num_buckets=NUM_BUCKETS,
        hidden=HIDDEN,
        num_classes=len(labels),
    )
    optimizer = torch.optim.Adam(model.parameters(), lr=LR)
    loss_fn = nn.CrossEntropyLoss()

    model.train()
    for epoch in range(EPOCHS):
        total_loss = 0.0
        correct = 0
        total = 0
        for x, y in loader:
            optimizer.zero_grad()
            logits = model(x)
            loss = loss_fn(logits, y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item() * x.size(0)
            preds = logits.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += x.size(0)
        if (epoch + 1) % 20 == 0 or epoch == 0:
            avg_loss = total_loss / total
            acc = correct / total
            print(
                f"Epoch {epoch + 1:3d}/{EPOCHS}  "
                f"loss={avg_loss:.4f}  "
                f"train_acc={acc:.3f}"
            )

    # 4. Save checkpoint
    torch.save(
        {
            "state_dict": model.state_dict(),
            "num_buckets": NUM_BUCKETS,
            "hidden": HIDDEN,
            "num_classes": len(labels),
            "labels": labels,
            "seed": SEED,
        },
        CHECKPOINT_PATH,
    )
    print(f"Wrote {CHECKPOINT_PATH}")


if __name__ == "__main__":
    main()
