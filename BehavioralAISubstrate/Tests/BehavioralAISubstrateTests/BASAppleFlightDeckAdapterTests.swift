import Foundation
import Testing
@testable import BASAdmin
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASObservability
@testable import BASRuntimeCore

@Suite("BASApple Flight Deck Adapter")
struct BASAppleFlightDeckAdapterTests {
    @Test("flight deck adapter compiles host-facing layer reports and overall health")
    func flightDeckAdapterCompilesHostFacingReports() {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 2, "reflective": 2],
                outcomeCount: [.providerSuccess: 4],
                outcomeCountByKind: [.providerSuccess: ["primary": 2, "reflective": 2]],
                activeProviderCount: ["foundationModels": 4],
                attemptedProviderCount: ["foundationModels": 4],
                fallbackActivations: 0,
                backendCount: ["coreML": 4],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 240, "reflective": 480],
                firstPresentableTotalMsByKind: ["primary": 100, "reflective": 180],
                promptAssemblyTotalMsByKind: ["primary": 40, "reflective": 80],
                admissionEvaluationTotalMsByKind: ["primary": 20, "reflective": 40],
                providerSelectionTotalMsByKind: ["primary": 20, "reflective": 40],
                executionTotalMsByKind: ["primary": 160, "reflective": 320],
                activeProviderDurationTotalMs: ["foundationModels": 720],
                backendDurationTotalMs: ["coreML": 720],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 480, "reflective": 720],
                prefixCharactersTotalByKind: ["primary": 220, "reflective": 320],
                immutablePrefixCharactersTotalByKind: ["primary": 140, "reflective": 220],
                adaptivePrefixCharactersTotalByKind: ["primary": 80, "reflective": 100],
                suffixCharactersTotalByKind: ["primary": 260, "reflective": 400],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: [],
                avoidableSkipReasonRawValues: []
            )
        )
        let lifecycleSummary = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "primary",
                    hasContextState: true,
                    generation: 2,
                    rebuiltSession: true,
                    staleFieldCount: 0,
                    anchorFieldCount: 2,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 2,
                    droppedEvidenceCount: 0,
                    droppedInjectedEvidenceCount: 0,
                    droppedDuplicateEvidenceCount: 0,
                    droppedBudgetEvidenceCount: 0
                )
            ]
        )
        let neuralSummary = BASNeuralSummaryBuilder.build(
            from: [
                BASNeuralTraceInput(
                    kind: "primary",
                    suppressedBehaviorCount: 0,
                    dominantActionRawValue: "encourage",
                    strongestSignalRawValue: "urgency"
                )
            ]
        )
        let brainSummary = BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "primary",
                    dominantReactionWeight: .briefLanguage,
                    profileCoreCount: 1,
                    activeGoalCount: 1,
                    relevantMemoryCount: 2,
                    loadedPromotedMemoryCount: 2,
                    loadedPendingMemoryCount: 0,
                    pendingCandidateCount: 1,
                    promotedRecordCount: 4,
                    screenedOutMemoryCount: 0,
                    loadedEligibilityReasonCounts: [:],
                    screenedOutEligibilityReasonCounts: [:],
                    snapshotFingerprint: "brain_fp",
                    lowTrustMemoryLoadRate: 0,
                    riskFlags: [],
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    activeConstraints: [.lockSensitiveMemory],
                    calibrationStatus: .stable,
                    calibrationAlerts: [],
                    evolutionCheckpointCount: 2,
                    evolutionPendingReviewCount: 0,
                    evolutionRollbackReady: true
                )
            ]
        )
        let inspectionSummary = BASRuntimeInspectionBuilder.build(
            from: BASRuntimeInspectionInput(
                activeProviderID: "foundationModels",
                fallbackProviderID: "template",
                runtimeGear: .balanced,
                environmentClass: .normal,
                deviceClass: .fullPhone,
                languageMode: .english,
                taskEntropyByKind: ["primary": .low],
                preferredProviderRawValueByKind: ["primary": "foundationModels"],
                strategyByKind: [
                    "primary": BASAdaptiveTaskStrategy(
                        kind: .primary,
                        entropy: .low,
                        runtimeGear: .balanced,
                        contextBudget: 320,
                        outputCharacterBudget: 180,
                        timeBudgetMs: 900,
                        toolCallBudget: 0,
                        retrievalItemBudget: 2,
                        retrievalMode: .filtered,
                        thinkingMode: .off,
                        outputMode: .guidedShort,
                        tone: .briefWarm,
                        actionSpace: ["encourage"],
                        responseLanguage: .english,
                        allowsModelInvocation: true
                    )
                ],
                effectivePreferredProviderRawValueByKind: ["primary": "foundationModels"],
                traceInputs: [
                    BASRuntimeInspectionTraceInput(
                        kind: "primary",
                        attemptedProviderIDs: ["foundationModels", "template"],
                        runtimeStrategy: BASAdaptiveTaskStrategy(
                            kind: .primary,
                            entropy: .low,
                            runtimeGear: .balanced,
                            contextBudget: 320,
                            outputCharacterBudget: 180,
                            timeBudgetMs: 900,
                            toolCallBudget: 0,
                            retrievalItemBudget: 2,
                            retrievalMode: .filtered,
                            thinkingMode: .off,
                            outputMode: .guidedShort,
                            tone: .briefWarm,
                            actionSpace: ["encourage"],
                            responseLanguage: .english,
                            allowsModelInvocation: true
                        ),
                        semanticPromptFingerprint: "semantic_fp",
                        stablePrefixFingerprint: "prefix_fp",
                        consistencyChecked: true,
                        consistencyRejected: false,
                        consistencyViolationKinds: []
                    )
                ],
                telemetrySummary: telemetrySummary,
                lifecycleSummary: lifecycleSummary,
                neuralSummary: neuralSummary,
                brainSummary: brainSummary,
                totalCacheEntries: 2,
                totalCacheLookupCount: 4,
                totalCacheRejectedStores: 0,
                totalCacheQuarantinedHits: 0,
                dominantBackendID: "coreML",
                registeredProviderCount: 4,
                registeredOpenModelProviderCount: 1,
                activeCircuitProviderIDs: [],
                circuitTripCount: 0,
                circuitTripCountByProvider: [:],
                circuitTripCountByReason: [:],
                traceCount: 4,
                replayCount: 1
            )
        )
        let compilation = BASAppleFlightDeckAdapter.compile(
            from: BASReferenceFlightDeckAssemblyInput(
                generatedAt: .now,
                isPureLocalClosedLoop: true,
                activeProviderTitle: "Foundation Models",
                backendTitle: "Core ML",
                activeTaskGraphTaskCount: 2,
                hardwareAccelerationActive: true,
                activeRuntimeUsingDeterministicFallback: false,
                fallbackTitle: "Template",
                inspectionSummary: inspectionSummary,
                brainSummary: brainSummary
            )
        )
        let builtCompilation = BASAppleFlightDeckBuilder.build(
            from: BASAppleFlightDeckSourceInput(
                generatedAt: compilation.generatedAt,
                registeredProviderIDs: ["foundationModels", "template"],
                activeProviderID: "foundationModels",
                activeProviderTitle: "Foundation Models",
                backendTitle: "Core ML",
                activeTaskGraphTaskCount: 2,
                hardwareAccelerationActive: true,
                runningOnSimulator: false,
                onDeviceIntelligenceEnabled: true,
                fallbackTitle: "Template",
                inspectionSummary: inspectionSummary,
                brainSummary: brainSummary
            )
        )

        #expect(compilation.isPureLocalClosedLoop)
        #expect(compilation.overallHealthID == "strong")
        #expect(compilation.layerReports.count == 8)
        #expect(compilation.layerReports.first(where: { $0.layerID == "runtime" })?.healthID == "strong")
        #expect(compilation.layerReports.first(where: { $0.layerID == "observability" }) != nil)
        #expect(builtCompilation == compilation)
    }
}
