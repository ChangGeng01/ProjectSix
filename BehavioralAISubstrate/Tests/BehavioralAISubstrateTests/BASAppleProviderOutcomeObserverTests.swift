import Testing
@testable import BASAppleAdapters
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy

@Suite("BASApple Provider Outcome Observer")
struct BASAppleProviderOutcomeObserverTests {
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
}
