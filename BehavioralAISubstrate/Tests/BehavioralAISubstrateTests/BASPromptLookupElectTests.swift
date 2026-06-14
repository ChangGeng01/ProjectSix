// P1 — prompt-lookup production wiring: the `draft(_:electAccelerated:)` protocol requirement.
//
// Invariant under test (ADR-014 default-off): an adapter WITHOUT an accelerated lane (the deterministic adapter,
// and by inheritance Apple/remote adapters) MUST be BYTE-EQUAL whether or not a turn is elected — the protocol
// default impl ignores `electAccelerated` and calls `draft(_:)`. Only adapters that override it (MLX prompt-lookup)
// change behavior, and there only for greedy turns (token-identical). This guards the "nothing changes until a
// host elects AND the adapter has a lane" contract.

import XCTest
import Foundation
@testable import BASOrgan

final class BASPromptLookupElectTests: XCTestCase {

    private func request(role: BASOrganRole = .core) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "p1-elect",
            role: role,
            preset: .greedyDeterministic,
            instruction: "Extract the capital of France as JSON.",
            context: ["France is a country in Western Europe; its capital is Paris."])
    }

    func testDefaultElectAcceleratedIsByteEqualToPlainDraft() async throws {
        let req = request()
        // FRESH adapters per call so the deterministic adapter's per-instance call counter is identical (#1) for
        // each — this isolates the `electAccelerated` flag from the counter confound. A no-lane adapter's protocol
        // default IGNORES the flag, so all three bodies must be byte-equal.
        let plain = try await BASOrganDeterministicAdapter().draft(req)
        let electedTrue = try await BASOrganDeterministicAdapter().draft(req, electAccelerated: true)
        let electedFalse = try await BASOrganDeterministicAdapter().draft(req, electAccelerated: false)

        XCTAssertEqual(electedTrue.body, plain.body, "elect=true must be byte-equal for a no-lane adapter")
        XCTAssertEqual(electedFalse.body, plain.body, "elect=false must be byte-equal")
        XCTAssertEqual(electedTrue.traceID, plain.traceID)
        XCTAssertEqual(electedTrue.providerID, plain.providerID)
    }

    func testPromptLookupEligibilityPolicy() {
        // The host-side doctrine end: prompt-lookup is elected ONLY for factual/deterministic purposes,
        // never for creative/scout (free-form is -8%, must stay gated off).
        XCTAssertTrue(BASDecodeLanePolicy.promptLookupEligible(for: .factual))
        XCTAssertTrue(BASDecodeLanePolicy.promptLookupEligible(for: .deterministic))
        XCTAssertFalse(BASDecodeLanePolicy.promptLookupEligible(for: .creative))
        XCTAssertFalse(BASDecodeLanePolicy.promptLookupEligible(for: .scoutDefault))
    }

    // MARK: - P1 wrapper propagation (audit must-fix): the elect flag must REACH the inner adapter through the
    // production wrapper chain (Routing / ContractEnforcing → gate), and the contract gate must STILL fail-closed.

    func testElectPropagatesThroughRoutingWrapper() async throws {
        let spy = P1SpyAdapter()
        let routing = BASRoutingOrganAdapter(primary: spy, secondary: P1SpyAdapter(), strategy: .primaryOnly)
        _ = try await routing.draft(request(), electAccelerated: true)
        let got = await spy.lastElect
        XCTAssertEqual(got, true, "routing must FORWARD electAccelerated to the primary (not swallow it)")
    }

    func testElectPropagatesThroughContractEnforcingWrapper() async throws {
        let spy = P1SpyAdapter()
        let wrapped = BASContractEnforcingOrganAdapter(inner: spy, purpose: .verify)
        _ = try await wrapped.draft(request(), electAccelerated: true)
        let got = await spy.lastElect
        XCTAssertEqual(got, true, "contract wrapper must forward elect through the gate to the inner adapter")
    }

    func testAcceleratedPathStillFailsClosedOnForbiddenContext() async throws {
        let spy = P1SpyAdapter()
        let wrapped = BASContractEnforcingOrganAdapter(inner: spy, purpose: .verify, forbiddenContext: ["SECRET"])
        let req = BASOrganRequest(
            requestID: "p1-failclosed", role: .core, preset: .greedyDeterministic,
            instruction: "verify", context: ["SECRET"])
        do {
            _ = try await wrapped.draft(req, electAccelerated: true)
            XCTFail("a forbidden-context contract MUST throw, even on the accelerated path")
        } catch {
            let called = await spy.draftCalled
            XCTAssertFalse(called, "the model MUST NOT be called when the contract is violated (validate-before)")
        }
    }
}

/// Spy adapter: records the `electAccelerated` flag the wrappers forward + whether the model was called, to
/// prove P1 propagation reaches the inner adapter and that the contract gate fail-closes before the model.
private actor P1SpyAdapter: BASOrganAdapter {
    nonisolated let descriptor: BASOrganDescriptor
    var lastElect: Bool?
    var draftCalled = false

    init() {
        descriptor = BASOrganDescriptor(
            providerID: "p1-spy", providerName: "P1 Spy", supportsStreaming: false,
            maxInputTokens: 4096, maxOutputTokens: 1024, runsOnDevice: true,
            supportedRoles: [.scout, .core])
    }

    func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        draftCalled = true
        return BASOrganDraft(
            requestID: request.requestID, providerID: "p1-spy", role: request.role,
            body: "spy-body", inputTokensEstimated: 1, outputTokensEstimated: 1,
            producedAt: Date(), traceID: "spy-trace")
    }

    func draft(_ request: BASOrganRequest, electAccelerated: Bool) async throws -> BASOrganDraft {
        lastElect = electAccelerated
        return try await draft(request)
    }

    func currentCapacity() async -> BASOrganCapacity { .unlimited }
}
