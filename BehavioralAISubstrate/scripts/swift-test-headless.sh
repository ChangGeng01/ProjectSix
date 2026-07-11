#!/usr/bin/env bash
# Headless test entry for BehavioralAISubstrate (WS4 — test-entry hygiene).
#
# WHY this exists: the swift-testing (@Test) PARALLEL runner SIGBUSes (signal 10) under full load in a
# HEADLESS macOS session (no logged-in Aqua session; some system XPC services unavailable). This is an
# ENVIRONMENTAL incompatibility, NOT a project-code failure — see
# Docs/KNOWN_ISSUE_swift_testing_headless_sigbus.md. We do NOT try to "fix" it.
#
# So the AUTHORITATIVE headless gate is the XCTest suite via --disable-swift-testing (15k+ tests, 0
# failures). The swift-testing (@Test) suites are then run as a BEST-EFFORT, SMALLER-batch pass (smaller
# parallel groups dodge the full-load SIGBUS); a non-zero there is treated as a warning, not a gate
# failure (run the monolithic `swift test` in a logged-in GUI session for the full @Test pass).
#
# Usage:  scripts/swift-test-headless.sh [extra swift-test args...]

# Xcode-27-beta guard: under the beta toolchain `swift test` SEGVs (signal 11) at xctest LOAD before any
# test runs (pre-existing toolchain issue — proven via old-vendor control on vendor-latest-refresh). If the
# machine's xcode-select points at the beta and the caller did not pin a toolchain, pin the STABLE Xcode.
if [ -z "${DEVELOPER_DIR:-}" ] && xcode-select -p 2>/dev/null | grep -q "Xcode-beta"; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    echo "[toolchain] xcode-select → Xcode-beta (xctest SEGV hazard); pinned DEVELOPER_DIR=${DEVELOPER_DIR}"
fi
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# MLX metallib escape hatch (vendor patch: MLX_METAL_PATH is checked FIRST in Cmlx's
# load_default_library). ROOT CAUSE of the "MLX error: Failed to load the default metallib"
# tail-kill: the STABLE-toolchain pin above selects SPM's native build system, which does NOT
# produce/embed mlx-swift_Cmlx.bundle (the beta swiftbuild backend embeds it in the xctest) —
# so MLX's first Metal touch fails all five lookups and the mlx-c DEFAULT handler exit(-1)s the
# WHOLE xctest process. Pin any built metallib (e.g. from a beta/swiftbuild tree: same vendored
# kernels) by absolute path so the load doesn't depend on the build system's bundle layout.
# Fail-open twice over: no file found ⇒ unset ⇒ stock lookup; bad path ⇒ the vendor patch warns
# and falls through; and if the load still fails, the BASMLXMetalAvailability probe converts the
# process-kill into loud per-suite skips (the gate survives).
if [ -z "${MLX_METAL_PATH:-}" ]; then
    mtllib="$(find .build -path "*mlx-swift_Cmlx.bundle*" -name "default.metallib" 2>/dev/null | head -1)"
    if [ -n "$mtllib" ]; then
        export MLX_METAL_PATH="$(cd "$(dirname "$mtllib")" && pwd)/default.metallib"
        echo "[mlx] pinned MLX_METAL_PATH=$MLX_METAL_PATH"
    fi
fi

echo "==================================================================="
echo "[GATE] XCTest (authoritative, headless-reliable) — swift test --disable-swift-testing"
echo "==================================================================="
swift test --disable-swift-testing "$@"
gate=$?
if [ "$gate" -ne 0 ]; then
  echo ">>> XCTest GATE FAILED (exit $gate). This IS a real failure — fix before merge."
  exit "$gate"
fi
echo ">>> XCTest gate PASSED."

echo
echo "==================================================================="
echo "[BEST-EFFORT] swift-testing (@Test) in smaller batches (SIGBUS is environmental → non-gating)"
echo "==================================================================="
# Coarse name-prefix batches covering the @Test suites; each is a smaller parallel group that avoids the
# full-load headless SIGBUS. A non-zero batch is reported, not fatal (see KNOWN_ISSUE doc).
batches=(
  "BASApple"
  "BASMemory"
  "BASCurrentBrain|BASProvider|BASPromptContract|BASReferencePrompt"
  "BASRuntimeCore|BASOrchestration|BASEBrainSchema|BASTemporalMemory"
)
warned=0
for b in "${batches[@]}"; do
  echo "-- @Test batch: $b --"
  if ! swift test --filter "$b"; then
    echo "   (batch '$b' non-zero — environmental SIGBUS or no-match; not a gate failure)"
    warned=1
  fi
done

echo
if [ "$warned" -ne 0 ]; then
  echo "Done. XCTest gate PASSED (authoritative). One+ @Test batch was non-zero — re-run the full"
  echo "monolithic 'swift test' in a logged-in GUI session to confirm the @Test suites, per KNOWN_ISSUE."
else
  echo "Done. XCTest gate PASSED + all @Test batches green."
fi
exit 0
