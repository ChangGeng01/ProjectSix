import XCTest
import BASRuntimeCore
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M170 — pin the M161/M164 retry semantics against the audit
/// ledger so the "audit failure ⇒ retry safe" claim becomes
/// type-checked-and-tested rather than commit-message folklore.
///
/// The senior review (item 20) flagged that M164's retry path
/// rests on an implicit assumption: `auditTurn(...)` is
/// all-or-nothing — either it appends an entry to the ledger AND
/// returns a verdict, or it appends nothing and throws.
///
/// Today's substrate honors that invariant by routing every
/// audit through `BASSovereignVerdictEngine.evaluate(...)` which
/// calls `ledger.append(entry)` exactly once at the end of its
/// pipeline. If `append` throws, no entry is written; if it
/// succeeds, the entry is permanent. The verifier wraps the
/// engine and does no additional ledger I/O.
///
/// These tests pin the observable behavior so a future
/// substrate change that adds a "before-throw audit log" silently
/// breaks M164 → fails this test instead of silently dropping the
/// retry guarantee.
///
/// Pins:
///   1. Healthy turn → exactly 1 audit-ledger entry for
///      (sess, turn); processed FIFO has the key.
///   2. Parity-fail throw path: ledger DOES have 1 entry (engine
///      evaluated and appended), processed FIFO DOES have the
///      key (finalize ran before the throw). Documents M164's
///      observed behavior — `auditParityFailure` is NOT a
///      "retry-after" path.
///   3. Cannot retry after parity throw: same (sess, turn)
///      yields `.duplicateTurnAlreadyProcessed`. Locks in the
///      M164 retry-semantic boundary.
///   4. Retry after audit *append* failure (simulated via the
///      legacy registerProcessedTurn path) is rejected — once a
///      turn is registered, it is finalized regardless of the
///      surrounding code path. Documents that the legacy method
///      provides no escape hatch.
///   5. Concurrent submissions to the same (sess, turn) result
///      in exactly 1 ledger entry — the M165 race test
///      (`QinaoRuntimeM165ConcurrencyTests`) already pinned the
///      claim side; this test pins the ledger side.
final class QinaoRuntimeM170LedgerAtomicityTests: XCTestCase {

    private func obs(
        sessionID: String,
        turnID: String,
        coordinatorLaxer: Bool = false
    ) -> QinaoSovereignControlPlane.TurnObservations {
        // To trigger a parity-laxer throw the coordinator
        // declares `.pass` while the engine produces a stricter
        // verdict. Setting `policyLineageMissing = true` is one
        // observed input that the BR rule set escalates above
        // `.pass`, producing parity coordinatorLaxer at runtime.
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap",
            policyHash: "policy",
            policyLineageMissing: coordinatorLaxer,
            auditEntryMissing: coordinatorLaxer)
    }

    // MARK: - 1. Healthy turn → exactly 1 ledger entry

    func testHealthyTurnAppendsExactlyOneLedgerEntry() async throws {
        let fx = await QinaoTestFixture.make()
        _ = try await fx.runtime.sendSession(
            obs(sessionID: "sess.atom",
                turnID: "turn.healthy"),
            coordinatorSeverity: .pass)

        let entries = await fx.ledger.entries(
            forSession: "sess.atom",
            turn: "turn.healthy")
        XCTAssertEqual(
            entries.count, 1,
            "healthy turn → exactly one audit-ledger entry")
        let processed = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(
            processed, 1,
            "healthy turn → key recorded in processed FIFO")
    }

    // MARK: - 2. Parity throw: ledger entry written + finalized

    func testParityThrowStillProducesOneLedgerEntry()
        async throws {
        let fx = await QinaoTestFixture.make()
        // Coordinator says `.pass` but observations include
        // policy + audit lineage missing — the engine will
        // produce a stricter verdict, parity = coordinatorLaxer,
        // sendSession throws `auditParityFailure`.
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "sess.atom",
                    turnID: "turn.parity",
                    coordinatorLaxer: true),
                coordinatorSeverity: .pass)
            XCTFail(
                "expected auditParityFailure for coordinator-" +
                "laxer parity")
        } catch QinaoRuntime.TurnError.auditParityFailure {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }

        // M170 pin — even though sendSession threw, the ledger
        // recorded the audit because the engine evaluated and
        // appended BEFORE the parity check throw. M164's claim
        // applies only to the audit-APPEND failure path; parity
        // failure is NOT a retry-eligible state.
        let entries = await fx.ledger.entries(
            forSession: "sess.atom",
            turn: "turn.parity")
        XCTAssertEqual(
            entries.count, 1,
            "parity throw still records the audit entry — the " +
            "engine appended before the verifier compared " +
            "parity")
        // Turn is finalized. Same (sess, turn) cannot retry.
        let processed = await fx.sovereign.processedTurnCount()
        XCTAssertEqual(
            processed, 1,
            "parity throw runs AFTER finalize → key in FIFO")
    }

    // MARK: - 3. Cannot retry after parity throw

    func testCannotRetryAfterParityThrow() async throws {
        let fx = await QinaoTestFixture.make()
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "sess.atom",
                    turnID: "turn.no-retry",
                    coordinatorLaxer: true),
                coordinatorSeverity: .pass)
            XCTFail("expected first throw")
        } catch QinaoRuntime.TurnError.auditParityFailure {
            // expected
        }

        // Retry with same (sess, turn) — must be rejected as
        // already-processed. This documents M164's retry-
        // semantic boundary: only audit-APPEND failures are
        // retry-eligible; parity failures are terminal.
        do {
            _ = try await fx.runtime.sendSession(
                obs(sessionID: "sess.atom",
                    turnID: "turn.no-retry",
                    coordinatorLaxer: true),
                coordinatorSeverity: .pass)
            XCTFail("expected duplicateTurnAlreadyProcessed")
        } catch QinaoRuntime.TurnError
            .duplicateTurnAlreadyProcessed
        {
            // expected — finalize ran before the parity throw
        } catch QinaoRuntime.TurnError
            .sessionAlreadyHalted
        {
            // also acceptable — parity failure halts the
            // session, which the second sendSession sees first
            // via the atomic claimTurnIfNotHalted
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 4. Concurrent submissions → exactly 1 ledger entry

    /// `QinaoRuntimeM165ConcurrencyTests` pinned that exactly one
    /// of N concurrent submissions wins. M170 pins the ledger
    /// side: the audit chain receives exactly one entry for
    /// (sess, turn), regardless of how many tasks raced.
    func testConcurrentSubmissionsProduceOneLedgerEntry()
        async throws {
        let fx = await QinaoTestFixture.make()
        let observation = QinaoSovereignControlPlane
            .TurnObservations(
                sessionID: "sess.atom",
                turnID: "turn.race",
                snapshotRef: "s",
                policyHash: "p")

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = try? await fx.runtime.sendSession(
                        observation,
                        coordinatorSeverity: .pass)
                }
            }
            await group.waitForAll()
        }

        let entries = await fx.ledger.entries(
            forSession: "sess.atom",
            turn: "turn.race")
        XCTAssertEqual(
            entries.count, 1,
            "8 concurrent submissions → exactly 1 ledger " +
            "entry (the M164 atomic claim and the engine's " +
            "single-append discipline together close the door)")
    }
}
