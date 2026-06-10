#!/usr/bin/env bash
# scripts/coreai-build-aimodel.sh — C0: produce the REAL Core AI asset for the context-classifier shadow.
#
# Compiles the repo's existing CoreML small-head (Sources/BASRuntimeCore/Resources/BASContextClassifier.mlmodel,
# the certified incumbent) into a Core AI `.aimodel` via `aimodelc` (ships in Xcode 27 at
# Contents/Developer/usr/bin/aimodelc; REQUIRES the Metal Toolchain component — Xcode ▸ Settings ▸ Components).
# Output lands at Sources/BASAppleAdapters/Resources/BASContextClassifier.aimodel where
# BASCoreAIContextClassifierAdapter loads it from Bundle.module.
#
# Honesty (R1): the script does NOT claim success on a green aimodelc exit alone — it verifies the output
# artifact exists + is non-empty, and prints the next verification step (AIModelAsset.summary() via the iOS 27
# probe) which is the real "asset loads" proof.
#
# Usage:
#   bash scripts/coreai-build-aimodel.sh                      # default paths
#   BETA_DEVELOPER_DIR=/Applications/Xcode-beta.app/... bash scripts/coreai-build-aimodel.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${BETA_DEVELOPER_DIR:-}" ]; then
  for _x in /Applications/Xcode-beta.app /Users/changgeng/Downloads/Xcode-beta.app; do
    [ -d "$_x/Contents/Developer" ] && BETA_DEVELOPER_DIR="$_x/Contents/Developer" && break
  done
fi
BETA_DEVELOPER_DIR="${BETA_DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
AIMODELC="$BETA_DEVELOPER_DIR/usr/bin/aimodelc"
SRC_MLMODEL="$REPO_ROOT/Sources/BASRuntimeCore/Resources/BASContextClassifier.mlmodel"
OUT_DIR="$REPO_ROOT/Sources/BASAppleAdapters/Resources"
OUT_AIMODEL="$OUT_DIR/BASContextClassifier.aimodel"
VENV="$REPO_ROOT/scripts/PhaseB_ContextClassifier/venv"
WORK="$(mktemp -d /tmp/bas-aimodelc.XXXXXX)"

echo "=============================================="
echo "Core AI asset build (C0)"
echo "aimodelc : $AIMODELC"
echo "input    : $SRC_MLMODEL"
echo "output   : $OUT_AIMODEL"
echo "=============================================="

[ -x "$AIMODELC" ] || { echo "❌ aimodelc not found/executable — is Xcode 27 at $BETA_DEVELOPER_DIR?"; exit 2; }
[ -f "$SRC_MLMODEL" ] || { echo "❌ source .mlmodel missing: $SRC_MLMODEL"; exit 2; }

# ---- (1) Metal Toolchain gate ------------------------------------
# aimodelc hard-requires the Metal Toolchain component. Probe with a no-op invocation: the distinctive error
# is "Core AI requires the Metal Toolchain." If present, attempt the guided install hint and stop.
PROBE_OUT="$(DEVELOPER_DIR="$BETA_DEVELOPER_DIR" "$AIMODELC" compile --output /dev/null 2>&1 || true)"
if printf '%s' "$PROBE_OUT" | grep -q "requires the Metal Toolchain"; then
    echo "❌ Metal Toolchain component NOT installed for Xcode 27."
    echo "   Install it (one-time, ~GBs): EITHER"
    echo "     a) GUI: open Xcode-beta ▸ Settings ▸ Components ▸ Other Components ▸ Metal Toolchain ▸ Get"
    echo "     b) CLI: DEVELOPER_DIR=$BETA_DEVELOPER_DIR xcodebuild -downloadComponent metalToolchain"
    echo "   then re-run this script."
    exit 3
fi
echo "✓ Metal Toolchain present (aimodelc probe did not demand it)"

# ---- (2) discover aimodelc's input contract (now that help works) -
echo ""
echo "---- aimodelc compile --help (ground truth) ----"
DEVELOPER_DIR="$BETA_DEVELOPER_DIR" "$AIMODELC" compile --help 2>&1 | sed 's/^/  /' | head -40 || true
echo "------------------------------------------------"

# ---- (3) try direct .mlmodel compile; fall back via .mlpackage ----
# Path A: aimodelc consumes the legacy .mlmodel directly.
run_compile() {  # $1 = input path
    DEVELOPER_DIR="$BETA_DEVELOPER_DIR" "$AIMODELC" compile "$1" --output "$OUT_AIMODEL" 2>&1 \
      || DEVELOPER_DIR="$BETA_DEVELOPER_DIR" "$AIMODELC" compile --input "$1" --output "$OUT_AIMODEL" 2>&1
}

mkdir -p "$OUT_DIR"
rm -rf "$OUT_AIMODEL"

echo ""
echo "Attempt A: direct .mlmodel → .aimodel"
A_OUT="$(run_compile "$SRC_MLMODEL")"; A_RC=$?
printf '%s\n' "$A_OUT" | tail -8 | sed 's/^/  /'

if [ ! -e "$OUT_AIMODEL" ]; then
    echo ""
    echo "Attempt B: bridge legacy .mlmodel → .mlpackage (coremltools venv) → .aimodel"
    [ -x "$VENV/bin/python3" ] || { echo "❌ coremltools venv missing at $VENV (and direct compile failed: rc=$A_RC)"; exit 4; }
    "$VENV/bin/python3" - "$SRC_MLMODEL" "$WORK/BASContextClassifier.mlpackage" <<'PY'
import sys
import coremltools as ct
src, dst = sys.argv[1], sys.argv[2]
m = ct.models.MLModel(src)
# Re-save as the modern ML Program package container (the toolchain-friendly format).
m.save(dst)
print(f"saved {dst}")
PY
    B_OUT="$(run_compile "$WORK/BASContextClassifier.mlpackage")"; B_RC=$?
    printf '%s\n' "$B_OUT" | tail -8 | sed 's/^/  /'
fi

# ---- (4) verify the artifact exists + is non-trivial --------------
if [ ! -e "$OUT_AIMODEL" ]; then
    echo ""
    echo "❌ FAILED: no $OUT_AIMODEL produced. Read the aimodelc output above — the input format/flags may"
    echo "   differ in this beta. (Honesty: nothing is claimed; the asset does not exist.)"
    exit 5
fi
SIZE_BYTES="$(du -sk "$OUT_AIMODEL" | awk '{print $1 * 1024}')"
echo ""
echo "✅ artifact produced: $OUT_AIMODEL (${SIZE_BYTES} bytes)"
[ "${SIZE_BYTES:-0}" -gt 1024 ] || { echo "⚠️  suspiciously small (<1KB) — inspect before trusting"; }

echo ""
echo "NEXT (the real proof, R1): wire it as a Package.swift resource (.copy) and run the iOS 27 probe"
echo "  (BAS_COREAI_E2E=1) — AIModelAsset/AIModel must load it and report the classifier function. A green"
echo "  aimodelc exit is NOT yet 'Core AI runs'."
