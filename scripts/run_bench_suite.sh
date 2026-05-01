#!/usr/bin/env bash
# M371 chapter 八十四 — wrapper that runs the QinaoSampleHost
# bench suite against the committed baselines at
# `bench-baselines/`. Exits non-zero on regression beyond the
# default 25% tolerance (or whatever QINAO_BENCH_TOLERANCE is
# set to in the env).
#
# Usage:
#   bash scripts/run_bench_suite.sh                    # full suite, fail on regression
#   bash scripts/run_bench_suite.sh --tolerance 0.10   # tighter 10% tolerance
#   bash scripts/run_bench_suite.sh --no-regression-fail  # report-only mode
#   bash scripts/run_bench_suite.sh --update-baselines  # rewrite baselines (CI bootstrap)
#
# Outputs:
#   - per-bench banner with cold/warm split
#   - markdown table at the end (consolidated suite report)
#   - exit 0 on within-tolerance, 3 on regression, 4 on incompatible
#     baseline, 1 on script-level error.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIR="${REPO_ROOT}/bench-baselines"
QINAO_PKG="${REPO_ROOT}/QinaoRuntimeSDK"

# Defaults — tunable via env or CLI.
TOLERANCE="${QINAO_BENCH_TOLERANCE:-0.25}"
WRITE_MISSING=""
NO_FAIL=""
UPDATE_BASELINES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tolerance)
            TOLERANCE="$2"
            shift 2
            ;;
        --no-regression-fail)
            NO_FAIL="1"
            shift
            ;;
        --update-baselines)
            UPDATE_BASELINES="1"
            shift
            ;;
        --help|-h)
            sed -n '2,17p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if [[ "${UPDATE_BASELINES}" == "1" ]]; then
    echo "[bench-suite] update-baselines mode: writing fresh baselines"
    export QINAO_BENCH_WRITE_MISSING_BASELINE=1
fi

export QINAO_BENCH_BASELINE_DIR="${BASELINE_DIR}"
export QINAO_BENCH_TOLERANCE="${TOLERANCE}"

mkdir -p "${BASELINE_DIR}"

# Each bench mode runs against its own baseline file; auto-compare
# fires per bench. Failure modes (exit 3 / 4) propagate from the
# bench runner. Wrap each in `|| true` when --no-regression-fail
# so we collect all results before exiting.

run_bench() {
    local mode="$1"
    shift
    echo ""
    echo "════════ ${mode} ════════"
    if [[ "${NO_FAIL}" == "1" ]]; then
        swift run --package-path "${QINAO_PKG}" \
            QinaoSampleHost "${mode}" "$@" || true
    else
        swift run --package-path "${QINAO_PKG}" \
            QinaoSampleHost "${mode}" "$@"
    fi
}

# Run each bench at its committed sample size (env vars override).
# Sample sizes match what the baselines were captured at —
# changing the size invalidates the baseline.
run_bench --lifecycle-bench
run_bench --sha256-bench
run_bench --json-codec-bench
QINAO_BENCH_LEDGER_ENTRY_COUNT="${QINAO_BENCH_LEDGER_ENTRY_COUNT:-1000}" \
    run_bench --audit-ledger-bench
QINAO_BENCH_FULL_STACK_SESSIONS="${QINAO_BENCH_FULL_STACK_SESSIONS:-10}" \
    run_bench --full-stack-bench

echo ""
echo "════════ bench-suite consolidated report ════════"
run_bench --bench-suite

echo ""
echo "[bench-suite] all benches completed"
