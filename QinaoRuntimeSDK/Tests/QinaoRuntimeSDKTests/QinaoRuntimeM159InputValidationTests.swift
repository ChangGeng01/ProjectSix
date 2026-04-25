import XCTest
import BASRuntimeCore
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M159 — sendSession input validation. Reject malformed
/// identifiers at Phase 0 with `TurnError.invalidInput(
/// field:reason:)` before any state mutation.
///
/// Pre-M159 the runtime silently accepted any string (empty,
/// whitespace, arbitrarily long) as `sessionID` / `turnID`.
/// Empty strings would propagate into ledger entries, synthetic
/// refs, halt-reason strings — corrupting audit-replay. M159
/// hard-rejects these at the front door.
///
/// Pins:
///   1. Empty sessionID rejected
///   2. Whitespace-only sessionID rejected
///   3. Empty turnID rejected
///   4. Too-long sessionID rejected
///   5. Validation runs BEFORE state mutation (no halted-check
///      side effect)
///   6. Valid IDs pass through unchanged (backward-compat)
final class QinaoRuntimeM159InputValidationTests: XCTestCase {

    private func obs(
        sessionID: String,
        turnID: String
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. Empty sessionID

    func testEmptySessionIDIsRejected() async throws {
        let fx = await QinaoTestFixture.make()
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "", turnID: "t.1"),
                coordinatorSeverity: .pass)
            XCTFail("expected invalidInput throw")
        } catch let QinaoRuntime.TurnError
            .invalidInput(field, reason)
        {
            XCTAssertEqual(field, "observations.sessionID")
            XCTAssertTrue(reason.contains("empty"))
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 2. Whitespace-only sessionID

    func testWhitespaceOnlySessionIDIsRejected() async throws {
        let fx = await QinaoTestFixture.make()
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "   \n\t  ", turnID: "t.1"),
                coordinatorSeverity: .pass)
            XCTFail("expected invalidInput throw")
        } catch let QinaoRuntime.TurnError
            .invalidInput(field, _)
        {
            XCTAssertEqual(field, "observations.sessionID")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 3. Empty turnID

    func testEmptyTurnIDIsRejected() async throws {
        let fx = await QinaoTestFixture.make()
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "sess.x", turnID: ""),
                coordinatorSeverity: .pass)
            XCTFail("expected invalidInput throw")
        } catch let QinaoRuntime.TurnError
            .invalidInput(field, _)
        {
            XCTAssertEqual(field, "observations.turnID")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 4. Too-long sessionID

    func testTooLongSessionIDIsRejected() async throws {
        let fx = await QinaoTestFixture.make()
        let huge = String(
            repeating: "a",
            count: QinaoRuntime.maxIdentifierLength + 1)
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: huge, turnID: "t.1"),
                coordinatorSeverity: .pass)
            XCTFail("expected invalidInput throw")
        } catch let QinaoRuntime.TurnError
            .invalidInput(_, reason)
        {
            XCTAssertTrue(
                reason.contains("exceeds"),
                "reason should mention length cap: \(reason)")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 5. Validation BEFORE state mutation

    /// If validation runs first, the halt-check (which would
    /// have logged something for an empty-id session) never
    /// fires. We can't directly observe "no state mutation"
    /// but we can pin the error TYPE — `invalidInput` precedes
    /// `sessionAlreadyHalted` in dispatch.
    func testValidationPrecedesHaltCheck() async throws {
        let fx = await QinaoTestFixture.make()
        // Mark a halt for "" — even though it's malformed,
        // markSessionHalted on this actor doesn't validate.
        await fx.sovereign.markSessionHalted(
            sessionID: "",
            reason: "test-precondition")
        // Now send to "" — M159 must throw invalidInput, NOT
        // sessionAlreadyHalted.
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "", turnID: "t.1"),
                coordinatorSeverity: .pass)
            XCTFail("expected invalidInput throw")
        } catch let QinaoRuntime.TurnError
            .invalidInput(field, _)
        {
            XCTAssertEqual(field, "observations.sessionID")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            XCTFail(
                "halted error fired before validation — wrong order")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 6. Valid IDs pass through

    func testValidIdentifiersPassThrough() async throws {
        let fx = await QinaoTestFixture.make()
        let outcome = try await fx.runtime.sendSession(
            obs(sessionID: "sess.valid",
                turnID: "turn.valid"),
            coordinatorSeverity: .pass)
        XCTAssertFalse(outcome.sessionHalted)
    }

    // MARK: - 7. Boundary case — length exactly at cap

    func testIdentifierAtMaxLengthAccepted() async throws {
        let fx = await QinaoTestFixture.make()
        let atCap = String(
            repeating: "x",
            count: QinaoRuntime.maxIdentifierLength)
        // Should NOT throw — at-cap is allowed, only > cap
        // is rejected.
        let outcome = try await fx.runtime.sendSession(
            obs(sessionID: atCap, turnID: "t"),
            coordinatorSeverity: .pass)
        XCTAssertFalse(outcome.sessionHalted)
    }
}
