#!/usr/bin/env bash
# Mamba-3 trained-graph (+MLP+gnorm, D=1024 int8) per-asset ANE compile-ceiling probe — ONE rung.
# Finds whether L layers compile 100%-ANE or hit ANECCompile() FAILED (partial off-ANE fallback).
# A partial fallback still LOADS + decodes, so the ONLY 100%-ANE-vs-fallback signal is the ANECCompile() FAILED
# string in the device system log — captured here via `log stream` in parallel with the --console process output.
# Usage: run-mamba3-ane-ladder.sh <L> [steps] [timeout_s]
set -uo pipefail
L="${1:?usage: run-mamba3-ane-ladder.sh <L> [steps] [timeout_s] [asset_name]}"
STEPS="${2:-32}"; TMO="${3:-150}"; ASSET_OVERRIDE="${4:-}"
DEV=9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6
BUNDLE=com.changgeng.basdevicetest
REPO=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
for x in /Applications/Xcode-beta.app /Applications/Xcode-27.app /Applications/Xcode.app; do
  [ -d "$x/Contents/Developer" ] && BETA="$x/Contents/Developer" && break
done
XR() { env DEVELOPER_DIR="$BETA" xcrun "$@"; }
ASSET="${ASSET_OVERRIDE:-Mamba3Deploy_L${L}_int8.aimodel}"; SRC="/tmp/draft_coreai/$ASSET"

if [ -n "$ASSET_OVERRIDE" ] && [ ! -d "$SRC" ]; then echo "L=$L VERDICT=ASSET_MISSING ($SRC)"; exit 2; fi
if [ -z "$ASSET_OVERRIDE" ] && [ ! -d "$SRC" ]; then
  echo ">> building $ASSET (random weights = op-graph compile probe)…"
  ( cd "$REPO" && FORCE_RANDOM=1 uv run --with coreai-torch python Tools/mamba3_deploy.py "$L" 8 ) \
    || { echo "L=$L VERDICT=BUILD_FAIL"; exit 2; }
fi
ST="${L},16,32;${L},16,64,64;${L},16,4,64;${L},16,64,4"   # angle;ssm;kprev;vprev (H16 P64 N64 R4)

echo ">> staging $ASSET → Documents (dir + explicit main.mlirb)…"
XR devicectl device copy to --device "$DEV" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
   --source "$SRC" --destination "Documents/$ASSET" >/dev/null 2>&1
XR devicectl device copy to --device "$DEV" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
   --source "$SRC/main.mlirb" --destination "Documents/$ASSET/main.mlirb" >/dev/null 2>&1

CAP="/tmp/mamba3_ladder_L${L}.log"; SYS="/tmp/mamba3_ladder_L${L}.syslog"; : > "$CAP"; : > "$SYS"
# ANECCompile() FAILED is emitted to the DEVICE os_log (NOT the process stdout that --console captures), so stream
# the device syslog via idevicesyslog in parallel — start it BEFORE the launch so it catches the load-time compile.
UDID="$(idevice_id -l 2>/dev/null | head -1)"
# line-buffered so matches flush to the file before we kill it; broad ANE-compiler pattern
( idevicesyslog ${UDID:+-u "$UDID"} 2>/dev/null \
  | grep --line-buffered -iE "ANECompiler|ANECCompile|aned|Espresso|ANEServices|H11ANE|com.apple.ane|neuralengine" > "$SYS" ) &
SYSPID=$!
sleep 3                                                   # let idevicesyslog connect+stream BEFORE the load-time compile
ENV_JSON="{\"BAS_ENDURANCE_AUTOSTART\":\"1\",\"BAS_COREAI_MAMBA3_PROBE\":\"1\",\"BAS_COREAI_MAMBA3_ASSET\":\"$ASSET\",\"BAS_COREAI_MAMBA3_UNITS\":\"ane\",\"BAS_COREAI_MAMBA3_STEPS\":\"$STEPS\",\"BAS_COREAI_MAMBA3_STATES\":\"$ST\"}"
echo ">> launching probe L=$L (steps=$STEPS, ane, timeout ${TMO}s)…"
XR devicectl device process launch --terminate-existing --console --device "$DEV" \
   --environment-variables "$ENV_JSON" "$BUNDLE" > "$CAP" 2>&1 &
LP=$!
for _ in $(seq 1 "$TMO"); do
  grep -qE "mamba3 DONE|mamba3 ERROR=|ERROR unit=ane|DECODE ERROR|WARMUP ERROR" "$CAP" 2>/dev/null && break
  sleep 1
done
sleep 3; kill "$LP" 2>/dev/null; kill "$SYSPID" 2>/dev/null

echo "===== L=$L  app markers ====="; grep -E "🐍" "$CAP" | sed 's/^/  /'
echo "===== L=$L  device ANE syslog ($(wc -l < "$SYS") lines captured; first 12) ====="; head -12 "$SYS" | sed 's/^/  /'
ANEC=$( grep -ciE "ANE cannot handle|Failed to create unit plist|ANECCompile\(\) FAILED|ANECCompile.*FAIL" "$SYS" "$CAP" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}' )
ANEACT=$( grep -ciE "ANECompiler|ANECCompile|aned" "$SYS" 2>/dev/null )
LOADED=$( grep -ciE "mamba3 loaded unit=ane" "$CAP" )
HARDERR=$( grep -ciE "mamba3 ERROR unit=ane|did NOT compile" "$CAP" )
if   [ "$HARDERR" -gt 0 ];   then V="HARD_FAIL (did not load on ANE)"
elif [ "$LOADED" -eq 0 ];    then V="NO_LOAD (timeout/crash before load marker)"
elif [ "$ANEC" -gt 0 ];      then V="PARTIAL_FALLBACK (ANECCompile FAILED — NOT 100%-ANE)"
elif [ "${ANEACT:-0}" -eq 0 ]; then V="UNDETERMINED (loaded, but syslog caught NO ANE-compiler activity — likely a CACHE HIT; detection blind)"
else                              V="CLEAN_100%_ANE (loaded, ANE-compiler active, no ANECCompile FAILED)"; fi
echo "L=$L  VERDICT=$V   (ANECCompile-fail-hits=$ANEC, ane-compiler-activity=${ANEACT:-0}, ane-load-markers=$LOADED)"
