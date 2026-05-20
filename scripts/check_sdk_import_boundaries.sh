#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Live host targets that must NOT import low-level BAS modules directly。
# Hosts go through BASHostKit / BASAdmin (latter only in debug/inspection)。
#
# Before host was severed 2026-05-20 (see /Archive/Legacy/README.md.archive-notice)。
# The original TARGETS list included Before/App,Before/Shared,BeforeTests,
# BeforeWatch,BeforeWidgetExtension。 These are now under Archive/Legacy/ and
# excluded from import-boundary enforcement per the 不删除 only relocate
# discipline — historical Before vocabulary is preserved but no longer
# constrains the substrate's evolving import surface。
TARGETS=(
  "SampleHost"
  "SampleHostTests"
)

FORBIDDEN_REGEX='^import BAS(RuntimeCore|Memory|Policy|Orchestration|Observability|Evaluation|AppleAdapters)$'
ADMIN_REGEX='^import BASAdmin$'
ADMIN_ALLOWED_PATH_REGEX='/(Debug|Inspection|Console|Testing)[^/]*\.swift:'

# M86 — portable searcher. Prefer ripgrep when available (fast, identical
# output format the rest of this script was built against); fall back to
# `grep -rnE` when `rg` is not on PATH so this gate never silently passes
# on a machine without ripgrep installed. Before M86 the script invoked
# `rg` unconditionally; on a machine without ripgrep every rg call emitted
# `rg: command not found` and returned non-zero, which the surrounding
# `if rg ...; then` treated as "no violations", making the whole gate
# vacuously green. Now the gate fails loudly when neither searcher can run.
if command -v rg >/dev/null 2>&1; then
  searcher() { rg -n "$1" "${@:2:$#-2}" -g '*.swift' > "${@: -1}"; }
elif command -v grep >/dev/null 2>&1; then
  searcher() {
    # $1 = pattern, $2..n-1 = target dirs, $n = output file
    local pattern="$1"
    local out="${@: -1}"
    local -a targets=()
    local arg
    for arg in "${@:2:$#-2}"; do targets+=("$arg"); done
    grep -rnE "$pattern" --include='*.swift' "${targets[@]}" > "$out"
  }
else
  echo "check_sdk_import_boundaries: neither 'rg' nor 'grep' found in PATH; cannot verify gate." >&2
  exit 2
fi

if searcher "$FORBIDDEN_REGEX" "${TARGETS[@]}" /tmp/bas_host_import_violations.txt; then
  echo "Direct low-level BAS imports are forbidden in host sources. Use BASHostKit instead." >&2
  cat /tmp/bas_host_import_violations.txt >&2
  exit 1
fi

if searcher "$ADMIN_REGEX" "${TARGETS[@]}" /tmp/bas_admin_imports.txt; then
  grep -Ev "$ADMIN_ALLOWED_PATH_REGEX" /tmp/bas_admin_imports.txt >/tmp/bas_admin_import_violations.txt || true
  if [[ -s /tmp/bas_admin_import_violations.txt ]]; then
    echo "Direct BASAdmin imports are only allowed in debug or inspection surfaces. Use BASHostKit elsewhere." >&2
    cat /tmp/bas_admin_import_violations.txt >&2
    exit 1
  fi
fi

"$ROOT/scripts/check_substrate_residuals.sh"

echo "BAS host import boundary check passed."
