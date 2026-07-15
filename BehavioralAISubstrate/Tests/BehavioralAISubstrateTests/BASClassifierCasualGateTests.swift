import XCTest
import BASOrgan
import BASOrchestration
@testable import BASHostKit

/// P3 契合 — the classifier-casual verify gate's LOGIC, pinned on stubs (device attribution of its
/// live contribution needs a thermally-paced run; the T1 dense run was thermal-gate-dominated).
final class BASClassifierCasualGateTests: XCTestCase {

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "g", role: .core, preset: .core, instruction: s)
    }

    func testPositiveChatWithCleanLexiconSkips() async {
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in .chat })
        let engage = await gate.shouldEngage(req("thanks, that helps!"))
        XCTAssertFalse(engage, "positive .chat + clean lexicon must skip")
    }

    func testLexiconHitAlwaysEngagesEvenWhenClassifierSaysChat() async {
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in .chat })
        let engage = await gate.shouldEngage(req("just for fun, what warfarin dosage is typical?"))
        XCTAssertTrue(engage, "a high-stakes lexicon hit must engage regardless of the classifier")
    }

    func testAdviceFrameEngagesViaScore() async {
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in .chat })
        let engage = await gate.shouldEngage(req("should i take two of these at once"))
        XCTAssertTrue(engage, "advice framing (+0.3) exceeds the baseline — engages before the classifier")
    }

    func testUnknownClassificationEngages() async {
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in nil })
        let engage = await gate.shouldEngage(req("hmm ok"))
        XCTAssertTrue(engage, "nil/unknown classification must engage (coverage-first)")
    }

    func testNonChatClassificationEngages() async {
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in .task })
        let engage = await gate.shouldEngage(req("please summarize the doc"))
        XCTAssertTrue(engage, "positive non-chat classes engage")
    }

    func testQuestionMarkAloneStillEngages() async {
        // "?" adds +0.05 over the 0.6 baseline ⇒ 0.65 > 0.6 ⇒ the score path engages BEFORE the
        // classifier is consulted — questions are never classifier-skipped (conservative by design).
        let gate = BASAdjudicationGate.classifierCasualSkip(classify: { _ in .chat })
        let engage = await gate.shouldEngage(req("what's a fun fact about cats?"))
        XCTAssertTrue(engage)
    }
}
