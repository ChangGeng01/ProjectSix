#!/usr/bin/env bash
# check_sovereign_choke_point.sh
#
# Enforce the single-choke-point discipline for L14 turn audit:
# `QinaoRuntime.sendSession()` is the ONLY path that calls
# `sovereign.auditTurn(...)`. Any other caller bypasses
# (a) the pre-flight halted-session refuse, (b) the M45 coverage
# verdict, (c) the parity fail-closed branch, and (d) the severity
# auto-halt branch — i.e. they would issue a verdict without the
# cross-layer reconciler ever seeing it.
#
# The rule covers Qinao sources only. BAS substrate fixtures and
# tests may call substrate-level audit primitives directly
# (they do not hold a `QinaoSovereignControlPlane`). Qinao tests
# are also exempt so integration tests can exercise each branch in
# isolation.
#
# Failure mode: if anything in Qinao's Sources tree other than
# `QinaoRuntime.sendSession` invokes `sovereign.auditTurn(` or
# `.auditTurn(`, the script fails the build.
#
# Locks in the M95 single-entry model: every turn that reaches
# auditTurn went through sendSession, which means it also went
# through recordTurnCoverage + pre-halted gate + halt branches +
# optional observation-bundle streaming. No silent bypass.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PKG_DIR="$ROOT/QinaoRuntimeSDK"
SOURCES_DIR="$PKG_DIR/Sources"

if [[ ! -d "$SOURCES_DIR" ]]; then
    echo "check_sovereign_choke_point: $SOURCES_DIR not found" >&2
    exit 1
fi

# Find all invocations of .auditTurn( in Qinao Sources — not
# definitions (which say `public func auditTurn`) and not doc
# comments (which say `///` and reference the name in prose).
# We use `grep -rn` directly for portability (rg is a builder
# convenience, not a script dependency).
RAW=$(grep -rn '\.auditTurn(' "$SOURCES_DIR" \
    --include='*.swift' 2>/dev/null || true)

CALLERS=$(printf '%s\n' "$RAW" \
    | grep -v '///' \
    | grep -v 'public func auditTurn' \
    | grep -v 'internal func auditTurn' \
    | grep -v 'return try await auditTurn(' \
    || true)

# Parse into file:line list.
if [[ -z "$CALLERS" ]]; then
    echo "check_sovereign_choke_point: no auditTurn callers found." >&2
    echo "  (expected exactly one in QinaoRuntime.sendSession)" >&2
    exit 1
fi

# Allowed caller: QinaoRuntime.sendSession — one site only.
ALLOWED_FILE="QinaoRuntimeSDK/Sources/QinaoRuntime/QinaoRuntime.swift"
ALLOWED_COUNT=$(printf '%s\n' "$CALLERS" \
    | grep -c "$ALLOWED_FILE" || true)
TOTAL_COUNT=$(printf '%s\n' "$CALLERS" | wc -l | tr -d ' ')

UNEXPECTED=$(printf '%s\n' "$CALLERS" \
    | grep -v "$ALLOWED_FILE" || true)

VIOLATIONS=0

if [[ "$ALLOWED_COUNT" -ne 1 ]]; then
    echo "check_sovereign_choke_point: expected EXACTLY 1 auditTurn" \
        "caller in $ALLOWED_FILE, found $ALLOWED_COUNT:" >&2
    printf '%s\n' "$CALLERS" | grep "$ALLOWED_FILE" >&2 || true
    VIOLATIONS=$((VIOLATIONS + 1))
fi

if [[ -n "$UNEXPECTED" ]]; then
    echo "check_sovereign_choke_point: forbidden auditTurn caller(s)" \
        "outside sendSession:" >&2
    printf '%s\n' "$UNEXPECTED" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
    echo "" >&2
    echo "check_sovereign_choke_point: $VIOLATIONS violation(s)." >&2
    echo "  L14 turn audit must flow through exactly one choke-point:" >&2
    echo "  QinaoRuntime.sendSession. Add your call there (or expose" >&2
    echo "  the needed capability via sendSession) rather than calling" >&2
    echo "  auditTurn directly." >&2
    exit 1
fi

echo "check_sovereign_choke_point: clean — $TOTAL_COUNT caller(s)," \
    "all in $ALLOWED_FILE."
exit 0
