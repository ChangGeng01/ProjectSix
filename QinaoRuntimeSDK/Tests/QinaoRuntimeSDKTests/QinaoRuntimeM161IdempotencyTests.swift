import XCTest
import BASRuntimeCore
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M161 — duplicate-turn rejection. Pre-M161 a re-submitted
/// `(sessionID, turnID)` would silently append a duplicate
/// audit-chain entry, corrupting replay semantics. M161 throws
/// `TurnError.duplicateTurnSubmission(sessionID:turnID:)` at
/// Phase 0 before any state mutation.
///
/// Pins:
///   1. Distinct turnIDs OK
///   2. Same (session, turn) twice → throw
///   3. Same turnID across DIFFERENT sessions OK
///   4. Same turnID after host marks halt → halt error wins
///      (halted check precedes duplicate check)
///   5. processedTurnCount() reflects accumulated keys
///   6. Lower-level recordSovereignFrame still allows re-record
///      (storage LWW preserved)
final class QinaoRuntimeM161IdempotencyTests: XCTestCase {

    private func obs(
        sessionID: String = "sess.m161",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. Distinct turnIDs OK

    func testDistinctTurnIDsAccepted() async throws {
        let fx = await QinaoTestFixture.make()
        for i in 0..<5 {
            _ = try await fx.runtime.sendSession(
                obs(turnID: "turn.\(i)"),
                coordinatorSeverity: .pass)
        }
        let count = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(count, 5)
    }

    // MARK: - 2. Duplicate (session, turn) throws

    func testDuplicateTurnIDThrows() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.dup"),
            coordinatorSeverity: .pass)
        do {
            _ = try await fx.runtime.sendSession(
                obs(turnID: "turn.dup"),
                coordinatorSeverity: .pass)
            XCTFail("expected duplicateTurnSubmission throw")
        } catch let QinaoRuntime.TurnError
            .duplicateTurnSubmission(sid, tid)
        {
            XCTAssertEqual(sid, "sess.m161")
            XCTAssertEqual(tid, "turn.dup")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 3. Same turnID across DIFFERENT sessions OK

    func testSameTurnIDAcrossDifferentSessionsAccepted()
        async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(sessionID: "sess.A", turnID: "turn.1"),
            coordinatorSeverity: .pass)
        // Different session, same turnID → accepted
        _ = try await fx.runtime.sendSession(
            obs(sessionID: "sess.B", turnID: "turn.1"),
            coordinatorSeverity: .pass)
        let count = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(count, 2)
    }

    // MARK: - 4. Halt check precedes duplicate check

    /// If a session is halted AND a duplicate is sent, halt wins
    /// (halt check fires first in Phase 0). Pin order.
    func testHaltedCheckPrecedesDuplicateCheck() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.x"),
            coordinatorSeverity: .pass)
        await fx.sovereign.markSessionHalted(
            sessionID: "sess.m161", reason: "test")
        do {
            _ = try await fx.runtime.sendSession(
                obs(turnID: "turn.x"),
                coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            // expected — halt check fires first
        } catch QinaoRuntime.TurnError.duplicateTurnSubmission {
            XCTFail(
                "duplicate fired before halt — wrong order")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 5. processedTurnCount accumulates

    func testProcessedTurnCountAccumulates() async throws {
        let fx = await QinaoTestFixture.make()
        let initial =
            await fx.sovereign.processedTurnCount()
        XCTAssertEqual(initial, 0)
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.a"),
            coordinatorSeverity: .pass)
        let afterFirst =
            await fx.sovereign.processedTurnCount()
        XCTAssertEqual(afterFirst, 1)
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.b"),
            coordinatorSeverity: .pass)
        let afterSecond =
            await fx.sovereign.processedTurnCount()
        XCTAssertEqual(afterSecond, 2)
    }

    // MARK: - 6. Storage-level LWW still works

    /// `recordSovereignFrame(_:)` and `recordRenderFrame(_:_:_:)`
    /// continue to accept re-record at the storage layer. M161
    /// only blocks the `sendSession` re-entry; storage-level
    /// LWW is intentionally retained for hosts that want to
    /// patch a frame post-emission (e.g. add a late-arriving
    /// reference).
    func testStorageLWWStillWorksUnderlying() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(turnID: "turn.lww"),
            coordinatorSeverity: .pass)
        // Direct re-record at storage layer should succeed.
        let replacement = BASSovereignFrame(
            frameID: "frame.sess.m161.turn.lww",
            sessionID: "sess.m161",
            turnID: "turn.lww",
            policyHash: "p")
        await fx.sovereign.recordSovereignFrame(replacement)
        // Frame count is still 1 (LWW replaced in place).
        let count = await fx.sovereign.sovereignFrameCount()
        XCTAssertEqual(count, 1)
    }
}
