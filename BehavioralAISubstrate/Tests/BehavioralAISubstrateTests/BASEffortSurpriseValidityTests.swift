import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASAppleAdapters
@testable import BASMLXAdapter
import BASMemory
import BASOrgan

/// VALIDITY check for the effort loop's core premise: that semantic SURPRISE (the probe's prediction error over
/// turn embeddings) is a good proxy for DIFFICULTY (turns that actually need more compute). I flagged this as
/// conceptually shaky — surprise measures conversational NOVELTY, not reasoning difficulty. This dissociates the
/// two with controlled turns (REAL MiniLM, no 4B needed) and reports the numbers, so the premise is MEASURED, not
/// assumed. Gated BAS_EFFORT_VALIDITY=1.
final class BASEffortSurpriseValidityTests: XCTestCase {

    private func probe() throws -> BASTurnSurpriseProbe {
        let p = try XCTUnwrap(BASTurnSurpriseProbe(), "MiniLM provider must be available")
        return p
    }
    private func skipUnlessReady() throws {
        guard ProcessInfo.processInfo.environment["BAS_EFFORT_VALIDITY"] == "1" else {
            throw XCTSkip("set BAS_EFFORT_VALIDITY=1 to measure surprise-vs-difficulty (real MiniLM)")
        }
    }
    /// Tier the allocator would pick for a given surprise at a FIXED moderate stakes (isolates the surprise axis).
    private func tier(_ surprise: Double) -> BASEffortLevel {
        BASEffortAllocator.resolve(surprise: surprise, stakes: 0.6, headroom: 1.0).applied
    }

    /// TEST A — difficulty-blindness: at matched (cold-start) novelty, does the probe assign MORE surprise to a
    /// genuinely HARD turn than a TRIVIAL one? If easy ≈ hard, the probe cannot tell difficulty apart.
    func testColdStartSurpriseDoesNotTrackDifficulty() async throws {
        try skipUnlessReady()
        let cases: [(label: String, turn: String)] = [
            ("EASY", "What is 2 plus 2?"),
            ("EASY", "What color is grass?"),
            ("HARD", "Prove that the square root of 2 is irrational."),
            ("HARD", "Derive the closed-form energy levels of a hydrogen atom from the Schrodinger equation."),
        ]
        print("=== A: cold-start surprise per turn (fresh probe each) — does it track DIFFICULTY? ===")
        var easy: [Double] = [], hard: [Double] = []
        for c in cases {
            let p = try probe()
            let mse = await p.observe(turn: c.turn) ?? 0
            let s = BASEffortSignals.surprise(fromMSE: mse)
            print("  [\(c.label)] surprise=\(String(format: "%.3f", s)) tier=\(tier(s).rawValue)  | \(c.turn)")
            if c.label == "EASY" { easy.append(s) } else { hard.append(s) }
        }
        let easyAvg = easy.reduce(0,+)/Double(easy.count), hardAvg = hard.reduce(0,+)/Double(hard.count)
        print("  A VERDICT: easyAvg=\(String(format: "%.3f", easyAvg)) hardAvg=\(String(format: "%.3f", hardAvg)) " +
              "→ \(hardAvg > easyAvg + 0.1 ? "tracks difficulty" : "DIFFICULTY-BLIND (surprise ~ same for easy & hard)")")
    }

    /// TEST C — the deeper question: does the REASONING MODEL already self-allocate effort? Qwen3.5 does extended
    /// "Thinking Process" — if its own output length scales with difficulty, an EXTERNAL effort gate is redundant
    /// (the model already spends more compute on hard turns). Measures output length on a controlled easy/hard
    /// set. Heavy (loads the 4B) — gated BAS_EFFORT_VALIDITY_4B=1.
    func testReasoningModelSelfAllocatesEffort() async throws {
        guard ProcessInfo.processInfo.environment["BAS_EFFORT_VALIDITY_4B"] == "1" else {
            throw XCTSkip("set BAS_EFFORT_VALIDITY_4B=1 to measure whether the 4B's own thinking length tracks difficulty")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)

        func length(_ turn: String) async -> Int {
            let req = BASOrganRequest(requestID: "len", role: .core, preset: .core, instruction: turn, context: [])
            var body = ""
            do { for try await c in organ.streamDraft(req) { body = c.cumulativeBody } } catch { return -1 }
            return body.split(whereSeparator: { $0 == " " || $0 == "\n" }).count   // word count ~ thinking depth
        }
        let easy = ["What is 2 plus 2?", "What color is grass?", "What is the capital of France?", "Is water wet?"]
        let hard = ["Prove that the square root of 2 is irrational.",
                    "Derive the closed-form energy levels of a hydrogen atom from the Schrodinger equation.",
                    "What is 6371 multiplied by 8429? Show full working.",
                    "Explain rigorously why P versus NP remains unresolved."]
        print("=== C: does the reasoning model self-allocate (output length vs difficulty)? ===")
        var easyLen = 0, hardLen = 0
        for t in easy { let n = await length(t); easyLen += n; print("  [EASY] words=\(n) | \(t)") }
        for t in hard { let n = await length(t); hardLen += n; print("  [HARD] words=\(n) | \(t)") }
        let ea = Double(easyLen)/4, ha = Double(hardLen)/4
        print("  C VERDICT: easyAvg=\(Int(ea)) words, hardAvg=\(Int(ha)) words → " +
              "\(ha > ea * 1.5 ? "MODEL SELF-ALLOCATES (thinks ~\(String(format: "%.1f", ha/max(ea,1)))× longer on hard) ⇒ external effort gate is redundant" : "no strong self-allocation signal")")
    }

    /// TEST B — novelty dominates difficulty: a TRIVIAL topic-SHIFT vs a HARD CONTINUATION of the current topic.
    /// If the easy-but-novel turn earns MORE surprise (and tier) than the hard-but-familiar one, the loop spends
    /// compute on the wrong axis.
    func testNoveltyOutweighsDifficulty() async throws {
        try skipUnlessReady()

        // Hard CONTINUATION: settle on arithmetic, then a genuinely hard arithmetic turn (same topic ⇒ low novelty).
        let p1 = try probe()
        for t in ["What is 2 plus 2?", "What is 3 plus 3?", "What is 5 plus 5?"] { _ = await p1.observe(turn: t) }
        let hardContMSE = await p1.observe(turn: "What is 6371 multiplied by 8429?") ?? 0
        let hardCont = BASEffortSignals.surprise(fromMSE: hardContMSE)

        // Easy SHIFT: settle on cooking, then a trivial arithmetic turn (topic shift ⇒ high novelty).
        let p2 = try probe()
        for t in ["How do I boil pasta?", "How long should I cook rice?", "What temperature to bake bread?"] { _ = await p2.observe(turn: t) }
        let easyShiftMSE = await p2.observe(turn: "What is 1 plus 1?") ?? 0
        let easyShift = BASEffortSignals.surprise(fromMSE: easyShiftMSE)

        print("=== B: novelty vs difficulty ===")
        print("  HARD continuation (6371×8429, same topic): surprise=\(String(format: "%.3f", hardCont)) tier=\(tier(hardCont).rawValue)")
        print("  EASY topic-shift (1+1, after cooking):     surprise=\(String(format: "%.3f", easyShift)) tier=\(tier(easyShift).rawValue)")
        print("  B VERDICT: \(easyShift > hardCont ? "NOVELTY WINS — the trivial topic-shift earns MORE effort than the hard turn (wrong axis)" : "difficulty held up against novelty")")
    }
}
