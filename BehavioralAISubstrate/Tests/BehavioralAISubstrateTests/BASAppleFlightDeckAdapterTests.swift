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
                requestCountByKind: ["quick": 2, "mirror": 2],
                outcomeCount: [.providerSuccess: 4],
                outcomeCountByKind: [.providerSuccess: ["quick": 2, "mirror": 2]],
                activeProviderCount: ["foundationModels": 4],
                attemptedProviderCount: ["foundationModels": 4],
                fallbackActivations: 0,
                backendCount: ["coreML": 4],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["quick": 240, "mirror": 480],
                firstPresentableTotalMsByKind: ["quick": 100, "mirror": 180],
                promptAssemblyTotalMsByKind: ["quick": 40, "mirror": 80],
                admissionEvaluationTotalMsByKind: ["quick": 20, "mirror": 40],
                providerSelectionTotalMsByKind: ["quick": 20, "mirror": 40],
                executionTotalMsByKind: ["quick": 160, "mirror": 320],
                activeProviderDurationTotalMs: ["foundationModels": 720],
                backendDurationTotalMs: ["coreML": 720],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                reminderSelectionNeedCount: [:],
                promptCharactersTotalByKind: ["quick": 480, "mirror": 720],
                prefixCharactersTotalByKind: ["quick": 220, "mirror": 320],
                immutablePrefixCharactersTotalByKind: ["quick": 140, "mirror": 220],
                adaptivePrefixCharactersTotalByKind: ["quick": 80, "mirror": 100],
                suffixCharactersTotalByKind: ["quick": 260, "mirror": 400],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                reminderKindRawValue: "reminder",
                reminderKnowledgeNeedRawValue: "knowledge",
                reminderControlNeedRawValue: "control",
                reminderRetrievalBypassReasonRawValues: [],
                avoidableSkipReasonRawValues: []
            )
        )
        let lifecycleSummary = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "quick",
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
                    kind: "quick",
                    suppressedBehaviorCount: 0,
                    dominantActionRawValue: "encourage",
                    strongestSignalRawValue: "urgency"
                )
            ]
        )
        let brainSummary = BASBrainSummaryBuilder.build(
            from: [
                BASBrainTraceInput(
                    kind: "quick",
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
                taskEntropyByKind: ["quick": .low],
                preferredProviderRawValueByKind: ["quick": "foundationModels"],
                strategyByKind: [
                    "quick": BASAdaptiveTaskStrategy(
                        kind: .quick,
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
                effectivePreferredProviderRawValueByKind: ["quick": "foundationModels"],
                traceInputs: [
                    BASRuntimeInspectionTraceInput(
                        kind: "quick",
                        attemptedProviderIDs: ["foundationModels", "template"],
                        runtimeStrategy: BASAdaptiveTaskStrategy(
                            kind: .quick,
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
