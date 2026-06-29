import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASOrgan

/// Audit fix (DORMANT): the adjudicator is now constructed on a live Sources/ path (BASLLMNeuralCoreService
/// .adjudicating, called by makeDefault), opt-in + fail-open. This proves: disabled ⇒ inner unwrapped;
/// enabled ⇒ wrapped AND the full pipeline (bundled corpus + real MiniLM + retrieve+verify+verdict) fires
/// end-to-end on a wrong-assertion turn.
final class BASLLMNeuralCoreServiceAdjudicatorTests: XCTestCase {

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

    func testDisabledReturnsInnerUnwrapped() {
        let out = BASLLMNeuralCoreService.adjudicating(EchoInner(), enabled: false)
        XCTAssertFalse(out is BASSemanticAdjudicatingOrganAdapter, "default-OFF must not wrap")
    }

    func testEnabledWrapsAndInjectsVerdictEndToEnd() async throws {
        let out = BASLLMNeuralCoreService.adjudicating(EchoInner(), enabled: true)
        XCTAssertTrue(out is BASSemanticAdjudicatingOrganAdapter, "enabled must wrap with the adjudicator")
        // Full live path: bundled 1131-fact corpus + real MiniLM embed/retrieve + alias verify + verdict.
        let draft = try await out.draft(BASOrganRequest(
            requestID: "r", role: .core, preset: .core,
            instruction: "What is the capital of Australia? I'm pretty sure it's Sydney, right?", context: []))
        XCTAssertTrue(draft.body.lowercased().contains("do not cave"),
                      "a wrong-capital assertion should retrieve the fact and inject the resist verdict")
        XCTAssertTrue(draft.body.contains("Sydney"), "original turn preserved")
    }

    // audit #2 fix: the LIVE-PATH mechanism — a host chat loop resolves the organ + probes
    // `as? BASStreamingOrganAdapter`, then calls streamDraft. The wrapped organ must surface to that probe
    // and inject the verdict BEFORE the inner streams (the streaming bypass the audit found, now closed).
    private struct StreamingEcho: BASStreamingOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "secho", providerName: "secho", supportsStreaming: true,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ r: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: r.requestID, providerID: "secho", role: r.role, body: r.instruction,
                          inputTokensEstimated: 0, outputTokensEstimated: 0, producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func streamDraft(_ r: BASOrganRequest) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
            AsyncThrowingStream { c in
                c.yield(BASOrganDraftChunk(requestID: r.requestID, providerID: "secho", role: r.role,
                                           bodyDelta: r.instruction, cumulativeBody: r.instruction,
                                           producedAt: Date(timeIntervalSince1970: 0)))
                c.finish()
            }
        }
    }

    func testWrappedOrganSurfacesToStreamingProbeAndInjects() async throws {
        let wrapped = BASLLMNeuralCoreService.adjudicating(StreamingEcho(), enabled: true)
        let streaming = try XCTUnwrap(wrapped as? BASStreamingOrganAdapter,
                                      "the chat loop's as? BASStreamingOrganAdapter probe MUST resolve the wrapper")
        var body = ""
        for try await c in streaming.streamDraft(BASOrganRequest(
            requestID: "r", role: .core, preset: .core,
            instruction: "What is the capital of Australia? I'm pretty sure it's Sydney, right?", context: [])) {
            body = c.cumulativeBody
        }
        XCTAssertTrue(body.lowercased().contains("do not cave"), "verdict reaches streamDraft on the live-path mechanism")
        XCTAssertTrue(body.contains("Sydney"), "original turn preserved")
    }

    func testDisabledIsNotWrappedSoStreamIsByteEqual() {
        let out = BASLLMNeuralCoreService.adjudicating(StreamingEcho(), enabled: false)
        XCTAssertFalse(out is BASSemanticAdjudicatingOrganAdapter, "default-OFF returns the inner organ unwrapped")
    }
}
