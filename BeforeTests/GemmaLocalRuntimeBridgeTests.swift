import XCTest
@testable import Before

final class GemmaLocalRuntimeBridgeTests: XCTestCase {
    func testMissingLibraryStatusIsNotReady() {
        let bridge = DynamicGemmaLocalRuntimeBridge(loadState: .missingLibrary)

        XCTAssertFalse(bridge.status.canRunInference)
        XCTAssertEqual(bridge.status.title, "Library missing")
    }

    func testMissingSymbolsStatusExplainsIncompatibility() {
        let bridge = DynamicGemmaLocalRuntimeBridge(
            loadState: .missingSymbols(
                GemmaRuntimeLibraryAsset(
                    fileName: "LiteRTLM",
                    path: "/tmp/LiteRTLM"
                ),
                ["litert_lm_session_generate_content"]
            )
        )

        XCTAssertFalse(bridge.status.canRunInference)
        XCTAssertEqual(bridge.status.title, "Incompatible")
        XCTAssertTrue(bridge.status.detail.contains("litert_lm_session_generate_content"))
    }

    func testQuickRefinementUsesRuntimeOutputAndPreservesVerdictAndActions() async {
        let promptRecorder = PromptRecorder()
        let bridge = DynamicGemmaLocalRuntimeBridge(
            loadState: .ready(
                GemmaRuntimeLibraryAsset(
                    fileName: "LiteRTLM",
                    path: "/tmp/LiteRTLM"
                ),
                { prompt, _, _ in
                    promptRecorder.store(prompt)
                    return """
                    CURRENT: You want relief quickly, not another loop.
                    AFTER: Tomorrow this will probably feel more like a patch than a choice.
                    """
                }
            ),
            modelPathProvider: { "/tmp/gemma-4-E4B-it.litertlm" }
        )

        let base = QuickCheckResult(
            currentPerspective: "Base current",
            afterPerspective: "Base after",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow, .goAheadAnyway]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "I am tired."
        )
        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            preferredProvider: .gemmaE4B,
            contextBudget: 220,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            responseLanguage: .chinese,
            allowsModelInvocation: true
        )

        let refined = await bridge.refineQuickResult(
            base: base,
            input: input,
            strategy: strategy
        )

        XCTAssertEqual(
            refined?.currentPerspective,
            "You want relief quickly, not another loop."
        )
        XCTAssertEqual(
            refined?.afterPerspective,
            "Tomorrow this will probably feel more like a patch than a choice."
        )
        XCTAssertEqual(refined?.verdict, .pause)
        XCTAssertEqual(refined?.primaryAction, .wait90s)
        XCTAssertEqual(refined?.secondaryActions, [.decideTomorrow, .goAheadAnyway])

        let capturedPrompt = promptRecorder.value
        XCTAssertNotNil(capturedPrompt)
        XCTAssertTrue(capturedPrompt?.contains("\"response_language\":\"chinese\"") == true)
        XCTAssertTrue(capturedPrompt?.contains("Keep the user-facing output in Chinese unless the structured format says otherwise.") == true)
    }

    func testQuickRefinementReturnsNilWithoutModelPath() async {
        let bridge = DynamicGemmaLocalRuntimeBridge(
            loadState: .ready(
                GemmaRuntimeLibraryAsset(
                    fileName: "LiteRTLM",
                    path: "/tmp/LiteRTLM"
                ),
                { _, _, _ in
                    """
                    CURRENT: Refined current.
                    AFTER: Refined after.
                    """
                }
            ),
            modelPathProvider: { nil }
        )

        let base = QuickCheckResult(
            currentPerspective: "Base current",
            afterPerspective: "Base after",
            verdict: .goAhead,
            primaryAction: .continueMindfully,
            secondaryActions: []
        )
        let input = QuickCheckInput(
            scenario: .other,
            motivation: .genuineNeed,
            expectedOutcome: .satisfied,
            controlLevel: .yes,
            note: ""
        )

        let refined = await bridge.refineQuickResult(base: base, input: input)

        XCTAssertNil(refined)
    }
}

private final class PromptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: String?

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func store(_ prompt: String) {
        lock.lock()
        storedValue = prompt
        lock.unlock()
    }
}
