import XCTest
import CryptoKit
import BASRuntimeCore
import BASSovereign
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoRuntime

/// M103 — end-to-end permit → sovereign ledger bridge test.
///
/// M99 added the `PermitEventRecorder` hook. M103 sovereign half
/// added `QinaoSovereignControlPlane.recordPermitIssued`. This
/// file wires them through `QinaoRuntime.makeSovereignPermitEventRecorder`
/// and proves:
///
/// 1. A successful permit issue produces exactly one ledger entry
///    with the expected shape (rule ID, digest, reason codes).
/// 2. Chain integrity survives — the ledger's `verifyChainIntegrity()`
///    returns true after the append.
/// 3. Multiple permits produce distinct hash-chained entries, each
///    verifiable.
/// 4. A blocked permit does NOT reach the ledger (no entry added).
final class QinaoPermitLedgerBridgeTests: XCTestCase {

    // MARK: - Fixtures

    private func makeLedgerAndSovereign(
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> (
        ledger: BASSovereignAuditLedger,
        sovereign: QinaoSovereignControlPlane
    ) {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now)
        return (ledger, sovereign)
    }

    private func makeIntent(
        digest: String = "digest-m103",
        sessionID: String = "sess-m103"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: "tool.m103",
            sessionID: sessionID,
            hostVersionID: "host.v1",
            summary: "integration test")
    }

    // MARK: - 1. Successful permit → single ledger entry

    func testSuccessfulPermitAppendsOneLedgerEntry() async throws {
        let (ledger, sovereign) = makeLedgerAndSovereign()
        let recorder = QinaoRuntime
            .makeSovereignPermitEventRecorder(
                sovereign: sovereign)
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: recorder)

        let preCount = await ledger.count()
        let permit = try await gate.requestActionPermit(
            for: makeIntent(), signals: .safe)
        let postCount = await ledger.count()

        XCTAssertEqual(permit.mode, .allow)
        XCTAssertEqual(
            postCount, preCount + 1,
            "exactly one ledger entry per successful permit")

        // Verify chain integrity (throws on failure).
        do {
            try await ledger.verifyChainIntegrity()
        } catch {
            XCTFail(
                "ledger chain integrity broken: \(error)")
        }

        // Verify the entry content matches the permit.
        let entry = await ledger.snapshot().last?.entry
        XCTAssertEqual(
            entry?.verdictRef,
            "permit:issued:\(permit.permitID)")
        XCTAssertEqual(entry?.ruleIDs, ["permit:issued"])
        XCTAssertEqual(
            entry?.actionRefs, [permit.digest])
        XCTAssertEqual(entry?.sessionID, permit.sessionID)
    }

    // MARK: - 2. Multiple permits chain cleanly

    func testMultiplePermitsChainWithVerifiableIntegrity()
        async throws {
        let (ledger, sovereign) = makeLedgerAndSovereign()
        let recorder = QinaoRuntime
            .makeSovereignPermitEventRecorder(
                sovereign: sovereign)
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: recorder)

        _ = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.1"), signals: .safe)
        _ = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.2"), signals: .safe)
        _ = try await gate.requestActionPermit(
            for: makeIntent(digest: "d.3"), signals: .safe)

        let count = await ledger.count()
        XCTAssertEqual(
            count, 3, "one entry per permit")
        do {
            try await ledger.verifyChainIntegrity()
        } catch {
            XCTFail("chain broken after 3 permits: \(error)")
        }

        // Order-preserving: entries appear in issue order.
        let digests = await ledger.snapshot()
            .flatMap { $0.entry.actionRefs }
        XCTAssertEqual(digests, ["d.1", "d.2", "d.3"])
    }

    // MARK: - 3. Blocked permit writes nothing

    func testBlockedPermitLeavesLedgerUntouched() async throws {
        let (ledger, sovereign) = makeLedgerAndSovereign()
        let recorder = QinaoRuntime
            .makeSovereignPermitEventRecorder(
                sovereign: sovereign)
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: recorder)

        let unsafe = QinaoRiskGate.RiskSignals(
            harmSeverity: 1.0,
            harmScope: 1.0,
            irreversibility: 1.0,
            uncertainty: 1.0,
            evidenceDebt: 1.0,
            manipulationIntensity: 1.0,
            pressureAuthenticity: 0.0,
            gsiScore: 1.0)

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(), signals: unsafe)
            XCTFail("expected block")
        } catch QinaoRiskGate.RiskError.denied {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }

        let count = await ledger.count()
        XCTAssertEqual(
            count, 0,
            "no entry when permit assessment rejects")
    }

    // MARK: - 4. SessionID round-trip

    func testPermitSessionIDAppearsOnLedgerEntry() async throws {
        let (ledger, sovereign) = makeLedgerAndSovereign()
        let recorder = QinaoRuntime
            .makeSovereignPermitEventRecorder(
                sovereign: sovereign)
        let gate = QinaoRiskGate(
            permitTTLSeconds: 60,
            permitEventRecorder: recorder)

        _ = try await gate.requestActionPermit(
            for: makeIntent(sessionID: "distinctive.session.m103"),
            signals: .safe)

        let entry = await ledger.snapshot().last?.entry
        XCTAssertEqual(
            entry?.sessionID, "distinctive.session.m103",
            "sessionID round-trips from permit through recorder to ledger")
    }
}
