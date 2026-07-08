import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// audit H21 — the purpose entry must route a seat request (`request.sessionID` set) to the
/// per-seat pool (`draftMultiTurn`), exactly like `draft(_:)`. Before the fix
/// `draft(_:purpose:)` hard-coded `sessionID: nil`, so the SAME seat request went stateful
/// via `draft(_:)` and stateless (conversation history LOST) via any purpose-aware decorator
/// (adjudicating / routing / gate / verifier / tool-planner) — byte-different output, no error.
///
/// Verified without a loaded model via the stable not-loaded reason strings: the seat-pool path
/// names `draftMultiTurn`, the stateless planner path names `draft(_:)`. If MLXLLM is not
/// compiled into this build, every path collapses to the same framework-unavailable reason and
/// the fork is unobservable → the test skips rather than asserting a vacuous equality.
final class BASMLXSeatRoutingH21Tests: XCTestCase {

    private func failureReason(
        _ body: () async throws -> BASOrganDraft
    ) async -> String {
        do { _ = try await body(); return "<no-error>" }
        catch BASOrganError.providerUnavailable(let reason) { return reason }
        catch { return "<other:\(error)>" }
    }

    private func req(_ sessionID: String?) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core,
                        instruction: "hi", context: [], sessionID: sessionID)
    }

    func testSeatRequestRoutesToMultiTurnThroughPurposeEntry() async throws {
        let adapter = MLXOrganAdapter()
        let seat = req("seat-A")
        let noSeat = req(nil)

        // Ground truth: the seat-pool entry's own not-loaded reason.
        let multiTurn = await failureReason {
            try await adapter.draftMultiTurn(seat, sessionID: "seat-A")
        }
        // Through the purpose entry: a seat request must reach the SAME seat-pool path (H21 fix).
        let purposeSeat = await failureReason {
            try await adapter.draft(seat, purpose: .factual)
        }
        // Through the purpose entry: a no-session request must take the stateless planner path.
        let purposeNoSeat = await failureReason {
            try await adapter.draft(noSeat, purpose: .factual)
        }

        try XCTSkipIf(!multiTurn.contains("draftMultiTurn"),
            "MLXLLM absent in this build — not-loaded reasons collapse; seat routing unobservable")

        XCTAssertEqual(purposeSeat, multiTurn,
            "seat request via draft(_:purpose:) must route to the seat pool (draftMultiTurn), " +
            "not the stateless planner path (H21)")
        XCTAssertFalse(purposeNoSeat.contains("draftMultiTurn"),
            "a no-session request must NOT take the seat path")
        XCTAssertNotEqual(purposeSeat, purposeNoSeat,
            "seat vs no-session must fork at the purpose entry")
    }
}
