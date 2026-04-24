import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M143 — 4th whitepaper L14 §5 sovereign action:
/// `.rollbackToLastClean(reason:hostVersionID:)` added to
/// `ChainBreakRecoveryPolicy`. Closes the halt/quarantine/rotate/
/// rollback quartet.
///
/// Pins:
///   1. New policy case is Equatable (payload-sensitive)
///   2. Outcome struct carries `rollbackPlanIDs: [String]` field
///   3. Healthy chain + rollback policy → noop (no plans
///      generated, no halts)
///   4. Outcome stable across backward-compat construction paths
final class QinaoRuntimeM143RollbackPolicyTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture.


    // MARK: - 1. Policy case is Equatable

    func testRollbackPolicyEquatable() {
        let a = QinaoSovereignControlPlane
            .ChainBreakRecoveryPolicy
            .rollbackToLastClean(
                reason: "r1", hostVersionID: "host.v1")
        let b = QinaoSovereignControlPlane
            .ChainBreakRecoveryPolicy
            .rollbackToLastClean(
                reason: "r1", hostVersionID: "host.v1")
        let c = QinaoSovereignControlPlane
            .ChainBreakRecoveryPolicy
            .rollbackToLastClean(
                reason: "r2", hostVersionID: "host.v1")
        let d = QinaoSovereignControlPlane
            .ChainBreakRecoveryPolicy
            .rollbackToLastClean(
                reason: "r1", hostVersionID: "host.v2")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c, "reason delta → not equal")
        XCTAssertNotEqual(a, d, "hostVersionID delta → not equal")
    }

    // MARK: - 2. Outcome carries rollbackPlanIDs field

    func testOutcomeHasRollbackPlanIDsField() {
        let outcome = QinaoSovereignControlPlane
            .ChainBreakRecoveryOutcome(
                wasHealthy: false,
                action: "rollback",
                lastVerifiedAuditID: "audit.x",
                haltedSessionIDs: ["sess.a"],
                rotatedSegmentIDs: [],
                rollbackPlanIDs: ["plan.1", "plan.2"],
                emittedAt: Date())
        XCTAssertEqual(
            outcome.rollbackPlanIDs, ["plan.1", "plan.2"])
        XCTAssertEqual(outcome.action, "rollback")
    }

    // MARK: - 3. Healthy chain + rollback policy → noop

    func testRollbackPolicyNoOpOnHealthyChain() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m143")
        let obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m143",
            turnID: "turn.1",
            snapshotRef: "s",
            policyHash: "p")
        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let outcome = await fx.sovereign
            .autoHealChainIntegrity(
                policy: .rollbackToLastClean(
                    reason: "test",
                    hostVersionID: "host.v1"),
                affectedSessionIDs: ["sess.m143"])
        XCTAssertTrue(outcome.wasHealthy)
        XCTAssertEqual(outcome.action, "noop")
        XCTAssertTrue(outcome.haltedSessionIDs.isEmpty)
        XCTAssertTrue(outcome.rollbackPlanIDs.isEmpty)
    }

    // MARK: - 4. Backward-compat init default empty rollbackPlans

    func testBackwardCompatInitDefaultsRollbackPlansEmpty() {
        // Host-authored outcome constructed without passing
        // rollbackPlanIDs (pre-M143 code shapes) — should default
        // to empty array.
        let outcome = QinaoSovereignControlPlane
            .ChainBreakRecoveryOutcome(
                wasHealthy: true,
                action: "noop",
                lastVerifiedAuditID: nil,
                haltedSessionIDs: [],
                rotatedSegmentIDs: [],
                emittedAt: Date())
        XCTAssertTrue(outcome.rollbackPlanIDs.isEmpty)
    }
}
