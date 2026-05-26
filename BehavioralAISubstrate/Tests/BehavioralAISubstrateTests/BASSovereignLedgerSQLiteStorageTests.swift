import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// M91 — SQLite-backed cross-process ledger persistence tests.
///
/// Pins:
///
/// 1. **Null storage default** — a ledger constructed without
///    explicit storage behaves byte-for-byte like pre-M91 (no file
///    I/O; `BASSovereignLedgerNullStorage` every time).
///
/// 2. **Write → close → reopen → verify** — with SQLite storage, a
///    ledger that appends N entries, then is dropped, then is
///    reconstructed on the same path, must produce a chain whose
///    `verifyChainIntegrity()` passes.
///
/// 3. **Ed25519 signatures survive restart** — re-opened ledgers
///    still verify under `BASSovereignAuditLedger.verify(_:
///    publicKey:)` (the M87 static cross-process verifier).
///
/// 4. **Segment rotation survives restart** — a closed segment on
///    disk re-materializes with its `tailHash` / `closedAt` /
///    `closedBy` / `closingRotationID` intact, so reopened ledgers
///    don't accidentally re-open the same segment.
///
/// 5. **Open segment survives restart and accepts new entries** —
///    if a segment was open at shutdown, reopening a ledger lands
///    new appends in the existing segment rather than creating a
///    duplicate.
///
/// 6. **Schema version pin** — the `PRAGMA user_version` stays at
///    `BASSovereignLedgerSQLiteStorage.schemaVersion == 1`.
///
/// 7. **Non-integrity parallel storage stays in-memory** — M45
///    `coverageVerdicts` and M90 `observationBundles` do NOT survive
///    restart in this milestone (documented M92 scope). The test
///    pins the "does not survive" expectation so a future M92 that
///    changes the contract can update the test deliberately.
final class BASSovereignLedgerSQLiteStorageTests: XCTestCase {

    // MARK: - Fixtures

    /// Generate a unique path per test under `/tmp` so parallel
    /// test runs don't stomp on each other.
    private func tmpPath(_ label: String = #function) -> String {
        let id = UUID().uuidString
        return "/tmp/bas-sovereign-ledger-\(label.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))-\(id).sqlite"
    }

    private func removeFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
        // SQLite WAL mode creates -wal and -shm sidecar files.
        try? FileManager.default.removeItem(atPath: path + "-wal")
        try? FileManager.default.removeItem(atPath: path + "-shm")
    }

    private func makeEntry(
        auditID: String,
        session: String = "session-m91",
        turn: String = "turn-1",
        verdict: String = "verdict-m91",
        at seconds: TimeInterval = 1_700_000_000
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ["BR-001", "BR-012"],
            signalRefs: ["sig-a", "sig-b"],
            actionRefs: [],
            snapshotRef: "snap-m91",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: seconds))
    }

    // MARK: - 1. Null storage default preserves pre-M91 behaviour

    func testNullStorageDefaultIsInMemoryOnly() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("m91-null-default")
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        let count = await ledger.count()
        XCTAssertEqual(count, 1)
        // No file created; nothing to clean up.
    }

    // MARK: - 2. Write → close → reopen → verify with SQLite

    func testSqliteWriteCloseReopenVerifyChain() async throws {
        let path = tmpPath()
        defer { removeFile(path) }

        // Pass 1: write 3 HMAC-signed entries to SQLite.
        do {
            let storage = try BASSovereignLedgerSQLiteStorage(
                path: path)
            let key = SymmetricKey(data: SHA256.hash(data:
                Data("m91-reopen-seed".utf8)))
            let ledger = BASSovereignAuditLedger(
                signingSecret: key,
                storage: storage)
            _ = try await ledger.append(makeEntry(auditID: "a-1"))
            _ = try await ledger.append(
                makeEntry(auditID: "a-2", turn: "turn-2"))
            _ = try await ledger.append(
                makeEntry(auditID: "a-3", turn: "turn-3"))
            let firstCount = await ledger.count()
            XCTAssertEqual(firstCount, 3)
            try await ledger.verifyChainIntegrity()
        }

        // Pass 2: reopen + verify.
        let storage2 = try BASSovereignLedgerSQLiteStorage(
            path: path)
        let key2 = SymmetricKey(data: SHA256.hash(data:
            Data("m91-reopen-seed".utf8)))
        let ledger2 = BASSovereignAuditLedger(
            signingSecret: key2,
            storage: storage2)
        let reloadedCount = await ledger2.count()
        XCTAssertEqual(
            reloadedCount, 3,
            "3 entries reconstructed from SQLite")
        try await ledger2.verifyChainIntegrity()

        // Pass 2: append a 4th entry and verify chain continues.
        _ = try await ledger2.append(
            makeEntry(auditID: "a-4", turn: "turn-4"))
        let finalCount = await ledger2.count()
        XCTAssertEqual(finalCount, 4)
        try await ledger2.verifyChainIntegrity()
    }

    // MARK: - 3. Ed25519 signatures survive restart

    func testEd25519SignaturesSurviveReopen() async throws {
        let path = tmpPath()
        defer { removeFile(path) }
        let pair = try BASSovereignEd25519KeyPair.fromSeed(
            "m91-ed25519-persistence")

        // Write under Ed25519 mode.
        let appendedAuditIDs: [String]
        do {
            let storage = try BASSovereignLedgerSQLiteStorage(
                path: path)
            let ledger = BASSovereignAuditLedger(
                ed25519KeyPair: pair,
                storage: storage)
            let a = try await ledger.append(makeEntry(auditID: "e-1"))
            let b = try await ledger.append(
                makeEntry(auditID: "e-2", turn: "turn-2"))
            appendedAuditIDs = [a.entry.auditID, b.entry.auditID]
        }

        // Reopen + static cross-process verify each entry.
        let storage2 = try BASSovereignLedgerSQLiteStorage(
            path: path)
        let ledger2 = BASSovereignAuditLedger(
            ed25519KeyPair: pair,
            storage: storage2)
        let snapshot = await ledger2.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        for (idx, appended) in snapshot.enumerated() {
            XCTAssertEqual(appended.entry.auditID, appendedAuditIDs[idx])
            XCTAssertTrue(
                BASSovereignAuditLedger.verify(
                    appended, publicKey: pair.publicKey),
                "entry \(idx) must still verify under the same public key")
        }
    }

    // MARK: - 4. Segment rotation survives restart

    func testSegmentRotationSurvivesReopen() async throws {
        let path = tmpPath()
        defer { removeFile(path) }

        let rotationID = "rot-m91-a"
        do {
            let storage = try BASSovereignLedgerSQLiteStorage(
                path: path)
            let ledger = BASSovereignAuditLedger.withSeed(
                "m91-rotation-seed",
                namespace:
                    BASSovereignTrustConstants.signingNamespace)
            // Swap in our SQLite storage via fresh init.
            _ = ledger  // suppress unused warning
            let sqLedger = BASSovereignAuditLedger(
                signingSecret: SymmetricKey(data:
                    SHA256.hash(data:
                        Data("m91-rotation-seed".utf8))),
                storage: storage)
            _ = try await sqLedger.append(makeEntry(auditID: "s-1"))
            _ = try await sqLedger.append(
                makeEntry(auditID: "s-2", turn: "turn-2"))
            let plan = BASSovereignLedgerRotationPlan(
                rotationID: rotationID,
                sessionID: "session-m91",
                beforeTurnID: nil,
                reason: .scheduledRotation,
                requestedAt: Date(timeIntervalSince1970: 1_700_001_000))
            _ = try await sqLedger.rotate(plan: plan)
        }

        // Reopen and check the closed segment came back intact.
        let storage2 = try BASSovereignLedgerSQLiteStorage(
            path: path)
        let ledger2 = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data:
                SHA256.hash(data:
                    Data("m91-rotation-seed".utf8))),
            storage: storage2)
        let allSegs = await ledger2.allSegments()
        XCTAssertEqual(
            allSegs.count, 1,
            "one segment existed at rotation time")
        let closed = allSegs[0]
        XCTAssertNotNil(
            closed.tailHash,
            "rotation left tailHash populated")
        XCTAssertEqual(closed.closingRotationID, rotationID)
        XCTAssertEqual(closed.closedBy, .scheduledRotation)
        XCTAssertNotNil(closed.closedAt)
    }

    // MARK: - 5. Open segment survives restart + accepts new appends

    func testOpenSegmentSurvivesReopenAndAcceptsNewAppends()
        async throws {
        let path = tmpPath()
        defer { removeFile(path) }

        do {
            let storage = try BASSovereignLedgerSQLiteStorage(
                path: path)
            let ledger = BASSovereignAuditLedger(
                signingSecret: SymmetricKey(data:
                    SHA256.hash(data:
                        Data("m91-open-seed".utf8))),
                storage: storage)
            _ = try await ledger.append(
                makeEntry(auditID: "o-1", session: "sess-X"))
            // No rotation — segment stays open.
        }

        let storage2 = try BASSovereignLedgerSQLiteStorage(
            path: path)
        let ledger2 = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data:
                SHA256.hash(data:
                    Data("m91-open-seed".utf8))),
            storage: storage2)

        // Before new append: 1 segment, still open.
        let preSegs = await ledger2.allSegments()
        XCTAssertEqual(preSegs.count, 1)
        XCTAssertNil(preSegs[0].tailHash,
            "segment reopened as OPEN (tailHash == nil)")

        // New append on same session MUST land in the existing
        // segment, not open a second one.
        _ = try await ledger2.append(
            makeEntry(auditID: "o-2", session: "sess-X", turn: "t2"))
        let postSegs = await ledger2.allSegments()
        XCTAssertEqual(
            postSegs.count, 1,
            "new append uses the existing open segment")
        XCTAssertEqual(postSegs[0].entryCount, 2)
        try await ledger2.verifyChainIntegrity()
    }

    // MARK: - 6. Schema version contract

    func testSqliteSchemaVersionIsStable() throws {
        // chapter 九百九十四.5 META-REVIEW Round-10 CRITICAL-1
        // update:bumped from 1 → 2 to add the
        // entry_schema_version column。 Pre-fix v1 schema dropped
        // BASSovereignAuditEntry.schemaVersion on persist + reload
        // → ch 993 hardened "1.1.0" warrant entries failed
        // signature verification after restart → ledger flagged
        // corrupt。 v2 schema preserves per-entry schemaVersion
        // via ALTER TABLE ADD COLUMN with safe default,migrating
        // existing v1 DBs automatically on first open。 ANY
        // further bump from 2 → 3 IS a breaking M91 format change
        // requiring new migration code。
        XCTAssertEqual(
            BASSovereignLedgerSQLiteStorage.schemaVersion,
            2,
            "ch 994.5 CRITICAL-1: schemaVersion at 2 since the " +
            "Round-10 ledger-integrity fix。 Bumping past 2 is a " +
            "breaking M91 format change requiring new migration")
    }

    // MARK: - 7. Parallel storages (coverage + obs bundles) stay in-memory

    func testCoverageAndObservationStoragesDoNotSurviveReopen()
        async throws {
        let path = tmpPath()
        defer { removeFile(path) }

        do {
            let storage = try BASSovereignLedgerSQLiteStorage(
                path: path)
            let ledger = BASSovereignAuditLedger(
                signingSecret: SymmetricKey(data:
                    SHA256.hash(data:
                        Data("m91-parallel-seed".utf8))),
                storage: storage)
            _ = try await ledger.append(makeEntry(auditID: "p-1"))
            // Record coverage + observation data — in-memory only.
            let verdict = BASObservationReconciliationVerdict(
                turnID: "turn-1",
                sessionID: "session-m91",
                severity: .clean,
                findings: [],
                emittedAt: Date(timeIntervalSince1970: 1_700_000_000))
            await ledger.recordCoverageVerdict(verdict)
            let report = BASObservationReconciliationReport(
                turnID: "turn-1",
                sessionID: "session-m91",
                summaries: [
                    BASObservationCoverageSummary(
                        layer: .sovereign,
                        turnID: "turn-1",
                        sessionID: "session-m91",
                        totalObservations: 1,
                        distinctSubjectCount: 1,
                        hasCoreSignalCoverage: true,
                        budgetTotalCost: 0.1,
                        emittedAt: Date(
                            timeIntervalSince1970: 1_700_000_000))
                ])
            await ledger.recordObservationBundle(report)

            let coverageCount = await ledger.coverageVerdictCount()
            let bundleCount = await ledger.observationBundleCount()
            XCTAssertEqual(coverageCount, 1)
            XCTAssertEqual(bundleCount, 1)
        }

        // Reopen. The hash-chain entry IS persisted; the parallel
        // storages are NOT (documented M91 scope; M92 candidate).
        let storage2 = try BASSovereignLedgerSQLiteStorage(
            path: path)
        let ledger2 = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data:
                SHA256.hash(data:
                    Data("m91-parallel-seed".utf8))),
            storage: storage2)
        let reopenedEntryCount = await ledger2.count()
        let reopenedCoverageCount =
            await ledger2.coverageVerdictCount()
        let reopenedBundleCount =
            await ledger2.observationBundleCount()
        XCTAssertEqual(
            reopenedEntryCount, 1,
            "chain entry persisted")
        XCTAssertEqual(
            reopenedCoverageCount, 0,
            "M45 coverage verdicts NOT persisted in M91 (M92 scope)")
        XCTAssertEqual(
            reopenedBundleCount, 0,
            "M90 observation bundles NOT persisted in M91 (M92 scope)")
    }

    // MARK: - 8. NullStorage protocol conformance round-trip

    func testNullStorageLoadStateReturnsEmpty() throws {
        let storage = BASSovereignLedgerNullStorage()
        let (entries, segments) = try storage.loadState()
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(segments.isEmpty)
    }
}
