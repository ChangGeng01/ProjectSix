#!/usr/bin/env bash
# scripts/run-iphone-air-dual-model-sweep.sh
# 10-HOUR UNATTENDED dual-model knob-sweep endurance run on iPhone Air — maximal data for future
# development. Wraps the proven wedge-surviving watchdog (run-endurance-watchdog.sh, ADR-038 §10.2)
# in a PHASE LOOP: each phase = (model, knob-config, minutes), launched as its own watchdog window,
# archived into its own dir. One command; the operator walks away.
#
# WHY A SWEEP (not one flat run): the session's new decode/observation levers (kvBits, maxKVSize, the
# U1 speculation memory governor, the U3 liveness monitor, the ADR-018 shadow-trial carrier) all need
# DEVICE evidence. A sweep produces clean A/B pairs against a per-model baseline in a single 10h sitting.
#
# TWO MODELS (deliberate contrast):
#   A = Llama-3.2-3B (standard arch, NO Gemma-3n wedge, CERTIFIED spec-decode pair 3B↔1B @ 2542MB FITS)
#       → the stable workhorse: clean long-run + spec-decode + governor + the KV-lever sweep.
#   B = Gemma-4-E4B (Gemma-3n arch, the recommended QUALITY default, single-model)
#       → architecture contrast: wedge/thermal/memory under the 512MB cache cap + KV levers on the
#         other arch + the liveness-monitor/watchdog recovery stats that Gemma-3n actually exercises.
#
# PHASE TABLE (600 min = 10h):
#   A1 Llama  baseline                 90m   spec-decode ON, governor armed, observation knobs
#   A2 Llama  +kvBits=4                75m   KV-quant A/B vs A1
#   A3 Llama  +kvBits=8                60m   KV-quant 3-point sweep (off/4/8)
#   A4 Llama  +maxKVSize=512           75m   rotating-KV cap A/B vs A1
#   B1 Gemma  baseline                120m   single-model quality default, observation knobs
#   B2 Gemma  +kvBits=4                90m   KV-quant A/B on Gemma-3n
#   B3 Gemma  +maxKVSize=512           90m   rotating-KV cap A/B on Gemma-3n
#
# OBSERVATION KNOBS ON EVERY PHASE (byte-safe, pure data): liveness monitor, shadow-trial carrier loop,
# sovereign verdict parity. The sovereign per-turn signed ledger, A3 MetricKit field metrics, and the
# P0 phase-split verdict are always-on in the runner. Cooldown is adaptive (base 60s); STALL_SEC is set
# ABOVE the adaptive cooldown ceiling so a legitimate cooldown never reads as a false wedge.
#
# Usage:
#   BUILD=1 bash scripts/run-iphone-air-dual-model-sweep.sh        # build+install once, then sweep
#   bash scripts/run-iphone-air-dual-model-sweep.sh                # app already installed
#   SCALE=0.1 bash scripts/run-iphone-air-dual-model-sweep.sh      # 10% durations — a ~1h smoke of the sweep
#   DEVICE_ID=... bash scripts/run-iphone-air-dual-model-sweep.sh
#
# PRE-FLIGHT (operator, one-time): iPhone UNLOCKED + Auto-Lock=Never + plugged in/charging + dev cert
# trusted. The Mac is kept awake via caffeinate for the whole window.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
BUILD="${BUILD:-0}"
SCALE="${SCALE:-1.0}"            # multiply every phase's minutes (0.1 ⇒ a ~1h dry-run of the full sweep shape)
WATCHDOG="${WATCHDOG:-${REPO_ROOT}/scripts/run-endurance-watchdog.sh}"

STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-${REPO_ROOT}/Docs/cert-logs/dual-model-sweep-${STAMP}}"
MANIFEST="${ARCHIVE_ROOT}/MANIFEST.txt"

# Observation knobs common to every phase (byte-safe, pure data). Trailing comma — concatenated into
# the watchdog's ENV_EXTRA slot. The sovereign ledger / field-metrics / P0 phase-split are always-on.
OBS_KNOBS='"BAS_LIVENESS_MONITOR":"1","BAS_LIVENESS_THRESHOLD_SEC":"30","BAS_SHADOW_TRIAL_LOOP":"1","BAS_SHADOW_PARITY":"enabled",'
# Adaptive-cooldown passthrough (BAS_INTERNAL_ADAPTIVE): 1 = keep the measured serious/critical thermal
# floors; 0 = full-send (flat base, no floors). Appended to the per-phase knobs below.
ADAPTIVE="${ADAPTIVE:-1}"
ADAPTIVE_KNOB='"BAS_INTERNAL_ADAPTIVE":"'"${ADAPTIVE}"'",'

# SWEEP_MODELS selects which phases run: "both" (one device, sequential — the default), "llama" (only the
# A phases), "e4b" (only the B phases). The dual-device parallel orchestrator pins one model per device.
SWEEP_MODELS="${SWEEP_MODELS:-both}"

# THERMAL RELAXATION (2026-06-12): COOLDOWN_BASE is the real "run hotter" lever — it sets the cooldown in
# the cool/fair band (base=0 ⇒ NO cooldown when cool ⇒ max inferences). ADAPTIVE (BAS_INTERNAL_ADAPTIVE)
# keeps the MEASURED thermal floors (serious ≥180s / critical ≥300s, ch1025.11): below them the device
# gets ZERO recovery and just throttles, so dropping the floors yields THROTTLED data, not MORE data —
# keep ADAPTIVE=1 unless you explicitly want to characterize the throttle envelope (ADAPTIVE=0 = flat
# base, no floors, "full send"). STALL_SEC must exceed the LARGEST legitimate cooldown or it false-wedges:
# with ADAPTIVE on, that ceiling is max(base*3+120, 300) (the critical floor dominates at low base); with
# ADAPTIVE off it is just `base`. Plus a 180s decode/poll margin.
COOLDOWN_BASE="${COOLDOWN_BASE:-60}"
if [ "${ADAPTIVE}" = "1" ]; then
    _cool_ceiling=$(( COOLDOWN_BASE * 3 + 120 ))
    [ "${_cool_ceiling}" -lt 300 ] && _cool_ceiling=300
else
    _cool_ceiling="${COOLDOWN_BASE}"
fi
STALL_SEC="${STALL_SEC:-$(( _cool_ceiling + 180 ))}"
MLX_PROMPTS="${MLX_PROMPTS:-3}"
MAX_DECODE_TOKENS="${MAX_DECODE_TOKENS:-256}"

# Phase table: "id|model|minutes|extra-knobs-json-fragment|description". The extra fragment carries a
# TRAILING comma (or is empty); it is concatenated after OBS_KNOBS. Governor armed on the Llama phases
# (byte-safe: greedy spec-decode is token-identical, so a draft drop/restore changes latency only).
GOV='"BAS_SPEC_GOVERNOR":"1",'
PHASES=(
  "A1|llama|90|${GOV}|Llama-3.2-3B baseline (spec-decode ON, governor armed)"
  "A2|llama|75|${GOV}\"BAS_KV_BITS\":\"4\",|Llama +kvBits=4 (KV-quant A/B vs A1)"
  "A3|llama|60|${GOV}\"BAS_KV_BITS\":\"8\",|Llama +kvBits=8 (3-point KV sweep off/4/8)"
  "A4|llama|75|${GOV}\"BAS_MAX_KV_SIZE\":\"512\",|Llama +maxKVSize=512 (rotating-KV A/B vs A1)"
  "B1|e2b|120||Gemma-4-E2B baseline (single-model; E4B+full substrate exceeds the 3376MB jetsam cap — see 2026-06-12 recovery)"
  "B2|e2b|90|\"BAS_KV_BITS\":\"4\",|Gemma-E2B +kvBits=4 (KV-quant A/B on Gemma-3n)"
  "B3|e2b|90|\"BAS_MAX_KV_SIZE\":\"512\",|Gemma-E2B +maxKVSize=512 (rotating-KV A/B)"
)

scaled_minutes() { awk -v m="$1" -v s="${SCALE}" 'BEGIN{v=m*s; if(v<1)v=1; printf "%d", v}'; }

echo "=================================================================="
echo "BAS DUAL-MODEL 10h SWEEP — iPhone Air, max data for future dev"
echo "Device: ${DEVICE_ID}"
echo "Archive root: ${ARCHIVE_ROOT}"
echo "Models: ${SWEEP_MODELS}  Scale: ${SCALE}  STALL_SEC=${STALL_SEC}s  cooldown_base=${COOLDOWN_BASE}s  adaptive=${ADAPTIVE}"
echo "=================================================================="

mkdir -p "${ARCHIVE_ROOT}"

# Keep the Mac awake for the whole window (the watchdog drives the device from here).
caffeinate -dimsu &
CAFFEINATE_PID=$!
cleanup() { kill "${CAFFEINATE_PID}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

if [ "${BUILD}" = "1" ]; then
    echo "Building + installing ${SCHEME} (once for the whole sweep) ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -allowProvisioningUpdates build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
fi

{
    echo "BAS dual-model sweep manifest — ${STAMP}"
    echo "device=${DEVICE_ID} bundle=${BUNDLE_ID} scale=${SCALE} stall_sec=${STALL_SEC} cooldown_base=${COOLDOWN_BASE}"
    echo "common observation knobs: ${OBS_KNOBS}"
    echo ""
    printf "%-4s %-7s %-8s %s\n" "id" "model" "minutes" "description"
} > "${MANIFEST}"

TOTAL_MIN=0
for row in "${PHASES[@]}"; do
    IFS='|' read -r PID MODEL MINS EXTRA DESC <<< "${row}"
    # SWEEP_MODELS filter: a single-model device runs only its own phases.
    if [ "${SWEEP_MODELS}" != "both" ] && [ "${SWEEP_MODELS}" != "${MODEL}" ]; then
        continue
    fi
    MINS="$(scaled_minutes "${MINS}")"
    TOTAL_MIN=$(( TOTAL_MIN + MINS ))
    PHASE_DIR="${ARCHIVE_ROOT}/phase-${PID}"
    printf "%-4s %-7s %-8s %s\n" "${PID}" "${MODEL}" "${MINS}m" "${DESC}" >> "${MANIFEST}"

    echo ""
    echo "── PHASE ${PID} (${MODEL}, ${MINS}min) — ${DESC}"
    echo "   archive → ${PHASE_DIR}"

    MODEL="${MODEL}" \
    MLX_PROMPTS="${MLX_PROMPTS}" \
    COOLDOWN_SEC="${COOLDOWN_BASE}" \
    MAX_DECODE_TOKENS="${MAX_DECODE_TOKENS}" \
    ENV_EXTRA="${OBS_KNOBS}${ADAPTIVE_KNOB}${EXTRA}" \
    ARCHIVE_DIR="${PHASE_DIR}" \
    WATCHDOG_MINUTES="${MINS}" \
    STALL_SEC="${STALL_SEC}" \
    PER_RUN_ITERS="300" \
    DEVICE_ID="${DEVICE_ID}" \
    BUNDLE_ID="${BUNDLE_ID}" \
    bash "${WATCHDOG}" 2>&1 | sed 's/^/   [wd] /'

    echo "   phase ${PID} done — data in ${PHASE_DIR}"
done

echo ""
echo "=================================================================="
echo "SWEEP COMPLETE — planned ${TOTAL_MIN}min across ${#PHASES[@]} phases"
echo "Archive: ${ARCHIVE_ROOT}"
echo "Manifest: ${MANIFEST}"
echo "Per-phase data: phase-A1/ … phase-B3/ (each: ch1025-endurance-*.log, field-metrics.jsonl,"
echo "  bas-sovereign-ledger.sqlite, bas-memory-atoms.sqlite, bas-vector-index.sqlite)"
echo "Analyze: see Docs/TEN_HOUR_DUAL_MODEL_RUNBOOK.md §Analysis"
echo "=================================================================="
