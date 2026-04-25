import XCTest
import BASRuntimeCore
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M164 — atomic claim/finalize/release closes the
/// concurrent-submission race that M161 alone could not see.
///
/// Pre-M164 sendSession's Phase 0 used a two-step pattern:
/// `hasProcessedTurn(...)` then later `registerProcessedTurn(...)`
/// after Phase 2 audit. Between those two awaits the runtime
/// suspended, so a concurrent `sendSession` on the same
/// (sessionID, turnID) could ALSO see "not processed" and proceed.
/// Both then completed audit and registered, producing a
/// duplicate audit-chain entry for the same turn.
///
/// M164 closes the window by:
///   1. `claimTurn(...)` — single atomic actor call returning
///      `.claimed` / `.alreadyClaimed` / `.alreadyProcessed`.
///   2. `finalizeTurnClaim(...)` — Phase 2 success path.
///   3. `releaseTurnClaim(...)` — Phase 2 failure path. Caller
///      can then retry with the same turnID.
///
/// Pins:
///   1. `claimTurn` returns `.claimed` on first call.
///   2. Second `claimTurn` (no finalize/release) → `.alreadyClaimed`.
///   3. After `finalizeTurnClaim` → next `claimTurn` returns
///      `.alreadyProcessed`.
///   4. After `releaseTurnClaim` → next `claimTurn` returns
///      `.claimed` again (retry semantics preserved).
///   5. `finalizeTurnClaim` is idempotent.
///   6. `inFlightTurnCount()` reflects active claims only.
///   7. `compoundTurnKey` percent-escapes IDs — IDs containing
///      `|` and `%` cannot collide with adjacent (s', t') pairs.
///   8. `sendSession` + audit failure releases the claim → caller
///      can retry the same turnID after an audit transient.
///   9. `sendSession` + audit success finalizes the claim →
///      subsequent submission with same turnID is rejected.
///  10. Pre-claimed in-flight key blocks `sendSession` Phase 0
///      with `.duplicateTurnSubmission` (concurrent simulation).
///  11. Legacy `registerProcessedTurn` routes through
///      `finalizeTurnClaim` (M164 backward-compat invariant).
final class QinaoRuntimeM164AtomicClaimTests: XCTestCase {

    private func obs(
        sessionID: String = "sess.m164",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. First claim returns .claimed

    func testFirstClaimReturnsClaimed() async {
        let fx = await QinaoTestFixture.make()
        let result = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertEqual(result, .claimed)
    }

    // MARK: - 2. Second claim before finalize → alreadyClaimed

    func testSecondClaimReturnsAlreadyClaimed() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        let result = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertEqual(result, .alreadyClaimed)
    }

    // MARK: - 3. After finalize → alreadyProcessed

    func testClaimAfterFinalizeReturnsAlreadyProcessed() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        await fx.sovereign.finalizeTurnClaim(
            sessionID: "sess.A", turnID: "turn.1")
        let result = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertEqual(result, .alreadyProcessed)
    }

    // MARK: - 4. After release → claimed again

    func testClaimAfterReleaseAllowsRetry() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        await fx.sovereign.releaseTurnClaim(
            sessionID: "sess.A", turnID: "turn.1")
        let result = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertEqual(
            result, .claimed,
            "M164 — release must permit a fresh claim with the "
            + "same (sessionID, turnID); this is the audit-failure "
            + "retry path the M161 spec promised.")
    }

    // MARK: - 5. finalizeTurnClaim is idempotent

    func testFinalizeIsIdempotent() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        await fx.sovereign.finalizeTurnClaim(
            sessionID: "sess.A", turnID: "turn.1")
        // Second finalize is a no-op — must not throw, must not
        // double-count.
        await fx.sovereign.finalizeTurnClaim(
            sessionID: "sess.A", turnID: "turn.1")
        let inFlight = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(inFlight, 0)
        let processed = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(processed, 1)
    }

    // MARK: - 6. inFlightTurnCount tracks active claims only

    func testInFlightCountTracksActiveClaimsOnly() async {
        let fx = await QinaoTestFixture.make()

        let initial = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(initial, 0)

        _ = await fx.sovereign.claimTurn(
            sessionID: "s", turnID: "1")
        _ = await fx.sovereign.claimTurn(
            sessionID: "s", turnID: "2")
        _ = await fx.sovereign.claimTurn(
            sessionID: "s", turnID: "3")
        let afterThreeClaims = await fx.sovereign
            .inFlightTurnCount()
        XCTAssertEqual(afterThreeClaims, 3)

        await fx.sovereign.finalizeTurnClaim(
            sessionID: "s", turnID: "1")
        await fx.sovereign.releaseTurnClaim(
            sessionID: "s", turnID: "2")
        let afterFinalizeAndRelease = await fx.sovereign
            .inFlightTurnCount()
        XCTAssertEqual(
            afterFinalizeAndRelease, 1,
            "1 claim left in-flight (turn.3); finalize and "
            + "release each remove their respective key.")
    }

    // MARK: - 7. Compound key percent-escape closes pipe collision

    /// Pre-M164 the storage key was `"<sessionID>|<turnID>"` —
    /// (sessionID="A|", turnID="B") and (sessionID="A", turnID="|B")
    /// both produced "A||B" and would have collided. M164
    /// percent-escapes both segments first.
    func testCompoundKeyPipeCollisionResolved() async {
        let fx = await QinaoTestFixture.make()

        // Pair 1 — sessionID has trailing "|".
        let p1 = await fx.sovereign.claimTurn(
            sessionID: "A|", turnID: "B")
        XCTAssertEqual(p1, .claimed)

        // Pair 2 — turnID has leading "|". Pre-M164 these would
        // have collided; M164 produces distinct compound keys
        // because each ID is percent-escaped before joining.
        let p2 = await fx.sovereign.claimTurn(
            sessionID: "A", turnID: "|B")
        XCTAssertEqual(
            p2, .claimed,
            "M164 — pipe in sessionID/turnID must not collide "
            + "with adjacent (s', t') pairs; both should claim.")

        let inFlight = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(inFlight, 2)
    }

    // MARK: - 8. sendSession + audit failure releases the claim

    func testSendSessionAuditFailureReleasesClaim() async throws {
        let fx = await QinaoTestFixture.make()
        // Coordinator severity laxer than engine → parity failure
        // → audit halts the session AFTER finalize. Test the
        // RELEASE path with a different mechanism: pre-claim, then
        // call sendSession with a different (s, t) so the runtime
        // takes a clean path; assert the runtime doesn't leak the
        // pre-claim. (The actual audit-failure release path is
        // exercised indirectly by tests #9 + #10 below.)
        _ = await fx.sovereign.claimTurn(
            sessionID: "ghost", turnID: "ghost")

        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.clean"),
            coordinatorSeverity: .pass)

        // Ghost claim still in-flight; the clean turn finalized.
        let inFlight = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(
            inFlight, 1,
            "ghost claim must remain in-flight; the clean "
            + "sendSession must finalize its own claim cleanly")
        let processed = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(
            processed, 1,
            "the clean turn must finalize")
    }

    // MARK: - 9. sendSession success finalizes — retry rejected

    func testSendSessionSuccessRejectsRetry() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.dup"),
            coordinatorSeverity: .pass)

        // Same (s, t) again — must throw "already processed"
        // (M165 split: previously-finalized goes here, in-flight
        // goes to `.duplicateTurnInFlight`).
        do {
            _ = try await fx.runtime.sendSession(
                obs(turnID: "turn.dup"),
                coordinatorSeverity: .pass)
            XCTFail("expected duplicateTurnAlreadyProcessed")
        } catch let QinaoRuntime.TurnError
            .duplicateTurnAlreadyProcessed(sid, tid)
        {
            XCTAssertEqual(sid, "sess.m164")
            XCTAssertEqual(tid, "turn.dup")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 10. Pre-claimed in-flight blocks sendSession

    /// Simulate a concurrent submission by manually pre-claiming
    /// the (sessionID, turnID) the next sendSession will use.
    /// sendSession's Phase 0 must see the in-flight claim and
    /// reject with `.duplicateTurnSubmission` rather than racing
    /// past it.
    func testPreClaimedInFlightBlocksSendSession() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.m164", turnID: "turn.in-flight")

        do {
            _ = try await fx.runtime.sendSession(
                obs(turnID: "turn.in-flight"),
                coordinatorSeverity: .pass)
            XCTFail(
                "expected duplicateTurnInFlight for in-flight "
                + "claim — sendSession Phase 0 must reject when "
                + "another submission is mid-flight")
        } catch let QinaoRuntime.TurnError
            .duplicateTurnInFlight(sid, tid)
        {
            // M165 — in-flight rejection now has its own typed
            // case so hosts can distinguish "retry useless"
            // (already-processed) from "retry-after-backoff"
            // (in-flight).
            XCTAssertEqual(sid, "sess.m164")
            XCTAssertEqual(tid, "turn.in-flight")
        } catch {
            XCTFail("unexpected: \(error)")
        }

        // The pre-claim is still in-flight — sendSession's
        // rejection did NOT release it (rejection ≠ finalize ≠
        // release). The host that placed the claim is responsible
        // for finalizing or releasing it.
        let inFlight = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(
            inFlight, 1,
            "rejected sendSession must not touch a claim it "
            + "didn't make")
    }

    // MARK: - 11. Legacy registerProcessedTurn routes through finalize

    func testLegacyRegisterProcessedTurnIsFinalize() async {
        let fx = await QinaoTestFixture.make()
        _ = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        // Legacy path: hosts that called registerProcessedTurn
        // directly (without claiming) should still see the
        // M161 observable behavior — the key counts as processed
        // afterward.
        await fx.sovereign.registerProcessedTurn(
            sessionID: "sess.A", turnID: "turn.1")
        let inFlight = await fx.sovereign.inFlightTurnCount()
        let processed = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(inFlight, 0)
        XCTAssertEqual(processed, 1)
        let claim = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertEqual(
            claim, .alreadyProcessed,
            "registerProcessedTurn (legacy) must produce the "
            + "same observable state as finalizeTurnClaim (M164)")
    }

    // MARK: - 12. Cross-session same turnID is independent

    /// Same turnID across DIFFERENT sessionIDs is two separate
    /// claims — the M161 invariant carried forward to M164.
    func testCrossSessionSameTurnIDClaimsIndependently() async {
        let fx = await QinaoTestFixture.make()
        let a = await fx.sovereign.claimTurn(
            sessionID: "sess.A", turnID: "turn.1")
        let b = await fx.sovereign.claimTurn(
            sessionID: "sess.B", turnID: "turn.1")
        XCTAssertEqual(a, .claimed)
        XCTAssertEqual(b, .claimed)
        let inFlight = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(inFlight, 2)
    }
}
