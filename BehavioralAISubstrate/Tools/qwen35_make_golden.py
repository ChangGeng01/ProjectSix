#!/usr/bin/env python3
"""Generate the MLX golden references the qwen35_* fidelity tools compare against (reproducibility helper).

The fidelity tools (qwen35_full_port_fidelity / qwen35_fixed_decode / qwen35_m3_host_fidelity /
qwen35_audit_shipped_form / qwen35_3asset_fused --verify) consume /tmp/gdn_coreai/mlx_{toks,logits}{,16,32}.npy.
This regenerates them from the local mlx-community/Qwen3.5-4B-4bit checkpoint. Run it FIRST, in an mlx_lm venv
(e.g. ~/qwen_honesty_finetune/.venv — mlx_lm 0.31.x), SEPARATELY from the torch tools (memory: don't hold MLX and
the ~4B torch port at once):

    ~/qwen_honesty_finetune/.venv/bin/python Tools/qwen35_make_golden.py
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import mlx.core as mx
from mlx_lm import load

OUT = Path("/tmp/gdn_coreai"); OUT.mkdir(parents=True, exist_ok=True)
SETS = {
    "": [100, 200, 300, 400, 500, 600],                          # T=6  (full-port check)
    "16": [100 + 100 * i for i in range(16)],                    # T=16 (windowing audit)
    "32": list(range(100, 100 + 32 * 50, 50))[:32],              # T=32 (shipped-recipe + M3-host)
}


def main() -> None:
    model, _ = load("mlx-community/Qwen3.5-4B-4bit")
    for suffix, toks in SETS.items():
        logits = model(mx.array([toks])); mx.eval(logits)
        last = logits[0, -1]
        np.save(OUT / f"mlx_toks{suffix}.npy", np.array(toks))
        np.save(OUT / f"mlx_logits{suffix}.npy", np.array(last.astype(mx.float32)))
        top5 = [int(x) for x in mx.argsort(last)[-5:][::-1]]
        print(f"golden T={len(toks):2d} → mlx_logits{suffix}.npy  top5={top5}")
    print(f"done → {OUT}")


if __name__ == "__main__":
    main()
