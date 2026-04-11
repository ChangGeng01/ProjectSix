import Testing
@testable import BASAppleAdapters

struct BASAppleAppLifecycleOrchestrationTests {
    @Test("app lifecycle orchestration prefers handoff over pending request during generic bootstrap")
    func appLifecycleOrchestrationPrefersHandoffOverPendingRequestDuringGenericBootstrap() {
        var actions: [String] = []

        BASAppleAppLifecycleOrchestrationExecutor.execute(
            phase: .initialAppearance,
            refreshMemoryProjection: { actions.append("projection") },
            refreshCurrentBrain: { actions.append("brain:\($0)") },
            presentPendingReflection: { actions.append("reflection") },
            consumeHandoff: { "handoff" },
            handleHandoff: { envelope in
                actions.append("handoff:\(envelope)")
            },
            consumePendingRequest: { "pending" },
            handlePendingRequest: { request in
                actions.append("pending:\(request)")
            },
            restoreActiveWorkspace: { actions.append("restore") },
            refreshPredictedIntervention: { actions.append("prediction") },
            syncWidgetSnapshot: { actions.append("widget") }
        )

        #expect(
            actions == [
                "projection",
                "brain:launch",
                "handoff:handoff"
            ]
        )
    }

    @Test("app lifecycle orchestration falls back to pending request when no handoff exists")
    func appLifecycleOrchestrationFallsBackToPendingRequestWhenNoHandoffExists() {
        var actions: [String] = []

        BASAppleAppLifecycleOrchestrationExecutor.consumeEntriesIfNeeded(
            consumeHandoff: { Optional<String>.none },
            handleHandoff: { envelope in
                actions.append("handoff:\(envelope)")
            },
            consumePendingRequest: { "pending" },
            handlePendingRequest: { request in
                actions.append("pending:\(request)")
            }
        )

        #expect(actions == ["pending:pending"])
    }
}
