#!/usr/bin/env bash
# RunPod one-time env setup for the 8-layer Mamba-3 cloud distill.
# POD TEMPLATE: a PyTorch 2.x + CUDA 12.x (Blackwell sm_120) image, 1× RTX PRO 6000 96GB ('WK'), a persistent volume mounted at /workspace.
# The harness uses ONLY torch (the chunked scan is pure-torch) + transformers + datasets. mamba_ssm is NOT needed
# (its kernel is for the Mamba-2 SSD, not our trapezoid). flash-attn is OPTIONAL (sdpa fallback is fine).
set -euo pipefail
# RunPod images ship torch in a Debian-managed system python (PEP 668) → pip refuses without --break-system-packages.
# The container is disposable, and torch already lives in that env, so we install transformers/datasets ALONGSIDE it there.
PIP="python -m pip install -q --break-system-packages"
$PIP --upgrade pip
# datasets pinned >=3.6 so the Parquet-export HotpotQA loads (the old script-dataset path broke on 2.x); upper bound for safety.
$PIP "transformers>=4.45" "datasets>=3.6,<5" accelerate sentencepiece safetensors
# flash-attn is OFF by default — no prebuilt wheel for Blackwell sm_120, and a kernel-less import would crash the teacher
# forward at runtime (the harness default is sdpa, which is fine for the one-time teacher cache). Opt in with FLASH_ATTN=1.
if [ "${FLASH_ATTN:-0}" = "1" ]; then
  $PIP flash-attn --no-build-isolation && echo "flash-attn installed" || echo "flash-attn build failed — sdpa fallback (fine)"
fi
python - <<'PY'
import torch
print("torch", torch.__version__, "| cuda", torch.cuda.is_available(),
      "|", (torch.cuda.get_device_name(0) if torch.cuda.is_available() else "no-gpu"))
assert torch.cuda.is_available(), "no CUDA GPU — pick an RTX PRO 6000 96GB pod"
from datasets import load_dataset                                   # fail-fast: confirm the image can actually serve HotpotQA Parquet
load_dataset("hotpotqa/hotpot_qa", "distractor", split="validation[:1]")
print("HotpotQA Parquet load OK")
PY
echo ">> setup OK. Next:  bash scripts/runpod_distill.sh"
