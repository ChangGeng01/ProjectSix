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
}
