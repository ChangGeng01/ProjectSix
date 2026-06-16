#!/usr/bin/env bash
# RunPod one-time env setup for the 8-layer Mamba-3 cloud distill.
# POD TEMPLATE: a PyTorch 2.x + CUDA 12.x image, 1× A100 80GB or H100 80GB, a persistent volume mounted at /workspace.
# The harness uses ONLY torch (the chunked scan is pure-torch) + transformers + datasets. mamba_ssm is NOT needed
# (its kernel is for the Mamba-2 SSD, not our trapezoid). flash-attn is OPTIONAL (sdpa fallback is fine).
set -euo pipefail
python -m pip install -q --upgrade pip
python -m pip install -q "transformers>=4.45" "datasets>=2.20" accelerate sentencepiece safetensors
# optional faster teacher forward; harmless to skip (harness falls back to sdpa):
python -m pip install -q flash-attn --no-build-isolation 2>/dev/null && echo "flash-attn installed" \
  || echo "flash-attn skipped — sdpa fallback (fine)"
python - <<'PY'
import torch
print("torch", torch.__version__, "| cuda", torch.cuda.is_available(),
      "|", (torch.cuda.get_device_name(0) if torch.cuda.is_available() else "no-gpu"))
assert torch.cuda.is_available(), "no CUDA GPU — pick an A100/H100 pod"
PY
echo ">> setup OK. Next:  bash scripts/runpod_distill.sh"
