#!/bin/zsh
set -euo pipefail

ROOT="/Users/changgeng/Project/Project06/Project06"
PROJECT="$ROOT/Before.xcodeproj"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-26.3.1}"
WATCH_SIMULATOR_NAME="${WATCH_SIMULATOR_NAME:-Apple Watch Series 11 (46mm)}"
WATCH_SIMULATOR_OS="${WATCH_SIMULATOR_OS:-26.2}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"
WATCH_DESTINATION="${WATCH_DESTINATION:-generic/platform=watchOS Simulator}"
DERIVED_DATA_ROOT="/tmp/before-quality-gate-double"
IOS_DERIVED_DATA="$DERIVED_DATA_ROOT/ios"
UI_DERIVED_DATA="$DERIVED_DATA_ROOT/ui"
WATCH_DERIVED_DATA="$DERIVED_DATA_ROOT/watch"

typeset -i score=0
typeset -i total=41

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
    printf "\nDOUBLE QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
    exit 1
  fi
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

run_before_tests_once() {
  xcodebuild -derivedDataPath "$IOS_DERIVED_DATA" -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test "$@"
}

run_before_tests() {
  local attempt log
  for attempt in 1 2; do
    prepare_before_test_simulator "$attempt"
    log="$(mktemp)"
    if run_before_tests_once "$@" > >(tee "$log") 2>&1; then
      rm -f "$log"
      return 0
    fi

    printf "iOS test run failed on attempt %d; resetting iOS derived data and retrying.\n" "$attempt"
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

run_watch_build() {
  xcodebuild -derivedDataPath "$WATCH_DERIVED_DATA" -project "$PROJECT" -scheme BeforeWatch -destination "$WATCH_DESTINATION" CODE_SIGNING_ALLOWED=NO build
}

run_step "Project generation pass #1" \
  xcodegen generate --spec "$ROOT/project.yml"

run_step "Project generation pass #2" \
  xcodegen generate --spec "$ROOT/project.yml"

run_step "Project metadata listing pass #1" \
  xcodebuild -project "$PROJECT" -list

run_step "Project metadata listing pass #2" \
  xcodebuild -project "$PROJECT" -list

run_step "SDK boundary and residual checks" \
  "$ROOT/scripts/check_sdk_import_boundaries.sh"

run_step "BeforeWatch build pass #1" \
  run_watch_build

run_step "BeforeWatch build pass #2" \
  run_watch_build

run_step "Full Before suite pass #1" \
  run_before_tests

run_step "Full Before suite pass #2" \
  run_before_tests

run_step "UI smoke pass #1" \
  run_ui_smoke

run_step "UI smoke pass #2" \
  run_ui_smoke

run_step "Recovery continuity tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/ActiveDecisionWorkspaceStoreTests \
    -only-testing:BeforeTests/DecisionTaskGraphStoreTests \
    -only-testing:BeforeTests/DecisionRecordRestorationTests

run_step "Recovery continuity tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/ActiveDecisionWorkspaceStoreTests \
    -only-testing:BeforeTests/DecisionTaskGraphStoreTests \
    -only-testing:BeforeTests/DecisionRecordRestorationTests

run_step "Replay and runtime export tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests

run_step "Replay and runtime export tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests

run_step "Launch handoff and pending reflection tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/PendingLaunchRequestStoreTests \
    -only-testing:BeforeTests/PendingReflectionStoreTests \
    -only-testing:BeforeTests/LaunchRequestResolverTests

run_step "Launch handoff and pending reflection tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/PendingLaunchRequestStoreTests \
    -only-testing:BeforeTests/PendingReflectionStoreTests \
    -only-testing:BeforeTests/LaunchRequestResolverTests

run_step "Envelope, bandit, current-brain, and prediction tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntentEnvelopeStoreTests \
    -only-testing:BeforeTests/DecisionReactionBanditStoreTests \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/InterventionPredictionEngineTests

run_step "Envelope, bandit, current-brain, and prediction tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntentEnvelopeStoreTests \
    -only-testing:BeforeTests/DecisionReactionBanditStoreTests \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/InterventionPredictionEngineTests

run_step "Widget privacy tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/WidgetSafeCopyTests \
    -only-testing:BeforeTests/WidgetSnapshotStoreTests

run_step "Widget privacy tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/WidgetSafeCopyTests \
    -only-testing:BeforeTests/WidgetSnapshotStoreTests

run_step "Shared and protected state tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/SharedContainerTests \
    -only-testing:BeforeTests/CodableStateStorageTests \
    -only-testing:BeforeTests/StateStorageIssueRecorderTests \
    -only-testing:BeforeTests/TomorrowBoxDraftTests

run_step "Shared and protected state tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/SharedContainerTests \
    -only-testing:BeforeTests/CodableStateStorageTests \
    -only-testing:BeforeTests/StateStorageIssueRecorderTests \
    -only-testing:BeforeTests/TomorrowBoxDraftTests

run_step "Support and shared-life storage tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/SupportInboxStoreTests \
    -only-testing:BeforeTests/SharedLifeStoreTests \
    -only-testing:BeforeTests/SharedLifeItemFactoryTests \
    -only-testing:BeforeTests/SupportRequestFactoryTests \
    -only-testing:BeforeTests/SupportRequestKindTests

run_step "Support and shared-life storage tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/SupportInboxStoreTests \
    -only-testing:BeforeTests/SharedLifeStoreTests \
    -only-testing:BeforeTests/SharedLifeItemFactoryTests \
    -only-testing:BeforeTests/SupportRequestFactoryTests \
    -only-testing:BeforeTests/SupportRequestKindTests

run_step "Admission and circuit-breaker tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceAdmissionControllerTests \
    -only-testing:BeforeTests/DecisionIntelligenceCircuitBreakerTests

run_step "Admission and circuit-breaker tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceAdmissionControllerTests \
    -only-testing:BeforeTests/DecisionIntelligenceCircuitBreakerTests

run_step "Provider routing and capability tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceExecutionProfileTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderRegistryTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderPipelineTests

run_step "Provider routing and capability tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceExecutionProfileTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderRegistryTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderPipelineTests

run_step "Prompt, debug, and response-cache tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligencePromptContractTests \
    -only-testing:BeforeTests/DecisionIntelligenceDebugStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceResponseCacheTests

run_step "Prompt, debug, and response-cache tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligencePromptContractTests \
    -only-testing:BeforeTests/DecisionIntelligenceDebugStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceResponseCacheTests

run_step "Telemetry and coordinator observability tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceTelemetryStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceCoordinatorTests \
    -only-testing:BeforeTests/DecisionContextLifecycleTests

run_step "Telemetry and coordinator observability tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceTelemetryStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceCoordinatorTests \
    -only-testing:BeforeTests/DecisionContextLifecycleTests

run_step "Memory, trust, embedding, and rebuild tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionMemorySystemTests \
    -only-testing:BeforeTests/DecisionMemoryGovernorTests \
    -only-testing:BeforeTests/DecisionMemoryEligibilityJudgeTests \
    -only-testing:BeforeTests/EmbeddingMemoryStoreTests

run_step "Memory, trust, embedding, and rebuild tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionMemorySystemTests \
    -only-testing:BeforeTests/DecisionMemoryGovernorTests \
    -only-testing:BeforeTests/DecisionMemoryEligibilityJudgeTests \
    -only-testing:BeforeTests/EmbeddingMemoryStoreTests

run_step "Neural, rule, and review engine tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionNeuralEngineTests \
    -only-testing:BeforeTests/DecisionReviewEngineTests \
    -only-testing:BeforeTests/CheckRuleEngineTests

run_step "Neural, rule, and review engine tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionNeuralEngineTests \
    -only-testing:BeforeTests/DecisionReviewEngineTests \
    -only-testing:BeforeTests/CheckRuleEngineTests

run_step "On-device runtime and model catalog tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/GemmaLocalRuntimeBridgeTests \
    -only-testing:BeforeTests/GemmaModelAssetCatalogTests \
    -only-testing:BeforeTests/GemmaRuntimeLibraryCatalogTests \
    -only-testing:BeforeTests/GemmaE4BIntelligenceServiceTests \
    -only-testing:BeforeTests/OnDeviceIntelligenceSessionTests

run_step "On-device runtime and model catalog tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/GemmaLocalRuntimeBridgeTests \
    -only-testing:BeforeTests/GemmaModelAssetCatalogTests \
    -only-testing:BeforeTests/GemmaRuntimeLibraryCatalogTests \
    -only-testing:BeforeTests/GemmaE4BIntelligenceServiceTests \
    -only-testing:BeforeTests/OnDeviceIntelligenceSessionTests

run_step "Launch, notification, reminder, and action tests pass #1" \
  run_before_tests \
    -only-testing:BeforeTests/HomePromptActionTests \
    -only-testing:BeforeTests/NotificationServiceTests \
    -only-testing:BeforeTests/ReminderSelectionPolicyTests \
    -only-testing:BeforeTests/ReminderTemplateLibraryTests \
    -only-testing:BeforeTests/DecisionModeRouterTests \
    -only-testing:BeforeTests/TomorrowBoxItemFactoryTests \
    -only-testing:BeforeTests/TomorrowBoxDelayTests

run_step "Launch, notification, reminder, and action tests pass #2" \
  run_before_tests \
    -only-testing:BeforeTests/HomePromptActionTests \
    -only-testing:BeforeTests/NotificationServiceTests \
    -only-testing:BeforeTests/ReminderSelectionPolicyTests \
    -only-testing:BeforeTests/ReminderTemplateLibraryTests \
    -only-testing:BeforeTests/DecisionModeRouterTests \
    -only-testing:BeforeTests/TomorrowBoxItemFactoryTests \
    -only-testing:BeforeTests/TomorrowBoxDelayTests

printf "\nDOUBLE QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
