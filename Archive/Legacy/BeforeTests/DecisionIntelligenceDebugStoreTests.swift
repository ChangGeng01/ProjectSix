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

    @Test
    func tracePrivacySanitizesSensitivePayloadOutsideTestingContext() {
        #expect(
            DecisionIntelligenceTracePrivacy.allowsSensitivePayload(
                environment: [:],
                considerRuntimeTestingContext: false
            ) == false
        )

        let prompt = DecisionIntelligenceTracePrivacy.sanitizedPrompt(
            detail: "Provider succeeded without fallback.",
            semanticPromptFingerprint: "semantic-1",
            stablePrefixFingerprint: "prefix-1",
            promptBudget: DecisionIntelligencePromptContract.ContextBudget(
                targetCharacters: 640,
                prefixCharacters: 180,
                suffixCharacters: 220
            )
        )
        let outputPreview = DecisionIntelligenceTracePrivacy.sanitizedOutputPreview(
            outputPreview: "Sensitive output preview"
        )

        #expect(prompt.contains("[REDACTED LIVE PROMPT]"))
        #expect(prompt.contains("Provider succeeded without fallback."))
        #expect(prompt.contains("semantic_fingerprint=semantic-1"))
        #expect(prompt.contains("stable_prefix=prefix-1"))
        #expect(prompt.contains("budget=target=640, actual=400, within=true"))
        #expect(prompt.contains("Sensitive output preview") == false)
        #expect(outputPreview.contains("[REDACTED LIVE OUTPUT PREVIEW]"))
        #expect(outputPreview.contains("length="))
        #expect(outputPreview.contains("Sensitive output preview") == false)
    }

    @Test
    func tracePrivacyAllowsSensitivePayloadForTestingOverrides() {
        let environment = DecisionTestingInterface.launchEnvironment(stubProfile: .smoke)

        #expect(DecisionIntelligenceTracePrivacy.allowsSensitivePayload(environment: environment) == true)
        #expect(
            DecisionIntelligenceTracePrivacy.allowsSensitivePayload(
                environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]
            ) == true
        )
    }
}
