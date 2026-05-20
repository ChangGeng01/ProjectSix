#!/usr/bin/env bash
# check_qinao_import_boundaries.sh
#
# Enforce the Qinao SDK's four-layer nesting model at the import level:
#   Human Host -> Qinao SDK -> Second Brain (BAS*) -> Neural Network
#
# Rules:
#   1. Qinao module sources may import: Foundation, CryptoKit, SwiftUI,
#      Combine, Observation, os, BackgroundTasks (for L1 maintenance
#      bridge — wrapped in canImport), BAS*, and sibling Qinao* modules.
#   2. Qinao module sources must NOT import host-level packages
#      (SampleHost, etc.) — façades flow downward only。 (Pre-2026-05-20
#      this list included Before / BeforeWatch / BeforeWidgetExtension;
#      those hosts were severed to Archive/Legacy/ and are no longer
#      reachable as Swift imports, but the regex keeps them as a belt-
#      and-suspenders ban against future re-introduction。)
#   3. Qinao tests may use @testable import Qinao* and may import BAS*
#      as part of substrate fixtures; they must not import host code.
#   4. The package builds green and the symbol-graph based redaction
#      check passes (delegated to check_sovereign_redaction.sh).
#
# This script does NOT enforce the host->BAS ban — that's
# check_sdk_import_boundaries.sh's job. It runs that script last so
# both boundaries are validated together.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PKG_DIR="$ROOT/QinaoRuntimeSDK"
SOURCES_DIR="$PKG_DIR/Sources"
TESTS_DIR="$PKG_DIR/Tests"

if [[ ! -d "$SOURCES_DIR" ]]; then
  echo "check_qinao_import_boundaries: $SOURCES_DIR not found" >&2
  exit 1
fi

ALLOWED_SOURCE_IMPORT_REGEX='^import (Foundation|CryptoKit|SwiftUI|Combine|Observation|os|BackgroundTasks|BAS[A-Za-z]+|Qinao[A-Za-z]+)$'
ALLOWED_TEST_IMPORT_REGEX='^(@testable )?import (XCTest|Foundation|CryptoKit|SwiftUI|BackgroundTasks|AppKit|UIKit|BAS[A-Za-z]+|Qinao[A-Za-z]+)$'
FORBIDDEN_HOST_PACKAGES_REGEX='^import (Before|SampleHost|BeforeWatch|BeforeWidgetExtension)[A-Za-z]*$'

violations=0

# Portable line scanner: prefer ripgrep, fall back to POSIX grep. Both
# CI runners (with rg) and bare macOS hosts (without rg) must see the
# same results — silent fallthrough to "passed" when rg is missing is
# exactly the failure mode we're trying to prevent.
scan_imports() {
  local dir="$1"
  local pattern="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$dir" -g '*.swift' || true
  else
    grep -rEn --include='*.swift' "$pattern" "$dir" || true
  fi
}

# ---- 1. Qinao source imports ----
while IFS= read -r line; do
  # line: <path>:<lineno>:<text>
  [[ -z "$line" ]] && continue
  text="${line#*:*:}"
  if [[ ! "$text" =~ $ALLOWED_SOURCE_IMPORT_REGEX ]]; then
    echo "UNKNOWN import in Qinao source: $line" >&2
    violations=$((violations + 1))
  fi
done < <(scan_imports "$SOURCES_DIR" '^import [A-Za-z]')

# ---- 2. Forbidden host imports in Qinao sources ----
forbidden_out="$(scan_imports "$SOURCES_DIR" "$FORBIDDEN_HOST_PACKAGES_REGEX")"
if [[ -n "$forbidden_out" ]]; then
  echo "Qinao sources must not import host packages (façades flow downward only):" >&2
  echo "$forbidden_out" >&2
  violations=$((violations + 1))
fi

# ---- 3. Qinao test imports ----
if [[ -d "$TESTS_DIR" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    text="${line#*:*:}"
    if [[ ! "$text" =~ $ALLOWED_TEST_IMPORT_REGEX ]]; then
      echo "UNKNOWN import in Qinao test: $line" >&2
      violations=$((violations + 1))
    fi
  done < <(scan_imports "$TESTS_DIR" '^(@testable )?import [A-Za-z]')

  forbidden_test_out="$(scan_imports "$TESTS_DIR" "$FORBIDDEN_HOST_PACKAGES_REGEX")"
  if [[ -n "$forbidden_test_out" ]]; then
    echo "Qinao tests must not import host packages:" >&2
    echo "$forbidden_test_out" >&2
    violations=$((violations + 1))
  fi
fi

# ---- 4. Build must succeed ----
(
  cd "$PKG_DIR"
  if ! swift build >/tmp/qinao_build.log 2>&1; then
    echo "QinaoRuntimeSDK failed to build:" >&2
    tail -40 /tmp/qinao_build.log >&2
    exit 1
  fi
) || violations=$((violations + 1))

# ---- 5. Redaction scan ----
if ! "$ROOT/scripts/check_sovereign_redaction.sh" >/tmp/qinao_redaction.log 2>&1; then
  cat /tmp/qinao_redaction.log >&2
  violations=$((violations + 1))
fi

# ---- 6. Delegate to host-side SDK boundary check ----
if ! "$ROOT/scripts/check_sdk_import_boundaries.sh" >/tmp/qinao_sdk_boundary.log 2>&1; then
  cat /tmp/qinao_sdk_boundary.log >&2
  violations=$((violations + 1))
fi

if [[ "$violations" -gt 0 ]]; then
  echo "Qinao import boundary check FAILED ($violations violation(s))." >&2
  exit 1
fi

echo "Qinao import boundary check passed."
