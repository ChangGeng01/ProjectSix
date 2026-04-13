import Foundation
import BASHostKit

struct DecisionEvolutionCoverageFacts: Equatable, Sendable {
    let recoveredCheckpoint: DecisionReviewCheckpointSnapshot?
    let latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    let recoveredEBrainAvailable: Bool
    let recoveredAuditFindingCount: Int
    let recoveredTicketCount: Int
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
        let recoveredCheckpoint = currentBrainState?.evolutionState.latestCheckpoint
            .flatMap { checkpoint -> DecisionReviewCheckpointSnapshot? in
                guard checkpoint.approvalState == .automatic else { return nil }
                return DecisionReviewCheckpointSnapshot(
                    summary: checkpoint,
                    mode: currentBrainState?.mode ?? .quick
                )
            } ?? export.evolutionControlSurface.activeCheckpoint

        let latestPersistedLineage = export.latestCheckpointLineage

        return DecisionEvolutionCoverageFacts(
            recoveredCheckpoint: recoveredCheckpoint,
            latestPersistedLineage: latestPersistedLineage,
            recoveredEBrainAvailable: recoveredCheckpoint != nil || latestPersistedLineage != nil,
            recoveredAuditFindingCount: recoveredCheckpoint?.auditFindings.count ?? export.runtimeAuditFindings.count,
            recoveredTicketCount: recoveredCheckpoint?.updateTicketSummaries.count ?? export.updateTicketSummaries.count
        )
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

        return BASReferenceCapabilityCoverageInput(
            activeProviderTitle: export.runtimeSnapshot.runtimeStatus.active.title,
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
}
