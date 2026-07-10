import XCTest
@testable import BASOrgan

/// Host proof for the framework-free `BASSaguaroLoop` (the Mamba∥MLX spec-decode round logic). Uses mock draft +
/// target so it runs with no MLX/CoreAI. Pins the two load-bearing invariants:
///   1. **Byte-identity** — the committed stream equals the target's own greedy output for ANY draft (a wrong
///      draft only lowers acceptance, never changes a token). This is the ADR-039 / 红线 7 property.
///   2. **The silent-corruption detector** — `accepted/rounds` ≈ K when the draft matches the target, → 0 when it
///      doesn't. A broken draft rewind would stay byte-identical but collapse acceptance; this is the only signal.
@available(iOS 16.0, macOS 13.0, *)
final class BASSaguaroLoopTests: XCTestCase {

    /// Emits a fixed `truth` sequence regardless of the draft, modeling a KV cache via the `fed` cursor (verify
    /// feeds seed+draft → +1+draft.count; trimRejected removes the rejected → net +1+acc per round).
    final class MockTarget: BASSaguaroTarget, @unchecked Sendable {
        let truth: [Int]
        let eos: Set<Int>
        var fed = 0
        init(truth: [Int], eos: Set<Int> = []) { self.truth = truth; self.eos = eos }
        func prefill() throws -> (firstToken: Int, isEOS: Bool) {
            fed = 0
            return (truth[0], eos.contains(truth[0]))
        }
        func verify(committedLast seed: Int, draft: [Int]) throws -> [Int] {
            var out: [Int] = []
            var i = 0
            while i <= draft.count { out.append(truth[fed + 1 + i]); i += 1 }
            fed += 1 + draft.count
            return out
        }
        func trimRejected(_ rejected: Int) { fed -= rejected }
    }

    /// Either proposes the true continuation (perfect → full accept) or garbage (wrong → zero accept).
    final class MockDraft: BASSaguaroDraft, @unchecked Sendable {
        let truth: [Int]
        let perfect: Bool
        var genCount = 1
        init(truth: [Int], perfect: Bool) { self.truth = truth; self.perfect = perfect }
        func reset() { genCount = 1 }
        func prefill(_ tokens: [Int]) async throws { genCount = 1 }
        func propose(seed: Int, k: Int) async throws -> [Int] {
            perfect ? (0..<k).map { truth[genCount + $0] } : Array(repeating: -999, count: k)
        }
        func commit(acc: Int, correction: Int) async throws { genCount += acc + 1 }
    }

    func testPerfectDraft_byteIdentical_fullAcceptance() async throws {
        let truth = Array(0..<500)
        let maxTokens = 60
        let r = try await BASSaguaroLoop.generate(
            promptTokens: [7, 8, 9],
            draft: MockDraft(truth: truth, perfect: true),
            target: MockTarget(truth: truth),
            eosTokenIds: [], maxTokens: maxTokens, numDraftTokens: 4)
        XCTAssertEqual(r.tokens, Array(truth.prefix(maxTokens)))   // byte-identity
        XCTAssertEqual(r.accepted, r.proposed)                      // every proposal accepted
        XCTAssertGreaterThan(r.meanAccepted, 3.5)                   // ≈ K=4 (rewind is sound)
    }

    func testWrongDraft_stillByteIdentical_zeroAcceptance() async throws {
        let truth = Array(0..<500)
        let maxTokens = 30
        let r = try await BASSaguaroLoop.generate(
            promptTokens: [7, 8, 9],
            draft: MockDraft(truth: truth, perfect: false),
            target: MockTarget(truth: truth),
            eosTokenIds: [], maxTokens: maxTokens, numDraftTokens: 4)
        XCTAssertEqual(r.tokens, Array(truth.prefix(maxTokens)))   // byte-identity holds DESPITE a wrong draft
        XCTAssertEqual(r.accepted, 0)                               // nothing accepted
        XCTAssertEqual(r.rounds, maxTokens - 1)                     // 1 token/round (pure autoregressive fallback)
    }

    func testStopBeforeEOS_terminatorNotEmitted() async throws {
        var truth = Array(0..<500); truth[10] = 42                  // EOS token at index 10
        let r = try await BASSaguaroLoop.generate(
            promptTokens: [1],
            draft: MockDraft(truth: truth, perfect: true),
            target: MockTarget(truth: truth, eos: [42]),
            eosTokenIds: [42], maxTokens: 100, numDraftTokens: 4)
        XCTAssertEqual(r.tokens, Array(truth.prefix(10)))           // 0…9, stops before truth[10]=42
        XCTAssertFalse(r.tokens.contains(42))                       // terminator never emitted
    }

    // audit organ-eval LOW-4: an EOS token INSIDE the accepted prefix stops emission before those
    // drafts are committed — `accepted` must not count them. `accepted` can never exceed the number
    // of tokens actually emitted (the old `accepted += acc` counted the whole accepted prefix).
    func testEOSInsideAcceptedPrefixDoesNotOvercountAccepted() async throws {
        var truth = Array(0..<500); truth[2] = 42        // EOS at index 2 (inside round 1's accepted prefix)
        let r = try await BASSaguaroLoop.generate(
            promptTokens: [1],
            draft: MockDraft(truth: truth, perfect: true),   // every proposed draft matches (acc = K)
            target: MockTarget(truth: truth, eos: [42]),
            eosTokenIds: [42], maxTokens: 100, numDraftTokens: 4)
        XCTAssertFalse(r.tokens.contains(42), "the EOS terminator is not emitted")
        XCTAssertLessThanOrEqual(r.accepted, r.tokens.count,
            "accepted draft tokens must never exceed emitted tokens (no over-count when EOS truncates the prefix)")
    }

    func testKZero_isPureAutoregressive_noDraftCalls() async throws {
        let truth = Array(0..<500)
        let draft = MockDraft(truth: truth, perfect: true)
        let r = try await BASSaguaroLoop.generate(
            promptTokens: [7],
            draft: draft, target: MockTarget(truth: truth),
            eosTokenIds: [], maxTokens: 20, numDraftTokens: 0)
        XCTAssertEqual(r.tokens, Array(truth.prefix(20)))           // identical with K=0
        XCTAssertEqual(r.proposed, 0)                               // draft never proposed
        XCTAssertEqual(draft.genCount, 1)                           // draft prefill/commit never ran
    }
}
