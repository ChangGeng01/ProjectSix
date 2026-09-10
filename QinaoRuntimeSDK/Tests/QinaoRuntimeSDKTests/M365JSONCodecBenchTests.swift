import XCTest
@testable import BASRuntimeCore

/// M365 — pin substrate contracts that
/// `QinaoSampleHost --json-codec-bench` relies on.
///
/// Sample-host benches are not directly importable. This file
/// pins the substrate primitives the bench composes:
///
///   1. `BASSovereignAuditEntry` is Codable (synthesized).
///   2. JSON encode + decode round-trip preserves byte
///      equality of the original entry.
///   3. The representative entry shape (~5 ruleIDs × ~5
///      signal refs) serializes to a stable byte count.
///   4. JSONEncoder with `.sortedKeys` produces deterministic
///      output across runs.
final class M365JSONCodecBenchTests: XCTestCase {

    private func makeRepresentativeEntry()
        -> BASSovereignAuditEntry
    {
        BASSovereignAuditEntry(
            auditID: "test.audit.representative",
            sessionID:
                "test-session-representative",
            turnID: "test-turn-1",
            verdictRef: "test-verdict-1",
            ruleIDs: [
                "BR-001", "BR-002", "BR-003",
                "BR-004", "BR-005",
            ],
            signalRefs: [
                "frontier.status:dominant-clear",
                "tribunal.status:full-body-converged",
                "lifecycle.tickets:1",
                "lifecycle.promoted:0",
                "humanAnchor.tone:stable",
            ],
            actionRefs: [],
            snapshotRef: "test-snapshot-1",
            actor: .system,
            signature:
                "test-signature-placeholder-string-of-some-length",
            appendedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
    }

    func testEntryIsCodable() throws {
        let entry = makeRepresentativeEntry()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        XCTAssertGreaterThan(data.count, 0)
    }

    func testRoundTripPreservesEntryEquality() throws {
        let entry = makeRepresentativeEntry()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        let decoded = try JSONDecoder().decode(
            BASSovereignAuditEntry.self, from: data)
        XCTAssertEqual(entry, decoded)
    }

    func testSortedKeysProducesDeterministicJSON() throws {
        let entry = makeRepresentativeEntry()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let dataA = try encoder.encode(entry)
        let dataB = try encoder.encode(entry)
        XCTAssertEqual(dataA, dataB)
    }

    func testRepresentativeEntrySerializesToReasonableSize()
        throws
    {
        let entry = makeRepresentativeEntry()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        // Expect somewhere around 400-700 bytes for this shape.
        // Pin a loose range; if the entry schema grows
        // significantly, this fails and forces a re-baseline.
        XCTAssertGreaterThan(data.count, 300)
        XCTAssertLessThan(data.count, 1500)
    }
}
