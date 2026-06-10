#!/usr/bin/env bash
# coreai-compile-check.sh — compile-certify the REAL Apple Core AI branch under Xcode 27.
#
# The default toolchain (Xcode 26.5) ships no CoreAI framework → `canImport(CoreAI)` is false → the Core AI
# adapter compiles to its no-op fallback (the regular `swift test` suite stays green that way). This script points
# SwiftPM at the Xcode 27 beta toolchain — which ships CoreAI.framework + the iOS/macOS 27 SDKs — and builds the
# BASAppleAdapters target so the REAL branch is type-checked against the genuine SDK:
#
#     AIModelAsset(contentsOf:) → AIModel(contentsOf:options:) → loadFunction → InferenceFunction.run → NDArray
#
# Scope is the single target to bound the Swift-6.4 blast radius (BASAppleAdapters' dependency subgraph does NOT
# include MLX/Metal, so the vendored MLX packages are not rebuilt). Any unrelated Swift-6.4 diagnostics in
# Vendor/* are an iOS-27-adaptation follow-on (#61), not a failure of THIS check. The beta build is isolated under
# .build/coreai-x27 so it never clobbers the default-toolchain .build the main suite uses.
#
# This is COMPILE certification only. Running Core AI inference requires an iOS 27 runtime (simulator / iPhone Air)
# + a real .aimodel asset — see scripts producing BASContextClassifier.aimodel and the on-device probe.
set -euo pipefail

if [ -z "${BETA_DEVELOPER_DIR:-}" ]; then
  for _x in /Applications/Xcode-beta.app /Users/changgeng/Downloads/Xcode-beta.app; do
    [ -d "$_x/Contents/Developer" ] && BETA_DEVELOPER_DIR="$_x/Contents/Developer" && break
  done
fi
BETA_DEVELOPER_DIR="${BETA_DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$PKG_DIR/.build/coreai-x27"

if [ ! -d "$BETA_DEVELOPER_DIR" ]; then
  echo "❌ Xcode 27 toolchain not found at: $BETA_DEVELOPER_DIR"
  echo "   Set BETA_DEVELOPER_DIR to <Xcode 27>.app/Contents/Developer and retry."
  exit 2
fi

# Confirm the toolchain genuinely carries CoreAI before trusting a green build.
MAC27_SDK="$BETA_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk"
if [ ! -d "$MAC27_SDK/System/Library/Frameworks/CoreAI.framework" ]; then
  echo "❌ CoreAI.framework absent from $MAC27_SDK — wrong/old beta? Aborting (a green build would be meaningless)."
  exit 2
fi

echo "🔧 Xcode 27 toolchain : $BETA_DEVELOPER_DIR"
DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun swift --version
echo "🧩 CoreAI.framework    : present in MacOSX27.0.sdk ✓"
# Non-vacuous-gate guard (R1): confirm canImport(CoreAI) actually resolves under this toolchain, so a green
# build genuinely exercises the gated branch (not a vacuous skip). Compiles a 1-line probe.
PROBE_SRC="$(mktemp /tmp/coreai_gate_probe.XXXXXX.swift)"
printf '#if canImport(CoreAI)\nimport CoreAI\nprint("YES")\n#else\nprint("NO")\n#endif\n' > "$PROBE_SRC"
GATE="$(DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun swiftc "$PROBE_SRC" -o "${PROBE_SRC%.swift}" 2>/dev/null && "${PROBE_SRC%.swift}")"
if [ "$GATE" != "YES" ]; then
  echo "❌ canImport(CoreAI) did NOT resolve under this toolchain (got '$GATE') — a green build would be vacuous."
  exit 2
fi
echo "🧪 canImport(CoreAI)   : YES (gate is live — the build will exercise the real branch)"
echo "🏗  Compile-certifying BASAppleAdapters (real CoreAI branch) under Xcode 27 …"

cd "$PKG_DIR"
DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun swift build \
  --target BASAppleAdapters \
  --scratch-path "$SCRATCH" \
  "$@"

echo "✅ Core AI real branch compile-certified under Xcode 27 — the adapter binds the genuine SDK API."
echo "   (Run-cert still pending: needs a real .aimodel + an iOS 27 runtime — sim / iPhone Air.)"
