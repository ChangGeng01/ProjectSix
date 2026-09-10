import XCTest
import BASRuntimeCore
@testable import BASSovereign

/// M322 — pin that `QinaoSampleHost --clean-reboot-demo`'s
/// `CleanRebootDemo.run()` helper composes
/// `BASSovereignCleanRebootCoordinator` correctly through both
/// rollback + deadStop scenarios.
///
/// `QinaoSampleHost` is an executable target so tests can't import
/// `CleanRebootDemo` directly. These tests instead pin the
/// **substrate contract** the demo depends on (mirroring M298 +
/// M313 + M314 patterns) so any breaking shape change in
/// `BASSovereignCleanRebootCoordinator` surfaces as a Qinao-side
/// test failure.
///
/// What this file pins:
///
///   1. `BASSovereignVerdictLevel` exposes `.rollback` and
///      `.deadStop` cases — demo synthesises verdicts at these
///      levels.
///   2. `RebootAction` enum cases that the demo banner relies on
///      have stable raw values.
///   3. The action sequence for rollback ALWAYS contains
///      `bootstrapNextSession`; deadStop ALWAYS contains
///      `haltAndAwaitHostIntervention`.
///   4. A coordinator with v0 (good, anchor bound) ← v1 (tainted)
///      configuration produces a rollback plan targeting v0
///      (mirrors the demo fixture).
final class QinaoSampleHostCleanRebootDemoTests: XCTestCase {

    /// 1. Verdict levels demo uses are stable.
    func testVerdictLevelEnumExposesRollbackAndDeadStop() {
        // Force compile-time check by binding both cases to vars.
        let rollback: BASSovereignVerdictLevel = .rollback
        let deadStop: BASSovereignVerdictLevel = .deadStop
        XCTAssertNotEqual(rollback, deadStop)
        XCTAssertEqual(rollback.rawValue, "rollback")
        XCTAssertEqual(deadStop.rawValue, "deadStop")
    }

    /// 2. RebootAction raw values match the demo banner literals
    ///    (audit grep keys).
    func testRebootActionRawValuesMatchBannerKeys() {
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .quarantineActiveSession.rawValue,
            "quarantineActiveSession")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .releaseSovereignLocks.rawValue,
            "releaseSovereignLocks")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .closeAuditLedgerForSession.rawValue,
            "closeAuditLedgerForSession")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .restoreSnapshot.rawValue,
            "restoreSnapshot")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .verifyRestoredIntegrity.rawValue,
            "verifyRestoredIntegrity")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .bootstrapNextSession.rawValue,
            "bootstrapNextSession")
        XCTAssertEqual(
            BASSovereignCleanRebootCoordinator.RebootAction
                .haltAndAwaitHostIntervention.rawValue,
            "haltAndAwaitHostIntervention")
    }

    /// 3. Direct coordinator drive: rollback against tainted
    ///    lineage produces a plan targeting the good ancestor
    ///    with bootstrap action present.
    func testRollbackPlansAgainstTaintedLineage() async throws {
        let snapshots = BASSovereignSnapshotManager()
        let tree = BASSovereignHostVersionTree()
        let ledger = BASSovereignAuditLedger.withSeed(
            "qinao-clean-reboot-test")
        let coord = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshots,
            versionTree: tree,
            ledger: ledger)
        let payload = Data("test-genesis".utf8)
        let anchor =
            BASSovereignSnapshotManager.SnapshotAnchor(
                anchorID: "anchor-v0",
                safeSnapshotRef: "safe-anchor-v0",
                integrityHash:
                    BASSovereignSnapshotManager.hash(payload))
        try await snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0",
            diffSummary: "test")
        try await tree.markBad(
            versionID: "v1",
            reason: "test-only tainted")
        try await coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")

        let verdict = BASSovereignVerdict(
            verdictID: "v-test",
            verdictLevel: .rollback,
            latched: true,
            reasonCodes: ["test"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash:
                BASSovereignTrustConstants
                    .builtInPolicyHash)

        let plan = try await coord.planReboot(
            verdict: verdict,
            sessionID: "test-session",
            currentHostVersionID: "v1")

        XCTAssertEqual(plan.targetVersionID, "v0",
                       "rollback walks to good ancestor")
        XCTAssertEqual(
            plan.targetAnchorID, "anchor-v0")
        XCTAssertTrue(plan.bootstrapNextSession)
        XCTAssertTrue(
            plan.actions.contains(.bootstrapNextSession))
        XCTAssertFalse(
            plan.actions.contains(
                .haltAndAwaitHostIntervention))
    }

    /// 4. DeadStop verdict produces a plan with halt action,
    ///    no bootstrap.
    func testDeadStopPlansHaltAndAwaitHost() async throws {
        let snapshots = BASSovereignSnapshotManager()
        let tree = BASSovereignHostVersionTree()
        let ledger = BASSovereignAuditLedger.withSeed(
            "qinao-deadstop-test")
        let coord = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshots,
            versionTree: tree,
            ledger: ledger)
        let payload = Data("ds-genesis".utf8)
        let anchor =
            BASSovereignSnapshotManager.SnapshotAnchor(
                anchorID: "anchor-v0",
                safeSnapshotRef: "safe-anchor-v0",
                integrityHash:
                    BASSovereignSnapshotManager.hash(payload))
        try await snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await tree.registerGenesis(versionID: "v0")
        try await coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")

        let verdict = BASSovereignVerdict(
            verdictID: "v-ds",
            verdictLevel: .deadStop,
            latched: true,
            reasonCodes: ["test"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash:
                BASSovereignTrustConstants
                    .builtInPolicyHash)

        let plan = try await coord.planReboot(
            verdict: verdict,
            sessionID: "ds-session",
            currentHostVersionID: "v0")

        XCTAssertFalse(plan.bootstrapNextSession)
        XCTAssertTrue(
            plan.actions.contains(
                .haltAndAwaitHostIntervention))
        XCTAssertFalse(
            plan.actions.contains(.bootstrapNextSession))
    }
}
