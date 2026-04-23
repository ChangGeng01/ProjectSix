#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SOURCE_TARGET="BehavioralAISubstrate/Sources"
README_TARGET="BehavioralAISubstrate/README.md"
TEST_TARGET="BehavioralAISubstrate/Tests/BehavioralAISubstrateTests"
# M86 — residual regex tightened.
#
# History: the pre-M86 regex also banned `\bmirror\b`, `BASMirror` (as a
# prefix), `(mirror)[A-Z_]` embedded identifiers, and `\bBefore\b`. Those
# patterns date from before M54's L7 Mirror Blade wiring, when `mirror`
# appeared in the substrate only as a legacy Before decision mode
# (BASMirrorRecord / BASMirrorSession). After M54 the substrate
# legitimately uses:
#
#   - `BASMirrorDraft` / `BASMirrorMode` (L7 Mirror Blade schema types)
#   - `.mirror` permit mode on `BASActionPermit` / `BASActionPermitMode`
#   - `mirrorText` / `mirrorDraft` / `mirrorBlade` / `mirrorMode` fields
#     on `BASDecomposeFrame` and L7 coordinator glue
#
# All of those are new-era vocabulary, not legacy Before host vocab. The
# legacy Before types (BASQuickCheck / BASBalanceBoard / BASMirrorRecord /
# BASReminder*) were fully deleted pre-M20 and verification shows zero
# remaining instances in BehavioralAISubstrate/Sources.
#
# The only reason the old regex "passed" was the ripgrep-missing bug
# the script inherited (see check_sdk_import_boundaries.sh M86 note);
# once `rg` is absent, `if rg ...; then` evaluates false and the gate
# vacuously reports green. The M86 portable searcher (grep fallback)
# exposed ~50 Mirror Blade false positives on the first real run.
#
# Tightening strategy:
#   - KEEP compound-identifier bans (quickCapture, sessionPrime, ...)
#   - KEEP word-boundary bans on legacy-only tokens (quick / balance /
#     buddy / history / openMode) — no L1-L14 whitepaper has reclaimed
#     these as canonical vocabulary
#   - KEEP prefix bans on explicit legacy type names (BASQuick /
#     BASBalance / BASReminder — zero current instances, so they guard
#     against future regressions)
#   - REMOVE `\bmirror\b` and `BASMirror` prefix — conflict with the L7
#     Mirror Blade schema
#   - REMOVE `(mirror)[A-Z_]` from the embedded identifier regex — L7
#     legitimately uses mirrorText / mirrorDraft / mirrorMode
#   - REMOVE `\bBefore\b` — it's an English word; narrow regressions
#     that actually ship host identifiers will still be caught by the
#     specific compound patterns above
WHOLE_WORD_RESIDUAL_REGEX='(\bquick\b|\bbalance\b|\bbuddy\b|sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source)'
EMBEDDED_IDENTIFIER_RESIDUAL_REGEX='((^|[^A-Za-z])(quick|balance)([A-Z_][A-Za-z0-9_]*))'
SOURCE_TEST_RESIDUAL_REGEX="${WHOLE_WORD_RESIDUAL_REGEX}|${EMBEDDED_IDENTIFIER_RESIDUAL_REGEX}"
README_RESIDUAL_REGEX='(\bquick\b|\bbalance\b|\bbuddy\b|sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source)'
TEST_ALLOWLIST_REGEX='/(BASCognitionCoreTests|BASMemoryCognitionCoreTests|BASReferencePromptModesCoreTests|BASAppleCurrentBrainBootstrapTests|BASAppleEvolutionCheckpointWriterTests)\.swift:'

# M86 — portable searcher. See check_sdk_import_boundaries.sh for the
# rationale (rg was invoked unconditionally and the script vacuously
# passed on machines without ripgrep because `if rg ...; then` treated
# the missing command as "no matches"). Now we fall back to `grep -rnE`
# when `rg` isn't installed and fail loudly when neither tool exists.
if command -v rg >/dev/null 2>&1; then
  searcher_swift_md() { rg -n "$1" "$2" -g '*.swift' -g '*.md' > "$3"; }
  searcher_swift()    { rg -n "$1" "$2" -g '*.swift'              > "$3"; }
elif command -v grep >/dev/null 2>&1; then
  searcher_swift_md() {
    grep -rnE "$1" --include='*.swift' --include='*.md' "$2" > "$3"
  }
  searcher_swift() {
    grep -rnE "$1" --include='*.swift' "$2" > "$3"
  }
else
  echo "check_substrate_residuals: neither 'rg' nor 'grep' found in PATH; cannot verify gate." >&2
  exit 2
fi

check_target() {
  local target="$1"
  local label="$2"
  local regex="$3"
  local output="$4"
  local mode="${5:-swift_md}"

  local succeeded=0
  if [[ "$mode" == "swift_md" ]]; then
    if searcher_swift_md "$regex" "$target" "$output"; then succeeded=1; fi
  else
    if searcher_swift "$regex" "$target" "$output"; then succeeded=1; fi
  fi

  if [[ "$succeeded" == "1" ]]; then
    echo "Substrate residual scan failed in $label. Move legacy Before vocabulary back to the host compatibility layer." >&2
    cat "$output" >&2
    exit 1
  fi
}

check_target "$SOURCE_TARGET" "substrate sources" "$SOURCE_TEST_RESIDUAL_REGEX" /tmp/bas_substrate_source_residuals.txt swift_md
# README is a single file; grep/rg handle single-file arguments for either globbing mode.
if [[ -f "$README_TARGET" ]]; then
  if searcher_swift_md "$README_RESIDUAL_REGEX" "$README_TARGET" /tmp/bas_substrate_readme_residuals.txt; then
    if [[ -s /tmp/bas_substrate_readme_residuals.txt ]]; then
      echo "Substrate residual scan failed in substrate README. Move legacy Before vocabulary back to the host compatibility layer." >&2
      cat /tmp/bas_substrate_readme_residuals.txt >&2
      exit 1
    fi
  fi
fi

if searcher_swift "$SOURCE_TEST_RESIDUAL_REGEX" "$TEST_TARGET" /tmp/bas_substrate_test_residuals_all.txt; then
  grep -Ev "$TEST_ALLOWLIST_REGEX" /tmp/bas_substrate_test_residuals_all.txt >/tmp/bas_substrate_test_residuals.txt || true
  if [[ -s /tmp/bas_substrate_test_residuals.txt ]]; then
    echo "Substrate residual scan failed in substrate tests. Keep legacy vocabulary only in explicit rejection coverage." >&2
    cat /tmp/bas_substrate_test_residuals.txt >&2
    exit 1
  fi
fi

echo "BAS substrate residual scan passed."
