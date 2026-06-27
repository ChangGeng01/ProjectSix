import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASAppleAdapters

/// Audit fix (single-direction eval): the SAFETY gate. Auto-generates BIDIRECTIONAL probes from the real
/// bundled 1131-fact corpus + real MiniLM:
///   • CORRECT assertion → must NOT be `.contradicts` (a false `.contradicts` = GASLIGHT a correct user — the worst failure)
///   • WRONG   assertion → should be `.contradicts` (recall)
/// and measures the GASLIGHT RATE that actually decides whether enabling the adjudicator is safe.
/// Gated BAS_ADJ_CALIBRATE=1 (loads CoreML + embeds 1131 facts).
final class BASAdjudicatorBidirectionalSafetyTests: XCTestCase {

    private func between(_ s: String, _ a: String, _ b: String) -> String? {
        guard let lo = s.range(of: a)?.upperBound,
              let hi = s.range(of: b, range: lo ..< s.endIndex)?.lowerBound else { return nil }
        let e = String(s[lo ..< hi]).trimmingCharacters(in: .whitespaces)
        return e.isEmpty ? nil : e
    }

    /// Derive a paraphrased question + a category key from a fact's reference (the corpus drops `category`).
    private func probe(_ f: BASVerifiedFact) -> (q: String, cat: String)? {
        let r = f.reference
        if let e = between(r, "The capital of ", " is ") { return ("What is the capital city of \(e)?", "capital") }
        if let e = between(r, "The currency of ", " is ") { return ("What currency does \(e) use?", "currency") }
        if let lo = r.range(of: " is located on the continent of ")?.lowerBound {
            return ("On which continent is \(r[..<lo])?", "continent")
        }
        if let e = between(r, "The atomic number of ", " is ") { return ("What is the atomic number of \(e)?", "atomic") }
        if let e = between(r, "The chemical symbol for ", " is ") { return ("What is the chemical symbol for \(e)?", "symbol") }
        if let lo = r.range(of: " was written by ")?.lowerBound { return ("Who wrote \(r[..<lo])?", "author") }
        return nil
    }

    func testGaslightRateAndRecallAtFullScale() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BAS_ADJ_CALIBRATE"] == "1",
                          "host safety calibration — set BAS_ADJ_CALIBRATE=1")
        let facts = BASBundledFactCorpus.load()
        XCTAssertGreaterThan(facts.count, 1000)
        let provider = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let bank = BASEmbeddingFactBank(facts: facts, provider: provider)
        await bank.load()

        // answers grouped by derived category → a real-but-wrong value for the contradiction direction
        var byCat: [String: [String]] = [:]
        for f in facts { if let p = probe(f) { byCat[p.cat, default: []].append(f.answer) } }

        var gaslight = 0, correctTotal = 0, recall = 0, wrongTotal = 0, correctAbstain = 0
        var i = 0
        for f in facts {
            i += 1
            if i % 9 != 0 { continue }                       // ~125 sampled across all categories
            guard let p = probe(f), let pool = byCat[p.cat], pool.count > 3 else { continue }
            let wrong = pool.first(where: { $0.lowercased() != f.answer.lowercased() }) ?? ""
            if wrong.isEmpty { continue }

            // CORRECT direction — gaslight if it fires .contradicts
            if let r = await bank.resolve(question: p.q, assertedValue: f.answer) {
                correctTotal += 1
                if r.groundTruth == .contradicts { gaslight += 1 }
            } else { correctAbstain += 1 }

            // WRONG direction — recall
            if let r = await bank.resolve(question: p.q, assertedValue: wrong) {
                wrongTotal += 1
                if r.groundTruth == .contradicts { recall += 1 }
            }
        }

        let gRate = Double(gaslight) / Double(max(1, correctTotal))
        let rRate = Double(recall) / Double(max(1, wrongTotal))
        print("BIDIRECTIONAL @\(facts.count) facts:")
        print("  GASLIGHT (correct asserted, falsely .contradicts): \(gaslight)/\(correctTotal) = \(Int(gRate*100))%  (abstained \(correctAbstain))")
        print("  RECALL   (wrong asserted, correctly .contradicts): \(recall)/\(wrongTotal) = \(Int(rRate*100))%")
        // SAFETY gate: a correct user must rarely be contradicted. This is the number that gates enabling.
        XCTAssertLessThan(gRate, 0.10, "GASLIGHT rate must be <10% to be safe to enable")
    }
}
