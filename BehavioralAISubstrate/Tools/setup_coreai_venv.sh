#!/usr/bin/env bash
# P0 — rebuild the PERSISTENT coreai-cv venv. The /tmp/coreai-cv venv gets WIPED on crash/reboot (it did this
# session), so the trainer env lives under $HOME. Idempotent. Usage: bash Tools/setup_coreai_venv.sh
#
# For .aimodel CONVERSION (coreai_torch 0.4.0) we do NOT install it here — it is invoked on demand via:
#     uv run --with coreai-torch python Tools/mamba3_faithful_ane.py <L>
# This venv is the pure-torch-MPS TRAINER stack (MOHAWK + the trainable Mamba-3 twin).
set -euo pipefail
VENV="${1:-$HOME/.venvs/coreai-cv}"
UV="${UV:-$HOME/.local/bin/uv}"

"$UV" venv "$VENV" --python 3.12
"$UV" pip install --python "$VENV/bin/python" \
    torch einops numpy transformers safetensors accelerate datasets

echo "== venv ready: $VENV =="
"$VENV/bin/python" - <<'PY'
import torch
print("torch", torch.__version__, "| mps", torch.backends.mps.is_available())
PY
