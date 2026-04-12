import Foundation
import Testing
@testable import BASAdmin
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASReferenceCapabilityCoverageBuilder")
struct BASReferenceCapabilityCoverageBuilderTests {
    @Test("builds ordered coverage report with live runtime and memory signals")
    func buildsOrderedCoverageReport() {
        let report = BASReferenceCapabilityCoverageBuilder.build(
            input: BASReferenceCapabilityCoverageInput(
                activeProviderTitle: "Foundation Models",
                runtimeSummary: makeRuntimeSummary(activeProviderID: "foundationModels", replayCount: 1, consistencyChecked: true),
                brainSummary: makeBrainSummary(calibrationStatus: .stable, brainTraceCount: 1),
                isPureLocalClosedLoop: true,
                layerReportCount: BASLayerKind.allCases.count,
                expectedLayerCount: BASLayerKind.allCases.count,
                hasTaskGraph: true,
                brainLoaded: true,
                activeTemplateCount: 2,
                failureGuardCount: 1,
                hasSensitiveConstraint: true
            )
        )

        #expect(report.sections.map(\.domain) == BASCapabilityDomain.allCases)
        #expect(report.sections.first(where: { $0.domain == .runtime })?.items.first(where: { $0.id == "runtime.local_first" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.consistency_harness" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .observability })?.items.first(where: { $0.id == "observability.flight_deck" })?.status == .ready)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .ready)
        #expect(report.overallScore > 0)
    }

    @Test("degrades gracefully when brain state is unavailable")
    func degradesGracefullyWithoutBrainState() {
        let report = BASReferenceCapabilityCoverageBuilder.build(
            input: BASReferenceCapabilityCoverageInput(
                activeProviderTitle: "Template",
                runtimeSummary: makeRuntimeSummary(activeProviderID: "template", replayCount: 0, consistencyChecked: false),
                brainSummary: makeBrainSummary(calibrationStatus: .drifting, brainTraceCount: 0),
                isPureLocalClosedLoop: false,
                layerReportCount: 4,
                expectedLayerCount: BASLayerKind.allCases.count,
                hasTaskGraph: false,
                brainLoaded: false,
                activeTemplateCount: 0,
                failureGuardCount: 0,
                hasSensitiveConstraint: false
            )
        )

        #expect(report.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.summary_layer" })?.status == .partial)
        #expect(report.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .partial)
        #expect(report.sections.first(where: { $0.domain == .observability })?.items.first(where: { $0.id == "observability.flight_deck" })?.status == .partial)
    }

    private func makeRuntimeSummary(
        activeProviderID: String,
        replayCount: Int,
        consistencyChecked: Bool
    ) -> BASRuntimeInspectionSummary {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 1],
                outcomeCount: [.providerSuccess: 1],
                outcomeCountByKind: [.providerSuccess: ["primary": 1]],
                activeProviderCount: [activeProviderID: 1],
                attemptedProviderCount: [activeProviderID: 1],
                fallbackActivations: 0,
                backendCount: ["coreML": 1],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 180],
                firstPresentableTotalMsByKind: ["primary": 120],
                promptAssemblyTotalMsByKind: ["primary": 25],
                admissionEvaluationTotalMsByKind: ["primary": 12],
                providerSelectionTotalMsByKind: ["primary": 8],
                executionTotalMsByKind: ["primary": 90],
                activeProviderDurationTotalMs: [activeProviderID: 180],
                backendDurationTotalMs: ["coreML": 180],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 320],
                prefixCharactersTotalByKind: ["primary": 120],
                immutablePrefixCharactersTotalByKind: ["primary": 80],
                adaptivePrefixCharactersTotalByKind: ["primary": 40],
                suffixCharactersTotalByKind: ["primary": 200],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "needs_knowledge",
                selectionControlNeedRawValue: "control_only",
                selectionRetrievalBypassReasonRawValues: ["control_only", "no_relevant_evidence", "budget_exceeded"],
                avoidableSkipReasonRawValues: ["template_pinned", "admission_skipped"]
            )
        )
        let lifecycleSummary = BASLifecycleSummaryBuilder.build(
            from: [
                BASLifecycleTraceInput(
                    kind: "primary",
                    hasContextState: true,
                    generation: 2,
                    rebuiltSession: false,
                    staleFieldCount: 0,
                    anchorFieldCount: 2,
                    hasFrontstageState: true,
                    retainedEvidenceCount: 2,
                    droppedEvidenceCount: 1,
                    droppedInjectedEvidenceCount: 0,
                    droppedDuplicateEvidenceCount: 0,
                    droppedBudgetEvidenceCount: 1
                )
            ]
        )
        let neuralSummary = BASNeuralSummaryBuilder.build(
            from: [
                BASNeuralTraceInput(
                    kind: "primary",
                    suppressedBehaviorCount: 1,
                    dominantActionRawValue: "pause",
                    strongestSignalRawValue: "urgency"
                )
            ]
        )
        let brainSummary = makeBrainSummary(calibrationStatus: .stable, brainTraceCount: 1)

        return BASRuntimeInspectionBuilder.build(
            from: BASRuntimeInspectionInput(
                activeProviderID: activeProviderID,
                fallbackProviderID: activeProviderID == "template" ? nil : "template",
                runtimeGear: .balanced,
                environmentClass: .normal,
                deviceClass: .fullPhone,
                languageMode: .english,
                taskEntropyByKind: ["primary": .low],
                preferredProviderRawValueByKind: ["primary": activeProviderID],
                strategyByKind: ["primary": primaryStrategy(providerAllowed: activeProviderID != "template")],
                effectivePreferredProviderRawValueByKind: ["primary": activeProviderID],
                traceInputs: [
                    BASRuntimeInspectionTraceInput(
                        kind: "primary",
                        attemptedProviderIDs: [activeProviderID],
                        runtimeStrategy: primaryStrategy(providerAllowed: activeProviderID != "template"),
                        semanticPromptFingerprint: "semantic-primary",
                        stablePrefixFingerprint: "prefix-primary",
                        consistencyChecked: consistencyChecked,
                        consistencyRejected: false,
                        consistencyViolationKinds: []
                    )
                ],
                telemetrySummary: telemetrySummary,
                lifecycleSummary: lifecycleSummary,
                neuralSummary: neuralSummary,
                brainSummary: brainSummary,
                totalCacheEntries: 1,
                totalCacheLookupCount: 1,
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
                replayCount: replayCount
            )
        )
    }

    private func makeBrainSummary(
        calibrationStatus: BASCalibrationStatus,
        brainTraceCount: Int
    ) -> BASBrainSummary {
        BASBrainSummaryBuilder.build(
            from: brainTraceCount == 0 ? [] : [
                BASBrainTraceInput(
                    kind: "primary",
                    dominantReactionWeight: .briefLanguage,
                    profileCoreCount: 1,
                    activeGoalCount: 1,
                    relevantMemoryCount: 2,
                    loadedPromotedMemoryCount: 3,
                    loadedPendingMemoryCount: 1,
                    pendingCandidateCount: 1,
                    promotedRecordCount: 6,
                    screenedOutMemoryCount: 1,
                    loadedEligibilityReasonCounts: [.goalOverride: 1],
                    screenedOutEligibilityReasonCounts: [.confidenceNoOverlap: 1],
                    snapshotFingerprint: "brain-fp",
                    lowTrustMemoryLoadRate: 0.1,
                    riskFlags: [],
                    identityRole: .pauseCompanion,
                    boundaryMode: .localOnlyAdvisory,
                    activeConstraints: [.lockSensitiveMemory],
                    calibrationStatus: calibrationStatus,
                    calibrationAlerts: calibrationStatus == .stable ? [] : [.templateCoverageGap],
                    evolutionCheckpointCount: 2,
                    evolutionPendingReviewCount: calibrationStatus == .stable ? 0 : 1,
                    evolutionRollbackReady: true
                )
            ]
        )
    }

    private func primaryStrategy(providerAllowed: Bool) -> BASAdaptiveTaskStrategy {
        BASAdaptiveTaskStrategy(
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
            allowsModelInvocation: providerAllowed
        )
    }
}
