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

swift_backend_args=()
case "${QINAO_SWIFT_BUILD_SYSTEM-default}" in
  default) ;;
  native) swift_backend_args=(--build-system native) ;;
  *)
    echo "check_qinao_import_boundaries: QINAO_SWIFT_BUILD_SYSTEM must be default or native" >&2
    exit 2
    ;;
esac

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

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/qinao-import-boundaries.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Portable line scanner: prefer ripgrep, fall back to POSIX grep. Both
# CI runners (with rg) and bare macOS hosts (without rg) must see the
# same results — silent fallthrough to "passed" when rg is missing is
# exactly the failure mode we're trying to prevent.
scan_imports() (
  local dir="$1"
  local pattern="$2"
  local output="$3"
  local rc=0
  if ! exec 3> "$output"; then
    echo "check_qinao_import_boundaries: cannot create scan output '$output'." >&2
    return 2
  fi
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$dir" -g '*.swift' >&3 || rc=$?
  else
    grep -rEn --include='*.swift' "$pattern" "$dir" >&3 || rc=$?
  fi
  exec 3>&-
  return "$rc"
)

scan_with_status() {
  local dir="$1"
  local pattern="$2"
  local output="$3"
  local label="$4"
  local rc=0
  scan_imports "$dir" "$pattern" "$output" || rc=$?
  if [[ "$rc" -gt 1 ]]; then
    echo "check_qinao_import_boundaries: scanner errored (rc=$rc) scanning $label." >&2
    violations=$((violations + 1))
  fi
}

# ---- 1. Qinao source imports ----
source_imports="$TEMP_DIR/source-imports.txt"
scan_with_status "$SOURCES_DIR" '^import [A-Za-z]' "$source_imports" "Qinao source imports"
while IFS= read -r line; do
  # line: <path>:<lineno>:<text>
  [[ -z "$line" ]] && continue
  text="${line#*:*:}"
  text="${text%%//*}"                       # audit fix: tolerate a trailing inline comment
  text="${text%"${text##*[![:space:]]}"}"   # rstrip so the ^import X$ anchor still matches
  if [[ ! "$text" =~ $ALLOWED_SOURCE_IMPORT_REGEX ]]; then
    echo "UNKNOWN import in Qinao source: $line" >&2
    violations=$((violations + 1))
  fi
done < "$source_imports"

# ---- 2. Forbidden host imports in Qinao sources ----
forbidden_source="$TEMP_DIR/forbidden-source-imports.txt"
scan_with_status "$SOURCES_DIR" "$FORBIDDEN_HOST_PACKAGES_REGEX" "$forbidden_source" "forbidden Qinao source imports"
forbidden_out="$(< "$forbidden_source")"
if [[ -n "$forbidden_out" ]]; then
  echo "Qinao sources must not import host packages (façades flow downward only):" >&2
  echo "$forbidden_out" >&2
  violations=$((violations + 1))
fi

# ---- 3. Qinao test imports ----
if [[ -d "$TESTS_DIR" ]]; then
  test_imports="$TEMP_DIR/test-imports.txt"
  scan_with_status "$TESTS_DIR" '^(@testable )?import [A-Za-z]' "$test_imports" "Qinao test imports"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    text="${line#*:*:}"
  text="${text%%//*}"                       # audit fix: tolerate a trailing inline comment
  text="${text%"${text##*[![:space:]]}"}"   # rstrip so the ^import X$ anchor still matches
    if [[ ! "$text" =~ $ALLOWED_TEST_IMPORT_REGEX ]]; then
      echo "UNKNOWN import in Qinao test: $line" >&2
      violations=$((violations + 1))
    fi
  done < "$test_imports"

  forbidden_tests="$TEMP_DIR/forbidden-test-imports.txt"
  scan_with_status "$TESTS_DIR" "$FORBIDDEN_HOST_PACKAGES_REGEX" "$forbidden_tests" "forbidden Qinao test imports"
  forbidden_test_out="$(< "$forbidden_tests")"
  if [[ -n "$forbidden_test_out" ]]; then
    echo "Qinao tests must not import host packages:" >&2
    echo "$forbidden_test_out" >&2
    violations=$((violations + 1))
  fi
fi

# ---- 4. Build must succeed ----
(
  cd "$PKG_DIR"
  if ! swift build ${swift_backend_args[@]+"${swift_backend_args[@]}"} >"$TEMP_DIR/qinao-build.log" 2>&1; then
    echo "QinaoRuntimeSDK failed to build:" >&2
    tail -40 "$TEMP_DIR/qinao-build.log" >&2
    exit 1
  fi
) || violations=$((violations + 1))

# ---- 5. Redaction scan ----
if ! "$ROOT/scripts/check_sovereign_redaction.sh" >"$TEMP_DIR/qinao-redaction.log" 2>&1; then
  cat "$TEMP_DIR/qinao-redaction.log" >&2
  violations=$((violations + 1))
fi

# ---- 6. Delegate to host-side SDK boundary check ----
if ! "$ROOT/scripts/check_sdk_import_boundaries.sh" >"$TEMP_DIR/qinao-sdk-boundary.log" 2>&1; then
  cat "$TEMP_DIR/qinao-sdk-boundary.log" >&2
  violations=$((violations + 1))
fi

if [[ "$violations" -gt 0 ]]; then
  echo "Qinao import boundary check FAILED ($violations violation(s))." >&2
  exit 1
fi

echo "Qinao import boundary check passed."
