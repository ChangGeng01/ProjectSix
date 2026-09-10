import Foundation
import BASHostKit

struct DecisionEvolutionCoverageFacts: Equatable, Sendable {
    let recoveredCheckpoint: DecisionReviewCheckpointSnapshot?
    let latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    let recoveredEBrainAvailable: Bool
    let recoveredAuditFindingCount: Int
    let recoveredTicketCount: Int
}

struct DecisionEvolutionRuntimeFacts: Equatable, Sendable {
    let effectiveEBrainSummary: DeveloperDecisionReplayEBrainSummary?
    let effectiveEBrainSource: DecisionTestingEBrainSource?
    let effectiveEBrainFactsBundle: DecisionEvolutionEBrainFactsBundle?
    let layerStackLines: [String]
    let thoughtFoldChecksum: String?
    let updateTicketSummaries: [String]
    let runtimeAuditFindings: [String]
    let effectiveActiveKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let coverageFacts: DecisionEvolutionCoverageFacts
}

enum DecisionCapabilityCoverageBuilder {
    static func build(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> BASCapabilityCoverageReport {
        build(
            from: export,
            currentBrainState: currentBrainState,
            evolutionFacts: evolutionFacts(
                from: export,
                currentBrainState: currentBrainState
            )
        )
    }

    static func build(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?,
        evolutionFacts: DecisionEvolutionCoverageFacts
    ) -> BASCapabilityCoverageReport {
        BASReferenceCapabilityCoverageBuilder.build(
            input: referenceInput(
                from: export,
                currentBrainState: currentBrainState,
                evolutionFacts: evolutionFacts
            )
        )
    }

    static func evolutionFacts(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> DecisionEvolutionCoverageFacts {
        export.evolutionRuntimeFacts(currentBrainState: currentBrainState).coverageFacts
    }

    private static func referenceInput(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?,
        evolutionFacts: DecisionEvolutionCoverageFacts? = nil
    ) -> BASReferenceCapabilityCoverageInput {
        let resolvedEvolutionFacts = evolutionFacts ?? self.evolutionFacts(
            from: export,
            currentBrainState: currentBrainState
        )
        let flightDeck = export.flightDeck
        let executionCapabilityFrame =
            flightDeck.eBrainSummary?.executionCapabilityFrame
            ?? export.executionCapabilityFrame

        return BASReferenceCapabilityCoverageInput(
            activeProviderTitle: export.runtimeSnapshot.runtimeStatus.active.title,
            executionTierID: executionCapabilityFrame.executionTierID,
            foundationTierID: executionCapabilityFrame.foundationTierID,
            horizonCoverage: horizonCoverage(from: executionCapabilityFrame),
            runtimeSummary: export.basRuntimeInspectionSummary,
            brainSummary: export.basBrainSummary,
            isPureLocalClosedLoop: flightDeck.isPureLocalClosedLoop,
            layerReportCount: flightDeck.layerReports.count,
            expectedLayerCount: DecisionSystemLayer.allCases.count,
            hasTaskGraph: export.runtimeSnapshot.activeTaskGraph?.tasks.isEmpty == false,
            brainLoaded: currentBrainState != nil,
            activeTemplateCount: currentBrainState?.activeTemplateIDs.count ?? 0,
            failureGuardCount: currentBrainState?.failureGuardIDs.count ?? 0,
            hasSensitiveConstraint: currentBrainState?.activeConstraints.contains(where: { $0.contains("sensitive") }) == true,
            recoveredEBrainAvailable: resolvedEvolutionFacts.recoveredEBrainAvailable,
            recoveredAuditFindingCount: resolvedEvolutionFacts.recoveredAuditFindingCount,
            recoveredTicketCount: resolvedEvolutionFacts.recoveredTicketCount
        )
    }

    private static func horizonCoverage(
        from frame: DecisionEBrainExecutionCapabilityFrame
    ) -> BASHorizonCoverageSnapshot {
        let worldPriorContract = frame.worldPriorContract
        let temporalKnowledgeContract = frame.temporalKnowledgeContract
        let evidenceContract = frame.evidenceContract
        let persistenceContract = frame.persistenceContract

        return BASHorizonCoverageSnapshot(
            worldPriorID: worldPriorContract.priorID,
            worldPriorPostureID: worldPriorContract.posture.rawValue,
            worldBoundaryID: worldPriorContract.boundaryID,
            hostIsolationID: worldPriorContract.hostIsolationID,
            sessionIsolationID: worldPriorContract.sessionIsolationID,
            toolTruthModeID: worldPriorContract.toolTruthModeID,
            temporalKnowledgeTierID: temporalKnowledgeContract.tier.rawValue,
            temporalRefreshRequirementID: temporalKnowledgeContract.refreshRequirement.rawValue,
            temporalDecayPolicyID: temporalKnowledgeContract.decayPolicy.rawValue,
            temporalTimeScopeID: temporalKnowledgeContract.timeScope.rawValue,
            evidenceGradientID: evidenceContract.gradient.rawValue,
            evidenceClaimTypeID: evidenceContract.claimType.rawValue,
            requiresCaveat: evidenceContract.requiresCaveat,
            requiresExternalRefresh: evidenceContract.requiresExternalRefresh,
            volatileClaimWriteModeID: persistenceContract.volatileClaimWriteModeID,
            contaminatedWriteModeID: persistenceContract.contaminatedWriteModeID,
            minimumDurableEvidenceCount: persistenceContract.minimumDurableEvidenceCount,
            forceStageNonContinuityDrafts: persistenceContract.forceStageNonContinuityDrafts,
            evidencePendingTagIDs: persistenceContract.evidencePendingTagIDs
        )
    }
}
