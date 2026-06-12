#!/usr/bin/env bash
# scripts/run-dual-device-parallel.sh
# TWO iPhone Air devices in PARALLEL — max device data in one 10h wall-clock sitting, cooling RELAXED.
#
# With two phones the thermal constraint loosens (a hot device has a sibling; throttling is itself the
# sustained-load envelope). So this orchestrator runs both phones at once with a LOW cooldown and, by
# default, SPLITS the models across devices so each model gets the WHOLE ~10h window (vs 5h each on one
# phone):
#
#   MODE=split (default):  device A = Llama-3.2-3B full sweep    (SWEEP_MODELS=llama, SCALE=2.0 ⇒ ~10h)
#                          device B = Gemma-4-E4B  full sweep    (SWEEP_MODELS=e4b,   SCALE=2.0 ⇒ ~10h)
#       → 2× time per model: denser KV/maxKV/governor A/B per model + longer baselines. Best for BREADTH.
#
#   MODE=parity:           BOTH devices run the SAME full dual-model sweep (SWEEP_MODELS=both, SCALE=1.0)
#       → 2-device parity for EVERY config (cross-device variance / cert-grade confidence). Best for CONFIDENCE.
#
# Relaxed cooling: COOLDOWN_BASE defaults to 0 (full-send, no thermal floors). The sweep auto-derives
# STALL_SEC = max(base*3+120, 300) + 180 ⇒ 480s at base 0, so a legitimate cooldown is never mistaken for
# a wedge while wedge detection stays tight. (Override COOLDOWN_BASE=N to reintroduce a floor.)
#
# Usage:
#   DEVICE_B=<udid> BUILD=1 bash scripts/run-dual-device-parallel.sh           # split (default), build both
#   DEVICE_B=<udid> MODE=parity bash scripts/run-dual-device-parallel.sh        # cross-device parity
#   DEVICE_A=<udid> DEVICE_B=<udid> SCALE=0.1 bash scripts/run-dual-device-parallel.sh   # ~1h dry-run of both
#
# Get the two UDIDs: xcrun devicectl list devices
# PRE-FLIGHT (each phone): UNLOCKED + Auto-Lock=Never + charging + dev cert trusted.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_A="${DEVICE_A:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"
DEVICE_B="${DEVICE_B:-}"
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
BUILD="${BUILD:-0}"
MODE="${MODE:-split}"
# Thermal RELAXED HARD (2026-06-12, operator "烫一点没关系"): base=0 ⇒ NO cooldown in the cool/fair band
# (max inferences when not hot). ADAPTIVE=1 keeps the MEASURED serious≥180s/critical≥300s recovery floors
# (ch1025.11: below them the device gets zero recovery and just throttles — dropping them yields throttled
# data, not more). Set ADAPTIVE=0 for true full-send (flat base, no floors) to characterize the throttle
# envelope on purpose.
COOLDOWN_BASE="${COOLDOWN_BASE:-0}"
ADAPTIVE="${ADAPTIVE:-1}"
SWEEP="${SWEEP:-${REPO_ROOT}/scripts/run-iphone-air-dual-model-sweep.sh}"
STAMP="$(date +%Y%m%d-%H%M%S)"

# --- validate the two distinct devices ---
if [ -z "${DEVICE_B}" ]; then
    echo "ERROR: set DEVICE_B=<second-udid>. List devices: xcrun devicectl list devices" >&2
    exit 2
fi
if [ "${DEVICE_A}" = "${DEVICE_B}" ]; then
    echo "ERROR: DEVICE_A and DEVICE_B are identical (${DEVICE_A}). Two DISTINCT phones required." >&2
    exit 2
fi

# --- per-mode model assignment + scale ---
case "${MODE}" in
    split)
        A_MODELS="llama"; B_MODELS="e2b"   # E2B (not E4B): E4B single-model + full substrate jetsams (2026-06-12)
        SCALE="${SCALE:-2.0}"   # one model fills ~10h (its phases sum to ~300m × 2.0)
        ;;
    parity)
        A_MODELS="both"; B_MODELS="both"
        SCALE="${SCALE:-1.0}"   # the full 600m dual-model sweep on each device
        ;;
    *)
        echo "ERROR: MODE must be 'split' or 'parity' (got '${MODE}')" >&2
        exit 2
        ;;
esac

ARCHIVE_A="${REPO_ROOT}/Docs/cert-logs/dual-device-${STAMP}/deviceA-${A_MODELS}"
ARCHIVE_B="${REPO_ROOT}/Docs/cert-logs/dual-device-${STAMP}/deviceB-${B_MODELS}"
LOG_A="${REPO_ROOT}/Docs/cert-logs/dual-device-${STAMP}/deviceA.stdout.log"
LOG_B="${REPO_ROOT}/Docs/cert-logs/dual-device-${STAMP}/deviceB.stdout.log"
mkdir -p "${ARCHIVE_A%/*}"

echo "=================================================================="
echo "BAS DUAL-DEVICE PARALLEL — mode=${MODE}  scale=${SCALE}  cooldown_base=${COOLDOWN_BASE}s  adaptive=${ADAPTIVE} (0=full-send, no thermal floors)"
echo "  device A ${DEVICE_A}  models=${A_MODELS}  → ${ARCHIVE_A}"
echo "  device B ${DEVICE_B}  models=${B_MODELS}  → ${ARCHIVE_B}"
echo "=================================================================="

# Keep the Mac awake for the whole window (it drives both devices).
caffeinate -dimsu &
CAFFEINATE_PID=$!
cleanup() { kill "${CAFFEINATE_PID}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# Build + install ONCE to both devices (the per-device sweeps then run BUILD=0).
if [ "${BUILD}" = "1" ]; then
    echo "Building ${SCHEME} once ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_A}" \
        -allowProvisioningUpdates build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_A}" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    for D in "${DEVICE_A}" "${DEVICE_B}"; do
        echo "Installing to ${D} ..."
        xcrun devicectl device install app --device "${D}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
    done
fi

# Launch both per-device sweeps in the background (each is its own caffeinate-free child — BUILD=0).
echo "Launching device A sweep (background) → ${LOG_A}"
SWEEP_MODELS="${A_MODELS}" SCALE="${SCALE}" COOLDOWN_BASE="${COOLDOWN_BASE}" ADAPTIVE="${ADAPTIVE}" \
  DEVICE_ID="${DEVICE_A}" BUNDLE_ID="${BUNDLE_ID}" BUILD=0 \
  ARCHIVE_ROOT="${ARCHIVE_A}" \
  bash "${SWEEP}" > "${LOG_A}" 2>&1 &
PID_A=$!

echo "Launching device B sweep (background) → ${LOG_B}"
SWEEP_MODELS="${B_MODELS}" SCALE="${SCALE}" COOLDOWN_BASE="${COOLDOWN_BASE}" ADAPTIVE="${ADAPTIVE}" \
  DEVICE_ID="${DEVICE_B}" BUNDLE_ID="${BUNDLE_ID}" BUILD=0 \
  ARCHIVE_ROOT="${ARCHIVE_B}" \
  bash "${SWEEP}" > "${LOG_B}" 2>&1 &
PID_B=$!

echo ""
echo "Both sweeps running. Tail live:  tail -f ${LOG_A}   (and ${LOG_B})"
echo "Waiting for both to finish ..."
wait "${PID_A}"; RC_A=$?
wait "${PID_B}"; RC_B=$?

echo ""
echo "=================================================================="
echo "DUAL-DEVICE PARALLEL COMPLETE"
echo "  device A (${A_MODELS}) rc=${RC_A}  data: ${ARCHIVE_A}"
echo "  device B (${B_MODELS}) rc=${RC_B}  data: ${ARCHIVE_B}"
echo "  stdout logs: ${LOG_A} , ${LOG_B}"
echo "Analyze per Docs/TEN_HOUR_DUAL_MODEL_RUNBOOK.md §Analysis (per device × per phase)"
echo "=================================================================="
