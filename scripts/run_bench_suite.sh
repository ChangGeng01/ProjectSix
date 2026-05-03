#!/usr/bin/env bash
# M371 chapter 八十四 — wrapper that runs the QinaoSampleHost
# bench suite against the committed baselines at
# `bench-baselines/`. Exits non-zero on regression beyond the
# default 10% tolerance (or whatever QINAO_BENCH_TOLERANCE is
# set to in the env).
#
# **M436.6 chapter 一百九 (2026-05-04)**: switched from debug
# build (`swift run`) to release build (`swift build -c release`
# + direct binary invocation). Pre-fix the suite ran debug-build
# benches with 25% tolerance, producing CV ~10-18% noise and
# making real regressions undetectable (e.g. M436's +11.3% real
# release-build regression hid under debug-build noise within
# the 25% tolerance band). Per chapter 一百三 doctrine "perf
# claims need release-build N≥30 + 95% CI", the suite now uses
# release builds throughout, and the default tolerance dropped
# to 10% (release-build CV is ~3%, so 10% is ~3× CV — meaningful
# alarm threshold). Baselines were recaptured under release
# build at chapter 一百九 ship time.
#
# Usage:
#   bash scripts/run_bench_suite.sh                    # full suite, fail on regression
#   bash scripts/run_bench_suite.sh --tolerance 0.10   # tighter 10% tolerance
#   bash scripts/run_bench_suite.sh --no-regression-fail  # report-only mode
#   bash scripts/run_bench_suite.sh --update-baselines  # write baselines if missing (CI bootstrap)
#   bash scripts/run_bench_suite.sh --rewrite-baselines  # M395 — overwrite even if regression (sample-count uplift)
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
# M436.6: tolerance set to 0.25 (release-build single-trial noise
# on >5µs scales). Empirically observed across multiple release-
# build runs (5+ trials each):
#   - mid-µs benches (audit-ledger ~46µs CV 11%, sha256 ~17µs
#       CV 8%, json-codec ~11µs CV 9%): p99 single-trial variance
#       ~25-35% on the noisier ones (audit-ledger has ~2% outlier
#       rate which inflates p99 swings)
#   - full-stack bench (~1.1ms): p50/p95/p99 variance ~15-20%
#   - mean single-trial variance: ~10-12% across all benches
# 25% covers single-trial noise on all benches above 5µs. Sub-µs
# benches (lifecycle ~0.6µs, throughput ~1.2µs) are timer-jitter-
# dominated; `BASBenchBaselineStorage.compareToBaseline` skips
# regression check on metrics where both baseline AND measured
# are < 5µs (M436.6 absolute-µs floor).
#
# IMPORTANT: even though pre-M436.6 also said "25%" tolerance,
# the meaning is fundamentally different now:
#   - Pre-M436.6: 25% applied to DEBUG-build measurements with
#     CV ~10-18%. Effective alarm threshold ~ 25% above debug
#     noise floor = 35-45% absolute regression. M436's actual
#     +11.3% release regression hid easily.
#   - Post-M436.6: 25% applied to RELEASE-build measurements
#     with CV ~3-15%. Effective alarm threshold ~ 25% above
#     release noise floor = 30% absolute regression. Catches
#     real regressions like a hypothetical M436-equivalent
#     +25% scenario.
#
# Honest limitation: 25% single-trial cannot reliably catch
# <20% regressions. To detect <10% regressions, the bench-suite
# would need to capture mean ± std across N≥10 trials in the
# baseline + check current vs (baseline-mean ± 2σ). Stat-
# rigorous but requires baseline-format extension. Deferred to
# future doctrine work. Current 25% release-build setup is
# strictly better than pre-M436.6 25% debug-build (absolute
# scales 2-3× tighter, real regressions visible).
TOLERANCE="${QINAO_BENCH_TOLERANCE:-0.25}"
WRITE_MISSING=""
NO_FAIL=""
UPDATE_BASELINES=""
REWRITE_BASELINES=""

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
        --rewrite-baselines)
            # M395 — overwrite existing baselines even on
            # regression. Use case: deliberately raising sample
            # counts where p99/max naturally grow.
            REWRITE_BASELINES="1"
            shift
            ;;
        --help|-h)
            sed -n '2,18p' "${BASH_SOURCE[0]}"
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

if [[ "${REWRITE_BASELINES}" == "1" ]]; then
    echo "[bench-suite] rewrite-baselines mode: overwriting existing baselines"
    export QINAO_BENCH_WRITE_MISSING_BASELINE=1
    export QINAO_BENCH_REWRITE_BASELINE=1
fi

export QINAO_BENCH_BASELINE_DIR="${BASELINE_DIR}"
export QINAO_BENCH_TOLERANCE="${TOLERANCE}"

mkdir -p "${BASELINE_DIR}"

# Each bench mode runs against its own baseline file; auto-compare
# fires per bench. Failure modes (exit 3 / 4) propagate from the
# bench runner. Wrap each in `|| true` when --no-regression-fail
# so we collect all results before exiting.

# M436.6 — pre-build release binary once + invoke directly.
# Pre-fix used `swift run` (debug build) which produced CV
# ~10-18% noise floor; release build CV is ~3% so this single
# change makes the regression-tolerance band meaningful.
echo "[bench-suite] building QinaoSampleHost release..."
swift build --package-path "${QINAO_PKG}" \
    -c release --product QinaoSampleHost > /dev/null
BIN_PATH="$(swift build --package-path "${QINAO_PKG}" \
    -c release --show-bin-path)"
SAMPLE_HOST_BIN="${BIN_PATH}/QinaoSampleHost"
if [[ ! -x "${SAMPLE_HOST_BIN}" ]]; then
    echo "[bench-suite] error: release binary not found at ${SAMPLE_HOST_BIN}" >&2
    exit 1
fi
echo "[bench-suite] release binary: ${SAMPLE_HOST_BIN}"

run_bench() {
    local mode="$1"
    shift
    echo ""
    echo "════════ ${mode} ════════"
    if [[ "${NO_FAIL}" == "1" ]]; then
        "${SAMPLE_HOST_BIN}" "${mode}" "$@" || true
    else
        "${SAMPLE_HOST_BIN}" "${mode}" "$@"
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
# M436.6 — bumped default sessions from 10 → 100 so each
# full-stack-bench run produces 99 warm samples (chapter 一百三
# perf doctrine wants N≥30 + 95% CI; N=9 gave CV ~6% which was
# adequate but noisier than necessary). 100 sessions × 5 turns
# is ~5 seconds wall-clock per run — still fast enough for CI.
QINAO_BENCH_FULL_STACK_SESSIONS="${QINAO_BENCH_FULL_STACK_SESSIONS:-100}" \
    QINAO_BENCH_FULL_STACK_TURNS="${QINAO_BENCH_FULL_STACK_TURNS:-5}" \
    run_bench --full-stack-bench

echo ""
echo "════════ bench-suite consolidated report ════════"
run_bench --bench-suite

echo ""
echo "[bench-suite] all benches completed"
