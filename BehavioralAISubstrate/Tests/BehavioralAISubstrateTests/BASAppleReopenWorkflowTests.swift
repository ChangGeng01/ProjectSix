import Foundation
import Testing
@testable import BASAppleAdapters

struct BASAppleReopenWorkflowTests {
    @Test("decision mode executor routes balance mode deterministically")
    func decisionModeExecutorRoutesBalanceModeDeterministically() {
        var routed: String?

        let handled = BASAppleWorkflowModeExecutor.execute(
            modeID: "balance",
            performPrimary: { routed = "quick" },
            performComparative: { routed = "balance" },
            performReflective: { routed = "mirror" }
        )

        #expect(handled)
        #expect(routed == "balance")
    }

    @Test("tomorrow box follow-up builder suppresses low risk and creates high-risk suggestion")
    func tomorrowBoxFollowUpBuilderSuppressesLowRiskAndCreatesHighRiskSuggestion() {
        let low = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: "low",
            title: "Pause",
            detail: "Low risk",
            modeID: "quick",
            reopenHint: nil,
            templateHint: nil,
            interventionHistorySummary: nil
        )
        let high = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: "high",
            title: "Pause",
            detail: "High risk",
            modeID: "balance",
            reopenHint: "Re-open slowly",
            templateHint: "Use the cooling template",
            interventionHistorySummary: "Delay helped before."
        )

        #expect(low.interventionSuggestion == nil)
        #expect(low.shouldRefreshPredictedIntervention)
        #expect(high.interventionSuggestion?.riskLevelID == "high")
        #expect(high.interventionSuggestion?.title == "Re-open slowly")
        #expect(high.interventionSuggestion?.suggestedModeID == "balance")
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
            modeID: "mirror",
            promptSeed: "Ignored because draft exists",
            hasDraft: true,
            clearActiveDecisionFlows: { cleared = true },
            activatePrimaryFromDraft: { activated = "quick" },
            activateComparativeFromDraft: { activated = "balance" },
            activateReflectiveFromDraft: { activated = "mirror" },
            startPrimary: { _ in Issue.record("Unexpected quick start") },
            startComparative: { _ in Issue.record("Unexpected balance start") },
            startReflective: { _ in Issue.record("Unexpected mirror start") },
            removeDeferredItem: { removed = true },
            followUp: BASAppleDeferredReopenFollowUp(
                interventionSuggestion: BASAppleReopenInterventionSuggestion(
                    riskLevelID: "high",
                    title: "Re-open slowly",
                    detail: "Delay helped before.",
                    evidenceSignalCount: 2,
                    suggestedModeID: "mirror",
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
        #expect(activated == "mirror")
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
