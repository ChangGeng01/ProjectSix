#!/usr/bin/env bash
# scripts/restage-decode-test-models.sh
#
# Rebuild + (optionally) re-stage the decode-acceleration TEST models used by the 2026-06-22
# 查缺补漏 / bandwidth-lever sweep (BASQuantABProbe BAS_QUANT_LOWBIT=… + BASSpecSpeedupProbe
# BAS_SPEC_DRAFT_LOCAL=1). These are all REPRODUCIBLE — 3 are public HF downloads, 2 are
# deterministic mlx_lm quant conversions of a public source model — so the local /tmp copies
# and the device-staged copies are throwaway. This script is the "下回来" recipe so deleting
# them is a one-command-reversible operation.
#
# Usage:
#   bash scripts/restage-decode-test-models.sh                 # download/convert into $WORK only
#   STAGE=1 bash scripts/restage-decode-test-models.sh         # also devicectl-push to the device
#   ONLY="mxfp4 g128" bash scripts/restage-decode-test-models.sh  # subset
#
# Env: WORK (default /tmp), DEVICE_ID, BUNDLE_ID, ONLY (space-separated names), STAGE (0/1).

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

WORK="${WORK:-/tmp}"
DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
STAGE="${STAGE:-0}"
SRC="unsloth/Llama-3.2-3B-Instruct"   # public source for the two local quant conversions

# beta toolchain for devicectl (matches the device-build scripts)
BETA="/Applications/Xcode.app/Contents/Developer"
for x in /Applications/Xcode-beta.app /Applications/Xcode.app; do
    [ -d "$x/Contents/Developer" ] && BETA="$x/Contents/Developer" && break
done

# name → action. "hf <repo>" = snapshot download; "convert <flags>" = mlx_lm quant convert.
declare -a MODELS=(
    "Llama-3.2-3B-Instruct-mxfp4|convert|-q --q-bits 4 --q-mode mxfp4"
    "Llama-3.2-3B-Instruct-g128|convert|-q --q-bits 4 --q-group-size 128"
    "Granite-4.0-H-Micro-4bit|hf|mlx-community/Granite-4.0-H-Micro-4bit"
    "Granite-4.0-H-Tiny-4bit-DWQ|hf|mlx-community/Granite-4.0-H-Tiny-4bit-DWQ"
    "Llama-3.2-1B-Instruct-4bit|hf|mlx-community/Llama-3.2-1B-Instruct-4bit"
)

want() { [ -z "${ONLY:-}" ] && return 0; case " $ONLY " in *" $1 "*) return 0;; *) return 1;; esac; }

for entry in "${MODELS[@]}"; do
    IFS='|' read -r name kind arg <<<"$entry"
    want "$name" || continue
    dst="$WORK/$name"
    echo "=============================================="
    echo "[$name] ($kind)"
    if [ -d "$dst" ] && [ -f "$dst/config.json" ]; then
        echo "  already present at $dst ($(du -sh "$dst" | cut -f1)) — skipping fetch"
    elif [ "$kind" = "hf" ]; then
        uv run --with huggingface_hub python - "$arg" "$dst" <<'PY'
import sys
from huggingface_hub import snapshot_download
snapshot_download(repo_id=sys.argv[1], local_dir=sys.argv[2])
print("downloaded", sys.argv[1])
PY
    else
        rm -rf "$dst"
        uv run --with mlx-lm python -m mlx_lm convert --hf-path "$SRC" --mlx-path "$dst" $arg 2>&1 \
            | grep -iE "bits per weight|error|traceback" | tail -3
    fi
    [ -f "$dst/config.json" ] && echo "  OK $(du -sh "$dst" | cut -f1)" || { echo "  ❌ FAILED ($name)"; continue; }

    if [ "$STAGE" = "1" ]; then
        echo "  staging → Documents/models/$name ..."
        env DEVELOPER_DIR="$BETA" xcrun devicectl device copy to --device "$DEVICE_ID" \
            --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
            --source "$dst" --destination "Documents/models/$name" 2>&1 | tail -1
    fi
done

echo "=============================================="
echo "Done. ${STAGE:+(staged to $DEVICE_ID) }Local copies under $WORK/."
echo "Catalog entries: MLXModelCatalog.{llama3_2_3B_mxfp4_local, llama3_2_3B_4bit_g128_local,"
echo "  granite4_h_micro_4bit_local, granite4_h_tiny_4bit_local, llama3_2_1B_4bit_local}."
