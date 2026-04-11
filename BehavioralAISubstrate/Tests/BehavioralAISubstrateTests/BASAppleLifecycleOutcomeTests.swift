import Foundation
import Testing
@testable import BASAppleAdapters

@Suite("BASApple Lifecycle Outcomes")
struct BASAppleLifecycleOutcomeTests {
    @Test("pending launch builder prefers explicit scenario over preferred mode")
    func pendingLaunchBuilderPrefersScenario() {
        let plan = BASApplePendingLaunchOutcomeBuilder.resolve(
            preferredModeID: "mirror",
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
            preferredModeID: "balance",
            scenarioID: nil,
            promptSeed: " reopen this "
        )

        BASApplePendingLaunchOutcomeExecutor.execute(
            plan: plan,
            performCapture: { _ in calls.append("quick") },
            performPresent: { action in
                calls.append("open:\(action.preferredModeID ?? "nil"):\(action.promptSeed)")
            },
            performRoutedInput: { _ in calls.append("route") }
        )

        #expect(calls == ["open:balance:reopen this"])
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
                calls.append("quick:\(plan.scenarioID ?? "nil"):\(plan.promptSeed)")
            },
            performPresent: { _ in
                calls.append("open")
            },
            performRoutedInput: { _ in
                calls.append("route")
            }
        )

        #expect(calls == ["quick:buy:hold this"])
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
            loadState: { "quick" },
            modeID: { $0 },
            restorePrimary: { _ in calls.append("quick") },
            restoreComparative: { _ in calls.append("balance") },
            restoreReflective: { _ in calls.append("mirror") },
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
            loadState: { "mirror" },
            modeID: { $0 },
            restorePrimary: { _ in calls.append("quick") },
            restoreComparative: { _ in calls.append("balance") },
            restoreReflective: { _ in calls.append("mirror") },
            selectHomeTab: { calls.append("home") },
            afterRestore: { calls.append("after") }
        )

        #expect(calls == ["mirror", "home", "after"])
    }
}
