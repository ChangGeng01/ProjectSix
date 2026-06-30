import XCTest
@testable import BASMLXAdapter
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
}
