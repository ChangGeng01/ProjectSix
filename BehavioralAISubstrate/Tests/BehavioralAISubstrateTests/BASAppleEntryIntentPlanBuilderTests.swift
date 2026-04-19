import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Entry Intent Plan Builder")
struct BASAppleEntryIntentPlanBuilderTests {
    @Test("watch capture keeps generic primary mode and uses watch handoff refresh")
    func watchCapturePlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "capture",
            surfaceID: "watch",
            preferredModeID: BASDecisionMode.primaryID,
            scenarioID: "buy",
            promptSeed: "Hold this.",
            riskLevelID: "medium",
            triggerReason: "watch_capture"
        )

        #expect(plan.actionKind == BASAppleEntryIntentActionKind.capture)
        #expect(plan.sourceSurface == BASAppleSurface.watch)
        #expect(plan.refreshTriggerKind == BASAppleBrainRefreshTriggerKind.watchHandoff)
        #expect(plan.promptSeed == "Hold this.")
        #expect(plan.scenarioID == "buy")
    }

    @Test("generic reopen routes as present and selects box tab")
    func reopenPlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "reopen",
            surfaceID: "notification",
            preferredModeID: BASDecisionMode.reflectiveID,
            scenarioID: nil,
            promptSeed: "Reopen this tomorrow item.",
            riskLevelID: "high",
            triggerReason: nil
        )

        #expect(plan.actionKind == BASAppleEntryIntentActionKind.present)
        #expect(plan.shouldSelectBoxTab)
        #expect(plan.refreshTriggerKind == BASAppleBrainRefreshTriggerKind.explicitRefresh)
        #expect(plan.preferredModeID == BASDecisionMode.reflectiveID)
    }

    @Test("generic resume becomes restore workspace")
    func resumePlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "resume",
            surfaceID: "app",
            preferredModeID: nil,
            scenarioID: nil,
            promptSeed: nil,
            riskLevelID: nil,
            triggerReason: nil
        )

        #expect(plan.actionKind == BASAppleEntryIntentActionKind.restore)
        #expect(plan.promptSeed.isEmpty)
        #expect(plan.shouldSelectBoxTab == false)
    }

    @Test("shared routed-input intent keeps the prompt and skips box-tab selection")
    func routedInputPlan() {
        let plan = BASAppleEntryIntentPlanBuilder.plan(
            kindID: "routedInput",
            surfaceID: "shortcut",
            preferredModeID: nil,
            scenarioID: nil,
            promptSeed: "Route this on the shared path.",
            riskLevelID: nil,
            triggerReason: nil
        )

        #expect(plan.actionKind == BASAppleEntryIntentActionKind.routedInput)
        #expect(plan.promptSeed == "Route this on the shared path.")
        #expect(plan.shouldSelectBoxTab == false)
        #expect(plan.refreshTriggerKind == BASAppleBrainRefreshTriggerKind.explicitRefresh)
    }
}
