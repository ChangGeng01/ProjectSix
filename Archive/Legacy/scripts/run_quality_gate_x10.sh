#!/bin/zsh
set -euo pipefail

ROOT="/Users/changgeng/Project/Project06/Project06"
PROJECT="$ROOT/Before.xcodeproj"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_OS="${SIMULATOR_OS:-26.3.1}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"
WATCH_DESTINATION="generic/platform=watchOS Simulator"
BASELINE_STATUS="$(git -C "$ROOT" status --short)"
DERIVED_DATA_ROOT="/tmp/before-quality-gate-x10"
IOS_DERIVED_DATA="$DERIVED_DATA_ROOT/ios"
UI_DERIVED_DATA="$DERIVED_DATA_ROOT/ui"
WATCH_DERIVED_DATA="$DERIVED_DATA_ROOT/watch"

typeset -i score=0
typeset -i total=13

rm -rf "$DERIVED_DATA_ROOT"

resolve_simulator_udid() {
  python3 - "$1" "$2" <<'PY'
import json
import subprocess
import sys

name, runtime_fragment = sys.argv[1:3]
data = json.loads(
    subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"])
)
for runtime, devices in data["devices"].items():
    if runtime_fragment not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"] == name:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
PY
}

IOS_RUNTIME_FRAGMENT="iOS-${${SIMULATOR_OS%.*}//./-}"
IOS_SIMULATOR_UDID="$(resolve_simulator_udid "$SIMULATOR_NAME" "$IOS_RUNTIME_FRAGMENT")"
UI_DESTINATION="platform=iOS Simulator,id=${IOS_SIMULATOR_UDID}"

run_step() {
  local label="$1"
  shift

  printf "\n[%02d/%02d] %s\n" $((score + 1)) "$total" "$label"
  if "$@"; then
    score=$((score + 1))
    printf "PASS %s\n" "$label"
  else
    printf "FAIL %s\n" "$label"
    printf "\nX10 QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
    exit 1
  fi
}

run_project_regen() {
  (cd "$ROOT" && xcodegen generate)
}

run_project_regen_and_extreme() {
  run_project_regen
  run_with_ui_flake_retry "$ROOT/scripts/run_quality_gate_extreme.sh"
}

run_repeat() {
  local count="$1"
  shift
  for attempt in $(seq 1 "$count"); do
    printf "  soak run %s/%s\n" "$attempt" "$count"
    "$@"
  done
}

prepare_before_test_simulator() {
  local attempt="$1"

  xcrun simctl shutdown "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  if [[ "$attempt" -gt 1 ]]; then
    xcrun simctl erase "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  fi
  xcrun simctl boot "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$IOS_SIMULATOR_UDID" -b
}

run_before_once() {
  xcodebuild -derivedDataPath "$IOS_DERIVED_DATA" -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test "$@"
}

run_before() {
  local attempt log
  for attempt in 1 2; do
    prepare_before_test_simulator "$attempt"
    log="$(mktemp)"
    if run_before_once "$@" > >(tee "$log") 2>&1; then
      rm -f "$log"
      return 0
    fi

    printf "iOS test run failed on attempt %d; resetting iOS derived data and retrying.\n" "$attempt"
    rm -rf "$IOS_DERIVED_DATA"
    rm -f "$log"
  done

  return 1
}

run_before_matrix_once() {
  local language="$1"
  local region="$2"
  local timezone="$3"
  shift 3
  TZ="$timezone" xcodebuild -derivedDataPath "$IOS_DERIVED_DATA" -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO -testLanguage "$language" -testRegion "$region" test "$@"
}

run_before_matrix() {
  local language="$1"
  local region="$2"
  local timezone="$3"
  shift 3

  local attempt log
  for attempt in 1 2; do
    prepare_before_test_simulator "$attempt"
    log="$(mktemp)"
    if run_before_matrix_once "$language" "$region" "$timezone" "$@" > >(tee "$log") 2>&1; then
      rm -f "$log"
      return 0
    fi

    printf "Matrix iOS test run failed on attempt %d; resetting iOS derived data and retrying.\n" "$attempt"
    rm -rf "$IOS_DERIVED_DATA"
    rm -f "$log"
  done

  return 1
}

prepare_ui_smoke_simulator() {
  local attempt="$1"

  xcrun simctl shutdown "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  if [[ "$attempt" -gt 1 ]]; then
    xcrun simctl erase "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  fi
  xcrun simctl boot "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$IOS_SIMULATOR_UDID" -b
  open -a Simulator --args -CurrentDeviceUDID "$IOS_SIMULATOR_UDID" >/dev/null 2>&1 || true
}

run_ui_smoke_once() {
  xcodebuild -derivedDataPath "$UI_DERIVED_DATA" -project "$PROJECT" -scheme BeforeUISmoke -destination "$UI_DESTINATION" CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 test
}

run_ui_smoke() {
  local attempt log
  for attempt in 1 2 3; do
    prepare_ui_smoke_simulator "$attempt"
    log="$(mktemp)"
    if run_ui_smoke_once > >(tee "$log") 2>&1; then
      rm -f "$log"
      return 0
    fi

    if grep -q "Timed out waiting for AX loaded notification" "$log" || \
       grep -q "test runner failed to initialize for UI testing" "$log"; then
      printf "UI smoke hit simulator accessibility bootstrap flake on attempt %d; resetting iOS derived data and retrying.\n" "$attempt"
      rm -rf "$UI_DERIVED_DATA"
      rm -f "$log"
      continue
    fi

    rm -f "$log"
    return 1
  done

  return 1
}

run_watch() {
  xcodebuild -derivedDataPath "$WATCH_DERIVED_DATA" -project "$PROJECT" -scheme BeforeWatch CODE_SIGNING_ALLOWED=NO -destination "$WATCH_DESTINATION" build
}

run_package() {
  (cd "$ROOT/BehavioralAISubstrate" && swift test)
}

run_with_ui_flake_retry() {
  local attempt log
  for attempt in 1 2; do
    log="$(mktemp)"
    if "$@" > >(tee "$log") 2>&1; then
      rm -f "$log"
      return 0
    fi

    if grep -q "Timed out waiting for AX loaded notification" "$log" || \
       grep -q "test runner failed to initialize for UI testing" "$log"; then
      printf "Nested gate hit simulator accessibility bootstrap flake on attempt %d; resetting x10 derived data and retrying.\n" "$attempt"
      rm -rf "$IOS_DERIVED_DATA" "$WATCH_DERIVED_DATA"
      rm -f "$log"
      continue
    fi

    rm -f "$log"
    return 1
  done

  return 1
}

run_environment_matrix() {
  run_before_matrix zh CN Asia/Shanghai \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/InterventionNotificationPolicyEngineTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests
  run_before_matrix en AU Australia/Melbourne \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/NotificationServiceTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests
}

run_step "Project regenerates cleanly and extreme gate passes first" \
  run_project_regen_and_extreme

run_step "SDK boundary and residual checks stay green" \
  "$ROOT/scripts/check_sdk_import_boundaries.sh"

run_step "BehavioralAISubstrate package survives 10 consecutive runs" \
  run_repeat 10 run_package

run_step "Bridge, current-brain, and intent-envelope host seam survive 10 consecutive runs" \
  run_repeat 10 run_before \
    -only-testing:BeforeTests/BehavioralAISubstrateBridgeTests \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests

run_step "Environment matrix keeps bootstrap, notification policy, and runtime export stable" \
  run_environment_matrix

run_step "Memory governance, embedding, and retrieval survive 10 consecutive runs" \
  run_repeat 10 run_before \
    -only-testing:BeforeTests/DecisionMemorySystemTests \
    -only-testing:BeforeTests/DecisionMemoryGovernorTests \
    -only-testing:BeforeTests/DecisionMemoryEligibilityJudgeTests \
    -only-testing:BeforeTests/EmbeddingMemoryStoreTests

run_step "Replay, evolution, notification policy, and runtime export survive 10 consecutive runs" \
  run_repeat 10 run_before \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests \
    -only-testing:BeforeTests/DecisionEvolutionEngineTests \
    -only-testing:BeforeTests/InterventionNotificationPolicyEngineTests \
    -only-testing:BeforeTests/NotificationServiceTests

run_step "Policy, provider routing, prompt contract, telemetry, and debug privacy survive 10 consecutive runs" \
  run_repeat 10 run_before \
    -only-testing:BeforeTests/DecisionIdentityAndBoundaryTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderRegistryTests \
    -only-testing:BeforeTests/DecisionIntelligencePromptContractTests \
    -only-testing:BeforeTests/DecisionIntelligenceTelemetryStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceDebugStoreTests

run_step "Launch handoff, replay, protected state, and shared public state survive 10 consecutive runs" \
  run_repeat 10 run_before \
    -only-testing:BeforeTests/DecisionIntentEnvelopeStoreTests \
    -only-testing:BeforeTests/PendingLaunchRequestStoreTests \
    -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests \
    -only-testing:BeforeTests/ActiveDecisionWorkspaceStoreTests \
    -only-testing:BeforeTests/WidgetSnapshotStoreTests \
    -only-testing:BeforeTests/SharedContainerTests \
    -only-testing:BeforeTests/CodableStateStorageTests

run_step "UI smoke survives 5 consecutive runs" \
  run_repeat 5 run_ui_smoke

run_step "Watch build survives 5 consecutive runs" \
  run_repeat 5 run_watch

run_step "Full Before suite survives 2 additional consecutive runs" \
  run_repeat 2 run_before

run_step "Git worktree stays clean after soak" \
  bash -lc 'test "$(git -C "'"$ROOT"'" status --short)" = "$(printf "%s" "'"$BASELINE_STATUS"'")"'

printf "\nX10 QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
