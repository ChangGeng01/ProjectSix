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

        #expect(plan.actionKind == .quickCapture)
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
            performQuickCapture: { _ in calls.append("quick") },
            performOpenMode: { action in
                calls.append("open:\(action.preferredModeID ?? "nil"):\(action.promptSeed)")
            },
            performRoutedPrompt: { _ in calls.append("route") }
        )

        #expect(calls == ["open:balance:reopen this"])
    }

    @Test("workspace restore executor skips when restore is not eligible")
    func workspaceRestoreExecutorSkipsWhenIneligible() {
        var calls: [String] = []

        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: false,
                hasActiveQuickSession: false,
                hasActiveBalanceSession: false,
                hasActiveMirrorSession: false,
                hasReflectionContext: false
            ),
            loadState: { "quick" },
            modeID: { $0 },
            restoreQuick: { _ in calls.append("quick") },
            restoreBalance: { _ in calls.append("balance") },
            restoreMirror: { _ in calls.append("mirror") },
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
                hasActiveQuickSession: false,
                hasActiveBalanceSession: false,
                hasActiveMirrorSession: false,
                hasReflectionContext: false
            ),
            loadState: { "mirror" },
            modeID: { $0 },
            restoreQuick: { _ in calls.append("quick") },
            restoreBalance: { _ in calls.append("balance") },
            restoreMirror: { _ in calls.append("mirror") },
            selectHomeTab: { calls.append("home") },
            afterRestore: { calls.append("after") }
        )

        #expect(calls == ["mirror", "home", "after"])
    }
}
