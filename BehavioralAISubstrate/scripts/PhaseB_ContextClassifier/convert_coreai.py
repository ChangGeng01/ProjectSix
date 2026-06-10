#!/usr/bin/env python3
# MARK: - convert_coreai.py — PyTorch → Apple Core AI .aimodel
#
# Converts the trained `context_classifier.pt` PyTorch checkpoint into an Apple
# Core AI `.aimodel` asset (the format BASCoreAIContextClassifierAdapter loads via
# AIModelAsset on iOS 27 / macOS 27).
#
# ## Why this exists alongside convert.py (the CoreML path)
#
# convert.py produces the CoreML `.mlmodel` (the certified incumbent). THIS script
# produces the Core AI `.aimodel` candidate so the substrate can shadow Core AI vs
# CoreML on the SAME head (ADR-041).
#
# ## Why coreai_torch and NOT `aimodelc`
#
# The `aimodelc` CLI (Xcode 27) has a STRICT exact-build Metal-Toolchain gate that
# Apple's beta-1 seed breaks (app build 27A5194q vs the only-published toolchain
# 27A5194o → rejected). The Python `coreai_torch` converter goes torch.export →
# TorchConverter.to_coreai() → AIProgram.save_asset(), using the `metal` compiler
# (which tolerates the o build) — so it BYPASSES the broken CLI gate. Verified:
# the produced .aimodel loads via the coreai Python runtime and matches the PyTorch
# reference 5/5 on argmax with logits-MAE ~1e-6.
#
# ## Environment (coreai-core has NO Python 3.14 wheel — use 3.12)
#
#     uv venv /tmp/coreai-cv --python 3.12
#     uv pip install --python /tmp/coreai-cv/bin/python coreai-torch
#     /tmp/coreai-cv/bin/python convert_coreai.py
#     # → BASContextClassifier.aimodel  (copy into Sources/BASAppleAdapters/Resources/)
#
# ## Contract (must match BASCoreAIContextClassifierAdapter + the CoreML incumbent)
#
#   input  tensor "bag_of_buckets" shape (1, 256) float32  (the shared bag-of-buckets encoder)
#   output tensor "logits"         shape (1, 7)   float32  (Swift takes argmax + softmax)

from __future__ import annotations

import sys
from pathlib import Path

try:
    import torch
    import coreai_torch
    from coreai_torch import TorchConverter
except ImportError:
    print("ERROR: missing deps. In a Python 3.12 venv run:\n"
          "  uv pip install coreai-torch")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).parent
CHECKPOINT_PATH = SCRIPT_DIR / "context_classifier.pt"
OUTPUT_PATH = SCRIPT_DIR / "BASContextClassifier.aimodel"

INPUT_NAME = "bag_of_buckets"
OUTPUT_NAME = "logits"


class ContextClassifier(torch.nn.Module):
    """Identical architecture to train.py / convert.py (kept local for portability)."""

    def __init__(self, num_buckets: int, hidden: int, num_classes: int) -> None:
        super().__init__()
        self.l1 = torch.nn.Linear(num_buckets, hidden)
        self.relu = torch.nn.ReLU()
        self.l2 = torch.nn.Linear(hidden, num_classes)

    def forward(self, x: "torch.Tensor") -> "torch.Tensor":
        return self.l2(self.relu(self.l1(x)))


def main() -> None:
    if not CHECKPOINT_PATH.exists():
        print(f"ERROR: checkpoint not found at {CHECKPOINT_PATH} — run train.py first")
        sys.exit(1)

    ckpt = torch.load(CHECKPOINT_PATH, map_location="cpu", weights_only=False)
    num_buckets = ckpt["num_buckets"]
    model = ContextClassifier(num_buckets, ckpt["hidden"], ckpt["num_classes"])
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    print(f"Loaded {num_buckets}->{ckpt['hidden']}->{ckpt['num_classes']} ({ckpt['labels']})")

    # 1. torch.export + Core AI decompositions (TorchConverter requires decomposed ops).
    example = torch.zeros(1, num_buckets, dtype=torch.float32)
    exported = torch.export.export(model, (example,))
    exported = exported.run_decompositions(coreai_torch.get_decomp_table())

    # 2. Convert to a Core AI AIProgram with the shared tensor names.
    converter = TorchConverter()
    converter.add_exported_program(
        exported,
        input_names=[INPUT_NAME],
        output_names=[OUTPUT_NAME],
        entrypoint_name="main",
    )
    program = converter.to_coreai()
    program.optimize()

    # 3. Save the .aimodel asset (minimum_os defaults to v27).
    if OUTPUT_PATH.exists():
        import shutil
        shutil.rmtree(OUTPUT_PATH) if OUTPUT_PATH.is_dir() else OUTPUT_PATH.unlink()
    program.save_asset(OUTPUT_PATH)
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
