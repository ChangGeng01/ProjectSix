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

/// M45 — end-to-end coverage-verdict integration on the main-path
/// `QinaoRuntime.sendSession` flow.
///
/// Before M45, the 14-layer observation-reconciliation substrate
/// (M20–M44) was dead code on the hot path — the verdict engine existed
/// but nothing ever fed it a report. M45 makes the reconciliation
/// engine load-bearing: every `sendSession` call builds a single-layer
/// (L14) coverage report, runs it through
/// `BASObservationReconciliationVerdictEngine`, and stores the result
/// in the shared audit ledger.
///
/// Contract covered here:
///
/// 1. Every clean turn records a `CoverageReading` and returns it on
///    the outcome. The verdict is also queryable from the sovereign
///    control plane for after-the-fact governance.
/// 2. A budget ceiling the turn breaches triggers a `coverageHalt`
///    throw and marks the session halted with reason `coverage-halt`.
/// 3. The coverage is computed **before** the audit-parity or
///    audit-severity halt branches so the ledger retains a per-turn
///    coverage row even on fail-closed paths.
/// 4. A pre-halted session refuses the turn before any coverage is
///    recorded — halt state gates the whole flow.
final class QinaoRuntimeCoverageTests: XCTestCase {

    // MARK: - Fixture (parallel to QinaoRuntimeSessionTests)

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
        sessionID: String = "sess.coverage",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.1",
            policyHash: "policy.hash.1")
    }

    // MARK: - Clean-path coverage

    /// Every clean turn produces a coverage verdict. The verdict's
    /// session/turn keys match the observations, its severity is not
    /// `.halt` (default ceiling is 1.0, L14 projection costs at most
    /// 0.10–0.15 per entry), and the verdict is queryable via the
    /// sovereign control plane afterwards.
    func testCleanTurnRecordsCoverageAndIsQueryable() async throws {
        let fx = await makeRuntime()
        let obs = observations()

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertEqual(outcome.coverage.sessionID, obs.sessionID)
        XCTAssertEqual(outcome.coverage.turnID, obs.turnID)
        XCTAssertNotEqual(outcome.coverage.severity, .halt)

        // Queryable back from the sovereign after the fact.
        let replay = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(replay, outcome.coverage)
    }

    /// Three successive clean turns each produce their own verdict;
    /// last-write-wins per (session, turn) does not collapse distinct
    /// turns of the same session.
    func testMultipleTurnsEachRecordDistinctCoverage() async throws {
        let fx = await makeRuntime()
        let o1 = observations(turnID: "turn.1")
        let o2 = observations(turnID: "turn.2")
        let o3 = observations(turnID: "turn.3")

        _ = try await fx.runtime.sendSession(o1, coordinatorSeverity: .pass)
        _ = try await fx.runtime.sendSession(o2, coordinatorSeverity: .pass)
        _ = try await fx.runtime.sendSession(o3, coordinatorSeverity: .pass)

        let v1 = await fx.sovereign.coverageReading(
            sessionID: o1.sessionID, turnID: "turn.1")
        let v2 = await fx.sovereign.coverageReading(
            sessionID: o2.sessionID, turnID: "turn.2")
        let v3 = await fx.sovereign.coverageReading(
            sessionID: o3.sessionID, turnID: "turn.3")
        XCTAssertNotNil(v1)
        XCTAssertNotNil(v2)
        XCTAssertNotNil(v3)
        XCTAssertEqual(v1?.turnID, "turn.1")
        XCTAssertEqual(v2?.turnID, "turn.2")
        XCTAssertEqual(v3?.turnID, "turn.3")
    }

    // MARK: - Budget-ceiling halt

    /// A ceiling below a single system-actor entry's cost (0.10) must
    /// trip the coverage halt path. The runtime throws
    /// `.coverageHalt`, marks the session halted, and records the
    /// reason `coverage-halt`.
    func testLowBudgetCeilingTripsCoverageHalt() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.coverage.halt", turnID: "turn.1")

        do {
            _ = try await fx.runtime.sendSession(
                obs,
                coordinatorSeverity: .pass,
                coverageBudgetCeiling: 0.05)
            XCTFail("expected coverageHalt")
        } catch QinaoRuntime.TurnError.coverageHalt(
            let sessionID, let turnID, let findings) {
            XCTAssertEqual(sessionID, obs.sessionID)
            XCTAssertEqual(turnID, obs.turnID)
            let hasOverspend = findings.contains {
                if case .budgetOverspend = $0 { return true }
                return false
            }
            XCTAssertTrue(
                hasOverspend,
                "coverageHalt must carry a budgetOverspend finding")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let halted = await fx.sovereign.isSessionHalted(obs.sessionID)
        XCTAssertTrue(halted)
        let reason = await fx.sovereign.haltReason(
            sessionID: obs.sessionID)
        XCTAssertEqual(reason, "coverage-halt")

        // And the coverage verdict itself is queryable — the halt path
        // records before it throws.
        let recorded = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(recorded?.severity, .halt)
    }

    // MARK: - Pre-halted session skips coverage

    /// A session marked halted before the call is rejected by the
    /// pre-flight gate. No audit runs, no coverage is recorded.
    func testPreHaltedSessionDoesNotRecordCoverage() async throws {
        let fx = await makeRuntime()
        let sessionID = "sess.pre.halted"
        await fx.sovereign.markSessionHalted(
            sessionID: sessionID, reason: "manual-pre-halt")
        let obs = observations(sessionID: sessionID, turnID: "turn.1")

        do {
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let recorded = await fx.sovereign.coverageReading(
            sessionID: sessionID, turnID: obs.turnID)
        XCTAssertNil(recorded)
    }

    // MARK: - Audit-severity halt preserves coverage

    /// A `.deadStop` severity on the audit path auto-halts the session
    /// but the outcome still carries a structured coverage verdict for
    /// the turn — coverage is recorded before any halt decision so the
    /// audit trail is complete.
    func testDeadStopHaltPathStillCarriesCoverage() async throws {
        let fx = await makeRuntime()
        // unauthorizedSelfMutation → BR-007 → minLevel .deadStop.
        let obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.coverage.deadstop",
            turnID: "turn.1",
            snapshotRef: "snap.1",
            policyHash: "policy.hash.1",
            unauthorizedSelfMutation: true)

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: nil)

        XCTAssertTrue(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .deadStop)
        XCTAssertEqual(outcome.coverage.sessionID, obs.sessionID)
        XCTAssertEqual(outcome.coverage.turnID, obs.turnID)

        // The coverage record persists through the halt path.
        let replay = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertEqual(replay, outcome.coverage)
    }

    // MARK: - Expected-layer expansion surfaces missing layers

    /// Callers can broaden the expectation set beyond the L14 default
    /// to surface layers the coordinator said should have reported but
    /// did not. Today L4 has no hot-path projection — naming it makes
    /// the verdict emit a `.missingLayer` finding. Severity climbs to
    /// `.advisory` but the session is not halted (advisory-tier).
    func testAdditionalExpectedLayersProduceMissingFindings() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.coverage.expected", turnID: "turn.1")

        let outcome = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            expectedCoverageLayerIDs: ["L14", "L4"])

        XCTAssertFalse(outcome.sessionHalted)
        // Advisory because L4 is silent; severity is not halt.
        XCTAssertNotEqual(outcome.coverage.severity, .halt)
        let hasMissingL4 = outcome.coverage.findings.contains {
            if case .missingLayer(let id) = $0, id == "L4" {
                return true
            }
            return false
        }
        XCTAssertTrue(
            hasMissingL4,
            "expected a .missingLayer(L4) finding when L4 is expected")
    }
}
