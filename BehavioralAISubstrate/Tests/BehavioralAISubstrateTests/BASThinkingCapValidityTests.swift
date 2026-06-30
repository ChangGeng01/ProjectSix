import XCTest
@testable import BASMLXAdapter
@testable import BASHostKit
import BASOrgan

/// VALIDATE (before building) the grounded compute lever: does turning the reasoning model's thinking OFF actually
/// save compute, and what is the QUALITY cost — and does it concentrate on HARD turns (so a gate could spare them)?
/// Run TWICE on the same turns: thinking ON (no env) then thinking OFF (BAS_DISABLE_THINKING=1). Each turn has a
/// checkable answer, so this measures BOTH words (compute) and correctness (quality). Gated BAS_THINKCAP=1.
final class BASThinkingCapValidityTests: XCTestCase {

    /// (turn, substring the correct answer must contain, isHard).
    private let cases: [(turn: String, answer: String, hard: Bool)] = [
        ("What is 2 plus 2? Answer concisely.", "4", false),
        ("What is the capital of France? Answer concisely.", "paris", false),
        ("Who wrote the novel 1984? Answer concisely.", "orwell", false),
        ("What is the largest planet in the solar system? Answer concisely.", "jupiter", false),
        ("What is 47 multiplied by 89? Answer concisely.", "4183", true),
        ("Is 91 a prime number? Answer concisely.", "no", true),
        ("A train travels 60 mph for 2.5 hours. How many miles does it travel? Answer concisely.", "150", true),
        ("What is 6371 multiplied by 8429? Answer concisely.", "53701159", true),
    ]

    func testThinkingCapComputeAndQuality() async throws {
        guard ProcessInfo.processInfo.environment["BAS_THINKCAP"] == "1" else {
            throw XCTSkip("set BAS_THINKCAP=1 (run once plain for thinking ON, once with BAS_DISABLE_THINKING=1 for OFF)")
        }
        let thinkingOff = ProcessInfo.processInfo.environment["BAS_DISABLE_THINKING"] == "1"
        let label = thinkingOff ? "THINK_OFF" : "THINK_ON"

        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)

        func run(_ turn: String) async -> String {
            let req = BASOrganRequest(requestID: "tc", role: .core, preset: .core, instruction: turn, context: [])
            var body = ""
            do { for try await c in organ.streamDraft(req) { body = c.cumulativeBody } } catch { return "" }
            return body
        }
        func words(_ s: String) -> Int { s.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }

        print("=== THINKCAP \(label) — words (compute) + correctness (quality) per turn ===")
        var easyW = 0, easyC = 0, easyN = 0, hardW = 0, hardC = 0, hardN = 0
        for c in cases {
            let body = await run(c.turn)
            let w = words(body)
            let correct = body.lowercased().contains(c.answer)
            print("  \(label)|\(c.hard ? "HARD" : "EASY")|words=\(w)|correct=\(correct) | \(c.turn.prefix(48))")
            if c.hard { hardW += w; hardC += correct ? 1 : 0; hardN += 1 }
            else      { easyW += w; easyC += correct ? 1 : 0; easyN += 1 }
        }
        print("  \(label) SUMMARY — EASY: \(easyC)/\(easyN) correct, avg \(easyW/max(easyN,1)) words | " +
              "HARD: \(hardC)/\(hardN) correct, avg \(hardW/max(hardN,1)) words")
    }

    /// GENERALIZATION: genuinely-hard NON-arithmetic reasoning traps (where thinking plausibly matters) — does
    /// thinking-off break them, and does BASThinkingGate (multi-digit + multiply cue) CATCH them? If off breaks
    /// them AND the gate says no-think, the gate does NOT generalize beyond arithmetic. Gated BAS_THINKGEN=1;
    /// run once plain (ON) + once with BAS_DISABLE_THINKING=1 (OFF).
    func testGeneralizationHardReasoning() async throws {
        guard ProcessInfo.processInfo.environment["BAS_THINKGEN"] == "1" else {
            throw XCTSkip("set BAS_THINKGEN=1 (+ BAS_DISABLE_THINKING=1 for the OFF pass)")
        }
        let thinkingOff = ProcessInfo.processInfo.environment["BAS_DISABLE_THINKING"] == "1"
        let label = thinkingOff ? "GEN_OFF" : "GEN_ON"
        let cases: [(turn: String, answer: String)] = [
            ("A bat and a ball cost $1.10 in total. The bat costs $1.00 more than the ball. How much does the ball cost in dollars? Answer concisely.", "0.05"),
            ("How many times does the letter r appear in the word strawberry? Answer with a number only.", "3"),
            ("What is the next number in the sequence 2, 6, 12, 20, 30? Answer with a number only.", "42"),
            ("If today is Wednesday, what day of the week is it 100 days from now? Answer with the day name only.", "friday"),
            ("Which is larger, 9.11 or 9.9? Answer with the number only.", "9.9"),
            ("A farmer has 17 sheep and all but 9 die. How many are left? Answer with a number only.", "9"),
        ]
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)
        func body(_ turn: String) async -> String {
            let req = BASOrganRequest(requestID: "g", role: .core, preset: .core, instruction: turn, context: [])
            var b = ""; do { for try await c in organ.streamDraft(req) { b = c.cumulativeBody } } catch { return "" }
            return b
        }
        print("=== \(label) — hard non-arithmetic reasoning: correct? + would the GATE keep thinking? ===")
        var correct = 0
        for c in cases {
            let r = await body(c.turn)
            let ok = r.lowercased().contains(c.answer.lowercased())
            let gate = BASThinkingGate.needsThinking(c.turn)
            correct += ok ? 1 : 0
            print("  \(label)|correct=\(ok)|gateKeepsThinking=\(gate) | \(c.turn.prefix(52))")
        }
        print("  \(label) SUMMARY — \(correct)/\(cases.count) correct")
    }
}
