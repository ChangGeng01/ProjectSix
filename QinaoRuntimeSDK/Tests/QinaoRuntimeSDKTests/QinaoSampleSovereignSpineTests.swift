import XCTest
import CryptoKit
import BASSovereign
@testable import QinaoSample
@testable import QinaoDefaults
@testable import QinaoMemory

/// integration sample-upgrade (2026-07-12) — QinaoSample now feeds every LLM exchange
/// into the assembled LLM-free sovereign spine as DATA (charter posture), instead of
/// teaching the loop-direct pattern (turn-path map's path B).
@MainActor
final class QinaoSampleSovereignSpineTests: XCTestCase {

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-sample-spine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The spine is assembled once and cached — one ledger, one memory, one runtime.
    func testSovereignHostIsCached() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = SampleSession(ledgerDirectory: dir)
        let a = try await session.sovereignHost()
        let b = try await session.sovereignHost()
        XCTAssertTrue(a.runtime === b.runtime, "the spine must be assembled once")
    }

    /// One recorded exchange = memory admission + audited turn + PERSISTED keyed-ledger
    /// rows verifiable on a cold reopen with the stored local secret.
    func testRecordTurnAuditsAndPersists() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = SampleSession(ledgerDirectory: dir)

        let line = await session.recordTurn(
            sessionID: "sess.sample.spine",
            prompt: "hello there",
            responseBody: "general kenobi",
            providerID: "mock.provider")
        XCTAssertTrue(line.contains("ledger appended"),
            "a healthy exchange must report the appended ledger, got: \(line)")
        XCTAssertFalse(line.contains("REFUSED"))
        // charter audit 2026-07-12: the admission outcome is surfaced, never swallowed.
        XCTAssertTrue(line.contains("memory admitted"), "got: \(line)")

        // Memory admitted (the data crossing) — with TRUTHFUL LLM provenance, not "host".
        let host = try await session.sovereignHost()
        let memCount = await host.memory.count()
        XCTAssertEqual(memCount, 1, "the exchange must land in governed memory")
        let atoms = await host.memory.recallFrontstage()
        XCTAssertEqual(atoms.first?.sourceType, "qinao-sample.llm:mock.provider",
            "LLM-authored content must not wear host provenance")

        // Keyed ledger persisted: reopen COLD with the stored secret; chain verifies.
        let secret = try SampleSession.loadOrCreateLedgerSecret(in: dir)
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: dir.appendingPathComponent("sovereign-ledger.sqlite").path)
        let reopened = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data: secret), storage: storage)
        let quarantined = await reopened.isIntegrityQuarantined
        XCTAssertFalse(quarantined, "reloaded sample ledger must verify its chain")
        let count = await reopened.count()
        XCTAssertGreaterThan(count, 0, "the audited turn must persist keyed entries")
    }

    /// Two exchanges accumulate memory; the second turn's L8 is fed by the first.
    func testSecondTurnSeesAccumulatedMemory() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = SampleSession(ledgerDirectory: dir)
        _ = await session.recordTurn(
            sessionID: "sess.sample.spine2", prompt: "p1",
            responseBody: "r1", providerID: "mock")
        let line2 = await session.recordTurn(
            sessionID: "sess.sample.spine2", prompt: "p2",
            responseBody: "r2", providerID: "mock")
        XCTAssertTrue(line2.contains("ledger appended"), "got: \(line2)")
        let host = try await session.sovereignHost()
        let memCount = await host.memory.count()
        XCTAssertEqual(memCount, 2)
    }

    /// The local HMAC secret is generated once and reused — the chain stays verifiable
    /// across restarts (a regenerated secret would quarantine the prior chain).
    func testLedgerSecretIsStableAcrossLoads() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let s1 = try SampleSession.loadOrCreateLedgerSecret(in: dir)
        let s2 = try SampleSession.loadOrCreateLedgerSecret(in: dir)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1.count, 32)
    }
}
