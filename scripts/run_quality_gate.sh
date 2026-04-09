#!/bin/zsh
set -euo pipefail

ROOT="/Users/changgeng/Project/Project06/Project06"
PROJECT="$ROOT/Before.xcodeproj"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-26.3.1}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"

typeset -i score=0
typeset -i total=20

run_step() {
  local label="$1"
  shift

  printf "\n[%02d/%02d] %s\n" $((score + 1)) "$total" "$label"
  if "$@"; then
    score=$((score + 1))
    printf "PASS %s\n" "$label"
  else
    printf "FAIL %s\n" "$label"
    printf "\nQUALITY GATE SCORE: %d/%d\n" "$score" "$total"
    exit 1
  fi
}

run_before_tests() {
  xcodebuild -project "$PROJECT" -scheme Before -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test "$@"
}

run_ui_smoke() {
  xcodebuild -project "$PROJECT" -scheme BeforeUISmoke -destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO test
}

run_step "Project generation" \
  xcodegen generate --spec "$ROOT/project.yml"

run_step "Project metadata listing" \
  xcodebuild -project "$PROJECT" -list

run_step "Full Before suite" \
  run_before_tests

run_step "UI smoke pass #1" \
  run_ui_smoke

run_step "UI smoke pass #2" \
  run_ui_smoke

run_step "Recovery continuity tests" \
  run_before_tests \
    -only-testing:BeforeTests/ActiveDecisionWorkspaceStoreTests \
    -only-testing:BeforeTests/DecisionTaskGraphStoreTests

run_step "Record restoration and replay tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionRecordRestorationTests \
    -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests \
    -only-testing:BeforeTests/DecisionTestingInterfaceTests

run_step "Launch handoff and pending reflection tests" \
  run_before_tests \
    -only-testing:BeforeTests/PendingLaunchRequestStoreTests \
    -only-testing:BeforeTests/PendingReflectionStoreTests \
    -only-testing:BeforeTests/LaunchRequestResolverTests

run_step "Widget privacy tests" \
  run_before_tests \
    -only-testing:BeforeTests/WidgetSafeCopyTests \
    -only-testing:BeforeTests/WidgetSnapshotStoreTests

run_step "Shared container and protected state tests" \
  run_before_tests \
    -only-testing:BeforeTests/SharedContainerTests \
    -only-testing:BeforeTests/TomorrowBoxDraftTests

run_step "Support and shared life storage tests" \
  run_before_tests \
    -only-testing:BeforeTests/SupportInboxStoreTests \
    -only-testing:BeforeTests/SharedLifeStoreTests \
    -only-testing:BeforeTests/SharedLifeItemFactoryTests

run_step "Admission and circuit-breaker tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceAdmissionControllerTests \
    -only-testing:BeforeTests/DecisionIntelligenceCircuitBreakerTests

run_step "Provider routing and capability tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceExecutionProfileTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderRegistryTests \
    -only-testing:BeforeTests/DecisionIntelligenceProviderPipelineTests

run_step "Prompt contract, debug privacy, and response cache tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligencePromptContractTests \
    -only-testing:BeforeTests/DecisionIntelligenceDebugStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceResponseCacheTests

run_step "Telemetry and coordinator observability tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionIntelligenceTelemetryStoreTests \
    -only-testing:BeforeTests/DecisionIntelligenceCoordinatorTests \
    -only-testing:BeforeTests/DecisionContextLifecycleTests

run_step "Memory governance and trust tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionMemorySystemTests \
    -only-testing:BeforeTests/DecisionMemoryGovernorTests \
    -only-testing:BeforeTests/DecisionMemoryEligibilityJudgeTests

run_step "Neural, rule, and review engine tests" \
  run_before_tests \
    -only-testing:BeforeTests/DecisionNeuralEngineTests \
    -only-testing:BeforeTests/DecisionReviewEngineTests \
    -only-testing:BeforeTests/CheckRuleEngineTests

run_step "On-device runtime and model catalog tests" \
  run_before_tests \
    -only-testing:BeforeTests/GemmaLocalRuntimeBridgeTests \
    -only-testing:BeforeTests/GemmaModelAssetCatalogTests \
    -only-testing:BeforeTests/GemmaRuntimeLibraryCatalogTests \
    -only-testing:BeforeTests/GemmaE4BIntelligenceServiceTests \
    -only-testing:BeforeTests/OnDeviceIntelligenceSessionTests

run_step "Launch, notification, reminder, and action tests" \
  run_before_tests \
    -only-testing:BeforeTests/HomePromptActionTests \
    -only-testing:BeforeTests/NotificationServiceTests \
    -only-testing:BeforeTests/ReminderSelectionPolicyTests \
    -only-testing:BeforeTests/ReminderTemplateLibraryTests \
    -only-testing:BeforeTests/DecisionModeRouterTests \
    -only-testing:BeforeTests/TomorrowBoxItemFactoryTests \
    -only-testing:BeforeTests/TomorrowBoxDelayTests \
    -only-testing:BeforeTests/SupportRequestFactoryTests \
    -only-testing:BeforeTests/SupportRequestKindTests

run_step "Clean worktree after gate" \
  git -C "$ROOT" diff --quiet --exit-code

printf "\nQUALITY GATE SCORE: %d/%d\n" "$score" "$total"
