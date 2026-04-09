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
typeset -i total=40

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

run_before_tests() {
  xcodebuild -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test "$@"
}

run_ui_smoke() {
  xcodebuild -project "$PROJECT" -scheme BeforeUISmoke -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test
}

run_watch_build() {
  xcodebuild -project "$PROJECT" -scheme BeforeWatch -destination "$WATCH_DESTINATION" CODE_SIGNING_ALLOWED=NO build
}

run_step "Project generation pass #1" \
  xcodegen generate --spec "$ROOT/project.yml"

run_step "Project generation pass #2" \
  xcodegen generate --spec "$ROOT/project.yml"

run_step "Project metadata listing pass #1" \
  xcodebuild -project "$PROJECT" -list

run_step "Project metadata listing pass #2" \
  xcodebuild -project "$PROJECT" -list

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
