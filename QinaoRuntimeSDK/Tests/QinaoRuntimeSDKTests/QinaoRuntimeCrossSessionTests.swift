import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M47 — cross-session isolation stress test for the main-path runtime.
///
/// The M45 coverage-verdict surface introduced per-`(sessionID, turnID)`
/// storage semantics on top of the `haltedSessions` / `haltReasons`
/// state M15 had put in place. The README promises:
///
/// > Coverage / halt / audit state is keyed per (sessionID, turnID) and
/// > does not leak across sessions.
///
/// This suite is the stress test behind that promise. A single
/// `QinaoRuntime` + `QinaoSovereignControlPlane` instance drives two
/// (and in some tests three) logical sessions through interleaved
/// turns, and every assertion is specifically about whether state in
/// session A can be observed, mutated, or silenced from session B's
/// perspective — and vice versa.
///
/// Contracts covered here:
///
/// 1. Coverage readings are session-local: `coverageReading(A, t)` and
///    `coverageReading(B, t)` are distinct even when turn IDs collide.
/// 2. Halt state is session-local: halting A via coverage-ceiling does
///    not halt B; B can still accept fresh turns.
/// 3. Halt reasons are session-local: A halted with `coverage-halt`
///    and B halted with `audit-severity:deadStop` produce two
///    distinguishable reason codes on the same sovereign.
/// 4. Pre-halting A (via `markSessionHalted`) only rejects A's next
///    turn — B's flow is unaffected.
/// 5. Interleaving turns across sessions (A.1, B.1, A.2, B.2) yields
///    four distinct coverage rows; none collapse across sessions.
/// 6. Clearing the halt on A does not clear the halt on B.
/// 7. Three concurrent sessions running in parallel (`async let`) each
///    land their own coverage row and per-session halt decisions stay
///    local — the actor-isolated sovereign does not crosstalk.
final class QinaoRuntimeCrossSessionTests: XCTestCase {

    // MARK: - Fixture

    actor ToolRecorder {
        var callCount = 0
        func record(name: String, payload: Data) -> Data {
            callCount += 1
            return Data()
        }
    }

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
        let recorder = ToolRecorder()
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)

        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now)
        let risk = QinaoRiskGate(permitTTLSeconds: 10, now: now)

        let constitution = BASHostConstitution(
            hostID: "host",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        let host = QinaoHost(pipeline: pipeline)

        let memory = QinaoMemory()
        let loop = QinaoLoop()

        let executor: QinaoRuntime.ToolExecutor = { name, payload in
            await recorder.record(name: name, payload: payload)
        }

        let runtime = QinaoRuntime(
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now)

        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String,
        turnID: String,
        unauthorizedSelfMutation: Bool = false
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.1",
            policyHash: "policy.hash.1",
            unauthorizedSelfMutation: unauthorizedSelfMutation)
    }

    // MARK: - 1. Coverage readings are session-local

    /// Two sessions run a turn each with the *same* turn ID. Each
    /// session's coverage row must be stored under its own
    /// `(sessionID, turnID)` key and must not overwrite the other.
    func testCoverageReadingsDoNotLeakAcrossSessions() async throws {
        let fx = await makeRuntime()
        let obsA = observations(sessionID: "sess.A", turnID: "turn.1")
        let obsB = observations(sessionID: "sess.B", turnID: "turn.1")

        let outcomeA = try await fx.runtime.sendSession(
            obsA, coordinatorSeverity: .pass)
        let outcomeB = try await fx.runtime.sendSession(
            obsB, coordinatorSeverity: .pass)

        XCTAssertEqual(outcomeA.coverage.sessionID, "sess.A")
        XCTAssertEqual(outcomeB.coverage.sessionID, "sess.B")

        // Each session's coverage is queryable and correctly keyed.
        let replayA = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.1")
        let replayB = await fx.sovereign.coverageReading(
            sessionID: "sess.B", turnID: "turn.1")
        XCTAssertEqual(replayA, outcomeA.coverage)
        XCTAssertEqual(replayB, outcomeB.coverage)

        // Cross-reads return nil — A's ledger has no row for B.
        let crossA = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.nonexistent")
        XCTAssertNil(crossA)
        let crossB = await fx.sovereign.coverageReading(
            sessionID: "sess.B", turnID: "turn.nonexistent")
        XCTAssertNil(crossB)
    }

    // MARK: - 2. Halt state is session-local

    /// Halting session A via a budget-ceiling breach must not prevent
    /// session B from running a clean turn on the same runtime.
    func testCoverageHaltInOneSessionDoesNotAffectAnother() async throws {
        let fx = await makeRuntime()
        let obsA = observations(sessionID: "sess.A", turnID: "turn.1")
        let obsB = observations(sessionID: "sess.B", turnID: "turn.1")

        // A trips the coverage halt (ceiling 0.05 is below the
        // single-entry L14 projection cost of 0.10).
        do {
            _ = try await fx.runtime.sendSession(
                obsA,
                coordinatorSeverity: .pass,
                coverageBudgetCeiling: 0.05)
            XCTFail("expected coverageHalt on A")
        } catch QinaoRuntime.TurnError.coverageHalt {
            // expected
        } catch {
            XCTFail("unexpected error on A: \(error)")
        }

        let haltedA1 = await fx.sovereign.isSessionHalted("sess.A")
        let haltedB1 = await fx.sovereign.isSessionHalted("sess.B")
        XCTAssertTrue(haltedA1)
        XCTAssertFalse(haltedB1)

        // B runs clean — the sovereign's halt predicate is per-session.
        let outcomeB = try await fx.runtime.sendSession(
            obsB, coordinatorSeverity: .pass)
        XCTAssertFalse(outcomeB.sessionHalted)
        XCTAssertEqual(outcomeB.coverage.sessionID, "sess.B")
    }

    // MARK: - 3. Halt reasons are session-local

    /// Two sessions halted for two different reasons must retain
    /// distinguishable reason codes on the sovereign.
    func testHaltReasonsAreSessionSpecific() async throws {
        let fx = await makeRuntime()

        // A: coverage-halt via tight ceiling.
        do {
            _ = try await fx.runtime.sendSession(
                observations(sessionID: "sess.A", turnID: "turn.1"),
                coordinatorSeverity: .pass,
                coverageBudgetCeiling: 0.05)
            XCTFail("expected coverageHalt on A")
        } catch QinaoRuntime.TurnError.coverageHalt { /* expected */ }

        // B: audit-severity halt via unauthorizedSelfMutation (BR-007
        // → .deadStop, ≥ .rollback so sendSession auto-halts).
        let outcomeB = try await fx.runtime.sendSession(
            observations(
                sessionID: "sess.B",
                turnID: "turn.1",
                unauthorizedSelfMutation: true),
            coordinatorSeverity: nil)
        XCTAssertTrue(outcomeB.sessionHalted)
        XCTAssertEqual(outcomeB.audit.severity, .deadStop)

        let reasonA = await fx.sovereign.haltReason(
            sessionID: "sess.A")
        let reasonB = await fx.sovereign.haltReason(
            sessionID: "sess.B")
        XCTAssertEqual(reasonA, "coverage-halt")
        XCTAssertEqual(reasonB, "audit-severity:deadStop")
        XCTAssertNotEqual(reasonA, reasonB)
    }

    // MARK: - 4. Pre-halted session does not block peers

    /// Marking session A halted manually refuses A's next turn with
    /// `sessionAlreadyHalted` but leaves B clean. The sovereign's
    /// pre-flight gate is keyed on the incoming sessionID only.
    func testPreHaltedSessionADoesNotBlockSessionB() async throws {
        let fx = await makeRuntime()
        await fx.sovereign.markSessionHalted(
            sessionID: "sess.A", reason: "manual-pre-halt")

        // A refuses.
        do {
            _ = try await fx.runtime.sendSession(
                observations(sessionID: "sess.A", turnID: "turn.1"),
                coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted on A")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // B runs cleanly on the same runtime.
        let outcomeB = try await fx.runtime.sendSession(
            observations(sessionID: "sess.B", turnID: "turn.1"),
            coordinatorSeverity: .pass)
        XCTAssertFalse(outcomeB.sessionHalted)
        XCTAssertEqual(outcomeB.coverage.sessionID, "sess.B")

        // And A's pre-flight rejection did not record any coverage.
        let preHaltedA = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.1")
        XCTAssertNil(preHaltedA)
    }

    // MARK: - 5. Interleaved turns across sessions

    /// A.1, B.1, A.2, B.2 interleaved must produce four distinct
    /// coverage rows, none collapsing across sessions.
    func testInterleavedTurnsStayDistinctPerSession() async throws {
        let fx = await makeRuntime()

        _ = try await fx.runtime.sendSession(
            observations(sessionID: "sess.A", turnID: "turn.1"),
            coordinatorSeverity: .pass)
        _ = try await fx.runtime.sendSession(
            observations(sessionID: "sess.B", turnID: "turn.1"),
            coordinatorSeverity: .pass)
        _ = try await fx.runtime.sendSession(
            observations(sessionID: "sess.A", turnID: "turn.2"),
            coordinatorSeverity: .pass)
        _ = try await fx.runtime.sendSession(
            observations(sessionID: "sess.B", turnID: "turn.2"),
            coordinatorSeverity: .pass)

        let a1 = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.1")
        let a2 = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.2")
        let b1 = await fx.sovereign.coverageReading(
            sessionID: "sess.B", turnID: "turn.1")
        let b2 = await fx.sovereign.coverageReading(
            sessionID: "sess.B", turnID: "turn.2")

        XCTAssertNotNil(a1)
        XCTAssertNotNil(a2)
        XCTAssertNotNil(b1)
        XCTAssertNotNil(b2)
        XCTAssertEqual(a1?.sessionID, "sess.A")
        XCTAssertEqual(a2?.sessionID, "sess.A")
        XCTAssertEqual(b1?.sessionID, "sess.B")
        XCTAssertEqual(b2?.sessionID, "sess.B")
        XCTAssertEqual(a1?.turnID, "turn.1")
        XCTAssertEqual(a2?.turnID, "turn.2")
        XCTAssertEqual(b1?.turnID, "turn.1")
        XCTAssertEqual(b2?.turnID, "turn.2")
    }

    // MARK: - 6. Halt clear on one session does not clear another

    /// Clearing the halt on A must leave B's halt state intact.
    func testClearingHaltOnOneSessionLeavesAnotherHalted() async throws {
        let fx = await makeRuntime()

        await fx.sovereign.markSessionHalted(
            sessionID: "sess.A", reason: "reason-A")
        await fx.sovereign.markSessionHalted(
            sessionID: "sess.B", reason: "reason-B")

        let bothHaltedA = await fx.sovereign.isSessionHalted("sess.A")
        let bothHaltedB = await fx.sovereign.isSessionHalted("sess.B")
        XCTAssertTrue(bothHaltedA)
        XCTAssertTrue(bothHaltedB)

        await fx.sovereign.clearHalt(sessionID: "sess.A")

        let afterClearA = await fx.sovereign.isSessionHalted("sess.A")
        let afterClearB = await fx.sovereign.isSessionHalted("sess.B")
        XCTAssertFalse(afterClearA)
        XCTAssertTrue(afterClearB)
        // B's reason is preserved even after A is cleared.
        let reasonB = await fx.sovereign.haltReason(
            sessionID: "sess.B")
        XCTAssertEqual(reasonB, "reason-B")
    }

    // MARK: - 7. Concurrent sessions — actor-isolated sovereign

    /// Three sessions issued as concurrent `async let` tasks must each
    /// receive their own coverage row; the sovereign's actor boundary
    /// must serialize them without crosstalk.
    func testThreeConcurrentSessionsEachLandTheirOwnCoverage() async throws {
        let fx = await makeRuntime()
        let obsA = observations(sessionID: "sess.A", turnID: "turn.1")
        let obsB = observations(sessionID: "sess.B", turnID: "turn.1")
        let obsC = observations(sessionID: "sess.C", turnID: "turn.1")

        async let taskA = fx.runtime.sendSession(
            obsA, coordinatorSeverity: .pass)
        async let taskB = fx.runtime.sendSession(
            obsB, coordinatorSeverity: .pass)
        async let taskC = fx.runtime.sendSession(
            obsC, coordinatorSeverity: .pass)

        let (outcomeA, outcomeB, outcomeC) =
            try await (taskA, taskB, taskC)

        XCTAssertEqual(outcomeA.coverage.sessionID, "sess.A")
        XCTAssertEqual(outcomeB.coverage.sessionID, "sess.B")
        XCTAssertEqual(outcomeC.coverage.sessionID, "sess.C")
        XCTAssertFalse(outcomeA.sessionHalted)
        XCTAssertFalse(outcomeB.sessionHalted)
        XCTAssertFalse(outcomeC.sessionHalted)

        // Every session's coverage row is queryable; none collided.
        let a = await fx.sovereign.coverageReading(
            sessionID: "sess.A", turnID: "turn.1")
        let b = await fx.sovereign.coverageReading(
            sessionID: "sess.B", turnID: "turn.1")
        let c = await fx.sovereign.coverageReading(
            sessionID: "sess.C", turnID: "turn.1")
        XCTAssertEqual(a, outcomeA.coverage)
        XCTAssertEqual(b, outcomeB.coverage)
        XCTAssertEqual(c, outcomeC.coverage)
    }

    // MARK: - 8. Concurrent halt + clean sessions

    /// One session halting (coverage ceiling) concurrently with two
    /// other sessions running cleanly must not leak halt state into
    /// the clean sessions.
    func testConcurrentHaltInOneSessionDoesNotAffectPeerSessions()
        async throws {
        let fx = await makeRuntime()
        let obsHalt = observations(
            sessionID: "sess.halt", turnID: "turn.1")
        let obsCleanA = observations(
            sessionID: "sess.cleanA", turnID: "turn.1")
        let obsCleanB = observations(
            sessionID: "sess.cleanB", turnID: "turn.1")

        // Capture the halt session's throw as a Bool so the three
        // concurrent tasks share a uniform non-throwing signature.
        @Sendable func runHalt() async -> Bool {
            do {
                _ = try await fx.runtime.sendSession(
                    obsHalt,
                    coordinatorSeverity: .pass,
                    coverageBudgetCeiling: 0.05)
                return false
            } catch QinaoRuntime.TurnError.coverageHalt {
                return true
            } catch {
                return false
            }
        }

        async let haltDidThrow = runHalt()
        async let cleanATask = fx.runtime.sendSession(
            obsCleanA, coordinatorSeverity: .pass)
        async let cleanBTask = fx.runtime.sendSession(
            obsCleanB, coordinatorSeverity: .pass)

        let (didHalt, outcomeA, outcomeB) =
            try await (haltDidThrow, cleanATask, cleanBTask)

        XCTAssertTrue(
            didHalt,
            "halt session must throw coverageHalt")

        let haltedMain = await fx.sovereign.isSessionHalted("sess.halt")
        let haltedCleanA = await fx.sovereign.isSessionHalted(
            "sess.cleanA")
        let haltedCleanB = await fx.sovereign.isSessionHalted(
            "sess.cleanB")
        XCTAssertTrue(haltedMain)
        XCTAssertFalse(haltedCleanA)
        XCTAssertFalse(haltedCleanB)
        XCTAssertFalse(outcomeA.sessionHalted)
        XCTAssertFalse(outcomeB.sessionHalted)

        // The halted session's reason did not propagate to peers.
        let reasonHalt = await fx.sovereign.haltReason(
            sessionID: "sess.halt")
        let reasonA = await fx.sovereign.haltReason(
            sessionID: "sess.cleanA")
        let reasonB = await fx.sovereign.haltReason(
            sessionID: "sess.cleanB")
        XCTAssertEqual(reasonHalt, "coverage-halt")
        XCTAssertNil(reasonA)
        XCTAssertNil(reasonB)
    }
}
