#!/usr/bin/env python3
"""B2 — weight-quantize the Llama-1B Core ML draft to fit the ANE (if the fp16 2.3GB model is size-rejected).

The fp16 draft (LlamaDraft1B_fp16.mlpackage, ~2.3GB) may exceed the ANE's weight-size limit → whole model marked
GPU-only (ane_capable=0). Weight-only quantization shrinks the weights (int4 ≈ 4× smaller ≈ 0.6GB) WITHOUT
changing the architecture or tokenizer (still a valid same-family draft). Drafts tolerate quantization — the
TARGET verify still guarantees byte-identity; quantization only affects ACCEPTANCE rate (speedup), not output.

Run:  /tmp/cml312/bin/python3 Tools/quantize_draft_coreml.py [nbits]   (nbits ∈ {4,8}, default 4)
In:   /tmp/draft/LlamaDraft1B_fp16.mlpackage
Out:  /tmp/draft/LlamaDraft1B_int<nbits>.mlpackage
Then: re-stage + the A19 placement probe — does the smaller model now A19-ANE-place?
"""
import sys

import coremltools as ct
import coremltools.optimize.coreml as cto

NBITS = int(sys.argv[1]) if len(sys.argv) > 1 else 4
# argv[2]=SRC mlpackage, argv[3]=OUT mlpackage (default: the 1B draft, back-compatible).
SRC = sys.argv[2] if len(sys.argv) > 2 else "/tmp/draft/LlamaDraft1B_fp16.mlpackage"
OUT = sys.argv[3] if len(sys.argv) > 3 else f"/tmp/draft/LlamaDraft1B_int{NBITS}.mlpackage"


def main() -> None:
    print(f">> loading {SRC}")
    model = ct.models.MLModel(SRC)
    # Per-block linear weight quantization (granularity that keeps ANE-friendly group sizes).
    config = cto.OptimizationConfig(
        global_config=cto.OpLinearQuantizerConfig(
            mode="linear_symmetric", dtype=f"int{NBITS}", granularity="per_block", block_size=32
        )
    )
    print(f">> linear_quantize_weights int{NBITS} per_block(32)…")
    q = cto.linear_quantize_weights(model, config)
    q.save(OUT)
    print(f">> SAVED {OUT}")


if __name__ == "__main__":
    main()
