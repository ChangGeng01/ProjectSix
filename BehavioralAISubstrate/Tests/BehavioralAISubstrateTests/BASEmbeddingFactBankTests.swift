import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASMemory

/// TDD for Phase-1 semantic retrieval. Uses a controlled topic-stub embedding provider (real semantics need
/// the MiniLM model + calibration, measured separately) to prove the MECHANICS: cosine top-1 retrieves the
/// right fact even when it shares NO distinctive token with the question (the substring gate's failure), and
/// the threshold abstains on off-topic questions (the coverage gate).
final class BASEmbeddingFactBankTests: XCTestCase {

    /// Topic-keyed vectors so similarity is controllable + deterministic.
    private struct TopicStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "topic-stub-v1"
        let dimension = 4
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            let t = text.lowercased()
            var v: [Float] = [0, 0, 0, 0]
            if t.contains("australia") || t.contains("canberra") { v[0] = 1 }
            if t.contains("canada") || t.contains("ottawa") { v[1] = 1 }
            if t.contains("penicillin") || t.contains("fleming") { v[2] = 1 }
            if v == [0, 0, 0, 0] { v[3] = 1 }   // off-topic ⇒ orthogonal to every fact
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    // cues are deliberately a dummy that would NOT substring-match the live questions — proving semantic > substring.
    private let facts = [
        BASVerifiedFact(answer: "Canberra", reference: "The capital of Australia is Canberra.", cues: ["zzz"]),
        BASVerifiedFact(answer: "Ottawa",   reference: "The capital of Canada is Ottawa.",      cues: ["zzz"]),
        BASVerifiedFact(answer: "Fleming",  reference: "Penicillin was discovered by Alexander Fleming.", cues: ["zzz"]),
    ]

    func testSemanticRetrievalContradictsWrongAssertion() async {
        let bank = BASEmbeddingFactBank(facts: facts, provider: TopicStub(), threshold: 0.5)
        // "Who discovered penicillin?" — the OLD substring gate (cue "zzz") would abstain; semantic matches.
        let r = await bank.resolve(question: "Who discovered penicillin?", assertedValue: "Pasteur")
        XCTAssertEqual(r?.reference, "Penicillin was discovered by Alexander Fleming.")
        XCTAssertEqual(r?.groundTruth, .contradicts)   // user said Pasteur, fact says Fleming
    }

    func testSemanticRetrievalAgreesRightAssertion() async {
        let bank = BASEmbeddingFactBank(facts: facts, provider: TopicStub(), threshold: 0.5)
        let r = await bank.resolve(question: "the capital of australia", assertedValue: "Canberra")
        XCTAssertEqual(r?.groundTruth, .agrees)
    }

    func testOffTopicBelowThresholdAbstains() async {
        let bank = BASEmbeddingFactBank(facts: facts, provider: TopicStub(), threshold: 0.5)
        // orthogonal vector ⇒ cosine 0 < 0.5 ⇒ abstain (coverage gate — no confident wrong-fact retrieval)
        let r = await bank.resolve(question: "What is the price of tea in Shanghai?", assertedValue: "ten yuan")
        XCTAssertNil(r)
    }

    func testEmptyAssertionAbstains() async {
        let bank = BASEmbeddingFactBank(facts: facts, provider: TopicStub(), threshold: 0.5)
        let r = await bank.resolve(question: "the capital of australia", assertedValue: "  ")
        XCTAssertNil(r)
    }

    func testHighThresholdMakesItStricter() async {
        // threshold 1.01 is unreachable ⇒ always abstain (verifies the gate is the cosine floor)
        let bank = BASEmbeddingFactBank(facts: facts, provider: TopicStub(), threshold: 1.01)
        let r = await bank.resolve(question: "the capital of australia", assertedValue: "Canberra")
        XCTAssertNil(r)
    }

    // MARK: CRAG margin gate — a close runner-up ⇒ ambiguous ⇒ abstain (anti confident-wrong-retrieval)

    private struct VecStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "vec"
        let dimension = 3
        let m: [String: [Float]]
        func embed(_ t: String) async -> BASMemory.BASEmbedding {
            BASMemory.BASEmbedding(vector: m[t] ?? [0, 0, 1], dimension: 3, providerVersion: providerVersion)
        }
    }

    func testClearWinnerFires() async {
        let stub = VecStub(m: ["alpha fact": [1, 0, 0], "beta fact": [0, 1, 0], "near alpha": [1, 0, 0]])
        let f = [BASVerifiedFact(answer: "A", reference: "alpha fact", cues: ["x"]),
                 BASVerifiedFact(answer: "B", reference: "beta fact", cues: ["x"])]
        let bank = BASEmbeddingFactBank(facts: f, provider: stub, threshold: 0.4, margin: 0.05)
        let r = await bank.resolve(question: "near alpha", assertedValue: "wrong")
        XCTAssertEqual(r?.reference, "alpha fact")     // margin 1.0 ⇒ fires
    }

    func testAmbiguousRunnerUpAbstains() async {
        let stub = VecStub(m: ["alpha fact": [1, 0, 0], "beta fact": [0, 1, 0],
                               "alpha-ish fact": [0.98, 0.2, 0], "near alpha": [1, 0, 0]])
        let f = [BASVerifiedFact(answer: "A", reference: "alpha fact", cues: ["x"]),
                 BASVerifiedFact(answer: "B", reference: "beta fact", cues: ["x"]),
                 BASVerifiedFact(answer: "C", reference: "alpha-ish fact", cues: ["x"])]
        let bank = BASEmbeddingFactBank(facts: f, provider: stub, threshold: 0.4, margin: 0.05)
        let r = await bank.resolve(question: "near alpha", assertedValue: "wrong")
        XCTAssertNil(r)   // top-1 1.0 vs top-2 ≈0.98 ⇒ margin 0.02 < 0.05 ⇒ ambiguous ⇒ abstain
    }
}
