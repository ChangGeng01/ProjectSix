import XCTest
@testable import BASHostKit

/// Validates the thinking gate against the MEASURED think-on / think-off data (BASThinkingCapValidityTests, run
/// 2026-06-30 on Qwen3.5-4B-4bit). Pure — no model. The gate must keep thinking exactly on the turns where
/// thinking-off broke correctness (multi-digit arithmetic), and the PROJECTED gated outcome must recover full
/// correctness at a fraction of the compute.
final class BASThinkingGateTests: XCTestCase {

    /// (turn, needsThinkingExpected, thinkOnCorrect, thinkOffCorrect, thinkOnWords, thinkOffWords) — measured.
    private let measured: [(turn: String, gate: Bool, onOK: Bool, offOK: Bool, onW: Int, offW: Int)] = [
        ("What is 2 plus 2? Answer concisely.", false, true, true, 239, 5),
        ("What is the capital of France? Answer concisely.", false, true, true, 537, 6),
        ("Who wrote the novel 1984? Answer concisely.", false, true, true, 584, 26),
        ("What is the largest planet in the solar system? Answer concisely.", false, true, true, 680, 33),
        ("What is 47 multiplied by 89? Answer concisely.", true, true, false, 514, 6),
        ("Is 91 a prime number? Answer concisely.", false, true, true, 531, 34),
        ("A train travels 60 mph for 2.5 hours. How many miles does it travel? Answer concisely.", false, true, true, 572, 26),
        ("What is 6371 multiplied by 8429? Answer concisely.", true, true, false, 433, 6),
    ]

    func testGateClassifiesMeasuredTurns() {
        for m in measured {
            XCTAssertEqual(BASThinkingGate.needsThinking(m.turn), m.gate,
                           "gate misclassified: \(m.turn)")
        }
    }

    /// The gate must keep thinking on EVERY turn where thinking-off lost correctness — otherwise it would ship a
    /// quality regression. (Necessary condition: no false "no-think" on a turn that needed thinking.)
    func testGateNeverSkipsThinkingWhereItWasNeeded() {
        for m in measured where m.onOK && !m.offOK {   // think-off broke this turn
            XCTAssertTrue(BASThinkingGate.needsThinking(m.turn),
                          "gate must KEEP thinking where thinking-off broke correctness: \(m.turn)")
        }
    }

    func testProjectedGatedOutcomeRecoversQualityAtLowerCompute() {
        var gatedCorrect = 0, gatedWords = 0, allThinkWords = 0, allOffCorrect = 0
        for m in measured {
            let think = BASThinkingGate.needsThinking(m.turn)
            gatedCorrect += (think ? m.onOK : m.offOK) ? 1 : 0
            gatedWords += think ? m.onW : m.offW
            allThinkWords += m.onW
            allOffCorrect += m.offOK ? 1 : 0
        }
        let n = measured.count
        let savings = Int((1.0 - Double(gatedWords) / Double(allThinkWords)) * 100)
        print("=== THINKING GATE (projected from measured data) ===")
        print("  gated:        \(gatedCorrect)/\(n) correct, \(gatedWords) words  (\(savings)% fewer than always-think)")
        print("  always-think: \(n)/\(n) correct, \(allThinkWords) words")
        print("  blanket-off:  \(allOffCorrect)/\(n) correct, (lost \(n - allOffCorrect) computation turns)")
        // The gate must recover FULL correctness (matching always-think) while spending materially less compute.
        XCTAssertEqual(gatedCorrect, n, "gate must recover full correctness")
        XCTAssertGreaterThan(savings, 50, "gate must save materially vs always-think")
        XCTAssertGreaterThan(gatedCorrect, allOffCorrect, "gate must beat blanket thinking-off on quality")
    }
}
