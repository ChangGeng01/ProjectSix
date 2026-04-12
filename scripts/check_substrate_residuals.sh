#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SOURCE_TARGET="BehavioralAISubstrate/Sources"
README_TARGET="BehavioralAISubstrate/README.md"
TEST_TARGET="BehavioralAISubstrate/Tests/BehavioralAISubstrateTests"
WHOLE_WORD_RESIDUAL_REGEX='(\bquick\b|\bbalance\b|\bmirror\b|\bbuddy\b|\bhistory\b|sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASMirror|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source|\bBefore\b)'
EMBEDDED_IDENTIFIER_RESIDUAL_REGEX='((^|[^A-Za-z])(quick|balance|mirror|reminder)([A-Z_][A-Za-z0-9_]*))'
SOURCE_TEST_RESIDUAL_REGEX="${WHOLE_WORD_RESIDUAL_REGEX}|${EMBEDDED_IDENTIFIER_RESIDUAL_REGEX}"
README_RESIDUAL_REGEX='(\bquick\b|\bbalance\b|\bmirror\b|\bbuddy\b|\bhistory\b|sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASMirror|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source)'
TEST_ALLOWLIST_REGEX='/(BASCognitionCoreTests|BASMemoryCognitionCoreTests|BASReferencePromptModesCoreTests|BASAppleCurrentBrainBootstrapTests)\.swift:'

check_target() {
  local target="$1"
  local label="$2"
  local regex="$3"
  local output="$4"

  if rg -n "$regex" "$target" -g '*.swift' -g '*.md' >"$output"; then
    echo "Substrate residual scan failed in $label. Move legacy Before vocabulary back to the host compatibility layer." >&2
    cat "$output" >&2
    exit 1
  fi
}

check_target "$SOURCE_TARGET" "substrate sources" "$SOURCE_TEST_RESIDUAL_REGEX" /tmp/bas_substrate_source_residuals.txt
check_target "$README_TARGET" "substrate README" "$README_RESIDUAL_REGEX" /tmp/bas_substrate_readme_residuals.txt

if rg -n "$SOURCE_TEST_RESIDUAL_REGEX" "$TEST_TARGET" -g '*.swift' >/tmp/bas_substrate_test_residuals_all.txt; then
  grep -Ev "$TEST_ALLOWLIST_REGEX" /tmp/bas_substrate_test_residuals_all.txt >/tmp/bas_substrate_test_residuals.txt || true
  if [[ -s /tmp/bas_substrate_test_residuals.txt ]]; then
    echo "Substrate residual scan failed in substrate tests. Keep legacy vocabulary only in explicit rejection coverage." >&2
    cat /tmp/bas_substrate_test_residuals.txt >&2
    exit 1
  fi
fi

echo "BAS substrate residual scan passed."
