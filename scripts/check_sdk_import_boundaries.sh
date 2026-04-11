#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGETS=(
  "Before/App"
  "Before/Shared"
  "BeforeWatch"
  "BeforeWidgetExtension"
  "SampleHost"
)

FORBIDDEN_REGEX='^import BAS(RuntimeCore|Memory|Policy|Orchestration|Observability|Evaluation|AppleAdapters|Admin)$'

if rg -n "$FORBIDDEN_REGEX" "${TARGETS[@]}" -g '*.swift' >/tmp/bas_host_import_violations.txt; then
  echo "Direct low-level BAS imports are forbidden in host sources. Use BASHostKit instead." >&2
  cat /tmp/bas_host_import_violations.txt >&2
  exit 1
fi

echo "BAS host import boundary check passed."
