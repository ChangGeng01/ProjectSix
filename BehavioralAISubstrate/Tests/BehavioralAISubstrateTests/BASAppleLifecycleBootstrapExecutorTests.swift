import Testing
@testable import BASAppleAdapters

@Suite("BASApple Lifecycle Bootstrap Executor")
struct BASAppleLifecycleBootstrapExecutorTests {
    private enum RefreshFailure: Error, Equatable { case failed }

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

    @Test("lifecycle bootstrap stops before current brain and later actions after projection failure")
    func lifecycleBootstrapStopsAfterProjectionFailure() {
        var calls: [String] = []
        #expect(throws: RefreshFailure.failed) {
            try BASAppleLifecycleBootstrapExecutor.execute(
                phase: .initialAppearance,
                refreshMemoryProjection: {
                    calls.append("projection")
                    throw RefreshFailure.failed
                },
                refreshCurrentBrain: { calls.append("brain:\($0)") },
                presentPendingReflection: { calls.append("reflection") },
                consumePendingLaunchRequest: { calls.append("pending") },
                restoreActiveWorkspace: { calls.append("restore") },
                refreshPredictedIntervention: { calls.append("prediction") }
            )
        }
        #expect(calls == ["projection"])
    }

    @Test("lifecycle bootstrap propagates current brain failure before later actions")
    func lifecycleBootstrapStopsAfterCurrentBrainFailure() {
        var calls: [String] = []
        #expect(throws: RefreshFailure.failed) {
            try BASAppleLifecycleBootstrapExecutor.execute(
                phase: .initialAppearance,
                refreshMemoryProjection: { calls.append("projection") },
                refreshCurrentBrain: {
                    calls.append("brain:\($0)")
                    throw RefreshFailure.failed
                },
                presentPendingReflection: { calls.append("reflection") },
                consumePendingLaunchRequest: { calls.append("pending") },
                restoreActiveWorkspace: { calls.append("restore") },
                refreshPredictedIntervention: { calls.append("prediction") }
            )
        }
        #expect(calls == ["projection", "brain:launch"])
    }

    @Test("session priming does not bootstrap or publish after projection failure")
    func sessionPrimingStopsAfterProjectionFailure() {
        var calls: [String] = []
        #expect(throws: RefreshFailure.failed) {
            _ = try BASAppleCurrentBrainRuntimeExecutor.primeSession(
                modeID: "primary",
                promptFragments: ["wait"],
                retrievalMode: "filtered",
                refreshMemoryProjection: {
                    calls.append("projection")
                    throw RefreshFailure.failed
                },
                bootstrapCurrentBrain: { _ in
                    calls.append("brain")
                    return "brain"
                },
                afterBootstrap: { _ in calls.append("after") }
            )
        }
        #expect(calls == ["projection"])
    }

    @Test("session priming propagates bootstrap failure without after-bootstrap publication")
    func sessionPrimingStopsAfterBootstrapFailure() {
        var calls: [String] = []
        #expect(throws: RefreshFailure.failed) {
            _ = try BASAppleCurrentBrainRuntimeExecutor.primeSession(
                modeID: "primary",
                promptFragments: ["wait"],
                retrievalMode: "filtered",
                refreshMemoryProjection: { calls.append("projection") },
                bootstrapCurrentBrain: { _ in
                    calls.append("brain")
                    throw RefreshFailure.failed
                },
                afterBootstrap: { _ in calls.append("after") }
            )
        }
        #expect(calls == ["projection", "brain"])
    }

    @Test("active brain refresh does not bootstrap after projection failure")
    func activeBrainRefreshStopsAfterProjectionFailure() {
        var bootstrapCallCount = 0
        #expect(throws: RefreshFailure.failed) {
            _ = try BASAppleCurrentBrainRuntimeExecutor.refreshActiveBrain(
                promptFragmentsByModeID: [:],
                modePriority: ["primary"],
                taskGraphModeID: nil,
                taskGraphPromptSeed: nil,
                retrievalModesByModeID: [:],
                refreshMemoryProjection: { throw RefreshFailure.failed },
                bootstrapCurrentBrain: { _ in
                    bootstrapCallCount += 1
                    return "brain"
                }
            )
        }
        #expect(bootstrapCallCount == 0)
    }
}
