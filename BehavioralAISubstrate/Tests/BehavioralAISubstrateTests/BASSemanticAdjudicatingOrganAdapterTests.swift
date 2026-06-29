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

    // MARK: - NLI gaslight-REDUCER hook (Phase 2)

    private func makeAdapter(nliProbe: BASNLIEntailmentProbe?, threshold: Float = 0.9) -> BASSemanticAdjudicatingOrganAdapter {
        BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: makeBank(), enabled: true,
                                            nliProbe: nliProbe, nliThreshold: threshold)
    }

    func testReconcileRescuesContradictionOnHighConfEntailment() async throws {
        let yes: BASNLIEntailmentProbe = { _, _ in (entails: true, confidence: 0.95) }
        let gt = await makeAdapter(nliProbe: yes).reconciled(.contradicts, reference: "ref", claim: "x")
        XCTAssertEqual(gt, .agrees, "a high-confidence entailment softens an alias contradiction to affirm")
    }

    func testReconcileKeepsContradictionBelowThreshold() async throws {
        let weak: BASNLIEntailmentProbe = { _, _ in (entails: true, confidence: 0.5) }   // < 0.9
        let gt = await makeAdapter(nliProbe: weak).reconciled(.contradicts, reference: "ref", claim: "x")
        XCTAssertEqual(gt, .contradicts, "a weak entailment leaves the alias verdict untouched")
    }

    func testReconcileKeepsContradictionWhenProbeDeclines() async throws {
        let none: BASNLIEntailmentProbe = { _, _ in nil }   // can't decide ⇒ no rescue (abstain-safe)
        let gt = await makeAdapter(nliProbe: none).reconciled(.contradicts, reference: "ref", claim: "x")
        XCTAssertEqual(gt, .contradicts)
    }

    func testReconcileNeverManufacturesContradiction() async throws {
        // .agrees / .unknown are NOT eligible — the reducer can only SOFTEN a correction, never create one,
        // even if the probe (wrongly) reports high-confidence non-entailment.
        let no: BASNLIEntailmentProbe = { _, _ in (entails: false, confidence: 0.99) }
        let a = await makeAdapter(nliProbe: no).reconciled(.agrees,  reference: "ref", claim: "x")
        let u = await makeAdapter(nliProbe: no).reconciled(.unknown, reference: "ref", claim: "x")
        XCTAssertEqual(a, .agrees)
        XCTAssertEqual(u, .unknown)
    }

    func testNilProbeIsByteEqual() async throws {
        let gt = await makeAdapter(nliProbe: nil).reconciled(.contradicts, reference: "ref", claim: "x")
        XCTAssertEqual(gt, .contradicts, "no probe ⇒ alias-only verify, byte-equal")
    }

    func testEndToEndProbeRescuesVerdict() async throws {
        // Pasteur ≠ Fleming ⇒ alias .contradicts ⇒ "do not cave"; a high-conf entailment stub RESCUES to affirm.
        let yes: BASNLIEntailmentProbe = { _, _ in (entails: true, confidence: 0.95) }
        let dec = makeAdapter(nliProbe: yes)
        await dec.warmUp()
        let draft = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        XCTAssertFalse(draft.body.lowercased().contains("do not cave"), "high-conf entailment softened the correction")
        XCTAssertTrue(draft.body.lowercased().contains("confirm it plainly"), "rescued to an affirm verdict")
    }
}
