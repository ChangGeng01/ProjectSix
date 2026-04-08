import XCTest
@testable import Before

@MainActor
final class DecisionContextLifecycleTests: XCTestCase {
    func testQuickNoteExpiresAfterTTL() {
        let lifecycle = DecisionContextLifecycle()
        let originalTime = Date(timeIntervalSinceReferenceDate: 1_000)
        lifecycle.touch(field: .quickNote, value: "I am exhausted", now: originalTime)

        let prepared = lifecycle.prepareQuickInput(
            QuickCheckInput(
                scenario: .buy,
                motivation: .stressed,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I am exhausted"
            ),
            now: originalTime.addingTimeInterval((60 * 20) + 1)
        )

        XCTAssertEqual(prepared.input.note, "")
        XCTAssertEqual(prepared.state.staleFields, [.quickNote])
    }

    func testMirrorPromptStaysWhileEmotionCanExpireAcrossRebuilds() {
        let lifecycle = DecisionContextLifecycle()
        let originalTime = Date(timeIntervalSinceReferenceDate: 2_000)
        lifecycle.touch(field: .mirrorPrompt, value: "Should I stay?", now: originalTime)
        lifecycle.touch(field: .mirrorEmotion, value: "I feel wrung out.", now: originalTime)

        _ = lifecycle.prepareMirrorInput(
            MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel wrung out.",
                relationship: "",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            now: originalTime
        )
        _ = lifecycle.prepareMirrorInput(
            MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel wrung out.",
                relationship: "",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            now: originalTime.addingTimeInterval(1)
        )
        _ = lifecycle.prepareMirrorInput(
            MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel wrung out.",
                relationship: "",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            now: originalTime.addingTimeInterval(2)
        )

        let rebuilt = lifecycle.prepareMirrorInput(
            MirrorInput(
                prompt: "Should I stay?",
                emotion: "I feel wrung out.",
                relationship: "",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            now: originalTime.addingTimeInterval((60 * 20) + 5)
        )

        XCTAssertTrue(rebuilt.state.rebuiltSession)
        XCTAssertEqual(rebuilt.input.prompt, "Should I stay?")
        XCTAssertEqual(rebuilt.input.emotion, "")
        XCTAssertTrue(rebuilt.state.activeFields.contains(.mirrorPrompt))
        XCTAssertTrue(rebuilt.state.staleFields.contains(.mirrorEmotion))
    }
}
