import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for the clean-reboot coordinator — the piece that turns
/// `.rollback` / `.deadStop` verdicts from strings into executable
/// plans. Every assertion here pins a real product promise:
///
/// - rollback → bootstraps next session after restore
/// - deadStop → halts and awaits host
/// - tainted lineage → picks a further-back known-good ancestor
/// - missing anchor for target → errors rather than silently
///   executing an unverifiable reboot
final class BASSovereignCleanRebootCoordinatorTests: XCTestCase {

    // MARK: - Fixture

    private func makeStack() async throws -> (
        snapshots: BASSovereignSnapshotManager,
        tree: BASSovereignHostVersionTree,
        ledger: BASSovereignAuditLedger,
        coord: BASSovereignCleanRebootCoordinator
    ) {
        let snapshots = BASSovereignSnapshotManager()
        let tree = BASSovereignHostVersionTree()
        let ledger = BASSovereignAuditLedger.withSeed(
            "test-reboot-coord")
        let coord = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshots,
            versionTree: tree,
            ledger: ledger)
        return (snapshots, tree, ledger, coord)
    }

    private func makeAnchor(
        id: String,
        payload: Data
    ) -> BASSovereignSnapshotManager.SnapshotAnchor {
        let hash = BASSovereignSnapshotManager.hash(payload)
        return BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: id,
            safeSnapshotRef: "safe-\(id)",
            integrityHash: hash)
    }

    private func verdict(
        level: BASSovereignVerdictLevel
    ) -> BASSovereignVerdict {
        BASSovereignVerdict(
            verdictID: "v-\(UUID().uuidString)",
            verdictLevel: level,
            latched: true,
            reasonCodes: ["BR-004"],
            revokedPermissions: [],
            userStubMode: .refusalOnly,
            policyHash: BASSovereignTrustConstants.builtInPolicyHash)
    }

    // MARK: - Happy path: rollback plan

    func testRollbackPlansBootstrapNextSession() async throws {
        let stack = try await makeStack()
        let payload = Data("genesis-payload".utf8)
        let anchor = makeAnchor(id: "anchor-v0", payload: payload)

        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.tree.registerVersion(
            versionID: "v1", parentID: "v0",
            diffSummary: "added goal X")
        try await stack.coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")

        let plan = try await stack.coord.planReboot(
            verdict: verdict(level: .rollback),
            sessionID: "s-1",
            currentHostVersionID: "v1")

        XCTAssertEqual(plan.targetVersionID, "v0")
        XCTAssertEqual(plan.targetAnchorID, "anchor-v0")
        XCTAssertTrue(plan.bootstrapNextSession)
        XCTAssertTrue(
            plan.actions.contains(.bootstrapNextSession),
            "rollback should bootstrap next session")
        XCTAssertFalse(
            plan.actions.contains(.haltAndAwaitHostIntervention))
    }

    // MARK: - deadStop halts

    func testDeadStopHaltsAndAwaitsHost() async throws {
        let stack = try await makeStack()
        let payload = Data("genesis-payload".utf8)
        let anchor = makeAnchor(id: "anchor-v0", payload: payload)
        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")

        let plan = try await stack.coord.planReboot(
            verdict: verdict(level: .deadStop),
            sessionID: "s-2",
            currentHostVersionID: "v0")

        XCTAssertFalse(plan.bootstrapNextSession)
        XCTAssertTrue(
            plan.actions.contains(.haltAndAwaitHostIntervention))
        XCTAssertFalse(
            plan.actions.contains(.bootstrapNextSession))
    }

    // MARK: - Tainted lineage skips bad ancestors

    func testTaintedIntermediateAncestorIsSkipped() async throws {
        let stack = try await makeStack()
        let payload = Data("genesis-payload".utf8)
        let anchor = makeAnchor(id: "anchor-v0", payload: payload)
        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)

        // Tree: v0 (good) ← v1 (tainted) ← v2 (current)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "a")
        try await stack.tree.registerVersion(
            versionID: "v2", parentID: "v1", diffSummary: "b")
        try await stack.tree.markBad(
            versionID: "v1", reason: "policy violation")
        try await stack.coord.bindAnchor(
            anchorID: "anchor-v0", toVersionID: "v0")

        let plan = try await stack.coord.planReboot(
            verdict: verdict(level: .rollback),
            sessionID: "s-3",
            currentHostVersionID: "v2")
        XCTAssertEqual(plan.targetVersionID, "v0")
    }

    // MARK: - Refusals

    func testNonRebootVerdictIsRejected() async throws {
        let stack = try await makeStack()
        try await stack.tree.registerGenesis(versionID: "v0")

        do {
            _ = try await stack.coord.planReboot(
                verdict: verdict(level: .throttle),
                sessionID: "s-4",
                currentHostVersionID: "v0")
            XCTFail("expected verdictDoesNotRequireReboot")
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .verdictDoesNotRequireReboot(let level)
        {
            XCTAssertEqual(level, .throttle)
        }
    }

    func testMissingAnchorForTargetIsRejected() async throws {
        let stack = try await makeStack()
        try await stack.tree.registerGenesis(versionID: "v0")

        do {
            _ = try await stack.coord.planReboot(
                verdict: verdict(level: .rollback),
                sessionID: "s-5",
                currentHostVersionID: "v0")
            XCTFail("expected versionHasNoAnchor")
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .versionHasNoAnchor(let vid)
        {
            XCTAssertEqual(vid, "v0")
        }
    }

    func testNoKnownGoodAncestorIsRejected() async throws {
        let stack = try await makeStack()
        let payload = Data("p".utf8)
        let anchor = makeAnchor(id: "a-v0", payload: payload)
        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.tree.markBad(
            versionID: "v0", reason: "genesis itself rotten")
        try await stack.coord.bindAnchor(
            anchorID: "a-v0", toVersionID: "v0")

        do {
            _ = try await stack.coord.planReboot(
                verdict: verdict(level: .rollback),
                sessionID: "s-6",
                currentHostVersionID: "v0")
            XCTFail("expected noKnownGoodAncestor")
        } catch BASSovereignCleanRebootCoordinator.CoordinatorError
            .noKnownGoodAncestor(let from)
        {
            XCTAssertEqual(from, "v0")
        }
    }

    // MARK: - Verification round-trip

    func testVerifyRestoredPayloadSucceedsOnMatch() async throws {
        let stack = try await makeStack()
        let payload = Data("payload-bytes-abc".utf8)
        let anchor = makeAnchor(id: "a-v0", payload: payload)
        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "x")
        try await stack.coord.bindAnchor(
            anchorID: "a-v0", toVersionID: "v0")

        let plan = try await stack.coord.planReboot(
            verdict: verdict(level: .rollback),
            sessionID: "s-ok",
            currentHostVersionID: "v1")

        let ok = await stack.coord.verifyRestoredPayload(
            plan: plan, presentedPayload: payload)
        XCTAssertTrue(ok)

        let tampered = Data("payload-bytes-xyz".utf8)
        let bad = await stack.coord.verifyRestoredPayload(
            plan: plan, presentedPayload: tampered)
        XCTAssertFalse(bad)
    }

    // MARK: - Ledger receives an audit entry for the plan

    func testPlanWritesAuditEntry() async throws {
        let stack = try await makeStack()
        let payload = Data("p".utf8)
        let anchor = makeAnchor(id: "a-v0", payload: payload)
        try await stack.snapshots.register(
            anchor: anchor, sealedPayload: payload)
        try await stack.tree.registerGenesis(versionID: "v0")
        try await stack.coord.bindAnchor(
            anchorID: "a-v0", toVersionID: "v0")

        let before = await stack.ledger.count()
        _ = try await stack.coord.planReboot(
            verdict: verdict(level: .rollback),
            sessionID: "s-aud",
            currentHostVersionID: "v0")
        let after = await stack.ledger.count()
        XCTAssertEqual(after, before + 1)
    }
}
