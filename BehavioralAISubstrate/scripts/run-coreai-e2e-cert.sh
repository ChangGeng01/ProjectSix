#!/usr/bin/env bash
# scripts/run-coreai-e2e-cert.sh — Core AI run-cert driver: the shadow parity probe (Core AI candidate vs
# CoreML incumbent context-classifier) on an iOS 27 RUNTIME. Two modes:
#
#   MODE=sim     (default) — boots the iOS 27.0 simulator, builds the DeviceTestApp with the Xcode 27 BETA
#                toolchain (canImport(CoreAI) true), installs + launches with BAS_COREAI_E2E=1, reads the
#                📊 coreai-e2e lines from `simctl launch --console-pty` capture.
#   MODE=device  — same flow against the physical iPhone Air (must be on iOS 27, unlocked); mirrors
#                scripts/run-device-app-cert.sh (fresh-log polling, asleep detection).
#
# Verdict: PASS iff `coreai-e2e available=true` AND ≥1 `coreai-e2e text=` parity line AND a final verdict line.
# `available=false reason=…` is an HONEST FAIL (prints the reason — e.g. missing .aimodel, OS<27, no-CoreAI build).
#
# Prereqs: Xcode 27 beta installed; for a real inference the .aimodel must exist
# (scripts/coreai-build-aimodel.sh) and be wired in Package.swift.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="${MODE:-sim}"
BETA_DEVELOPER_DIR="${BETA_DEVELOPER_DIR:-/Users/changgeng/Downloads/Xcode-beta.app/Contents/Developer}"
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
ENV_JSON='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_COREAI_E2E":"1"}'
DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"   # any iOS 27.0 sim device
SIM_RUNTIME="${SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"

[ -d "$BETA_DEVELOPER_DIR" ] || { echo "❌ Xcode 27 beta not found at $BETA_DEVELOPER_DIR"; exit 2; }

echo "=============================================="
echo "Core AI run-cert (shadow parity probe)"
echo "Mode      : $MODE"
echo "Toolchain : $BETA_DEVELOPER_DIR (Xcode 27 — canImport(CoreAI) true)"
echo "Env       : $ENV_JSON"
echo "=============================================="

parse_verdict() {  # $1 = file with captured 📊 lines
    echo ""
    echo "=== coreai-e2e lines ==="
    grep -aE "coreai-e2e" "$1" | sed 's/^/  /' || true
    echo ""
    if grep -aq "coreai-e2e available=false" "$1"; then
        echo "RESULT: HONEST-FAIL — Core AI probe reports unavailable:"
        grep -a "coreai-e2e available=false" "$1" | head -1 | sed 's/^/  /'
        return 1
    fi
    if grep -aq "coreai-e2e available=true" "$1" \
       && grep -aqE "coreai-e2e text=[0-9]+ incumbent=" "$1" \
       && grep -aq "coreai-e2e verdict agree=" "$1"; then
        echo "RESULT: PASS — Core AI ran a REAL inference; parity lines above (record them in the cert doc)."
        return 0
    fi
    echo "RESULT: FAIL — probe started but did not complete (no verdict line). Inspect the capture: $1"
    return 1
}

if [ "$MODE" = "sim" ]; then
    # ---- iOS 27 SIMULATOR flow ------------------------------------
    XCRUN="env DEVELOPER_DIR=$BETA_DEVELOPER_DIR xcrun"
    # (1) find-or-create an iOS 27.0 sim device
    UDID="$($XCRUN simctl list devices "$SIM_RUNTIME" 2>/dev/null | grep -E "$SIM_NAME \(" | head -1 \
            | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
    if [ -z "${UDID}" ]; then
        echo "Creating iOS 27.0 sim '$SIM_NAME' …"
        DEVTYPE="$($XCRUN simctl list devicetypes 2>/dev/null | grep -F "$SIM_NAME (" | head -1 \
            | sed -E 's/.*\((com\.apple\.[^)]*)\).*/\1/')"
        UDID="$($XCRUN simctl create "coreai-e2e-$SIM_NAME" "${DEVTYPE:-iPhone 17 Pro}" "$SIM_RUNTIME")" || {
            echo "❌ could not create an iOS 27.0 simulator"; exit 3; }
    fi
    echo "Sim UDID: $UDID"
    $XCRUN simctl boot "$UDID" 2>/dev/null || true   # ok if already booted

    # (2) build for the sim with the BETA toolchain
    echo "Building $SCHEME for the iOS 27 simulator (beta toolchain) …"
    env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "id=$UDID" -derivedDataPath /tmp/bas-coreai-sim-dd build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -8
    APP="$(find /tmp/bas-coreai-sim-dd/Build/Products -maxdepth 2 -name "*.app" -path "*iphonesimulator*" | head -1)"
    [ -n "$APP" ] || { echo "❌ no .app produced — see build errors above"; exit 4; }

    # (3) install + launch with console capture
    $XCRUN simctl install "$UDID" "$APP"
    CAP="$(mktemp /tmp/bas-coreai-sim.XXXXXX.log)"
    echo "Launching with console capture → $CAP"
    $XCRUN simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    env SIMCTL_CHILD_BAS_ENDURANCE_AUTOSTART=1 SIMCTL_CHILD_BAS_COREAI_E2E=1 \
        DEVELOPER_DIR="$BETA_DEVELOPER_DIR" \
        xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID" > "$CAP" 2>&1 &
    LAUNCH_PID=$!
    # The probe is short; give it up to ~120s, polling for the verdict line.
    for i in $(seq 1 24); do
        sleep 5
        grep -aq "coreai-e2e verdict\|coreai-e2e available=false" "$CAP" && break
    done
    kill "$LAUNCH_PID" 2>/dev/null || true
    parse_verdict "$CAP"; exit $?

elif [ "$MODE" = "device" ]; then
    # ---- PHYSICAL iPhone Air flow (mirrors run-device-app-cert.sh) -
    # Pre-flight: confirm the device is on iOS 27 (Core AI floor). devicectl prints the OS in `list devices`.
    OSLINE="$(env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun devicectl list devices 2>/dev/null | grep -i "$DEVICE_ID")"
    echo "Device line: ${OSLINE:-<not found>}"
    echo "Building + installing $SCHEME on the iPhone (beta toolchain) …"
    env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "id=$DEVICE_ID" -allowProvisioningUpdates build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -8
    APP="$(env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "id=$DEVICE_ID" -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1 \
        | grep -iE "installed|error" | tail -2

    # Fresh-log polling flow (the app writes Documents/ch1025-endurance-*.log).
    PULL_DIR="$(mktemp -d /tmp/bas-coreai-dev.XXXXXX)"
    newest_log() {
        rm -rf "$PULL_DIR"; mkdir -p "$PULL_DIR"
        env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun devicectl device copy from --device "$DEVICE_ID" \
            --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
            --source Documents --destination "$PULL_DIR" >/dev/null 2>&1
        find "$PULL_DIR" -type f -name "ch1025-endurance-2026*.log" 2>/dev/null | sort | tail -1
    }
    PRIOR_BASE="$(basename "$(newest_log)" 2>/dev/null || echo none)"
    echo "Baseline newest log: $PRIOR_BASE"
    env DEVELOPER_DIR="$BETA_DEVELOPER_DIR" xcrun devicectl device process launch --terminate-existing \
        --device "$DEVICE_ID" --environment-variables "$ENV_JSON" "$BUNDLE_ID" 2>&1 | grep -i "Launched" \
        || { echo "❌ devicectl launch failed"; exit 3; }
    FRESH=""
    for i in $(seq 1 12); do
        sleep 12
        NEW="$(newest_log)"; BASE="$(basename "${NEW:-none}")"
        if [ -n "$NEW" ] && [ "$BASE" \> "$PRIOR_BASE" ]; then
            FRESH="$NEW"; echo "poll $i: FRESH log $BASE"
            grep -aq "coreai-e2e verdict\|coreai-e2e available=false" "$NEW" 2>/dev/null && break
        else
            echo "poll $i: no fresh log yet"
        fi
    done
    [ -n "$FRESH" ] || { echo "RESULT: NO FRESH LOG — iPhone asleep/locked? Unlock + re-run."; exit 4; }
    parse_verdict "$FRESH"; exit $?

else
    echo "❌ unknown MODE=$MODE (use sim|device)"; exit 2
fi
