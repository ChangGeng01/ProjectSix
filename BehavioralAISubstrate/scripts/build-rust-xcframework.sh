#!/usr/bin/env bash
# scripts/build-rust-xcframework.sh
# chapter 七百六 / M2187 第一刀 — MULTI-LANGUAGE
#                                 AUGMENTATION ARC Rust
#                                 pilot:builds the
#                                 BASRustMemoryTracker
#                                 XCFramework from the
#                                 Cargo workspace。
#
# ## Output
#
#   Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework
#
# Reproducibility flags (chapter 七百一 RED FLAG #1):
#   - SOURCE_DATE_EPOCH = git commit timestamp
#   - codegen-units = 1
#   - panic = abort
#   - strip = symbols
#   - lto = false (avoids LLVM cross-compile non-determinism)
#
# Verify reproducibility:run script twice on a clean
# tree,then `shasum -a 256` both .xcframework outputs。
# Hashes MUST match for the chapter 七百六 byte-equality
# invariant to hold。
#
# ## Cross-compilation scope (HONEST acknowledgment)
#
# THIS SCRIPT currently builds the HOST-NATIVE slice only
# (arm64-apple-darwin) to keep the M2187-M2190 sequence
# self-contained on a single Apple Silicon dev machine。
#
# Cross-compiling to arm64-apple-ios + arm64-apple-ios-sim
# requires:
#   1. `rustup target add aarch64-apple-ios`
#   2. `rustup target add aarch64-apple-ios-sim`
#   3. Re-run this script with TARGETS array expanded
#
# The XCFramework structure supports those slices being
# added later without breaking the host slice。 Substrate
# CI runs on macOS arm64 only today (per chapter 七百一
# plan honest-scope note),so host-only slice is
# sufficient for current PR validation。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARGO_ROOT="${REPO_ROOT}/Cargo"
VENDOR_DIR="${REPO_ROOT}/Vendor/bas-rust-binaries"
XCFRAMEWORK_NAME="BASRustMemoryTracker"
XCFRAMEWORK_OUT="${VENDOR_DIR}/${XCFRAMEWORK_NAME}.xcframework"
LIB_NAME="bas_memory_usage_tracker"

# Reproducibility — pin SOURCE_DATE_EPOCH to the latest
# git commit。 Two clean rebuilds at the same HEAD will
# see the same value here。
SDE=$(cd "${REPO_ROOT}" && git log -1 --format=%ct 2>/dev/null \
      || echo "1700000000")
export SOURCE_DATE_EPOCH="${SDE}"

# Reproducibility flags layered on top of profile.release
# in Cargo.toml。 Explicit even though the profile sets
# them — defensive against future Cargo.toml drift。
export RUSTFLAGS="-C codegen-units=1 -C strip=symbols"
export CARGO_TERM_COLOR=always

# Targets shipped。 Add cross-compile targets here:
#   "aarch64-apple-ios"     (iOS device)
#   "aarch64-apple-ios-sim" (iOS simulator)
TARGETS=(
  "aarch64-apple-darwin"
)

echo "==> SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
echo "==> RUSTFLAGS=${RUSTFLAGS}"
echo "==> targets:${TARGETS[*]}"
echo ""

# Step 1: cargo build --release per target。
for t in "${TARGETS[@]}"; do
  echo "==> cargo build --release --target ${t}"
  (
    cd "${CARGO_ROOT}"
    cargo build \
      --release \
      --target "${t}" \
      --manifest-path bas-memory-usage-tracker/Cargo.toml
  )
done

# Step 2: assemble xcodebuild -create-xcframework args。
# Each slice contributes `-library <path> -headers <dir>`。
rm -rf "${XCFRAMEWORK_OUT}"
mkdir -p "${VENDOR_DIR}"

XC_ARGS=()
for t in "${TARGETS[@]}"; do
  LIB_PATH="${CARGO_ROOT}/target/${t}/release/lib${LIB_NAME}.a"
  if [ ! -f "${LIB_PATH}" ]; then
    echo "ERROR:expected static lib not found:${LIB_PATH}"
    exit 1
  fi
  XC_ARGS+=("-library" "${LIB_PATH}"
            "-headers" "${CARGO_ROOT}/bas-memory-usage-tracker/include")
done

echo ""
echo "==> xcodebuild -create-xcframework"
xcodebuild -create-xcframework \
  "${XC_ARGS[@]}" \
  -output "${XCFRAMEWORK_OUT}"

echo ""
echo "==> XCFramework written to:"
echo "    ${XCFRAMEWORK_OUT}"
echo ""
echo "==> SHA256 of each slice (reproducibility check):"
find "${XCFRAMEWORK_OUT}" -name "*.a" -exec shasum -a 256 {} \;
echo ""
echo "Done。"
