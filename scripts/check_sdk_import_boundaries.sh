#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGETS=(
  "Before/App"
  "Before/Shared"
  "BeforeTests"
  "BeforeWatch"
  "BeforeWidgetExtension"
  "SampleHost"
  "SampleHostTests"
)

FORBIDDEN_REGEX='^import BAS(RuntimeCore|Memory|Policy|Orchestration|Observability|Evaluation|AppleAdapters)$'
ADMIN_REGEX='^import BASAdmin$'
ADMIN_ALLOWED_PATH_REGEX='/(Debug|Inspection|Console|Testing)[^/]*\.swift:'

if rg -n "$FORBIDDEN_REGEX" "${TARGETS[@]}" -g '*.swift' >/tmp/bas_host_import_violations.txt; then
  echo "Direct low-level BAS imports are forbidden in host sources. Use BASHostKit instead." >&2
  cat /tmp/bas_host_import_violations.txt >&2
  exit 1
fi

if rg -n "$ADMIN_REGEX" "${TARGETS[@]}" -g '*.swift' >/tmp/bas_admin_imports.txt; then
  grep -Ev "$ADMIN_ALLOWED_PATH_REGEX" /tmp/bas_admin_imports.txt >/tmp/bas_admin_import_violations.txt || true
  if [[ -s /tmp/bas_admin_import_violations.txt ]]; then
    echo "Direct BASAdmin imports are only allowed in debug or inspection surfaces. Use BASHostKit elsewhere." >&2
    cat /tmp/bas_admin_import_violations.txt >&2
    exit 1
  fi
fi

"$ROOT/scripts/check_substrate_residuals.sh"

echo "BAS host import boundary check passed."
