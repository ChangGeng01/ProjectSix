import XCTest
@testable import BASMLXAdapter
import BASOrgan

/// CGR offline validation (the frontier playbook's "measure before build"). Tests the premise CGR rests on — that
/// the model's OWN answer-confidence is a real DIFFICULTY signal (high when it already knows ⇒ thinking is waste;
/// low when it needs to reason). Uses teacher-forced answer-token probability (no-think) on Qwen3.5-4B-4bit. If the
/// model's no-think confidence in the CORRECT answer is high for easy turns and low for hard turns, CGR's intrinsic
/// signal separates difficulty (unlike my external surprise/length signals) ⇒ build the interceptor. If it does
/// NOT separate, CGR is dead before any decode-loop code. Gated BAS_CGR_VALIDATE=1.
final class BASCGRValidityTests: XCTestCase {

    // (question, correct answer). Easy = the model knows without thinking; Hard = the multi-step cliff I measured.
    private let easy: [(q: String, a: String)] = [
        ("What is 2 plus 2?", "4"),
        ("What is the capital of France?", "Paris"),
        ("Who wrote the novel 1984?", "Orwell"),
        ("What is the largest planet in the solar system?", "Jupiter"),
    ]
    private let hard: [(q: String, a: String)] = [
        ("What is 47 multiplied by 89?", "4183"),
        ("What is 6371 multiplied by 8429?", "53701159"),
        ("What is the next number in the sequence 2, 6, 12, 20, 30?", "42"),
        ("If today is Wednesday, what day of the week is it 100 days from now?", "Friday"),
    ]

    func testNoThinkConfidenceSeparatesDifficulty() async throws {
        guard ProcessInfo.processInfo.environment["BAS_CGR_VALIDATE"] == "1" else {
            throw XCTSkip("set BAS_CGR_VALIDATE=1 to teacher-force Qwen3.5-4B and measure no-think answer confidence")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)

        // Generate the model's OWN no-think answer (correctly aligned), then teacher-force ITS tokens to get the
        // model's self-confidence in its own answer (mean prob). Also record whether that answer is CORRECT. CGR's
        // premise: self-confidence is HIGH where the model already knows (easy ⇒ stop early) and LOW where it must
        // reason (hard ⇒ keep thinking). The honest failure mode to watch: CONFIDENTLY-WRONG on hard turns.
        func measure(_ q: String, _ correct: String) async -> (conf: Double, correct: Bool, ans: String) {
            let req = BASOrganRequest(requestID: "cgr", role: .core, preset: .core,
                                      instruction: q + " /no_think", context: [])
            var body = ""
            do { for try await c in organ.streamDraft(req) { body = c.cumulativeBody } } catch { return (-1, false, "ERR") }
            let answer = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !answer.isEmpty,
                  let probs = try? await organ.teacherForcedAnswerConfidence(for: req, answer: answer),
                  !probs.isEmpty else { return (-1, false, answer) }
            let mean = probs.reduce(0, +) / Float(probs.count)
            let isCorrect = answer.lowercased().contains(correct.lowercased())
            return (Double(mean), isCorrect, String(answer.prefix(40)))
        }

        print("=== CGR VALIDATION — model's self-confidence in its OWN no-think answer; separate easy from hard? ===")
        var easySum = 0.0, hardSum = 0.0, easyOK = 0, hardOK = 0
        for c in easy { let m = await measure(c.q, c.a); easySum += m.conf; easyOK += m.correct ? 1 : 0
            print(String(format: "  [EASY] meanP=%.3f correct=%@ | %@ → %@", m.conf, m.correct ? "Y":"N", c.q, m.ans)) }
        for c in hard { let m = await measure(c.q, c.a); hardSum += m.conf; hardOK += m.correct ? 1 : 0
            print(String(format: "  [HARD] meanP=%.3f correct=%@ | %@ → %@", m.conf, m.correct ? "Y":"N", c.q, m.ans)) }
        let ea = easySum / Double(easy.count), ha = hardSum / Double(hard.count)
        print(String(format: "  CGR VERDICT: easy meanP=%.3f (%d/%d correct), hard meanP=%.3f (%d/%d correct) → %@",
                     ea, easyOK, easy.count, ha, hardOK, hard.count,
                     ea > ha * 1.3 ? "SEPARATES (self-confidence tracks difficulty ⇒ CGR viable)"
                       : "does NOT separate (model is confidently-wrong on hard ⇒ CGR's stop-signal would mis-fire)"))
    }
}
