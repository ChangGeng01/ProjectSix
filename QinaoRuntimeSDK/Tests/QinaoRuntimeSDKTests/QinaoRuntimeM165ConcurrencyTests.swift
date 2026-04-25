import XCTest
import BASRuntimeCore
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M165 — REAL concurrency tests with `TaskGroup` / `async let`.
///
/// The pre-M165 M164 test suite "concurrent simulation" was
/// purely sequential — a manual `claimTurn` followed by a
/// `sendSession` on the same key. That tested the state machine
/// (claim → reject) but produced no actual concurrent submission.
/// The M164 commit message claimed "close concurrent-submission
/// race" but the test suite never spawned more than one task.
///
/// This file fires N submissions concurrently against the same
/// `(sessionID, turnID)` and asserts:
///
///   1. Exactly ONE wins and produces a healthy outcome.
///   2. The remaining N-1 throw `.duplicateTurnInFlight` or
///      `.duplicateTurnAlreadyProcessed`.
///   3. The audit ledger contains EXACTLY ONE entry for that
///      (sessionID, turnID) — no duplicates accreted.
///
/// Without M164's atomic `claimTurnIfNotHalted` (the actor-hop
/// collapse), the pre-M161 pattern `hasProcessedTurn` →
/// `auditTurn` → `registerProcessedTurn` would race here: under
/// concurrent submissions of the same key, more than one task
/// would see "not processed" before any registered, and both
/// would write audit entries. M164 replaces that with the actor-
/// isolated atomic claim; this test holds it accountable.
///
/// Each test runs the concurrent submission `iterations` times
/// to surface non-deterministic ordering (`scheduling` does
/// matter here — the tasks' awaits interleave differently each
/// run). 32 iterations is the smallest count that historically
/// catches single-actor-hop races on this codebase.
final class QinaoRuntimeM165ConcurrencyTests: XCTestCase {

    private static let iterations = 32

    private func obs(
        sessionID: String = "sess.m165",
        turnID: String = "turn.race"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. N concurrent submissions → exactly one wins

    /// Spawn 8 sendSession tasks all on the same (sessionID,
    /// turnID) and assert: exactly one returns a healthy
    /// TurnOutcome; the other 7 throw a duplicate variant.
    /// The audit ledger keeps a single entry.
    ///
    /// 32 iterations because this is the kind of race that only
    /// flakes 1-in-N runs under specific scheduling. Iteration
    /// is cheap (each turn is microseconds in the in-memory
    /// fixture).
    func testConcurrentSubmissionsAllowOnlyOneWinner()
        async throws {
        for iteration in 0..<Self.iterations {
            let fx = await QinaoTestFixture.make()
            let observation = obs(
                sessionID: "sess.race.\(iteration)",
                turnID: "turn.race.\(iteration)")

            let results = await withTaskGroup(
                of: SubmissionOutcome.self
            ) { group -> [SubmissionOutcome] in
                for _ in 0..<8 {
                    group.addTask {
                        do {
                            _ = try await fx.runtime
                                .sendSession(
                                    observation,
                                    coordinatorSeverity: .pass)
                            return .succeeded
                        } catch QinaoRuntime.TurnError
                            .duplicateTurnAlreadyProcessed
                        {
                            return .rejectedAlreadyProcessed
                        } catch QinaoRuntime.TurnError
                            .duplicateTurnInFlight
                        {
                            return .rejectedInFlight
                        } catch {
                            return .other(
                                String(describing: error))
                        }
                    }
                }
                var collected: [SubmissionOutcome] = []
                for await r in group { collected.append(r) }
                return collected
            }

            let succeeded = results.filter {
                if case .succeeded = $0 { return true }
                return false
            }
            let rejected = results.filter {
                switch $0 {
                case .rejectedInFlight,
                     .rejectedAlreadyProcessed:
                    return true
                default:
                    return false
                }
            }
            let other = results.filter {
                if case .other = $0 { return true }
                return false
            }

            XCTAssertEqual(
                succeeded.count, 1,
                "iteration \(iteration): exactly one of 8 "
                + "concurrent submissions must succeed; saw "
                + "\(succeeded.count). Other outcomes: "
                + "\(other)")
            XCTAssertEqual(
                rejected.count, 7,
                "iteration \(iteration): the other 7 must be "
                + "rejected as duplicates; saw \(rejected.count)")
            XCTAssertEqual(
                other.count, 0,
                "iteration \(iteration): no unexpected error "
                + "types should appear; saw \(other)")

            // Audit chain integrity: exactly one entry per turn.
            let processed = await fx.sovereign
                .processedTurnCount()
            XCTAssertEqual(
                processed, 1,
                "iteration \(iteration): exactly one finalized "
                + "claim (one audit-ledger entry) per turn")
            let inFlight = await fx.sovereign
                .inFlightTurnCount()
            XCTAssertEqual(
                inFlight, 0,
                "iteration \(iteration): no leaked in-flight "
                + "claims after all tasks complete")
        }
    }

    // MARK: - 2. Concurrent halt + claim — atomic ordering

    /// Spawn N tasks where half call `markSessionHalted` and the
    /// other half call `sendSession` on a fresh (s, t). After
    /// the storm settles, every claimed turn must EITHER be
    /// processed (audit completed) OR rejected with
    /// `sessionAlreadyHalted` — never claimed-then-stuck-in-
    /// flight. The pre-M165 separate halt/claim awaits could
    /// produce stuck claims; M165 atomic `claimTurnIfNotHalted`
    /// rejects out of the gate.
    func testConcurrentHaltDoesNotLeakInFlightClaims()
        async throws {
        for iteration in 0..<Self.iterations {
            let fx = await QinaoTestFixture.make()
            let session = "sess.halt.\(iteration)"

            await withTaskGroup(of: Void.self) { group in
                // Race: 4 senders vs. 1 halter.
                for i in 0..<4 {
                    let turnID = "turn.\(i)"
                    group.addTask {
                        let o = QinaoSovereignControlPlane
                            .TurnObservations(
                                sessionID: session,
                                turnID: turnID,
                                snapshotRef: "s",
                                policyHash: "p")
                        _ = try? await fx.runtime
                            .sendSession(
                                o,
                                coordinatorSeverity: .pass)
                    }
                }
                group.addTask {
                    await fx.sovereign.markSessionHalted(
                        sessionID: session,
                        reason: "concurrent-halt-test")
                }
                await group.waitForAll()
            }

            // Hard assertion: zero leaked in-flight. Either the
            // sender finalized before halt landed (claim → audit
            // → finalize), or the halt landed first and the
            // sender got `.sessionHalted` rejection (no claim).
            let leaked = await fx.sovereign.inFlightTurnCount()
            XCTAssertEqual(
                leaked, 0,
                "iteration \(iteration): halt + claim race must "
                + "not leak in-flight claims; saw \(leaked)")
        }
    }

    // MARK: - 3. Cancellation releases the claim

    /// M165 — Task cancellation between claim and audit must not
    /// permanently lock the (sessionID, turnID). The deferred
    /// release in sendSession's outer scope cleans up the
    /// in-flight key; subsequent submissions with the same
    /// (s, t) succeed.
    func testTaskCancellationReleasesClaim() async throws {
        let fx = await QinaoTestFixture.make()
        let observation = obs(turnID: "turn.cancel")

        // Start a submission and cancel it before it can
        // finalize. Yielding gives the spawned task time to
        // reach the claim point but not the finalize point;
        // cancelling then races the cleanup defer.
        let task = Task {
            try await fx.runtime.sendSession(
                observation,
                coordinatorSeverity: .pass)
        }
        // Give the spawned task a moment to claim (one yield
        // is enough to reach the actor hop). The exact moment
        // doesn't matter for correctness — even if cancellation
        // arrives after finalize, the test still proves the
        // post-cancel state is clean.
        await Task.yield()
        task.cancel()
        _ = try? await task.value

        // Wait for the deferred Task that releases the claim to
        // get scheduled. 50ms is generous for an in-process
        // actor hop.
        try await Task.sleep(nanoseconds: 50_000_000)

        let leaked = await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(
            leaked, 0,
            "cancelled sendSession must not leak in-flight "
            + "claims; the deferred Task in the outer scope "
            + "should release the slot")

        // Same (s, t) is now submittable again — proves the
        // claim was actually released, not merely "cleared".
        // (If the original submission had finalized before
        // cancellation, this would throw `alreadyProcessed`,
        // which we treat as a passing variant since the
        // post-state is still clean.)
        do {
            _ = try await fx.runtime.sendSession(
                observation,
                coordinatorSeverity: .pass)
            // success — claim was released, retry succeeded
        } catch QinaoRuntime.TurnError
            .duplicateTurnAlreadyProcessed
        {
            // also acceptable — the original submission
            // finalized BEFORE cancellation took effect; the
            // claim transitioned to processed cleanly
        } catch {
            XCTFail(
                "unexpected error after cancel + retry: "
                + "\(error)")
        }
    }
}

private enum SubmissionOutcome: Sendable {
    case succeeded
    case rejectedAlreadyProcessed
    case rejectedInFlight
    case other(String)
}
