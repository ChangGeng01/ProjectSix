import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

struct BASAppleReopenWorkflowTests {
    @Test("decision mode executor routes comparative mode deterministically")
    func decisionModeExecutorRoutesBalanceModeDeterministically() {
        var routed: String?

        let handled = BASAppleWorkflowModeExecutor.execute(
            modeID: BASDecisionMode.comparativeID,
            performPrimary: { routed = "primary" },
            performComparative: { routed = "comparative" },
            performReflective: { routed = "reflective" }
        )

        #expect(handled)
        #expect(routed == "comparative")
    }

    @Test("tomorrow box follow-up builder suppresses low risk and creates high-risk suggestion")
    func tomorrowBoxFollowUpBuilderSuppressesLowRiskAndCreatesHighRiskSuggestion() {
        let low = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: "low",
            title: "Pause",
            detail: "Low risk",
            modeID: BASDecisionMode.primaryID,
            reopenHint: nil,
            templateHint: nil,
            interventionHistorySummary: nil
        )
        let high = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: "high",
            title: "Pause",
            detail: "High risk",
            modeID: BASDecisionMode.comparativeID,
            reopenHint: "Re-open slowly",
            templateHint: "Use the cooling template",
            interventionHistorySummary: "Delay helped before."
        )

        #expect(low.interventionSuggestion == nil)
        #expect(low.shouldRefreshPredictedIntervention)
        #expect(high.interventionSuggestion?.riskLevelID == "high")
        #expect(high.interventionSuggestion?.title == "Re-open slowly")
        #expect(high.interventionSuggestion?.suggestedModeID == BASDecisionMode.comparativeID)
        #expect(high.interventionSuggestion?.reason == "Use the cooling template")
        #expect(high.interventionSuggestion?.evidenceSignalCount == 2)
    }

    @Test("tomorrow box reopen executor routes drafted mode and finalizes follow-up")
    func tomorrowBoxReopenExecutorRoutesDraftedModeAndFinalizesFollowUp() {
        var cleared = false
        var activated: String?
        var removed = false
        var suggestion: BASAppleReopenInterventionSuggestion?
        var refreshed = false
        var selectedHome = false
        var persisted = false

        BASAppleDeferredReopenExecutor.execute(
            modeID: BASDecisionMode.reflectiveID,
            promptSeed: "Ignored because draft exists",
            hasDraft: true,
            clearActiveDecisionFlows: { cleared = true },
            activatePrimaryFromDraft: { activated = "primary" },
            activateComparativeFromDraft: { activated = "comparative" },
            activateReflectiveFromDraft: { activated = "reflective" },
            startPrimary: { _ in Issue.record("Unexpected primary start") },
            startComparative: { _ in Issue.record("Unexpected comparative start") },
            startReflective: { _ in Issue.record("Unexpected reflective start") },
            removeDeferredItem: { removed = true },
            followUp: BASAppleDeferredReopenFollowUp(
                interventionSuggestion: BASAppleReopenInterventionSuggestion(
                    riskLevelID: "high",
                    title: "Re-open slowly",
                    detail: "Delay helped before.",
                    evidenceSignalCount: 2,
                    suggestedModeID: BASDecisionMode.reflectiveID,
                    reason: "Use the cooling template",
                    expiresAt: .now.addingTimeInterval(60)
                )
            ),
            setInterventionSuggestion: { suggestion = $0 },
            refreshPredictedIntervention: { refreshed = true },
            selectHomeTab: { selectedHome = true },
            persistActiveWorkspaceState: { persisted = true }
        )

        #expect(cleared)
        #expect(activated == "reflective")
        #expect(removed)
        #expect(suggestion?.title == "Re-open slowly")
        #expect(refreshed == false)
        #expect(selectedHome)
        #expect(persisted)
    }

    @Test("drafted mode reopen executor only finalizes for supported modes")
    func draftedModeReopenExecutorOnlyFinalizesForSupportedModes() {
        var finalized = false

        let handled = BASAppleDraftedWorkflowReopenExecutor.execute(
            modeID: "unsupported",
            clearActiveDecisionFlows: {},
            activatePrimary: {},
            activateComparative: {},
            activateReflective: {},
            afterSuccessfulReopen: { finalized = true }
        )

        #expect(handled == false)
        #expect(finalized == false)
    }
}
