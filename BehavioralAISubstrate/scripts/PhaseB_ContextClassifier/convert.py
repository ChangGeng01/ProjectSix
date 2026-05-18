#!/usr/bin/env python3
# MARK: - convert.py — PyTorch → CoreML .mlpackage
# chapter 七百三十六 / M2250 — Phase B-1 PyTorch→CoreML conversion
#
# Converts the trained `context_classifier.pt` PyTorch
# checkpoint into a CoreML `.mlpackage` ready for loading
# via Swift `MLModel` at inference time。
#
# ## Usage
#
#     pip3 install coremltools torch
#     python3 train.py
#     python3 convert.py
#     # → produces BASContextClassifier.mlpackage
#
# ## Output
#
# `BASContextClassifier.mlpackage` (CoreML format) which
# Phase B-2 then checks into Sources/BASRuntimeCore/
# Resources/ for Bundle.module.url(forResource:withExtension:)
# loading at runtime。
#
# ## Honest scope
#
# CoreML's neural network converter expects a torch.jit.trace
# graph。 We trace through the tiny 2-layer MLP defined in
# train.py。 The hash-bucket tokenization is NOT part of the
# CoreML model — it stays in Swift (BASContextClassifier
# InputEncoder) and runs before each MLModel.prediction()
# call。 This keeps the model itself small + lets us reuse
# the same encoder for both training (Python) and inference
# (Swift) by reproducing the SHA256 algorithm。

import json
import sys
from pathlib import Path

try:
    import torch
    import torch.nn as nn
    import coremltools as ct
except ImportError:
    print("ERROR: missing deps. Run:")
    print("  pip3 install torch coremltools")
    sys.exit(1)

# Re-define the model architecture identically to train.py
# (avoiding cross-script import for portability)
class ContextClassifier(nn.Module):
    def __init__(self, num_buckets: int, hidden: int,
                 num_classes: int):
        super().__init__()
        self.l1 = nn.Linear(num_buckets, hidden)
        self.relu = nn.ReLU()
        self.l2 = nn.Linear(hidden, num_classes)

    def forward(self, x):
        return self.l2(self.relu(self.l1(x)))


SCRIPT_DIR = Path(__file__).parent
CHECKPOINT_PATH = SCRIPT_DIR / "context_classifier.pt"
OUTPUT_PATH = SCRIPT_DIR / "BASContextClassifier.mlmodel"


def main():
    if not CHECKPOINT_PATH.exists():
        print(f"ERROR: checkpoint not found. Run train.py first")
        sys.exit(1)

    # 1. Load checkpoint
    ckpt = torch.load(
        CHECKPOINT_PATH,
        map_location="cpu",
        weights_only=False,
    )
    num_buckets = ckpt["num_buckets"]
    hidden = ckpt["hidden"]
    num_classes = ckpt["num_classes"]
    labels = ckpt["labels"]
    print(f"Loaded checkpoint: {num_buckets}→{hidden}→"
          f"{num_classes} ({labels})")

    model = ContextClassifier(
        num_buckets=num_buckets,
        hidden=hidden,
        num_classes=num_classes,
    )
    model.load_state_dict(ckpt["state_dict"])
    model.eval()

    # 2. Trace
    example_input = torch.zeros(
        1, num_buckets, dtype=torch.float32
    )
    traced = torch.jit.trace(model, example_input)

    # 3. Convert via coremltools
    # Input: 1×NUM_BUCKETS float32 bag-of-buckets vector
    # Output: 1×NUM_CLASSES logits (Swift takes argmax)
    # Note: convert_to="neuralnetwork" produces .mlmodel
    # instead of .mlpackage to avoid coremltools 9.0
    # BlobWriter issue on Python 3.14+。 Swift CoreML
    # runtime loads .mlmodel transparently — Phase B-3
    # adapter uses the same MLModel API regardless of
    # format。 Phase B-2+ can revisit mlprogram once
    # coremltools / Python compatibility settles。
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(
                name="bag_of_buckets",
                shape=(1, num_buckets),
            )
        ],
        convert_to="neuralnetwork",
    )

    # 4. Add metadata so Swift can introspect
    mlmodel.short_description = (
        "BAS context classifier (Phase B-1 seed). "
        "Bag-of-256-buckets → 64 → 7 BASContextTaskType."
    )
    mlmodel.author = "BehavioralAISubstrate Phase B-1"
    mlmodel.version = "0.1.0"
    mlmodel.user_defined_metadata["labels"] = json.dumps(labels)
    mlmodel.user_defined_metadata["num_buckets"] = str(num_buckets)
    mlmodel.user_defined_metadata["chapter"] = "七百三十六"

    # 5. Save
    if OUTPUT_PATH.exists():
        if OUTPUT_PATH.is_dir():
            import shutil
            shutil.rmtree(OUTPUT_PATH)
        else:
            OUTPUT_PATH.unlink()
    mlmodel.save(str(OUTPUT_PATH))
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
