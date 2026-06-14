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
}
