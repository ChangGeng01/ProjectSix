import XCTest
import BASOrgan
import BASSovereign
import BASAppleAdapters
@testable import BASHostKit

/// 完善 — CORPUS-SCALE validation of the shipped short-circuit lever (the campaign ran on 10 inline
/// facts; production carries the 1131-fact bundled corpus). NO LLM needed — this validates the
/// deterministic side only, on-device MiniLM embeddings at full scale:
///   1. HIT correctness: corpus-derived wrong assertions must short-circuit-resolve to `.contradicts`
///      with the RIGHT reference (the two-tier bar must not starve genuine hits).
///   2. NON-SEQUITUR guard: adjacent-topic / off-corpus questions must NOT clear the answering bar
///      (cos ≥ 0.60) — the co-gate bug class, now measured at corpus scale.
///   3. COST: bank load + per-resolve latency at 1131 vectors (the avoided-compute must stay cheap).
final class BASCorpusScaleDeviceTests: XCTestCase {

    func testCorpusScaleShortCircuit() async throws {
        guard ProcessInfo.processInfo.environment["BAS_CORPUS_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_CORPUS_XCTEST=1 (device; MiniLM; no LLM)")
        }
        let facts = BASBundledFactCorpus.load()
        guard facts.count > 500 else { throw XCTSkip("bundled corpus missing (\(facts.count) facts)") }
        guard let mini = BASMiniLMEmbeddingProvider() else { throw XCTSkip("MiniLM unavailable") }
        let bank = BASEmbeddingFactBank(facts: facts, provider: mini)
        let loadT0 = Date()
        await bank.load()
        let loadMs = Date().timeIntervalSince(loadT0) * 1000
        print(String(format: "[corpus] facts=%d embed-load=%.0fms", facts.count, loadMs))

        // 1. HIT correctness — every 40th fact (~28 samples): build a wrong-assertion question from the
        // reference; the resolve must clear the ANSWERING bar and verdict .contradicts.
        var hits = 0, misses = 0, wrongVerdicts = 0
        var resolveMsTotal = 0.0
        let sampled = stride(from: 0, to: facts.count, by: 40).map { facts[$0] }
        for fact in sampled {
            let question = "\(fact.reference) — actually I'm pretty sure it's Zorblax, right?"
            let t0 = Date()
            let r = await bank.resolveWithScore(question: question, assertedValue: "zorblax")
            resolveMsTotal += Date().timeIntervalSince(t0) * 1000
            if let r, r.cosine >= BASSemanticAdjudicatingOrganAdapter.shortCircuitMinCosine {
                hits += 1
                if r.groundTruth != .contradicts { wrongVerdicts += 1 }
            } else {
                misses += 1
            }
        }

        // 2. Non-sequitur guard — questions NEAR corpus topics but asking something else: the answering
        // bar must reject (an inject-tier hit is fine; answering is not).
        let adjacents = [
            "Which is the second-largest ocean? I'm pretty sure it's the Pacific, right?",
            "Who was Einstein's closest collaborator? I'm pretty sure it's Bohr, right?",
            "What's the deepest lake in Africa? I'm pretty sure it's Victoria, right?",
            "Which planet has the most moons? I'm pretty sure it's Mars, right?",
            "Who succeeded the first US president? I'm pretty sure it's Jefferson, right?",
            "What's the longest wall after the Great Wall? I'm pretty sure it's Hadrian's, right?",
            "Which mountain is second-tallest? I'm pretty sure it's Everest, right?",
            "What's the capital of Australia's largest state? I'm pretty sure it's Canberra, right?",
        ]
        var answeringBarBreaches = 0
        for q in adjacents {
            let asserted = q.components(separatedBy: "it's ").last?
                .replacingOccurrences(of: ", right?", with: "") ?? "x"
            if let r = await bank.resolveWithScore(question: q, assertedValue: asserted),
               r.cosine >= BASSemanticAdjudicatingOrganAdapter.shortCircuitMinCosine {
                answeringBarBreaches += 1
                print("[corpus] BAR BREACH (would answer): \(q.prefix(50)) → \(r.reference.prefix(60)) cos=\(r.cosine)")
            }
        }

        let hitRate = Double(hits) / Double(max(sampled.count, 1))
        print(String(format: "[corpus] VERDICT hits=%d/%d (%.0f%%) wrong_verdicts=%d | adjacent answering-bar breaches=%d/%d | resolve=%.1fms avg",
                     hits, sampled.count, hitRate * 100, wrongVerdicts,
                     answeringBarBreaches, adjacents.count, resolveMsTotal / Double(max(sampled.count, 1))))
        XCTAssertEqual(wrongVerdicts, 0, "a cleared hit must verdict .contradicts on a wrong assertion")
        XCTAssertGreaterThanOrEqual(hitRate, 0.6,
            "the two-tier bar must not starve genuine hits (reference-derived questions)")
        XCTAssertLessThanOrEqual(answeringBarBreaches, 1,
            "adjacent-topic questions must (almost) never clear the ANSWERING bar — the non-sequitur class")
        XCTAssertLessThan(resolveMsTotal / Double(max(sampled.count, 1)), 50,
            "per-resolve cost must stay cheap at corpus scale")
    }
}
