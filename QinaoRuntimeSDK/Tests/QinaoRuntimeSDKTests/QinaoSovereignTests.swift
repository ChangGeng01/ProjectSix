import XCTest
import CryptoKit
import BASRuntimeCore
import BASSovereign
@testable import QinaoSovereign

/// M7.7 — QinaoSovereign control-plane façade.
///
/// The tests below prove:
///
/// - **Rollback planning** translates coordinator errors into the
///   façade's host-facing error enum (no BAS names leak).
/// - **Plan shape** uses only the host-vocabulary `Step` enum —
///   no "verdict", "sentinel", "ring", or "EBRAIN" appear in the
///   returned plan's string form (belt-and-suspenders for the
///   redaction scanner).
/// - **Snapshot continuity** — `verifyRestore` rejects a payload
///   whose SHA-256 doesn't match the anchor's integrity hash.
/// - **Warrant lifecycle** — issuance binds (session, digest),
///   validation checks TTL, expired warrants are refused.
/// - **Halt interlock** — once a session is halted, new warrant
///   requests for it are refused at source.
final class QinaoSovereignTests: XCTestCase {

    // MARK: - Fixture

    private struct Fixture: Sendable {
        let sovereign: QinaoSovereignControlPlane
        let snapshotManager: BASSovereignSnapshotManager
        let versionTree: BASSovereignHostVersionTree
        let clock: MutableClock
    }

    final class MutableClock: @unchecked Sendable {
        var now: Date
        init(_ t: Date) { self.now = t }
    }

    private func makeFixture(
        startAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        warrantTTL: TimeInterval = 30
    ) -> Fixture {
        let clock = MutableClock(startAt)
        let now: @Sendable () -> Date = { [clock] in clock.now }
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
            warrantTTLSeconds: warrantTTL,
            now: now)
        return Fixture(
            sovereign: sovereign,
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            clock: clock)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func seedAnchor(
        in fx: Fixture,
        anchorID: String,
        versionID: String,
        payload: Data
    ) async throws {
        let anchor = BASSovereignSnapshotManager.SnapshotAnchor(
            anchorID: anchorID,
            safeSnapshotRef: "snap.\(anchorID)",
            integrityHash: sha256Hex(payload))
        _ = try await fx.snapshotManager.register(
            anchor: anchor, sealedPayload: payload)
        try await fx.versionTree.registerGenesis(versionID: versionID)
        try await fx.sovereign.bindSnapshotAnchor(
            anchorID: anchorID, toVersionID: versionID)
    }

    // MARK: - Rollback plan happy path

    func testRequestRollbackProducesHostFacingPlan() async throws {
        let fx = makeFixture()
        let payload = Data("v1-body".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.v1", versionID: "host.v1",
            payload: payload)

        let plan = try await fx.sovereign.requestRollback(
            sessionID: "sess.1", fromVersionID: "host.v1")

        XCTAssertEqual(plan.sessionID, "sess.1")
        XCTAssertEqual(plan.fromVersionID, "host.v1")
        XCTAssertEqual(plan.toVersionID, "host.v1")
        XCTAssertEqual(plan.snapshotAnchorID, "a.v1")
        XCTAssertTrue(plan.bootstrapNextSession)
        XCTAssertFalse(plan.planID.isEmpty)

        // Expected host-facing step sequence for a rollback-level
        // plan: quarantine → release → close → restore → verify →
        // bootstrapNextSession. No "halt-and-await".
        XCTAssertEqual(
            plan.steps,
            [
                .quarantineCurrentSession,
                .releaseActiveLocks,
                .closeSessionAuditTrail,
                .restoreSnapshot,
                .verifyRestoredIntegrity,
                .bootstrapNextSession,
            ])
    }

    func testHaltSessionProducesDeadStopPlan() async throws {
        let fx = makeFixture()
        let payload = Data("v1-halt".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.halt", versionID: "host.v1",
            payload: payload)

        let plan = try await fx.sovereign.haltSession(
            sessionID: "sess.1", fromVersionID: "host.v1")

        XCTAssertFalse(plan.bootstrapNextSession)
        XCTAssertTrue(plan.steps.contains(.awaitHumanIntervention))
        XCTAssertFalse(plan.steps.contains(.bootstrapNextSession))

        let halted = await fx.sovereign.isSessionHalted("sess.1")
        XCTAssertTrue(halted)
    }

    // MARK: - Rollback error translation

    func testRollbackUnknownVersionSurfacesTypedError() async throws {
        let fx = makeFixture()
        do {
            _ = try await fx.sovereign.requestRollback(
                sessionID: "sess.1", fromVersionID: "host.vX")
            XCTFail("expected unknownVersion")
        } catch QinaoSovereignControlPlane.SovereignError
            .unknownVersion(let id)
        {
            XCTAssertEqual(id, "host.vX")
        }
    }

    func testRollbackWithoutAnchorSurfacesTypedError() async throws {
        let fx = makeFixture()
        try await fx.versionTree.registerGenesis(versionID: "host.v1")
        do {
            _ = try await fx.sovereign.requestRollback(
                sessionID: "sess.1", fromVersionID: "host.v1")
            XCTFail("expected missingRollbackAnchor")
        } catch QinaoSovereignControlPlane.SovereignError
            .missingRollbackAnchor(let id)
        {
            XCTAssertEqual(id, "host.v1")
        }
    }

    // MARK: - Verify restore (integrity)

    func testVerifyRestoreAcceptsMatchingPayload() async throws {
        let fx = makeFixture()
        let payload = Data("v1-body".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.v1", versionID: "host.v1",
            payload: payload)
        let plan = try await fx.sovereign.requestRollback(
            sessionID: "sess.1", fromVersionID: "host.v1")

        try await fx.sovereign.verifyRestore(
            plan: plan, presentedPayload: payload)
    }

    func testVerifyRestoreRejectsTamperedPayload() async throws {
        let fx = makeFixture()
        let payload = Data("v1-body".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.v1", versionID: "host.v1",
            payload: payload)
        let plan = try await fx.sovereign.requestRollback(
            sessionID: "sess.1", fromVersionID: "host.v1")

        let tampered = Data("v1-body-tampered".utf8)
        do {
            try await fx.sovereign.verifyRestore(
                plan: plan, presentedPayload: tampered)
            XCTFail("expected integrityMismatch")
        } catch QinaoSovereignControlPlane.SovereignError
            .integrityMismatch(let v)
        {
            XCTAssertEqual(v, "host.v1")
        }
    }

    func testVerifyRestoreRejectsForgedPlan() async throws {
        // A plan this façade never issued cannot be verified. Proves
        // `planCache` is the only provenance path.
        let fx = makeFixture()
        let forgedPlan = QinaoSovereignControlPlane.RollbackPlan(
            planID: "plan.forged",
            sessionID: "sess.1",
            fromVersionID: "host.v1",
            toVersionID: "host.v1",
            snapshotAnchorID: "a.v1",
            steps: [.restoreSnapshot, .verifyRestoredIntegrity,
                    .bootstrapNextSession],
            issuedAt: Date(),
            bootstrapNextSession: true,
            auditRef: "ar.forged")

        do {
            try await fx.sovereign.verifyRestore(
                plan: forgedPlan, presentedPayload: Data())
            XCTFail("expected integrityMismatch for forged plan")
        } catch QinaoSovereignControlPlane.SovereignError
            .integrityMismatch
        {
            // expected
        }
    }

    // MARK: - Warrant lifecycle

    func testIssueWarrantBindsSessionAndDigest() async throws {
        let fx = makeFixture()
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "d.a",
            sessionID: "sess.1",
            hostVersionID: "host.v1")
        let warrant = try await fx.sovereign.issueWarrant(for: intent)
        XCTAssertEqual(warrant.sessionID, intent.sessionID)
        XCTAssertEqual(warrant.intentDigest, intent.digest)

        let valid = await fx.sovereign.isWarrantValid(warrant, for: intent)
        XCTAssertTrue(valid)
    }

    func testWarrantRejectsWrongIntent() async throws {
        let fx = makeFixture()
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "d.a",
            sessionID: "sess.1",
            hostVersionID: "host.v1")
        let warrant = try await fx.sovereign.issueWarrant(for: intent)

        let wrongDigest = QinaoSovereignControlPlane.Intent(
            digest: "d.b",
            sessionID: "sess.1",
            hostVersionID: "host.v1")
        let wrongSession = QinaoSovereignControlPlane.Intent(
            digest: "d.a",
            sessionID: "sess.2",
            hostVersionID: "host.v1")

        let v1 = await fx.sovereign.isWarrantValid(
            warrant, for: wrongDigest)
        let v2 = await fx.sovereign.isWarrantValid(
            warrant, for: wrongSession)
        XCTAssertFalse(v1)
        XCTAssertFalse(v2)
    }

    func testWarrantExpiresAfterTTL() async throws {
        let fx = makeFixture(warrantTTL: 5)
        let intent = QinaoSovereignControlPlane.Intent(
            digest: "d.a",
            sessionID: "sess.1",
            hostVersionID: "host.v1")
        let warrant = try await fx.sovereign.issueWarrant(for: intent)

        fx.clock.now = fx.clock.now.addingTimeInterval(10)
        let valid = await fx.sovereign.isWarrantValid(warrant, for: intent)
        XCTAssertFalse(valid)
    }

    func testClearHaltReenablesWarrantIssuance() async throws {
        let fx = makeFixture()
        let payload = Data("p".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.v1", versionID: "host.v1",
            payload: payload)
        _ = try await fx.sovereign.haltSession(
            sessionID: "sess.1", fromVersionID: "host.v1")

        // Halted: issuance fails.
        do {
            _ = try await fx.sovereign.issueWarrant(
                for: QinaoSovereignControlPlane.Intent(
                    digest: "d.a",
                    sessionID: "sess.1",
                    hostVersionID: "host.v1"))
            XCTFail("expected sessionHalted")
        } catch QinaoSovereignControlPlane.SovereignError.sessionHalted {
            // expected
        }

        // Clear halt → issuance succeeds.
        await fx.sovereign.clearHalt(sessionID: "sess.1")
        _ = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: "d.a",
                sessionID: "sess.1",
                hostVersionID: "host.v1"))
    }

    // MARK: - Redaction

    /// The host-facing plan must never carry substrate internal
    /// vocabulary. Assert the JSON form of the plan is clean.
    func testPlanJSONHasNoSubstrateTerms() async throws {
        let fx = makeFixture()
        let payload = Data("v1-body".utf8)
        try await seedAnchor(
            in: fx, anchorID: "a.v1", versionID: "host.v1",
            payload: payload)
        let plan = try await fx.sovereign.requestRollback(
            sessionID: "sess.1", fromVersionID: "host.v1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(data: try encoder.encode(plan.steps),
                          encoding: .utf8) ?? ""
        let forbidden = [
            "verdict", "sentinel", "blackRing", "black_ring",
            "EBRAIN", "BAS",
        ]
        for term in forbidden {
            XCTAssertFalse(
                json.lowercased().contains(term.lowercased()),
                "redaction leak: '\(term)' found in plan JSON: \(json)")
        }
    }

    // MARK: - M9 · Turn audit

    /// Clean primitives flow through to `.pass` with `.engineOnly`
    /// parity when no coordinator severity is supplied.
    private func cleanObservations(
        sessionID: String = "sess.audit",
        turnID: String = "turn.1"
    ) -> BASSovereignTurnObservations {
        BASSovereignTurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.audit",
            policyHash: BASSovereignTrustConstants.builtInPolicyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.0,
            manipulationStrength: 0.0,
            uncertaintyScore: 0.0,
            gsiScore: 0.0,
            hostGateValue: 0.9,
            quarantineCount: 0,
            runMode: .engage,
            emergencyBrakeLevel: .none,
            operation: .pureInference,
            evidenceSufficient: true)
    }

    func testAuditTurnCleanPassEngineOnly() async throws {
        let fx = makeFixture()
        let obs = cleanObservations()
        let report = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: nil)
        XCTAssertEqual(report.sessionID, "sess.audit")
        XCTAssertEqual(report.turnID, "turn.1")
        XCTAssertEqual(report.severity, .pass)
        XCTAssertNil(report.coordinatorSeverity)
        XCTAssertEqual(report.parity, .engineOnly)
        XCTAssertTrue(report.isAcceptable)
        XCTAssertFalse(report.auditRef.isEmpty)
    }

    /// BR-006 — policy lineage missing forces `.deadStop`; when the
    /// coordinator also says `.deadStop`, parity is `.match`.
    func testAuditTurnPolicyLineageMissingMatchesCoordinatorDeadStop()
        async throws
    {
        let fx = makeFixture()
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: true,
            auditEntryMissing: obs.auditEntryMissing,
            runtimeUnstableInHighRisk: obs.runtimeUnstableInHighRisk,
            riskPermitHeadConflict: obs.riskPermitHeadConflict,
            externalSideEffectWithoutSCT: obs.externalSideEffectWithoutSCT,
            hostRemovalBypassed: obs.hostRemovalBypassed,
            unauthorizedSelfMutation: obs.unauthorizedSelfMutation,
            memoryOrHostWriteBypass: obs.memoryOrHostWriteBypass,
            irreversibilityScore: obs.irreversibilityScore,
            manipulationStrength: obs.manipulationStrength,
            uncertaintyScore: obs.uncertaintyScore,
            gsiScore: obs.gsiScore,
            hostGateValue: obs.hostGateValue,
            quarantineCount: obs.quarantineCount,
            runMode: obs.runMode,
            emergencyBrakeLevel: obs.emergencyBrakeLevel,
            operation: obs.operation,
            evidenceSufficient: obs.evidenceSufficient)

        let report = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: .deadStop)

        XCTAssertEqual(report.severity, .deadStop)
        XCTAssertEqual(report.coordinatorSeverity, .deadStop)
        XCTAssertEqual(report.parity, .match)
        XCTAssertTrue(report.isAcceptable)
    }

    /// Coordinator stricter than engine is allowed — audit severity is
    /// `.pass`, coordinator severity is `.throttle`, parity is
    /// `.coordinatorStricter`, and the report is acceptable.
    func testAuditTurnCoordinatorStricterIsAcceptable() async throws {
        let fx = makeFixture()
        let obs = cleanObservations()
        let report = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: .throttle)
        XCTAssertEqual(report.severity, .pass)
        XCTAssertEqual(report.parity, .coordinatorStricter)
        XCTAssertTrue(report.isAcceptable)
    }

    /// Engine fires `.memoryFreeze` (≥) on memoryOrHostWriteBypass
    /// (BR-004). Coordinator says `.pass` (too lax). Parity is
    /// `.coordinatorLaxer`; report flags fail-closed.
    func testAuditTurnCoordinatorLaxerIsFailClosed() async throws {
        let fx = makeFixture()
        var obs = cleanObservations()
        obs = BASSovereignTurnObservations(
            sessionID: obs.sessionID, turnID: obs.turnID,
            snapshotRef: obs.snapshotRef, policyHash: obs.policyHash,
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: true,
            irreversibilityScore: 0.0,
            manipulationStrength: 0.0,
            uncertaintyScore: 0.0,
            gsiScore: 0.0,
            hostGateValue: obs.hostGateValue,
            quarantineCount: 0,
            runMode: obs.runMode,
            emergencyBrakeLevel: obs.emergencyBrakeLevel,
            operation: .memoryPromote,
            evidenceSufficient: true)

        let report = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: .pass)
        XCTAssertGreaterThanOrEqual(report.severity, .memoryFreeze)
        XCTAssertEqual(report.coordinatorSeverity, .pass)
        XCTAssertEqual(report.parity, .coordinatorLaxer)
        XCTAssertFalse(report.isAcceptable)
    }

    /// Severity mirror ladder is monotonic (Comparable).
    func testAuditSeverityOrdering() {
        typealias S = QinaoSovereignControlPlane.AuditSeverity
        let ordered: [S] = [
            .pass, .throttle, .shadowLock, .toolCut,
            .memoryFreeze, .quarantine, .rollback, .deadStop]
        for i in 0..<(ordered.count - 1) {
            XCTAssertLessThan(ordered[i], ordered[i + 1])
        }
    }

    /// Every turn audit writes one entry to the shared ledger, so the
    /// auditRef is unique across back-to-back audits with the same
    /// inputs.
    func testAuditTurnProducesUniqueAuditRefs() async throws {
        let fx = makeFixture()
        let obs = cleanObservations()
        let r1 = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: nil)
        let r2 = try await fx.sovereign.auditTurn(
            observations: obs, coordinatorSeverity: nil)
        XCTAssertNotEqual(r1.auditRef, r2.auditRef)
        XCTAssertEqual(r1.severity, .pass)
        XCTAssertEqual(r2.severity, .pass)
    }
}
