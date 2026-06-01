// ch1044 A2 — verify-on-reload: a storage-wired ledger re-verifies its persisted chain
// on first use and QUARANTINES (refuses new appends) if any entry's signature/linkage
// no longer checks — the "integrity > availability" gate that previously had no caller.

import XCTest
import CryptoKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignAuditLedgerReloadVerifyTests: XCTestCase {

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-reload-\(UUID().uuidString).sqlite").path
    }

    private func entry(_ id: String) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: id, sessionID: "s", turnID: "t", verdictRef: "v",
            ruleIDs: ["BR-001"], signalRefs: [], actionRefs: [],
            snapshotRef: "snap", actor: .system, signature: "",
            appendedAt: Date(timeIntervalSince1970: 1))
    }

    /// A chain signed by key A, reloaded under a DIFFERENT key B (the shape of a
    /// tampered/forged persisted file), must quarantine + refuse new appends.
    func testReloadUnderWrongKeyQuarantinesAndRefusesAppend() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let keyA = BASSovereignEd25519KeyPair.generate()
        let keyB = BASSovereignEd25519KeyPair.generate()

        let ledgerA = BASSovereignAuditLedger(
            ed25519KeyPair: keyA,
            storage: try BASSovereignLedgerSQLiteStorage(path: path))
        _ = try await ledgerA.append(entry("a1"))
        _ = try await ledgerA.append(entry("a2"))

        let ledgerB = BASSovereignAuditLedger(
            ed25519KeyPair: keyB,
            storage: try BASSovereignLedgerSQLiteStorage(path: path))
        let quarantined = await ledgerB.isIntegrityQuarantined
        XCTAssertTrue(quarantined,
            "reloading a chain whose signatures don't verify must quarantine")
        do {
            _ = try await ledgerB.append(entry("b1"))
            XCTFail("a quarantined ledger must refuse new appends")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry { /* expected */ }
    }

    /// Control: reloading with the CORRECT key verifies and does NOT quarantine.
    func testReloadUnderCorrectKeyVerifiesAndAccepts() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let keyA = BASSovereignEd25519KeyPair.generate()

        let ledgerA = BASSovereignAuditLedger(
            ed25519KeyPair: keyA,
            storage: try BASSovereignLedgerSQLiteStorage(path: path))
        _ = try await ledgerA.append(entry("a1"))

        let ledgerB = BASSovereignAuditLedger(
            ed25519KeyPair: keyA,
            storage: try BASSovereignLedgerSQLiteStorage(path: path))
        let quarantined = await ledgerB.isIntegrityQuarantined
        XCTAssertFalse(quarantined, "a legit same-key reload must NOT quarantine")
        _ = try await ledgerB.append(entry("a2"))  // append works
    }
}
