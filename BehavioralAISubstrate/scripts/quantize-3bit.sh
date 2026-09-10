#!/usr/bin/env bash
# scripts/quantize-3bit.sh — Tranche C: produce the locally-quantized 3-bit Llama-3.2-3B
# (mlx-community publishes no 3B-class 3-bit). Decode is bandwidth-bound qmv GEMV, so 3-bit reads
# ~25% fewer bytes/token than 4-bit through the same kernel. Output: ~1.3GB model dir (4-bit ≈ 1.8GB).
#
# Usage: bash scripts/quantize-3bit.sh [out-dir]   (default ~/litert-models/Llama-3.2-3B-Instruct-3bit)
# Stage to device:  xcrun devicectl device copy to --device <UDID> \
#   --domain-type appDataContainer --domain-identifier com.changgeng.basdevicetest \
#   --source <out-dir> --destination Documents/models/Llama-3.2-3B-Instruct-3bit
# Run:  BAS_MLX_MODEL=llama3b_3bit (the MLXModelCatalog.llama3_2_3B_3bit_local local-directory entry)
set -euo pipefail
OUT="${1:-$HOME/litert-models/Llama-3.2-3B-Instruct-3bit}"
VENV="${VENV:-$HOME/venvs/mlxlm}"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q -U mlx-lm
"$VENV/bin/python" -m mlx_lm convert \
  --hf-path mlx-community/Llama-3.2-3B-Instruct-bf16 \
  -q --q-bits 3 --q-group-size 64 \
  --mlx-path "$OUT"
ls -lh "$OUT"
