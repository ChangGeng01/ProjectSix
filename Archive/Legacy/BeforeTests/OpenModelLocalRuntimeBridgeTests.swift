import XCTest
@testable import Before

final class OpenModelLocalRuntimeBridgeTests: XCTestCase {
    func testStatusReportsHeuristicPreviewReadiness() {
        let bridge = DynamicOpenModelLocalRuntimeBridge()
        let asset = OpenModelAsset(fileName: "mistral-7b.gguf", fileSizeBytes: 4_200)

        let status = bridge.status(for: asset)

        XCTAssertTrue(status.canServeRequests)
        XCTAssertEqual(status.mode, .heuristicPreview)
        XCTAssertEqual(status.title, "Heuristic preview")
        XCTAssertTrue(status.detail.contains("local heuristic adapter"))
    }

    func testBridgeDelegatesQuickAndReminderToInjectedLocalAdapter() async {
        let localAdapter = RecordingLocalModelAdapter()
        let bridge = DynamicOpenModelLocalRuntimeBridge(localAdapter: localAdapter)
        let asset = OpenModelAsset(fileName: "phi-4.gguf", fileSizeBytes: 8_000)
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.leaveStimulus]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "I want a reward."
        )
        let candidates = [
            ReminderSelectionCandidate(id: UUID(), content: "First", rank: 0),
            ReminderSelectionCandidate(id: UUID(), content: "Chosen", rank: 1)
        ]

        let refined = await bridge.refineQuickResult(
            asset: asset,
            base: base,
            input: input,
            strategy: nil,
            contextState: nil,
            neuralState: nil,
            brainState: nil
        )
        let reminder = await bridge.pickReminder(
            asset: asset,
            from: candidates,
            scenario: .buy,
            prompt: "Need a practical replacement.",
            mode: .quick,
            strategy: nil
        )

        XCTAssertEqual(refined?.currentPerspective, "Stub current")
        XCTAssertEqual(refined?.afterPerspective, "Stub after")
        XCTAssertEqual(reminder?.content, "Chosen")
    }
}

private struct RecordingLocalModelAdapter: LocalModelAdapting {
    func route(prompt: String, scenario: ScenarioType?, fallback: RoutedDecision) -> RoutedDecision {
        fallback
    }

    func enhanceQuickResult(_ result: QuickCheckResult, input: QuickCheckInput) -> QuickCheckResult {
        QuickCheckResult(
            currentPerspective: "Stub current",
            afterPerspective: "Stub after",
            verdict: result.verdict,
            primaryAction: result.primaryAction,
            secondaryActions: result.secondaryActions
        )
    }

    func enhanceBalanceResult(_ result: BalanceBoardResult, input: BalanceBoardInput) -> BalanceBoardResult {
        result
    }

    func enhanceMirrorResult(_ result: MirrorResult, input: MirrorInput) -> MirrorResult {
        result
    }

    func pickReminder(
        from orderedCandidates: [String],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> String? {
        orderedCandidates.last
    }
}
