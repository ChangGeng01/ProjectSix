#!/usr/bin/env bash
# NAME-COLLISION NOTE (2026-07-12): this PARENT-REPO script is the RESIDUAL-MARKER scan
# (M86 regex over leftover TODO/placeholder markers in BehavioralAISubstrate/Sources).
# Renamed from check_substrate_residuals.sh (2026-07-12) to end the name collision with
# BehavioralAISubstrate/scripts/check_substrate_residuals.sh
# (the residuals GATE: print()-count + density, called by pre-commit-gates.sh). Same
# filename, different jobs — a red in one does NOT contradict a green in the other.
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
#   - REMOVE `\bquick\b` (2026-05-20,post-Before-severance) — same
#     reasoning as `\bBefore\b`:「quick」 is a common English word
#     (e.g。 「quick start」 in BASCognitiveBrain.md heading) that
#     false-positives the residual scan。 The `BASQuick` prefix ban
#     + `quickCapture` / `quickEnvelope` compound bans + the
#     `(quick|balance)([A-Z_]...)` embedded identifier regex still
#     catch every real legacy identifier。 Zero loss of coverage,
#     full loss of false positives。 Same rationale applied to
#     `\bbalance\b` and `\bbuddy\b` — both common English words。
WHOLE_WORD_RESIDUAL_REGEX='(sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source)'
EMBEDDED_IDENTIFIER_RESIDUAL_REGEX='((^|[^A-Za-z])(quick|balance)([A-Z_][A-Za-z0-9_]*))'
SOURCE_TEST_RESIDUAL_REGEX="${WHOLE_WORD_RESIDUAL_REGEX}|${EMBEDDED_IDENTIFIER_RESIDUAL_REGEX}"
README_RESIDUAL_REGEX='(sessionPrime|quickCapture|\bopenMode\b|reopenTomorrowItem|resumeCurrentDecision|BASQuick|BASBalance|BASReminder|quickEnvelope|balanceEnvelope|mirrorEnvelope|reminderEnvelope|reminder-source)'
TEST_ALLOWLIST_REGEX='/(BASCognitionCoreTests|BASMemoryCognitionCoreTests|BASReferencePromptModesCoreTests|BASAppleCurrentBrainBootstrapTests|BASAppleEvolutionCheckpointWriterTests)\.swift:'

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/substrate-residual-markers.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

capture_output() (
  local out="$1"
  local label="$2"
  shift 2
  if ! exec 3> "$out"; then
    echo "check_substrate_residuals: cannot create $label output '$out'." >&2
    return 2
  fi
  "$@" >&3
)

# M86 — portable searcher. See check_sdk_import_boundaries.sh for the
# rationale (rg was invoked unconditionally and the script vacuously
# passed on machines without ripgrep because `if rg ...; then` treated
# the missing command as "no matches"). Now we fall back to `grep -rnE`
# when `rg` isn't installed and fail loudly when neither tool exists.
if command -v rg >/dev/null 2>&1; then
  searcher_swift_md() (
    capture_output "$3" scan rg -n "$1" "$2" -g '*.swift' -g '*.md'
  )
  searcher_swift() (
    capture_output "$3" scan rg -n "$1" "$2" -g '*.swift'
  )
elif command -v grep >/dev/null 2>&1; then
  searcher_swift_md() (
    capture_output "$3" scan grep -rnE "$1" --include='*.swift' --include='*.md' "$2"
  )
  searcher_swift() (
    capture_output "$3" scan grep -rnE "$1" --include='*.swift' "$2"
  )
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

  local rc=0
  if [[ "$mode" == "swift_md" ]]; then
    searcher_swift_md "$regex" "$target" "$output" || rc=$?
  else
    searcher_swift "$regex" "$target" "$output" || rc=$?
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "Substrate residual scan failed in $label. Move legacy Before vocabulary back to the host compatibility layer." >&2
    cat "$output" >&2
    exit 1
  elif [[ "$rc" -gt 1 ]]; then
    echo "check_substrate_residuals: scanner errored (rc=$rc) scanning $label." >&2
    cat "$output" >&2
    exit 2
  fi
}

check_target "$SOURCE_TARGET" "substrate sources" "$SOURCE_TEST_RESIDUAL_REGEX" "$TEMP_DIR/source-residuals.txt" swift_md
# README is a single file; grep/rg handle single-file arguments for either globbing mode.
if [[ -f "$README_TARGET" ]]; then
  readme_output="$TEMP_DIR/readme-residuals.txt"
  _rc=0
  searcher_swift_md "$README_RESIDUAL_REGEX" "$README_TARGET" "$readme_output" || _rc=$?
  if [[ "$_rc" -eq 0 ]]; then
    echo "Substrate residual scan failed in substrate README. Move legacy Before vocabulary back to the host compatibility layer." >&2
    cat "$readme_output" >&2
    exit 1
  elif [[ "$_rc" -gt 1 ]]; then
    echo "check_substrate_residuals: scanner errored (rc=$_rc) scanning substrate README." >&2
    cat "$readme_output" >&2
    exit 2
  fi
fi

test_residuals_all="$TEMP_DIR/test-residuals-all.txt"
test_residuals="$TEMP_DIR/test-residuals.txt"
_rc=0
searcher_swift "$SOURCE_TEST_RESIDUAL_REGEX" "$TEST_TARGET" "$test_residuals_all" || _rc=$?
if [[ "$_rc" -eq 0 ]]; then
  _filter_rc=0
  capture_output "$test_residuals" filter grep -Ev "$TEST_ALLOWLIST_REGEX" "$test_residuals_all" || _filter_rc=$?
  if [[ "$_filter_rc" -gt 1 ]]; then
    echo "check_substrate_residuals: test allowlist filter errored (rc=$_filter_rc)." >&2
    cat "$test_residuals" >&2
    exit 2
  fi
  if [[ "$_filter_rc" -eq 0 ]]; then
    echo "Substrate residual scan failed in substrate tests. Keep legacy vocabulary only in explicit rejection coverage." >&2
    cat "$test_residuals" >&2
    exit 1
  fi
elif [[ "$_rc" -gt 1 ]]; then
  echo "check_substrate_residuals: scanner errored (rc=$_rc) scanning substrate tests." >&2
  cat "$test_residuals_all" >&2
  exit 2
fi

echo "BAS substrate residual scan passed."
