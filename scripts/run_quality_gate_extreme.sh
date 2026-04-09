#!/bin/zsh
set -euo pipefail

ROOT="/Users/changgeng/Project/Project06/Project06"
PROJECT="$ROOT/Before.xcodeproj"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-26.3.1}"
WATCH_SIMULATOR_NAME="${WATCH_SIMULATOR_NAME:-Apple Watch Series 11 (46mm)}"
WATCH_SIMULATOR_OS="${WATCH_SIMULATOR_OS:-26.2}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"
WATCH_DESTINATION="platform=watchOS Simulator,name=${WATCH_SIMULATOR_NAME},OS=${WATCH_SIMULATOR_OS}"

typeset -i score=0
typeset -i total=12

run_step() {
  local label="$1"
  shift

  printf "\n[%02d/%02d] %s\n" $((score + 1)) "$total" "$label"
  if "$@"; then
    score=$((score + 1))
    printf "PASS %s\n" "$label"
  else
    printf "FAIL %s\n" "$label"
    printf "\nEXTREME QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
    exit 1
  fi
}

run_before_tests() {
  xcodebuild -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test "$@"
}

run_ui_smoke() {
  xcodebuild -project "$PROJECT" -scheme BeforeUISmoke -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test
}

run_watch_build() {
  xcodebuild -project "$PROJECT" -scheme BeforeWatch -destination "$WATCH_DESTINATION" CODE_SIGNING_ALLOWED=NO build
}

run_repeat() {
  local count="$1"
  shift
  for attempt in $(seq 1 "$count"); do
    printf "  soak run %s/%s\n" "$attempt" "$count"
    "$@"
  done
}

run_step "Double gate passes first" \
  "$ROOT/scripts/run_quality_gate_double.sh"

run_step "Full Before suite pass #3" \
  run_before_tests

run_step "UI smoke pass #3" \
  run_ui_smoke

run_step "BeforeWatch build pass #3" \
  run_watch_build

run_step "Envelope, bandit, current-brain, prediction, and embedding stability survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/DecisionIntentEnvelopeStoreTests \
    -only-testing:BeforeTests/DecisionReactionBanditStoreTests \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/InterventionPredictionEngineTests \
    -only-testing:BeforeTests/EmbeddingMemoryStoreTests

run_step "Recovery, replay, launch handoff, and protected/shared state survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/ActiveDecisionWorkspaceStoreTests \
    -only-testing:BeforeTests/DecisionTaskGraphStoreTests \
    -only-testing:BeforeTests/DecisionRecordRestorationTests \
    -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests \
    -only-testing:BeforeTests/PendingLaunchRequestStoreTests \
    -only-testing:BeforeTests/PendingReflectionStoreTests \
    -only-testing:BeforeTests/LaunchRequestResolverTests \
    -only-testing:BeforeTests/SharedContainerTests \
    -only-testing:BeforeTests/CodableStateStorageTests \
    -only-testing:BeforeTests/StateStorageIssueRecorderTests

run_step "Memory governance, trust, template, failure archive, and embedding survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/DecisionMemorySystemTests \
    -only-testing:BeforeTests/DecisionMemoryGovernorTests \
    -only-testing:BeforeTests/DecisionMemoryEligibilityJudgeTests \
    -only-testing:BeforeTests/CurrentBrainStateLoaderTests \
    -only-testing:BeforeTests/EmbeddingMemoryStoreTests

run_step "Admission and circuit-breaker survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceAdmissionControllerTests \
    -only-testing:BeforeTests/DecisionIntelligenceCircuitBreakerTests

run_step "Provider routing, prompt contract, debug privacy, response cache, and telemetry survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceExecutionProfileTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderRegistryTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderPipelineTests \
    -only-testing:BeforeTests/DecisionIntelligencePromptContractTests \
    -only-testing:BeforeTests/DecisionIntelligenceDebugStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceResponseCacheTests \
    -only-testing:BeforeTests/DecisionIntelligenceTelemetryStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceCoordinatorTests

run_step "Launch, notification, reminder, router, and Tomorrow Box action surfaces survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/HomePromptActionTests \
    -only-testing:BeforeTests/NotificationServiceTests \
    -only-testing:BeforeTests/ReminderSelectionPolicyTests \
    -only-testing:BeforeTests/ReminderTemplateLibraryTests \
    -only-testing:BeforeTests/DecisionModeRouterTests \
    -only-testing:BeforeTests/TomorrowBoxItemFactoryTests \
    -only-testing:BeforeTests/TomorrowBoxDelayTests \
    -only-testing:BeforeTests/TomorrowBoxDraftTests

run_step "On-device runtime and model catalog survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/GemmaLocalRuntimeBridgeTests \
    -only-testing:BeforeTests/GemmaModelAssetCatalogTests \
    -only-testing:BeforeTests/GemmaRuntimeLibraryCatalogTests \
    -only-testing:BeforeTests/GemmaE4BIntelligenceServiceTests \
    -only-testing:BeforeTests/OnDeviceIntelligenceSessionTests

run_step "Widget privacy and shared public state survive 3 consecutive runs" \
  run_repeat 3 run_before_tests \
    -only-testing:BeforeTests/WidgetSafeCopyTests \
    -only-testing:BeforeTests/WidgetSnapshotStoreTests

printf "\nEXTREME QUALITY GATE SCORE: %d/%d\n" "$score" "$total"
