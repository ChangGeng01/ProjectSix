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
# Verify reproducibility:run the script twice with
# BAS_CLEAN_REBUILD=1 (cold target dirs — REQUIRED;a warm
# re-run reuses cargo's fingerprint cache,including the
# clang-compiled sqlite3.o,and proves nothing),then
# `shasum -a 256` both .xcframework outputs。 Hashes MUST
# match for the chapter 七百六 byte-equality invariant to
# hold。 DEVELOPER_DIR is pinned below because sqlite3.o's
# bytes follow the active clang。
#
# ## Cross-compilation scope
#
# **M2191 chapter 七百七 第一刀**:TARGETS array
# expanded from host-only (arm64-apple-darwin) to
# include arm64-apple-ios + arm64-apple-ios-sim per
# the chapter 七百六 / M2190 planned-future-cut。
# Requires rustup targets `aarch64-apple-ios` +
# `aarch64-apple-ios-sim` installed on the maintainer
# machine。 Substrate now ships iOS-deployable Rust
# pilot binaries。
#
# Reverting to host-only:reduce TARGETS to one entry
# + rerun。 The XCFramework structure supports any
# subset of the three slices。

set -euo pipefail

# M2191 chapter 七百七 第一刀 — prefer rustup-managed
# cargo at `~/.cargo/bin/cargo` if available。 Homebrew's
# `/opt/homebrew/bin/cargo` does NOT see rustup-installed
# cross-compile targets (aarch64-apple-ios + aarch64-
# apple-ios-sim),so the iOS slices only build when this
# script picks up rustup's cargo first。 rust-toolchain
# .toml in repo root pins the rustup channel to stable
# 1.84+。
if [ -x "${HOME}/.cargo/bin/cargo" ]; then
    export PATH="${HOME}/.cargo/bin:${PATH}"
fi

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

# Pin the iOS/macOS slices to the package minimums (Package.swift: .iOS(.v18), .macOS(.v14)). Rust's
# *-apple-ios / *-apple-darwin targets honor these deployment-target env vars for the per-object min-OS load
# command. WITHOUT them, a build under a newer Xcode SDK bakes in that SDK's default (e.g. iOS 26.5), which then
# mismatches the iOS-18 app deployment target at link time ("built for newer 'iOS' version than being linked").
export IPHONEOS_DEPLOYMENT_TARGET="18.0"
export MACOSX_DEPLOYMENT_TARGET="14.0"

# 全面进化 T2.1a audit fix — pin the C COMPILER, not just the Rust
# toolchain。 The bundle contains ONE clang-compiled member
# (libsqlite3-sys's sqlite3.o via the cc crate);its bytes vary
# with the active clang (stable vs beta Xcode produce different
# codegen),and cargo's fingerprint cache reuses the cached .o
# across script runs — so "run the script twice" was structurally
# unable to detect the drift (audited 2026-06-11: 456/458 archive
# members reproducible,sqlite3.o the sole exception)。 DEVELOPER_DIR
# resolves /usr/bin/cc → this Xcode's clang for the cc crate。
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Targets shipped。 Three slices since M2191 chapter
# 七百七 第一刀 (expanded from host-only at M2187)。
TARGETS=(
  "aarch64-apple-darwin"
  "aarch64-apple-ios"
  "aarch64-apple-ios-sim"
)

echo "==> SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
echo "==> RUSTFLAGS=${RUSTFLAGS}"
echo "==> DEVELOPER_DIR=${DEVELOPER_DIR}"
echo "==> targets:${TARGETS[*]}"
echo ""

# BAS_CLEAN_REBUILD=1 — cold-rebuild mode for reproducibility
# verification:wipes each target's release dir so EVERY member
# (including the clang-compiled sqlite3.o) recompiles from source。
# The doctrine check is two CLEAN rebuilds hashing identically;
# warm re-runs only prove the cache works。
if [ "${BAS_CLEAN_REBUILD:-0}" = "1" ]; then
  for t in "${TARGETS[@]}"; do
    echo "==> BAS_CLEAN_REBUILD: rm -rf target/${t}/release"
    rm -rf "${CARGO_ROOT}/target/${t}/release"
  done
fi

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

# M2189 第三刀 — `module.modulemap` ships in include/
# alongside the header so each slice's Headers/
# directory automatically gets it via the `-headers`
# arg above。 Swift consumers can then
# `import BASRustMemoryTrackerBinary`。

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
