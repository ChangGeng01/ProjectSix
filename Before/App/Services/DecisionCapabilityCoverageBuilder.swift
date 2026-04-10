import Foundation
import BASAdmin

enum DecisionCapabilityCoverageBuilder {
    static func build(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> BASCapabilityCoverageReport {
        BASReferenceCapabilityCoverageBuilder.build(
            input: referenceInput(
                from: export,
                currentBrainState: currentBrainState
            )
        )
    }

    private static func referenceInput(
        from export: DecisionTestingRuntimeExport,
        currentBrainState: CurrentBrainState?
    ) -> BASReferenceCapabilityCoverageInput {
        let flightDeck = export.flightDeck

        return BASReferenceCapabilityCoverageInput(
            activeProviderTitle: export.summary.activeProvider.title,
            runtimeSummary: export.basRuntimeInspectionSummary,
            brainSummary: export.basBrainSummary,
            isPureLocalClosedLoop: flightDeck.isPureLocalClosedLoop,
            layerReportCount: flightDeck.layerReports.count,
            expectedLayerCount: DecisionSystemLayer.allCases.count,
            hasTaskGraph: export.runtimeSnapshot.activeTaskGraph?.tasks.isEmpty == false,
            brainLoaded: currentBrainState != nil,
            activeTemplateCount: currentBrainState?.activeTemplateIDs.count ?? 0,
            failureGuardCount: currentBrainState?.failureGuardIDs.count ?? 0,
            hasSensitiveConstraint: currentBrainState?.activeConstraints.contains(where: { $0.contains("sensitive") }) == true
        )
    }
}
