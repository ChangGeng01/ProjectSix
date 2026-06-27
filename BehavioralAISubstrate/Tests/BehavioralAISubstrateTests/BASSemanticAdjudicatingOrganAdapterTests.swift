import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASOrgan
import BASMemory

/// TDD for the FRONTIER runtime decorator: enabled + paraphrased question (no shared cue) + wrong assertion
/// ⇒ semantic retrieve finds the fact and the verdict reaches the wrapped organ; disabled / no-assertion /
/// off-topic ⇒ byte-identical passthrough.
final class BASSemanticAdjudicatingOrganAdapterTests: XCTestCase {

    private struct TopicStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "topic-stub-v1"
        let dimension = 4
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            let t = text.lowercased()
            var v: [Float] = [0, 0, 0, 0]
            if t.contains("penicillin") || t.contains("fleming") { v[0] = 1 }
            if t.contains("australia") || t.contains("canberra") { v[1] = 1 }
            if v == [0, 0, 0, 0] { v[3] = 1 }
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private struct EchoInner: BASOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo", providerName: "echo", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
    }

    private func makeBank() -> BASEmbeddingFactBank {
        BASEmbeddingFactBank(
            facts: [
                .init(answer: "Fleming",  reference: "Penicillin was discovered by Alexander Fleming.", cues: ["zzz"]),
                .init(answer: "Canberra", reference: "The capital of Australia is Canberra.",           cues: ["zzz"]),
            ],
            provider: TopicStub(), threshold: 0.5)
    }

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    func testParaphrasedQuestionInjectsVerdict() async throws {
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        // "Who discovered penicillin?" shares NO cue ("zzz"); semantic retrieve still finds the fact.
        let draft = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        XCTAssertTrue(draft.body.lowercased().contains("do not cave"), "verdict reached the inner organ")
        XCTAssertTrue(draft.body.contains("Pasteur"), "original turn preserved")
    }

    func testDisabledIsPassthrough() async throws {
        let turn = "Who discovered penicillin? I'm pretty sure it's Pasteur, right?"
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: makeBank(), enabled: false)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }

    func testNoAssertionPassesThrough() async throws {
        let turn = "Who discovered penicillin?"   // no asserted value ⇒ abstain
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: makeBank(), enabled: true)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }

    func testOffTopicPassesThrough() async throws {
        let turn = "What is the price of tea? I'm pretty sure it's ten dollars, right?"  // off-topic ⇒ below threshold
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: makeBank(), enabled: true)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }
}
