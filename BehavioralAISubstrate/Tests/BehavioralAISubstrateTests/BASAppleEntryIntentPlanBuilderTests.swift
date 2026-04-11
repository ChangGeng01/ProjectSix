import Foundation
import Testing
@testable import BASAppleAdapters

@Suite("BASApple Entry Intent Plan Builder")
struct BASAppleEntryIntentPlanBuilderTests {
    @Test("watch quick capture stays quick and uses watch handoff refresh")
    func watchQuickCapturePlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "quickCapture",
            surfaceID: "watch",
            preferredModeID: "quick",
            scenarioID: "buy",
            promptSeed: "Hold this.",
            riskLevelID: "medium",
            triggerReason: "watch_capture"
        )

        #expect(plan.actionKind == .quickCapture)
        #expect(plan.sourceSurface == .watch)
        #expect(plan.refreshTriggerKind == .watchHandoff)
        #expect(plan.promptSeed == "Hold this.")
        #expect(plan.scenarioID == "buy")
    }

    @Test("reopen tomorrow routes as open mode and selects box tab")
    func reopenTomorrowPlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "reopenTomorrowItem",
            surfaceID: "notification",
            preferredModeID: "mirror",
            scenarioID: nil,
            promptSeed: "Reopen this tomorrow item.",
            riskLevelID: "high",
            triggerReason: nil
        )

        #expect(plan.actionKind == .openMode)
        #expect(plan.shouldSelectBoxTab)
        #expect(plan.refreshTriggerKind == .explicitRefresh)
        #expect(plan.preferredModeID == "mirror")
    }

    @Test("resume current decision becomes restore workspace")
    func resumePlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "resumeCurrentDecision",
            surfaceID: "app",
            preferredModeID: nil,
            scenarioID: nil,
            promptSeed: nil,
            riskLevelID: nil,
            triggerReason: nil
        )

        #expect(plan.actionKind == .restoreWorkspace)
        #expect(plan.promptSeed.isEmpty)
        #expect(plan.shouldSelectBoxTab == false)
    }
}
