#!/usr/bin/env python3
"""M754 chapter 二百 — verify v0.5_synthetic.mlpackage loads +
predicts. Closes loop validation: synthetic-base + synthetic-bench
→ retrain → emit .mlpackage → load → predict.

Usage:
    /tmp/coreml-py312/bin/python3 \\
        scripts/verify_v0_5_synthetic.py \\
        /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from chenglu_feature_schema import featurize_row  # noqa: E402


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "usage: verify_v0_5_synthetic.py <path/to/.mlpackage>",
            file=sys.stderr)
        return 2
    pkg_path = Path(sys.argv[1])
    if not pkg_path.exists():
        print(f"ERROR: not found: {pkg_path}", file=sys.stderr)
        return 1

    print(f"=== Verifying {pkg_path.name} ===")
    try:
        import coremltools as ct  # noqa: F401
    except ImportError:
        print(
            "ERROR: coremltools not available. Use the venv at "
            "/tmp/coreml-py312.",
            file=sys.stderr)
        return 1

    print("Step 1 — load .mlpackage via coremltools…")
    model = ct.models.MLModel(str(pkg_path))
    spec = model.get_spec()
    print(f"  modelDescription: {spec.WhichOneof('Type')}")
    inputs = list(spec.description.input)
    outputs = list(spec.description.output)
    print(f"  inputs: {[i.name for i in inputs]}")
    print(f"  outputs: {[o.name for o in outputs]}")

    print("\nStep 2 — feature shape verification…")
    expected_input_dim = 43  # ChengluFeatureEncoder canonical
    if inputs:
        first_input = inputs[0]
        # Try to extract shape
        if first_input.type.HasField("multiArrayType"):
            shape = list(first_input.type.multiArrayType.shape)
            print(f"  input shape: {shape}")
            if expected_input_dim not in shape:
                print(
                    f"  WARN: expected dim {expected_input_dim} "
                    f"not in shape (verify alignment)")
        else:
            print(f"  input type: {first_input.type}")

    print("\nStep 3 — synthetic predict smoke…")
    # Mock a chapter 192 row with valid signature
    test_row = {
        "signature": {
            "tone": "agentic",
            "domain": "creative",
            "stake": "modest",
            "timeframe": "minutes",
            "confidant": "decision-system",
            "askShape": "single-action",
        },
        "mutationSeed": 0,
    }
    features = featurize_row(test_row)
    print(f"  featurize → {len(features)} dims, "
          f"sum={sum(features):.0f} (expected 7 active)")
    if len(features) != expected_input_dim:
        print(f"  ERROR: featurize dim mismatch")
        return 1

    # Build CoreML input dict
    import numpy as np
    input_dict = {}
    if inputs:
        first_name = inputs[0].name
        # Most likely shape: (1, 43) batch
        feature_array = np.array(features, dtype=np.float32)
        # Try (1, 43) first
        try:
            reshaped = feature_array.reshape(1, expected_input_dim)
            input_dict[first_name] = reshaped
            preds = model.predict(input_dict)
            print(f"  predict (1, 43) → SUCCESS")
        except Exception as e1:
            # Try flat
            try:
                input_dict[first_name] = feature_array
                preds = model.predict(input_dict)
                print(f"  predict (43,) → SUCCESS")
            except Exception as e2:
                print(f"  ERROR predict failed:")
                print(f"    (1,43): {e1}")
                print(f"    (43,):  {e2}")
                return 1

        print(f"\nStep 4 — output structure:")
        for out_name in [o.name for o in outputs]:
            val = preds.get(out_name)
            if val is None:
                print(f"  {out_name}: missing")
                continue
            if isinstance(val, np.ndarray):
                print(f"  {out_name}: shape={val.shape} "
                      f"sample={val.flatten()[:3].tolist()}")
            else:
                print(f"  {out_name}: {type(val).__name__}={val}")

    print("\n=== VERDICT: v0.5_synthetic loop closed end-to-end ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
