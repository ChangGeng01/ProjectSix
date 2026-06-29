import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASOrgan

/// TDD for the runtime decorator: enabled + known fact + recognized wrong assertion ⇒ verdict reaches the
/// wrapped organ; disabled / no-assertion / not-covered ⇒ byte-identical passthrough (abstain).
final class BASAdjudicatingOrganAdapterTests: XCTestCase {

    private let bank = [
        BASVerifiedFact(answer: "Canberra", reference: "The capital of Australia is Canberra.",
                        cues: ["capital", "australia"])
    ]

    /// Inner organ that echoes the (possibly verdict-injected) instruction back as the draft body, so the
    /// test can see exactly what reached the model.
    private actor EchoInner: BASOrganAdapter {
        nonisolated var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo", providerName: "echo", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true,
                               supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
    }

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    func testEnabledKnownFactWrongAssertionInjectsVerdict() async throws {
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true)
        let draft = try await dec.draft(req("What is the capital of Australia? I'm pretty sure it's Sydney, right?"))
        XCTAssertTrue(draft.body.lowercased().contains("do not cave"), "verdict reached the inner organ")
        XCTAssertTrue(draft.body.contains("Sydney"), "original turn preserved")
    }

    func testDisabledIsBytePassthrough() async throws {
        let turn = "What is the capital of Australia? I'm pretty sure it's Sydney, right?"
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: false)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }

    func testNoAssertionPassesThrough() async throws {
        let turn = "What is the capital of Australia?"   // no asserted value → abstain
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }

    func testUnknownFactPassesThrough() async throws {
        let turn = "What is the GDP of France? I'm pretty sure it's 2 trillion, right?"  // not in bank → abstain
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true)
        let draft = try await dec.draft(req(turn))
        XCTAssertEqual(draft.body, turn)
    }

    // MARK: - Parity with the semantic adapter: streaming + gate + observe + accelerated

    private struct StreamingEchoInner: BASStreamingOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo-stream", providerName: "echo-stream", supportsStreaming: true,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo-stream", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func streamDraft(_ request: BASOrganRequest) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
            AsyncThrowingStream { c in
                c.yield(BASOrganDraftChunk(requestID: request.requestID, providerID: "echo-stream", role: request.role,
                                           bodyDelta: request.instruction, cumulativeBody: request.instruction,
                                           producedAt: Date(timeIntervalSince1970: 0)))
                c.finish()
            }
        }
    }
    private actor Collector {
        private(set) var outcomes: [BASAdjudicationObservationRecord.Outcome] = []
        func add(_ r: BASAdjudicationObservationRecord) { outcomes.append(r.outcome) }
    }
    private func collect(_ s: AsyncThrowingStream<BASOrganDraftChunk, Error>) async throws -> String {
        var body = ""; for try await c in s { body = c.cumulativeBody }; return body
    }
    private let wrongCapital = "What is the capital of Australia? I'm pretty sure it's Sydney, right?"

    func testStreamingProbeResolvesAndInjects() async throws {
        let dec: any BASOrganAdapter = BASAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), facts: bank, enabled: true)
        let streaming = try XCTUnwrap(dec as? BASStreamingOrganAdapter, "sibling must surface to the streaming probe")
        let body = try await collect(streaming.streamDraft(req(wrongCapital)))
        XCTAssertTrue(body.lowercased().contains("do not cave"), "verdict reaches streamDraft")
        XCTAssertTrue(body.contains("Sydney"), "original turn preserved")
    }

    func testStreamingFailOpenNonStreamingInner() async throws {
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true)
        let body = try await collect(dec.streamDraft(req(wrongCapital)))
        XCTAssertTrue(body.lowercased().contains("do not cave"), "fail-open still delivers the verdict via inner draft()")
    }

    func testDisabledStreamingByteEqual() async throws {
        let dec = BASAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), facts: bank, enabled: false)
        let body = try await collect(dec.streamDraft(req(wrongCapital)))
        XCTAssertEqual(body, wrongCapital, "disabled ⇒ streamed request unchanged")
    }

    func testGateSkipAvoidsInjectionAndRecords() async throws {
        let c = Collector()
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true,
                                              gate: .never, observer: { await c.add($0) })
        let draft = try await dec.draft(req(wrongCapital))
        XCTAssertFalse(draft.body.lowercased().contains("do not cave"), "gate skip ⇒ no verdict")
        let outs = await c.outcomes
        XCTAssertEqual(outs, [.gateSkipped])
    }

    func testObserverRecordsEachOutcome() async throws {
        let c = Collector()
        func make() -> BASAdjudicatingOrganAdapter {
            BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true, observer: { await c.add($0) })
        }
        _ = try await make().draft(req(wrongCapital))                                          // injected
        _ = try await make().draft(req("What is the capital of Australia?"))                   // noAssertion
        _ = try await make().draft(req("What is the GDP of France? I'm sure it's 2 trillion?")) // belowThreshold (not covered)
        let outs = await c.outcomes
        XCTAssertEqual(outs, [.injected, .noAssertion, .belowThreshold])
    }

    func testAcceleratedOverloadsAdjudicate() async throws {
        let dec = BASAdjudicatingOrganAdapter(wrapping: EchoInner(), facts: bank, enabled: true)
        let elect = try await dec.draft(req(wrongCapital), electAccelerated: true)
        let purpose = try await dec.draft(req(wrongCapital), purpose: .scoutDefault)
        XCTAssertTrue(elect.body.lowercased().contains("do not cave"))
        XCTAssertTrue(purpose.body.lowercased().contains("do not cave"))
    }
}
