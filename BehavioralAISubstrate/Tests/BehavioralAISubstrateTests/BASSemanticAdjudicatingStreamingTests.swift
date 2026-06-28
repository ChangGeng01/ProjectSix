import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASOrgan
import BASMemory

/// Audit fix proof: the factual-belief adjudicator decorator now conforms to `BASStreamingOrganAdapter`, so
/// the verdict reaches the LIVE `streamDraft(_:)` path (the chat loop probes `as? BASStreamingOrganAdapter`).
///
/// Before this fix the decorator overrode only `draft(_:)`, so the streaming probe was TRANSPARENT to it —
/// the inner organ's `streamDraft` was reached directly and adjudication was bypassed on every streamed turn.
///
/// These tests prove, end-to-end on the streaming path:
///   1. the wrapper resolves through the exact `as? BASStreamingOrganAdapter` probe the loop uses,
///   2. an enabled + recognized wrong-assertion turn gets the verdict prepended BEFORE the inner streams,
///   3. disabled ⇒ byte-identical stream pass-through,
///   4. FAIL-OPEN: a non-streaming inner still delivers the adjudicated turn,
///   5. the real `BASLLMNeuralCoreService.adjudicating(_:)` factory yields a streaming-capable adjudicator,
///   6. the real-runtime `BASHostRuntime.adjudicatingOrgan(_:)` seam wraps (on) / is byte-equal (off).
final class BASSemanticAdjudicatingStreamingTests: XCTestCase {

    // MARK: - Doubles

    /// Topic-only embedding so the lightweight bank resolves penicillin/Australia without the real MiniLM.
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

    /// Inner organ that STREAMS the (possibly adjudicated) instruction back as a single chunk, so a test can
    /// read exactly what request text reached the inner `streamDraft`.
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
            AsyncThrowingStream { continuation in
                continuation.yield(BASOrganDraftChunk(
                    requestID: request.requestID, providerID: "echo-stream", role: request.role,
                    bodyDelta: request.instruction, cumulativeBody: request.instruction,
                    producedAt: Date(timeIntervalSince1970: 0)))
                continuation.finish()
            }
        }
    }

    /// Reference-typed streaming inner so the default-OFF path can assert INSTANCE identity (=== ) — proving
    /// adjudicating()/adjudicatingOrgan() return the SAME object, not just a non-wrapped one.
    private final class StreamingEchoClassInner: BASStreamingOrganAdapter, @unchecked Sendable {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo-class", providerName: "echo-class", supportsStreaming: true,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo-class", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func streamDraft(_ request: BASOrganRequest) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield(BASOrganDraftChunk(
                    requestID: request.requestID, providerID: "echo-class", role: request.role,
                    bodyDelta: request.instruction, cumulativeBody: request.instruction,
                    producedAt: Date(timeIntervalSince1970: 0)))
                continuation.finish()
            }
        }
    }

    /// Inner organ that overrides BOTH accelerated overloads and tags the body with which lane was reached,
    /// so a test can prove the decorator delegates to the inner's accelerated lane (not the plain default).
    private struct LaneRecordingInner: BASOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "lane", providerName: "lane", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        private func echo(_ tag: String, _ request: BASOrganRequest) -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "lane", role: request.role,
                          body: tag + ":" + request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft { echo("plain", request) }
        func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
            echo("elect", request)
        }
        func draft(_ request: BASOrganRequest, purpose: BASDecodeLanePolicy.Purpose) async throws -> BASOrganDraft {
            echo("purpose-" + purpose.rawValue, request)
        }
    }

    /// Inner organ that ONLY implements `draft(_:)` (no streaming) — exercises the fail-open fallback.
    private struct NonStreamingEchoInner: BASOrganAdapter {
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

    // MARK: - Helpers

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

    private func collect(
        _ stream: AsyncThrowingStream<BASOrganDraftChunk, Error>
    ) async throws -> String {
        var body = ""
        for try await chunk in stream { body = chunk.cumulativeBody }
        return body
    }

    // MARK: - 1. The wrapper is no longer transparent to the streaming probe

    func testWrapperResolvesThroughStreamingProbe() {
        let dec: any BASOrganAdapter =
            BASSemanticAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), bank: makeBank(), enabled: true)
        // This is the EXACT probe the live chat loop runs (BASOrganRegistryEndpoint.streamBody).
        XCTAssertNotNil(dec as? BASStreamingOrganAdapter,
                        "decorator must surface to the loop's `as? BASStreamingOrganAdapter` probe")
    }

    // MARK: - 2. Enabled ⇒ the verdict reaches the streaming path

    func testVerdictReachesStreamingPath() async throws {
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        let body = try await collect(
            dec.streamDraft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?")))
        XCTAssertTrue(body.lowercased().contains("do not cave"),
                      "verdict must be prepended into the request the inner streamDraft consumes")
        XCTAssertTrue(body.contains("Pasteur"), "original turn preserved in the streamed request")
    }

    // MARK: - 3. Disabled ⇒ byte-identical stream pass-through

    func testDisabledStreamingIsByteEqualPassthrough() async throws {
        let turn = "Who discovered penicillin? I'm pretty sure it's Pasteur, right?"
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), bank: makeBank(), enabled: false)
        let body = try await collect(dec.streamDraft(req(turn)))
        XCTAssertEqual(body, turn, "disabled decorator must stream the inner's output unchanged")
    }

    // MARK: - 3b. No-claim / off-topic ⇒ pass-through on the streaming path too

    func testNoAssertionStreamingPassesThrough() async throws {
        let turn = "Who discovered penicillin?"   // no asserted value ⇒ abstain
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: StreamingEchoInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        let body = try await collect(dec.streamDraft(req(turn)))
        XCTAssertEqual(body, turn, "abstain ⇒ streamed request is unchanged")
    }

    // MARK: - 4. FAIL-OPEN: a non-streaming inner still delivers the adjudicated turn

    func testFailOpenNonStreamingInnerStillDeliversVerdict() async throws {
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: NonStreamingEchoInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        // The wrapper still conforms to streaming; fall back to the inner's draft() and emit one chunk.
        // Probe through an existential, exactly as the live loop does (`adapter as? BASStreamingOrganAdapter`).
        let erased: any BASOrganAdapter = dec
        let streaming = try XCTUnwrap(erased as? BASStreamingOrganAdapter)
        let body = try await collect(
            streaming.streamDraft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?")))
        XCTAssertTrue(body.lowercased().contains("do not cave"),
                      "fail-open fallback must still inject the verdict via the inner draft()")
        XCTAssertTrue(body.contains("Pasteur"), "original turn preserved in the fail-open chunk")
    }

    // MARK: - 5. The real adjudicating() factory yields a streaming-capable adjudicator

    /// Full live wrap: bundled fact corpus + real MiniLM embed/retrieve + alias verify + verdict, consumed
    /// through the streaming probe exactly as the chat loop does.
    func testRealAdjudicatingFactoryStreamsVerdict() async throws {
        let wrapped = BASLLMNeuralCoreService.adjudicating(StreamingEchoInner(), enabled: true)
        let streaming = try XCTUnwrap(wrapped as? BASStreamingOrganAdapter,
                                      "adjudicating() must return a streaming-capable wrapper when enabled")
        let body = try await collect(streaming.streamDraft(BASOrganRequest(
            requestID: "r", role: .core, preset: .core,
            instruction: "What is the capital of Australia? I'm pretty sure it's Sydney, right?", context: [])))
        XCTAssertTrue(body.lowercased().contains("do not cave"),
                      "a wrong-capital assertion should retrieve the fact and stream the resist verdict")
        XCTAssertTrue(body.contains("Sydney"), "original turn preserved on the streamed request")
    }

    // MARK: - 6. The real-runtime seam wraps (on) and is byte-equal (off)

    func testRuntimeSeamDisabledReturnsInnerUnwrapped() {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let out = runtime.adjudicatingOrgan(StreamingEchoInner(), enabled: false)
        XCTAssertFalse(out is BASSemanticAdjudicatingOrganAdapter, "default-OFF runtime seam must not wrap")
    }

    /// Constraint A (byte-equal): default-OFF must return the SAME adapter INSTANCE, not merely an unwrapped
    /// one — proven with a reference-typed inner so `===` is meaningful (audit: instance-identity untested).
    func testDisabledReturnsSameInstanceFactory() {
        let inner = StreamingEchoClassInner()
        let out = BASLLMNeuralCoreService.adjudicating(inner, enabled: false)
        XCTAssertTrue((out as AnyObject) === inner, "adjudicating(enabled:false) must return the SAME instance")
    }

    func testDisabledReturnsSameInstanceRuntimeSeam() {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let inner = StreamingEchoClassInner()
        let out = runtime.adjudicatingOrgan(inner, enabled: false)
        XCTAssertTrue((out as AnyObject) === inner, "adjudicatingOrgan(enabled:false) must return the SAME instance")
    }

    /// prewarmAdjudicator on a bare (OFF) adapter is a no-op and never substitutes/wraps it.
    func testPrewarmAdjudicatorIsNoOpOnBareAdapter() async {
        let inner = StreamingEchoClassInner()
        await BASLLMNeuralCoreService.prewarmAdjudicator(inner)   // must not crash / wrap
        let out = BASLLMNeuralCoreService.adjudicating(inner, enabled: false)
        XCTAssertTrue((out as AnyObject) === inner, "prewarm path leaves the OFF adapter identical")
    }

    func testRuntimeSeamEnabledWrapsAndStreams() async throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let out = runtime.adjudicatingOrgan(StreamingEchoInner(), enabled: true)
        let streaming = try XCTUnwrap(out as? BASStreamingOrganAdapter,
                                      "enabled runtime seam must produce a streaming-capable adjudicator")
        let body = try await collect(streaming.streamDraft(BASOrganRequest(
            requestID: "r", role: .core, preset: .core,
            instruction: "What is the capital of Australia? I'm pretty sure it's Sydney, right?", context: [])))
        XCTAssertTrue(body.lowercased().contains("do not cave"),
                      "verdict must reach streamDraft through the runtime construction seam")
    }

    // MARK: - 7. Accelerated-overload transparency (adjudicate, then keep the inner's accelerated lane)

    func testElectAcceleratedOverloadAdjudicatesAndKeepsLane() async throws {
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: LaneRecordingInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        let draft = try await dec.draft(
            req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"), electAccelerated: true)
        XCTAssertTrue(draft.body.hasPrefix("elect:"), "must delegate to the inner's accelerated overload, not plain draft()")
        XCTAssertTrue(draft.body.lowercased().contains("do not cave"), "verdict injected before the accelerated lane")
    }

    func testPurposeOverloadAdjudicatesAndKeepsLane() async throws {
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: LaneRecordingInner(), bank: makeBank(), enabled: true)
        await dec.warmUp()
        let draft = try await dec.draft(
            req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"), purpose: .factual)
        XCTAssertTrue(draft.body.hasPrefix("purpose-factual:"), "must delegate to the inner's purpose overload")
        XCTAssertTrue(draft.body.lowercased().contains("do not cave"), "verdict injected before the purpose lane")
    }

    func testAcceleratedOverloadsAreByteEqualWhenDisabled() async throws {
        let turn = "Who discovered penicillin? I'm pretty sure it's Pasteur, right?"
        let dec = BASSemanticAdjudicatingOrganAdapter(wrapping: LaneRecordingInner(), bank: makeBank(), enabled: false)
        let elect = try await dec.draft(req(turn), electAccelerated: true)
        let purpose = try await dec.draft(req(turn), purpose: .scoutDefault)
        // Default-OFF: lane preserved AND no verdict — byte-equal with the inner's own accelerated path.
        XCTAssertEqual(elect.body, "elect:" + turn)
        XCTAssertEqual(purpose.body, "purpose-scoutDefault:" + turn)
    }
}
