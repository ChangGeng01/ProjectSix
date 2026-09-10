import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Lifecycle Outcomes")
struct BASAppleLifecycleOutcomeTests {
    @Test("pending launch builder prefers explicit scenario over preferred mode")
    func pendingLaunchBuilderPrefersScenario() {
        let plan = BASApplePendingLaunchOutcomeBuilder.resolve(
            preferredModeID: "reflective",
            scenarioID: "buy",
            promptSeed: "  hold this  "
        )

        #expect(plan.actionKind == .capture)
        #expect(plan.scenarioID == "buy")
        #expect(plan.preferredModeID == nil)
        #expect(plan.promptSeed == "hold this")
    }

    @Test("pending launch executor routes to the matching action only")
    func pendingLaunchExecutorRoutesToMatchingAction() {
        var calls: [String] = []
        let plan = BASApplePendingLaunchOutcomeBuilder.resolve(
            preferredModeID: "comparative",
            scenarioID: nil,
            promptSeed: " reopen this "
        )

        BASApplePendingLaunchOutcomeExecutor.execute(
            plan: plan,
            performCapture: { _ in calls.append("primary") },
            performPresent: { action in
                calls.append("open:\(action.preferredModeID ?? "nil"):\(action.promptSeed)")
            },
            performRoutedInput: { _ in calls.append("route") }
        )

        #expect(calls == ["open:comparative:reopen this"])
    }

    @Test("pending launch runtime executor resolves and routes in one package-owned step")
    func pendingLaunchRuntimeExecutorResolvesAndRoutes() {
        var calls: [String] = []

        BASApplePendingLaunchRuntimeExecutor.execute(
            input: BASApplePendingLaunchRuntimeInput(
                preferredModeID: nil,
                scenarioID: "buy",
                promptSeed: " hold this "
            ),
            performCapture: { plan in
                calls.append("primary:\(plan.scenarioID ?? "nil"):\(plan.promptSeed)")
            },
            performPresent: { _ in
                calls.append("open")
            },
            performRoutedInput: { _ in
                calls.append("route")
            }
        )

        #expect(calls == ["primary:buy:hold this"])
    }

    @Test("lifecycle entry source executor prefers handoff over pending launch")
    func lifecycleEntrySourceExecutorPrefersHandoffOverPendingLaunch() {
        var calls: [String] = []

        BASAppleLifecycleEntrySourceExecutor.execute(
            consumeHandoff: { "handoff" },
            handleHandoff: { calls.append($0) },
            consumePendingRequest: { "pending" },
            handlePendingRequest: { calls.append($0) }
        )

        #expect(calls == ["handoff"])
    }

    @Test("workspace restore executor skips when restore is not eligible")
    func workspaceRestoreExecutorSkipsWhenIneligible() {
        var calls: [String] = []

        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: false,
                hasActivePrimaryWorkflow: false,
                hasActiveComparativeWorkflow: false,
                hasActiveReflectiveWorkflow: false,
                hasReflectionContext: false
            ),
            loadState: { "primary" },
            modeID: { $0 },
            restorePrimary: { _ in calls.append("primary") },
            restoreComparative: { _ in calls.append("comparative") },
            restoreReflective: { _ in calls.append("reflective") },
            selectHomeTab: { calls.append("home") },
            afterRestore: { calls.append("after") }
        )

        #expect(calls.isEmpty)
    }

    @Test("workspace restore executor restores the selected mode then runs post actions")
    func workspaceRestoreExecutorRestoresSelectedModeThenRunsPostActions() {
        var calls: [String] = []

        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: true,
                hasActivePrimaryWorkflow: false,
                hasActiveComparativeWorkflow: false,
                hasActiveReflectiveWorkflow: false,
                hasReflectionContext: false
            ),
            loadState: { BASDecisionMode.reflectiveID },
            modeID: { $0 },
            restorePrimary: { _ in calls.append("primary") },
            restoreComparative: { _ in calls.append("comparative") },
            restoreReflective: { _ in calls.append("reflective") },
            selectHomeTab: { calls.append("home") },
            afterRestore: { calls.append("after") }
        )

        #expect(calls == ["reflective", "home", "after"])
    }
}
