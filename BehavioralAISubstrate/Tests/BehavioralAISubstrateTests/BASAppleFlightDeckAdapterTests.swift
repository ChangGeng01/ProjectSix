import Foundation
import Testing
@testable import BASAdmin
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASObservability
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
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

    @Test("flight deck adapter surfaces replay revocation from inspection bundle")
    func flightDeckAdapterSurfacesReplayRevocationFromInspectionBundle() {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 1],
                outcomeCount: [.providerSuccess: 1],
                outcomeCountByKind: [.providerSuccess: ["primary": 1]],
                activeProviderCount: ["foundationModels": 1],
                attemptedProviderCount: ["foundationModels": 1],
                fallbackActivations: 0,
                backendCount: ["coreML": 1],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 240],
                firstPresentableTotalMsByKind: ["primary": 100],
                promptAssemblyTotalMsByKind: ["primary": 40],
                admissionEvaluationTotalMsByKind: ["primary": 20],
                providerSelectionTotalMsByKind: ["primary": 20],
                executionTotalMsByKind: ["primary": 160],
                activeProviderDurationTotalMs: ["foundationModels": 240],
                backendDurationTotalMs: ["coreML": 240],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 480],
                prefixCharactersTotalByKind: ["primary": 220],
                immutablePrefixCharactersTotalByKind: ["primary": 140],
                adaptivePrefixCharactersTotalByKind: ["primary": 80],
                suffixCharactersTotalByKind: ["primary": 260],
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
                    generation: 1,
                    rebuiltSession: false,
                    staleFieldCount: 0,
                    anchorFieldCount: 1,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 1,
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
                    strongestSignalRawValue: "clarity"
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
                    relevantMemoryCount: 1,
                    loadedPromotedMemoryCount: 1,
                    loadedPendingMemoryCount: 0,
                    pendingCandidateCount: 0,
                    promotedRecordCount: 2,
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
                    evolutionCheckpointCount: 1,
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
                        attemptedProviderIDs: ["foundationModels"],
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
                traceCount: 1,
                replayCount: 1
            )
        )
        let inspectionBundle = BASInspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_123),
            trace: BASExecutionTrace(
                inputSummary: "resume",
                selectedRoute: .local("foundationModels"),
                memoriesRecalled: ["Memory A"],
                toolsCalled: [],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 12,
                    retrievalMs: 12,
                    generationMs: 120,
                    toolMs: 0
                ),
                outputSummary: "ok"
            ),
            replayFingerprint: BASReplayFingerprint(value: String(repeating: "b", count: 64)),
            replayDisposition: BASReplayDisposition(
                isAvailable: false,
                reason: "Replay revoked by forget gate forget.guard.anchor after checkpoint exports and sync exports.",
                forgetRequestID: "forget.guard.anchor",
                checkpointsRevoked: true,
                syncExportsRevoked: true
            ),
            releaseDecision: BASReleaseDecision(kind: .allow, reason: "allowed"),
            anomalySignals: [],
            calibration: nil
        )

        let compilation = BASAppleFlightDeckBuilder.build(
            from: BASAppleFlightDeckSourceInput(
                generatedAt: Date(timeIntervalSince1970: 1_800_000_123),
                registeredProviderIDs: ["foundationModels", "template"],
                activeProviderID: "foundationModels",
                activeProviderTitle: "Foundation Models",
                backendTitle: "Core ML",
                activeTaskGraphTaskCount: 1,
                hardwareAccelerationActive: true,
                runningOnSimulator: false,
                onDeviceIntelligenceEnabled: true,
                fallbackTitle: "Template",
                inspectionSummary: inspectionSummary,
                brainSummary: brainSummary,
                inspectionBundle: inspectionBundle
            )
        )

        #expect(compilation.layerReports.first(where: { $0.layerID == "data" })?.blockers.contains(where: {
            $0.contains("forget.guard.anchor")
        }) == true)
        #expect(compilation.layerReports.first(where: { $0.layerID == "observability" })?.blockers.contains(where: {
            $0.contains("forget.guard.anchor")
        }) == true)
    }
}
#endif
