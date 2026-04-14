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
