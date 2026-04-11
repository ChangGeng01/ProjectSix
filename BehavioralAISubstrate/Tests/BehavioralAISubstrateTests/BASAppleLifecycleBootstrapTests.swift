import Testing
@testable import BASAppleAdapters

struct BASAppleLifecycleBootstrapTests {
    @Test("initial appearance lifecycle plan keeps the full bootstrap order")
    func initialAppearanceLifecyclePlanKeepsTheFullBootstrapOrder() {
        let actions = BASAppleLifecycleBootstrapPlanner.actions(for: .initialAppearance)

        #expect(actions.map(\.kind) == [
            .refreshMemoryProjection,
            .refreshCurrentBrain,
            .presentPendingReflection,
            .consumePendingLaunchRequest,
            .restoreActiveWorkspace,
            .refreshPredictedIntervention,
            .syncWidgetSnapshot
        ])
        #expect(actions[1].currentBrainTriggerID == "launch")
    }

    @Test("scene active lifecycle plan skips widget sync and uses scene trigger")
    func sceneActiveLifecyclePlanSkipsWidgetSyncAndUsesSceneTrigger() {
        let actions = BASAppleLifecycleBootstrapPlanner.actions(for: .sceneActive)

        #expect(actions.map(\.kind) == [
            .refreshMemoryProjection,
            .refreshCurrentBrain,
            .presentPendingReflection,
            .consumePendingLaunchRequest,
            .restoreActiveWorkspace,
            .refreshPredictedIntervention
        ])
        #expect(actions[1].currentBrainTriggerID == "sceneActive")
    }

    @Test("session prime plan compacts prompt fragments and preserves retrieval mode")
    func sessionPrimePlanCompactsPromptFragmentsAndPreservesRetrievalMode() {
        let plan = BASAppleCurrentBrainRuntimePlanner.sessionPrimePlan(
            modeID: "reflective",
            promptFragments: ["  first  ", "", "second"],
            retrievalMode: "filtered"
        )

        #expect(plan.modeID == "reflective")
        #expect(plan.promptSeed == "first second")
        #expect(plan.retrievalMode == "filtered")
        #expect(plan.triggerID == "sessionPrime")
    }

    @Test("active refresh plan resolves active seed and retrieval mode by mode id")
    func activeRefreshPlanResolvesActiveSeedAndRetrievalModeByModeID() {
        let plan = BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
            promptFragmentsByModeID: [
                "comparative": ["should", "win"]
            ],
            modePriority: ["primary", "comparative", "reflective"],
            taskGraphModeID: "reflective",
            taskGraphPromptSeed: "ignored",
            retrievalModesByModeID: [
                "primary": "off",
                "comparative": "adaptive",
                "reflective": "filtered"
            ]
        )

        #expect(plan.modeID == "comparative")
        #expect(plan.promptSeed == "should win")
        #expect(plan.retrievalMode == "adaptive")
        #expect(plan.triggerID == "explicitRefresh")
    }

    @Test("active refresh plan falls back to task graph and default retrieval mode")
    func activeRefreshPlanFallsBackToTaskGraphAndDefaultRetrievalMode() {
        let plan = BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
            promptFragmentsByModeID: [:],
            modePriority: ["primary", "comparative", "reflective"],
            taskGraphModeID: "reflective",
            taskGraphPromptSeed: "resume this",
            retrievalModesByModeID: [:]
        )

        #expect(plan.modeID == "reflective")
        #expect(plan.promptSeed == "resume this")
        #expect(plan.retrievalMode == "adaptive")
    }
}
