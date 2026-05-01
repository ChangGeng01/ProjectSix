import XCTest
@testable import BASSovereign
@testable import BASRuntimeCore

/// M357 — pin substrate contracts that
/// `QinaoSampleHost --audit-ledger-bench` relies on.
///
/// Sample-host benches are not directly importable
/// (executable target). This file pins the substrate
/// primitives the bench composes:
///
///   1. `BASSovereignAuditLedger.withEd25519Seed(_:)` builds a
///      working ledger from a deterministic seed string.
///   2. `BASSovereignAuditLedger.append(_:)` is async-throws
///      and increments `count()` by 1 per successful append.
///   3. The append path produces non-empty signatures (Ed25519
///      production path).
final class M357AuditLedgerBenchTests: XCTestCase {

    private func makeEntry(
        index: Int
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: "test.audit.\(index)",
            sessionID: "test-session",
            turnID: "turn-\(index)",
            verdictRef: "v",
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap",
            actor: .system,
            signature: "",
            appendedAt: Date(
                timeIntervalSince1970:
                    1_700_000_000 + Double(index)))
    }

    func testEd25519SeedFactoryProducesUsableLedger()
        async throws
    {
        let ledger = try BASSovereignAuditLedger
            .withEd25519Seed("m357-test-seed")
        let appended = try await ledger.append(
            makeEntry(index: 0))
        XCTAssertEqual(
            appended.entry.auditID, "test.audit.0")
        XCTAssertFalse(appended.entry.signature.isEmpty)
    }

    func testAppendIncrementsCountByOne() async throws {
        let ledger = try BASSovereignAuditLedger
            .withEd25519Seed("m357-test-seed")
        let initialCount = await ledger.count()
        XCTAssertEqual(initialCount, 0)
        for i in 0..<5 {
            _ = try await ledger.append(
                makeEntry(index: i))
        }
        let finalCount = await ledger.count()
        XCTAssertEqual(finalCount, 5)
    }

    func testAppendedEntriesAreQueryableByAuditRef()
        async throws
    {
        let ledger = try BASSovereignAuditLedger
            .withEd25519Seed("m357-test-seed")
        for i in 0..<3 {
            _ = try await ledger.append(
                makeEntry(index: i))
        }
        let queried = try await ledger.query(
            byAuditRef: "test.audit.1")
        XCTAssertEqual(
            queried.entry.auditID, "test.audit.1")
    }

    func testChainIntegrityVerifiesAfterMultipleAppends()
        async throws
    {
        let ledger = try BASSovereignAuditLedger
            .withEd25519Seed("m357-test-seed")
        for i in 0..<10 {
            _ = try await ledger.append(
                makeEntry(index: i))
        }
        try await ledger.verifyChainIntegrity()
    }
}
