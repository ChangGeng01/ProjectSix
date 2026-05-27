import Testing
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Lifecycle Bootstrap Executor")
struct BASAppleLifecycleBootstrapExecutorTests {
    @Test("executor preserves generic initial appearance action order")
    func executorPreservesGenericInitialAppearanceActionOrder() {
        var calls: [String] = []

        BASAppleLifecycleBootstrapExecutor.execute(
            phase: .initialAppearance,
            refreshMemoryProjection: { calls.append("refreshMemoryProjection") },
            refreshCurrentBrain: { calls.append("refreshCurrentBrain:\($0)") },
            presentPendingReflection: { calls.append("presentPendingReflection") },
            consumePendingLaunchRequest: { calls.append("consumePendingLaunchRequest") },
            restoreActiveWorkspace: { calls.append("restoreActiveWorkspace") },
            refreshPredictedIntervention: { calls.append("refreshPredictedIntervention") },
            syncWidgetSnapshot: { calls.append("syncWidgetSnapshot") }
        )

        #expect(calls == [
            "refreshMemoryProjection",
            "refreshCurrentBrain:launch",
            "consumePendingLaunchRequest"
        ])
    }

    @Test("executor falls back to explicit refresh when trigger id is missing")
    func executorFallsBackToExplicitRefreshWhenTriggerIsMissing() {
        var triggerIDs: [String] = []

        BASAppleLifecycleBootstrapExecutor.execute(
            phase: .sceneActive,
            refreshMemoryProjection: {},
            refreshCurrentBrain: { triggerIDs.append($0) },
            presentPendingReflection: {},
            consumePendingLaunchRequest: {},
            restoreActiveWorkspace: {},
            refreshPredictedIntervention: {}
        )

        #expect(triggerIDs == ["sceneActive"])
    }

    @Test("current brain runtime executor primes a session after refreshing memory")
    func currentBrainRuntimeExecutorPrimesSessionAfterRefreshingMemory() {
        var calls: [String] = []

        let currentBrain = BASAppleCurrentBrainRuntimeExecutor.primeSession(
            modeID: "primary",
            promptFragments: ["  should ", "I", "wait?  "],
            retrievalMode: "filtered",
            refreshMemoryProjection: {
                calls.append("refresh")
            },
            bootstrapCurrentBrain: { plan in
                calls.append("bootstrap:\(plan.modeID):\(plan.promptSeed):\(plan.retrievalMode):\(plan.triggerID)")
                return "brain"
            },
            afterBootstrap: { currentBrain in
                calls.append("after:\(currentBrain)")
            }
        )

        #expect(currentBrain == "brain")
        #expect(calls == [
            "refresh",
            "bootstrap:primary:should I wait?:filtered:\(BASCurrentBrainBootstrapTrigger.sessionBootstrapID)",
            "after:brain"
        ])
    }

    @Test("current brain runtime executor refreshes the active brain with task graph fallback")
    func currentBrainRuntimeExecutorRefreshesActiveBrainWithTaskGraphFallback() {
        var calls: [String] = []

        let currentBrain = BASAppleCurrentBrainRuntimeExecutor.refreshActiveBrain(
            promptFragmentsByModeID: [:],
            modePriority: ["primary", "comparative", "reflective"],
            taskGraphModeID: "reflective",
            taskGraphPromptSeed: "resume this",
            retrievalModesByModeID: ["reflective": "filtered"],
            triggerID: "sceneActive",
            refreshMemoryProjection: {
                calls.append("refresh")
            },
            bootstrapCurrentBrain: { plan in
                calls.append("bootstrap:\(plan.modeID):\(plan.promptSeed):\(plan.retrievalMode):\(plan.triggerID)")
                return "current"
            }
        )

        #expect(currentBrain == "current")
        #expect(calls == [
            "refresh",
            "bootstrap:reflective:resume this:filtered:sceneActive"
        ])
    }
}
#endif
