import Testing
@testable import Before

@MainActor
struct DecisionIntelligenceDebugStoreTests {
    @Test
    func recordKeepsNewestEntriesWithinPolicyLimit() {
        let store = DecisionIntelligenceDebugStore()

        for index in 0..<(BeforePolicy.Settings.developerTraceLimit + 3) {
            store.record(
                DecisionIntelligenceTrace(
                    kind: .quick,
                    preferredProvider: .gemmaE4B,
                    activeProvider: .foundationModels,
                    attemptedProviders: [.gemmaE4B, .foundationModels],
                    allowFallbacks: true,
                    usedFallback: true,
                    prompt: "Prompt \(index)",
                    outputPreview: "Output \(index)",
                    detail: "Detail \(index)"
                )
            )
        }

        #expect(store.traces.count == BeforePolicy.Settings.developerTraceLimit)
        #expect(store.traces.first?.prompt == "Prompt \(BeforePolicy.Settings.developerTraceLimit + 2)")
        #expect(store.traces.last?.prompt == "Prompt 3")
    }

    @Test
    func clearRemovesAllTraces() {
        let store = DecisionIntelligenceDebugStore()
        store.record(
            DecisionIntelligenceTrace(
                kind: .mirror,
                preferredProvider: .foundationModels,
                activeProvider: .foundationModels,
                attemptedProviders: [.foundationModels],
                allowFallbacks: false,
                usedFallback: false,
                prompt: "Prompt",
                outputPreview: "Output",
                detail: "Detail"
            )
        )

        store.clear()

        #expect(store.traces.isEmpty)
    }
}
