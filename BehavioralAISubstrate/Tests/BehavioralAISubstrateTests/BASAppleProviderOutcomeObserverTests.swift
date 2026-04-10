import Testing
@testable import BASAppleAdapters
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Provider Outcome Observer")
struct BASAppleProviderOutcomeObserverTests {
    private struct MockProvider: Sendable {
        let id: String
    }

    @Test("observer owns provider narrative variants and consistency rejection details")
    func observerBuildsNarratives() {
        let live = BASAppleProviderOutcomeObserver.providerDetail(
            preferredTitle: "Foundation",
            activeTitle: "Gemma",
            allowFallbacks: true,
            activeResolutionDetail: "Core ML: on-device"
        )
        let cached = BASAppleProviderOutcomeObserver.cachedProviderDetail(
            preferredTitle: "Foundation",
            activeTitle: "Gemma",
            allowFallbacks: true
        )
        let fallback = BASAppleProviderOutcomeObserver.deterministicFallbackDetail(
            base: "All compatible providers were unavailable.",
            suspendedProviderTitles: ["Foundation"]
        )
        let rejected = BASAppleProviderOutcomeObserver.rejectedConsistencyDetail(
            base: live,
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(
                        kind: .modeMismatch,
                        message: "Response drifted away from quick mode."
                    )
                ]
            ),
            source: "provider quick refinement"
        )

        #expect(live.contains("Foundation"))
        #expect(live.contains("Gemma"))
        #expect(live.contains("Core ML"))
        #expect(cached.contains("structured prompt cache"))
        #expect(fallback.contains("Foundation"))
        #expect(rejected.contains("provider quick refinement"))
    }

    @Test("observer compiles sanitized traces and telemetry observations")
    func observerCompilesTraceAndTelemetry() {
        let trace = BASAppleProviderOutcomeObserver.traceObservation(
            from: BASAppleProviderTraceInput(
                environment: [:],
                considerRuntimeTestingContext: false,
                runtimeTestingContextDetected: false,
                testingOverridePresent: false,
                kind: "quick",
                preferredProviderID: "foundationModels",
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                allowFallbacks: true,
                prompt: "live prompt",
                outputPreview: "live output",
                detail: "Gemma handled quick refinement.",
                semanticPromptFingerprint: "semantic-1",
                stablePrefixFingerprint: "prefix-1",
                promptBudget: BASPromptBudget(
                    targetCharacters: 220,
                    prefixCharacters: 80,
                    suffixCharacters: 60
                ),
                lifecycleMetrics: BASRequestLifecycleMetrics(
                    promptAssemblyMs: 20,
                    admissionEvaluationMs: 10,
                    providerSelectionMs: 15,
                    firstPresentableMs: 100,
                    executionMs: 55
                )
            )
        )
        let telemetry = BASAppleProviderOutcomeObserver.telemetryObservation(
            from: BASAppleTelemetryRecordInput(
                kind: "mirror",
                outcome: .providerSuccess,
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                usedFallback: true,
                durationMs: 1_650,
                lifecycleMetrics: BASAppleProviderOutcomeObserver.lifecycleMetrics(
                    promptPreparedMs: 25,
                    admissionEvaluatedMs: 40,
                    providerSelectionMs: 70,
                    firstPresentableMs: 160
                ),
                promptBudget: BASPromptBudget(
                    targetCharacters: 420,
                    prefixCharacters: 180,
                    suffixCharacters: 120
                ),
                runtimeTimeBudgetMs: 1_400,
                admissionPressureID: "low",
                activeBackendID: "coreML"
            )
        )

        #expect(trace.compilation.allowsSensitivePayload == false)
        #expect(trace.compilation.storedPrompt.contains("[REDACTED LIVE PROMPT]"))
        #expect(trace.compilation.executionTrace.selectedRoute.preferredModelID == "gemmaE4B")
        #expect(telemetry.compilation.isSlowRequest)
        #expect(telemetry.compilation.exceedsTimeBudget)
        #expect(telemetry.compilation.lowPressureModelCall)
        #expect(telemetry.compilation.usedFallback)
    }

    @Test("observer can compile provider request events into trace telemetry and circuit outputs")
    func observerCompilesObservedProviderEvents() {
        let context = BASAppleProviderObservationContext(
            kind: "quick",
            preferredProviderID: "foundationModels",
            allowFallbacks: true,
            providerProfilesByID: [
                "foundationModels": BASAppleProviderProfile(
                    providerID: "foundationModels",
                    title: "Foundation"
                ),
                "gemmaE4B": BASAppleProviderProfile(
                    providerID: "gemmaE4B",
                    title: "Gemma",
                    activeResolutionDetail: "Core ML: on-device",
                    activeBackendID: "coreML"
                )
            ],
            promptBudget: BASPromptBudget(
                targetCharacters: 220,
                prefixCharacters: 80,
                suffixCharacters: 60
            ),
            brainState: nil,
            admissionPressureID: "low",
            runtimeTimeBudgetMs: 1_000,
            admissionReason: "Pressure is low.",
            semanticPromptFingerprint: "semantic-1",
            stablePrefixFingerprint: "prefix-1",
            prompt: "live prompt",
            templatePinnedOutputPreview: "template preview",
            admissionSkippedOutputPreview: "admission preview",
            deterministicFallbackOutputPreview: "fallback preview",
            templatePinnedDetail: "Template pinned.",
            admissionSkippedDetailPrefix: "Admission skipped.",
            deterministicFallbackBase: "No provider returned a result.",
            cachedConsistencySource: "cached quick refinement",
            providerConsistencySource: "provider quick refinement",
            recordsTemplatePinnedTrace: true
        )
        let event = BASProviderRequestEvent.providerSuccess(
            BASProviderRequestAttemptEvent(
                planSummary: BASProviderRequestPlanSummary(
                    task: .quick,
                    preferredProviderID: "foundationModels",
                    orderedProviderIDs: ["foundationModels", "gemmaE4B"],
                    resolvedProviderIDs: ["foundationModels", "gemmaE4B"],
                    compatibleProviderIDs: ["foundationModels", "gemmaE4B"],
                    incompatibleProviderIDs: [],
                    suspendedProviderIDs: [],
                    usedTestingOverride: false,
                    providerSelectionDurationMs: 12
                ),
                provider: MockProvider(id: "gemmaE4B"),
                result: "ignored",
                assessment: BASProviderReleaseAssessment(
                    outputPreview: "provider output",
                    consistencyCheck: nil
                ),
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"]
            )
        )

        let observation = BASAppleProviderOutcomeObserver.observeEvent(
            event,
            context: context,
            durationMs: 640,
            promptPreparedMs: 30,
            admissionEvaluatedMs: 50,
            providerID: { $0.id }
        )

        #expect(observation.telemetryObservation?.input.activeProviderID == "gemmaE4B")
        #expect(observation.telemetryObservation?.compilation.activeBackendID == "coreML")
        #expect(observation.trace?.activeProviderID == "gemmaE4B")
        #expect(observation.trace?.observation.detail.contains("Foundation") == true)
        #expect(observation.trace?.observation.detail.contains("Gemma") == true)
        #expect(observation.circuitEvents == [
            BASAppleProviderCircuitEvent.providerSuccess(
                providerID: "gemmaE4B",
                kind: "quick",
                durationMs: 640
            )
        ])
    }
}
