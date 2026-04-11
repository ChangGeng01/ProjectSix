import Foundation
import Testing
@testable import BASAppleAdapters

struct BASAppleReopenWorkflowTests {
    @Test("decision mode executor routes balance mode deterministically")
    func decisionModeExecutorRoutesBalanceModeDeterministically() {
        var routed: String?

        let handled = BASAppleDecisionModeExecutor.execute(
            modeID: "balance",
            performQuick: { routed = "quick" },
            performBalance: { routed = "balance" },
            performMirror: { routed = "mirror" }
        )

        #expect(handled)
        #expect(routed == "balance")
    }

    @Test("tomorrow box follow-up builder suppresses low risk and creates high-risk suggestion")
    func tomorrowBoxFollowUpBuilderSuppressesLowRiskAndCreatesHighRiskSuggestion() {
        let low = BASAppleTomorrowBoxReopenFollowUpBuilder.build(
            riskLevelID: "low",
            title: "Pause",
            detail: "Low risk",
            modeID: "quick",
            reopenHint: nil,
            templateHint: nil,
            interventionHistorySummary: nil
        )
        let high = BASAppleTomorrowBoxReopenFollowUpBuilder.build(
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

        BASAppleTomorrowBoxReopenExecutor.execute(
            modeID: "mirror",
            promptSeed: "Ignored because draft exists",
            hasDraft: true,
            clearActiveDecisionFlows: { cleared = true },
            activateQuickFromDraft: { activated = "quick" },
            activateBalanceFromDraft: { activated = "balance" },
            activateMirrorFromDraft: { activated = "mirror" },
            startQuick: { _ in Issue.record("Unexpected quick start") },
            startBalance: { _ in Issue.record("Unexpected balance start") },
            startMirror: { _ in Issue.record("Unexpected mirror start") },
            removeTomorrowBoxItem: { removed = true },
            followUp: BASAppleTomorrowBoxReopenFollowUp(
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

        let handled = BASAppleDraftedModeReopenExecutor.execute(
            modeID: "unsupported",
            clearActiveDecisionFlows: {},
            activateQuick: {},
            activateBalance: {},
            activateMirror: {},
            afterSuccessfulReopen: { finalized = true }
        )

        #expect(handled == false)
        #expect(finalized == false)
    }
}
