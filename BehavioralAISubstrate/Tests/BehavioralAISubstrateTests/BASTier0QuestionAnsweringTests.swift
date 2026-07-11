import XCTest
@testable import BASHostKit
import BASMemory
import BASSovereign
import BASOrgan

/// tier-0 expansion (2026-07-11, operator-directed "tier-0 扩展也做掉 用 NLI question-fit 门"):
/// covered QUESTION-form turns answer straight from the fact bank (ZERO LLM calls) — guarded by
/// the deterministic NLI question-fit gate, which also now guards the existing assertion
/// short-circuit (closing the 0.82-cosine qualifier breach for both).
final class BASTier0QuestionAnsweringTests: XCTestCase {

    /// Deterministic provider: fixed vectors per known text; the question and its fact share a
    /// vector (cosine 1.0), off-corpus is orthogonal.
    private final class FixtureProvider: BASMemory.BASEmbeddingProvider, @unchecked Sendable {
        var providerVersion: String { "t0-v1" }
        var dimension: Int { 4 }
        var table: [String: [Float]] = [:]
        func embed(_ text: String) async -> BASEmbedding {
            let v = table[text.lowercased()] ?? [0, 0, 0, 1]
            return BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private final class CountingInner: BASOrganAdapter, @unchecked Sendable {
        var draftCalls = 0
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "counting.inner", providerName: "counting",
                               supportsStreaming: false, maxInputTokens: 4096,
                               maxOutputTokens: 256, runsOnDevice: true,
                               supportedRoles: [.scout, .core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            draftCalls += 1
            return BASOrganDraft(
                requestID: request.requestID, providerID: "counting.inner", role: request.role,
                body: "LLM-ANSWER", inputTokensEstimated: 1, outputTokensEstimated: 1,
                producedAt: Date(), traceID: "t")
        }
    }

    private func makeStack(tier0: Bool = true)
        -> (adapter: BASSemanticAdjudicatingOrganAdapter, inner: CountingInner) {
        let provider = FixtureProvider()
        let auQ = "what is the capital of australia?"
        let auBreach = "what is the capital of australia's largest state?"
        let shared: [Float] = [1, 0, 0, 0]
        provider.table[auQ] = shared
        provider.table[auBreach] = shared            // cosine 1.0 — the breach: topic-identical
        provider.table["the capital of australia is canberra."] = shared
        let facts = [BASVerifiedFact(
            answer: "Canberra",
            reference: "The capital of Australia is Canberra.",
            cues: [])]
        let bank = BASEmbeddingFactBank(facts: facts, provider: provider)
        let inner = CountingInner()
        let adapter = BASSemanticAdjudicatingOrganAdapter(
            wrapping: inner, bank: bank, enabled: true,
            shortCircuitCovered: true, tier0QuestionAnswering: tier0)
        return (adapter, inner)
    }

    private func req(_ text: String) -> BASOrganRequest {
        BASOrganRequest(requestID: UUID().uuidString, role: .scout, preset: .scout,
                        instruction: text, context: [])
    }

    func testCoveredQuestionAnswersWithZeroLLMCalls() async throws {
        let (adapter, inner) = makeStack()
        let draft = try await adapter.draft(req("What is the capital of Australia?"))
        XCTAssertEqual(inner.draftCalls, 0, "tier-0: the covered question never reaches the LLM")
        XCTAssertTrue(draft.body.contains("Canberra"), "the bank's ANSWER is the draft: \(draft.body)")
    }

    func testQualifierBreachFallsThroughToLLM() async throws {
        // The 0.82-class breach at cosine 1.0 here — WITHOUT the fit gate this would answer
        // Canberra to a question about Australia's largest state (non-sequitur).
        let (adapter, inner) = makeStack()
        let draft = try await adapter.draft(req("What is the capital of Australia's largest state?"))
        XCTAssertEqual(inner.draftCalls, 1, "question-fit UNFIT ⇒ the LLM answers, tier-0 abstains")
        XCTAssertEqual(draft.body, "LLM-ANSWER")
    }

    func testOffCorpusFallsThroughToLLM() async throws {
        let (adapter, inner) = makeStack()
        _ = try await adapter.draft(req("What is the airspeed of an unladen swallow?"))
        XCTAssertEqual(inner.draftCalls, 1, "below the CRAG gate ⇒ normal LLM path")
    }

    func testDefaultOffIsByteParity() async throws {
        let (adapter, inner) = makeStack(tier0: false)
        let draft = try await adapter.draft(req("What is the capital of Australia?"))
        XCTAssertEqual(inner.draftCalls, 1, "tier0QuestionAnswering=false ⇒ LLM answers (ADR-014)")
        XCTAssertEqual(draft.body, "LLM-ANSWER")
    }
}
