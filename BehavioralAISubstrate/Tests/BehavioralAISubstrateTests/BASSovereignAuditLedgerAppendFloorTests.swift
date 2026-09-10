// ch1044 A2 append-floor — an OPT-IN minimum schema version for new appends. Default (no
// floor) accepts any version (byte-equal-off, current behavior). A hardened-only ledger
// rejects sub-1.2.0 (ambiguous delimiter-join) entries at append time.

import XCTest
import CryptoKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignAuditLedgerAppendFloorTests: XCTestCase {

    private func entry(
        _ id: String, schema: String
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            schemaVersion: schema,
            auditID: id, sessionID: "s", turnID: "t", verdictRef: "v",
            ruleIDs: ["BR-001"], signalRefs: [], actionRefs: [],
            snapshotRef: "snap", actor: .system, signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
    }

    func testDefaultLedgerHasNoFloorAndAcceptsLegacySchema() async throws {
        // No floor (the default) = byte-equal-off: a 1.0.0 entry is accepted as today.
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate())
        _ = try await ledger.append(entry("a1", schema: "1.0.0"))
        _ = try await ledger.append(entry("a2", schema: "1.1.0"))
        _ = try await ledger.append(entry("a3", schema: "1.2.0"))
    }

    func testHardenedFloorRejectsSubHardenedAppends() async throws {
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate(),
            minimumSchemaVersion: BASSovereignAuditEntry.hardenedSchemaVersion)  // "1.2.0"
        for legacy in ["1.0.0", "1.1.0"] {
            do {
                _ = try await ledger.append(entry("x", schema: legacy))
                XCTFail("floor must reject a \(legacy) entry")
            } catch BASSovereignAuditLedger.LedgerError
                .schemaVersionBelowFloor(let found, let floor) {
                XCTAssertEqual(found, legacy)
                XCTAssertEqual(floor, "1.2.0")
            }
        }
    }

    func testHardenedFloorAcceptsHardenedAppends() async throws {
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate(),
            minimumSchemaVersion: "1.2.0")
        _ = try await ledger.append(entry("h1", schema: "1.2.0"))  // at the floor → accepted
    }

    func testSchemaRankOrdersVersionsAndFailsClosedOnMalformed() {
        typealias L = BASSovereignAuditLedger
        XCTAssertTrue(L.schemaRank("1.0.0") < L.schemaRank("1.1.0"))
        XCTAssertTrue(L.schemaRank("1.1.0") < L.schemaRank("1.2.0"))
        XCTAssertTrue(L.schemaRank("1.2.0") < L.schemaRank("1.10.0"),
            "numeric (not lexicographic) comparison: 1.10.0 > 1.2.0")
        XCTAssertTrue(L.schemaRank("bogus") < L.schemaRank("1.0.0"),
            "a malformed version must rank below any well-formed one (fail-closed)")
        XCTAssertTrue(L.schemaRank("1.2.0") == L.schemaRank("1.2.0"))
    }
}
