#!/usr/bin/env bash
# scripts/purge-device-test-models.sh
#
# The "删掉" recipe — surgically remove the 2026-06-22 decode-TEST models staged under the device's
# Documents/models/ (devicectl has NO per-file delete, so this drives the in-app BASModelPurgeProbe,
# BAS_PURGE_TEST_MODELS=1). Allowlist-only: deletes the 5 named test-model subdirs (mxfp4, g128,
# Granite-H-Micro, Granite-H-Tiny, Llama-1B) + the loose root-orphan files whose names are in the
# probe's orphanFileAllowlist; NEVER touches other subdirs (the pre-existing 3bit + gemma-e4b).
# Pairs with scripts/restage-decode-test-models.sh (STAGE=1) — everything removed is re-stageable,
# so this is fully reversible.
#
# Usage:
#   bash scripts/purge-device-test-models.sh                 # DRYRUN (lists what WOULD be deleted; deletes nothing)
#   PURGE=1 bash scripts/purge-device-test-models.sh         # ACTUALLY delete (BAS_PURGE_DRYRUN=0)
#   PURGE=1 KEEP_ORPHANS=1 bash scripts/purge-device-test-models.sh   # delete only the 5 named subdirs, keep orphans
#   BUILD=1 bash scripts/purge-device-test-models.sh         # rebuild+install the app first
#
# Env: DEVICE_ID, BUNDLE_ID, PURGE (0/1), KEEP_ORPHANS (0/1), BUILD (0/1).

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
PROJECT="DeviceTestApp/BASDeviceTest.xcodeproj"
SCHEME="BASDeviceTestApp"
PURGE="${PURGE:-0}"; KEEP_ORPHANS="${KEEP_ORPHANS:-0}"; BUILD="${BUILD:-0}"

BETA="/Applications/Xcode.app/Contents/Developer"
for x in /Applications/Xcode-beta.app /Applications/Xcode.app; do
    [ -d "$x/Contents/Developer" ] && BETA="$x/Contents/Developer" && break
done
XR() { env DEVELOPER_DIR="$BETA" xcrun "$@"; }

if [ "$BUILD" = "1" ]; then
    echo "Building + installing ${SCHEME} ..."
    XR xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=${DEVICE_ID}" -allowProvisioningUpdates build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3
    APP="$(XR xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=${DEVICE_ID}" -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    XR devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1 | grep -iE "App installed|error" | tail -1
fi

# DRYRUN unless PURGE=1; KEEP_ORPHANS=1 disables the root-orphan pass.
DRY=$([ "$PURGE" = "1" ] && echo 0 || echo 1)
ORPH=$([ "$KEEP_ORPHANS" = "1" ] && echo 0 || echo 1)
echo "=============================================="
echo "Device: ${DEVICE_ID}   dryrun=${DRY}  purgeOrphans=${ORPH}"
[ "$DRY" = "1" ] && echo "MODE: DRYRUN (nothing will be deleted)" || echo "MODE: ⚠️  REAL DELETE"
echo "=============================================="

ENV_JSON="{\"BAS_ENDURANCE_AUTOSTART\":\"1\",\"BAS_PURGE_TEST_MODELS\":\"1\",\"BAS_PURGE_DRYRUN\":\"${DRY}\",\"BAS_PURGE_ROOT_ORPHANS\":\"${ORPH}\"}"
XR devicectl device process launch --terminate-existing --device "$DEVICE_ID" \
    --environment-variables "$ENV_JSON" "$BUNDLE_ID" 2>&1 | grep -iq "Launched" \
    || { echo "ABORT: launch failed (device locked? re-pair?)."; exit 3; }

# Poll for the model-purge log (info-files; no model pull) and print it.
PULL="$(mktemp -d /tmp/bas-purge.XXXXXX)"
STAMP="$(date +%Y%m%d)"
for i in $(seq 1 18); do
    sleep 8
    NEW="$(XR devicectl device info files --device "$DEVICE_ID" --domain-type appDataContainer \
        --domain-identifier "$BUNDLE_ID" --subdirectory Documents --no-recurse --search "model-purge-${STAMP}" 2>/dev/null \
        | grep -oE "model-purge-${STAMP}-[0-9]+\.log" | sort | tail -1)"
    [ -z "$NEW" ] && { echo "poll $i: no log yet"; continue; }
    XR devicectl device copy from --device "$DEVICE_ID" --domain-type appDataContainer \
        --domain-identifier "$BUNDLE_ID" --source "Documents/$NEW" --destination "$PULL/$NEW" >/dev/null 2>&1
    if grep -qE "model-purge DONE" "$PULL/$NEW" 2>/dev/null; then
        echo "----- $NEW -----"; cat "$PULL/$NEW"; exit 0
    fi
    echo "poll $i: running"
done
echo "TIMEOUT — device asleep/locked? unlock + retry."; exit 4
