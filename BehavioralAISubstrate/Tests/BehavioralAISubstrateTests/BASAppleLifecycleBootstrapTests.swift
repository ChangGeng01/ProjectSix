import Testing
@testable import BASAppleAdapters

struct BASAppleLifecycleBootstrapTests {
    @Test("initial appearance lifecycle plan keeps the minimal generic bootstrap order")
    func initialAppearanceLifecyclePlanKeepsTheMinimalGenericBootstrapOrder() {
        let actions = BASAppleLifecycleBootstrapPlanner.actions(for: .initialAppearance)

        #expect(actions.map(\.kind) == [
            .refreshMemoryProjection,
            .refreshCurrentBrain,
            .consumePendingLaunchRequest
        ])
        #expect(actions[1].bootstrapTriggerID == "launch")
    }

    @Test("scene active lifecycle plan keeps the minimal generic refresh order")
    func sceneActiveLifecyclePlanKeepsTheMinimalGenericRefreshOrder() {
        let actions = BASAppleLifecycleBootstrapPlanner.actions(for: .sceneActive)

        #expect(actions.map(\.kind) == [
            .refreshMemoryProjection,
            .refreshCurrentBrain,
            .consumePendingLaunchRequest
        ])
        #expect(actions[1].bootstrapTriggerID == "sceneActive")
    }

    @Test("custom lifecycle behavior lets host own bootstrap order and active refresh defaults")
    func customLifecycleBehaviorLetsHostOwnBootstrapOrderAndActiveRefreshDefaults() {
        let behavior = BASAppleLifecycleBootstrapBehavior(
            actionsByPhaseID: [
                BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshCurrentBrain, bootstrapTriggerID: "hostLaunch"),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                ]
            ],
            activeRefreshDefaultModeID: "reflective",
            activeRefreshDefaultRetrievalModeID: "filtered"
        )

        let actions = BASAppleLifecycleBootstrapPlanner.actions(
            for: .initialAppearance,
            behavior: behavior
        )
        let plan = BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
            promptFragmentsByModeID: [:],
            modePriority: ["primary", "comparative", "reflective"],
            taskGraphModeID: nil,
            taskGraphPromptSeed: nil,
            retrievalModesByModeID: [:],
            behavior: behavior
        )

        #expect(actions.map(\.kind) == [.refreshCurrentBrain, .restoreActiveWorkspace])
        #expect(actions.first?.bootstrapTriggerID == "hostLaunch")
        #expect(plan.modeID == "reflective")
        #expect(plan.retrievalMode == "filtered")
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
