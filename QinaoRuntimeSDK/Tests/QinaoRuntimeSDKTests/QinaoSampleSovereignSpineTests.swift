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
        // deep-audit HIGH-1 (2026-07-13): under the seed constitution (review_required),
        // raw LLM content is HELD as .candidate, not auto-promoted — the outcome is surfaced.
        XCTAssertTrue(line.contains("memory held"), "got: \(line)")

        // Memory landed (the data crossing) with TRUTHFUL LLM provenance — but as a HELD
        // candidate, so it is present in the full recall yet NOT frontstage-eligible.
        let host = try await session.sovereignHost()
        let memCount = await host.memory.count()
        XCTAssertEqual(memCount, 1, "the exchange must land in memory (held for review)")
        let frontstage = await host.memory.recallFrontstage()
        XCTAssertTrue(frontstage.isEmpty,
            "unreviewed LLM content must NOT be frontstage-eligible under review_required")

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

    /// Two exchanges accumulate memory (both held as candidates under the seed
    /// constitution's review_required — deep-audit HIGH-1); count reflects both.
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

    /// deep-audit P1-12 (2026-07-13): the SIGNED, PERSISTED audit entry is content-bound to
    /// the exchange. Before the fix, snapshotRef was the fixed placeholder "snap.sample", so
    /// two different prompts/responses produced byte-identical audit content. Now snapshotRef
    /// is derived from the SHA-256 digests of prompt AND response — reverting the derivation
    /// (back to "snap.sample") reds this tooth.
    func testPersistedAuditEntryIsContentBoundToTheExchange() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = SampleSession(ledgerDirectory: dir)

        let prompt = "what is the capital of France?"
        let response = "Paris."
        _ = await session.recordTurn(
            sessionID: "sess.bind", prompt: prompt,
            responseBody: response, providerID: "mock.provider")

        let promptDigest = SampleSession.sha256Hex(prompt)
        let responseDigest = SampleSession.sha256Hex(response)
        let expectedRef = "snap.sample.\(promptDigest.prefix(8)).\(responseDigest.prefix(8))"

        // Reopen COLD with the stored secret; the chain must verify AND a persisted entry's
        // signed snapshotRef must commit to THIS exchange.
        let secret = try SampleSession.loadOrCreateLedgerSecret(in: dir)
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: dir.appendingPathComponent("sovereign-ledger.sqlite").path)
        let reopened = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(data: secret), storage: storage)
        let quarantined = await reopened.isIntegrityQuarantined
        XCTAssertFalse(quarantined, "reloaded sample ledger must verify its chain")

        let entries = await reopened.snapshot()
        XCTAssertTrue(entries.contains { $0.entry.snapshotRef == expectedRef },
            "a persisted audit entry must be content-bound to the exchange "
            + "(snapshotRef=\(expectedRef)); got \(entries.map { $0.entry.snapshotRef })")
        // The bound ref depends on BOTH digests: a different response changes the expected ref.
        let wrongResponseRef =
            "snap.sample.\(promptDigest.prefix(8)).\(SampleSession.sha256Hex("different").prefix(8))"
        XCTAssertFalse(entries.contains { $0.entry.snapshotRef == wrongResponseRef },
            "the ref must bind the actual response, not just the prompt")
        // Reversal witness: the fixed placeholder must be gone.
        XCTAssertFalse(entries.contains { $0.entry.snapshotRef == "snap.sample" },
            "the fixed placeholder snapshotRef must no longer be persisted")
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
