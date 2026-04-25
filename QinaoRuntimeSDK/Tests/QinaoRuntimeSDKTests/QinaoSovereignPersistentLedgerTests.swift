import XCTest
import BASSovereign
@testable import QinaoSovereign

/// M189 — cross-process audit-ledger persistence at the Qinao
/// public surface.
///
/// ## What this proves
///
/// `Configuration.ledgerDatabasePath` is the single host-facing
/// knob that turns SQLite-backed ledger persistence on. M91
/// already shipped `BASSovereignLedgerSQLiteStorage` at the
/// substrate layer; M189 is the Qinao SDK on-ramp.
///
/// Two things must hold:
///
/// 1. **Persistence happens.** A control plane bootstrapped with
///    a fresh path, asked to record a turn coverage verdict,
///    must materialise audit-ledger rows on disk.
/// 2. **Reopen rehydrates.** A second control plane bootstrapped
///    on the SAME path must observe the prior turn's audit data
///    via standard query APIs — proving cross-process recovery.
///
/// We simulate "different process" by tearing down the first
/// `QinaoSovereignControlPlane` actor, reopening a new one on
/// the same path. The SQLite file persists; the actor doesn't.
final class QinaoSovereignPersistentLedgerTests: XCTestCase {

    private func makeTempPath() -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-m189-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        return dir.path
    }

    private func cleanup(_ path: String) {
        // Sidecar files SQLite may create.
        for suffix in ["", "-journal", "-wal", "-shm"] {
            try? FileManager.default
                .removeItem(atPath: path + suffix)
        }
    }

    // MARK: - 1. nil path → in-memory (backwards compat)

    func testNilPathBootstrapsInMemoryLedger() async throws {
        let config = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: Data("m189-mem".utf8))
        // No path supplied — pre-M189 behavior preserved.
        let (plane, _) = QinaoSovereignControlPlane
            .bootstrap(configuration: config)
        // Smoke: a newly-bootstrapped control plane has no halted
        // sessions yet.
        let halted = await plane.isSessionHalted("any.session")
        XCTAssertFalse(halted)
    }

    // MARK: - 2. Cold start with path → file is created

    func testFreshPathCreatesSqliteFile() async throws {
        let path = makeTempPath()
        defer { cleanup(path) }

        let config = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: Data("m189-fresh".utf8),
            ledgerDatabasePath: path)
        _ = QinaoSovereignControlPlane
            .bootstrap(configuration: config)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: path),
            "fresh-path bootstrap MUST create the SQLite file")
    }

    // MARK: - 3. Cross-process: write → close → reopen → query

    /// The full integrity proof: bootstrap, drive an audit turn
    /// (which appends a hash-chained entry into the ledger),
    /// drop the actor, bootstrap a NEW one on the same path, and
    /// verify the entry count survived. Per M91 only `audit_entries`
    /// + `segments` are persisted; coverage cache and observation
    /// bundles are observability-grade and don't survive — `auditTurn`
    /// is the canonical path that produces a persisted entry.
    func testReopenSamePathRecoversAuditChain() async throws {
        let path = makeTempPath()
        defer { cleanup(path) }
        let secret = Data("m189-cross-process".utf8)
        let sessionID = "sess.m189.cross"
        let turnID = "turn.cross.1"

        // Phase A — first "process": bootstrap, run one audit turn
        // through the verifier engine (appends to the chain), then
        // let the actor go out of scope.
        let countAfterPhaseA: Int = try await {
            let configA = QinaoSovereignControlPlane.Configuration(
                ledgerSigningSecret: secret,
                ledgerDatabasePath: path)
            let (planeA, _) = QinaoSovereignControlPlane
                .bootstrap(configuration: configA)
            let observations = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: sessionID,
                    turnID: turnID,
                    snapshotRef: "snap.m189",
                    policyHash: "policy.m189")
            _ = try await planeA.auditTurn(
                observations: observations,
                coordinatorSeverity: .pass)
            return await planeA.auditEntryCount()
        }()
        XCTAssertGreaterThan(
            countAfterPhaseA, 0,
            "phase A must produce at least one audit entry " +
            "before we test reopening")
        // planeA out of scope; SQLite file persists.

        // Phase B — bootstrap a NEW control plane on the same path.
        // The audit chain must be recovered such that count is
        // at least the phase-A count.
        let configB = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: secret,
            ledgerDatabasePath: path)
        let (planeB, _) = QinaoSovereignControlPlane
            .bootstrap(configuration: configB)

        let countAfterReopen = await planeB.auditEntryCount()
        XCTAssertGreaterThanOrEqual(
            countAfterReopen, countAfterPhaseA,
            "audit ledger entry count after reopen must be ≥ the " +
            "phase-A count (rehydrate must restore the chain). " +
            "phase A: \(countAfterPhaseA), after reopen: " +
            "\(countAfterReopen)")
    }

    // MARK: - 4. Two distinct paths produce independent ledgers

    func testTwoDistinctPathsAreIndependent() async throws {
        let pathA = makeTempPath()
        let pathB = makeTempPath()
        defer { cleanup(pathA); cleanup(pathB) }

        let secret = Data("m189-disjoint".utf8)
        let configA = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: secret,
            ledgerDatabasePath: pathA)
        let configB = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: secret,
            ledgerDatabasePath: pathB)

        let (planeA, _) = QinaoSovereignControlPlane
            .bootstrap(configuration: configA)
        let (planeB, _) = QinaoSovereignControlPlane
            .bootstrap(configuration: configB)

        let observations = QinaoSovereignControlPlane
            .TurnObservations(
                sessionID: "sess.a", turnID: "t1",
                snapshotRef: "snap.a", policyHash: "policy.a")
        _ = try await planeA.auditTurn(
            observations: observations, coordinatorSeverity: .pass)

        // planeB never ran an audit; its ledger must be empty.
        let countA = await planeA.auditEntryCount()
        let countB = await planeB.auditEntryCount()
        XCTAssertGreaterThan(
            countA, 0,
            "plane A's path must accumulate entries")
        XCTAssertEqual(
            countB, 0,
            "plane B's path must remain untouched — ledger " +
            "isolation per database path")
    }
}
