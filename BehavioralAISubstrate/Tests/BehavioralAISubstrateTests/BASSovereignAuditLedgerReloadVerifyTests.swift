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

// ── 大审计本周层·H13/H14 gates(2026-07-07)────────────────────────────────────

/// H13:persist 失败后内存链不得分叉。失败一次的存储 → append 抛 → 内存回滚 →
/// 下一次成功 append 的 priorHash 指向真实前驱(GENESIS)→ reload 不 quarantine。
private final class FlakyOnceStorage: BASSovereignLedgerStorage, @unchecked Sendable {
    let inner: BASSovereignLedgerSQLiteStorage
    private let lock = NSLock()
    private var failNextAppend = true
    init(_ inner: BASSovereignLedgerSQLiteStorage) { self.inner = inner }
    struct Boom: Error {}
    func loadState() throws -> (entries: [BASSovereignAuditLedger.AppendedEntry],
                                segments: [BASSovereignLedgerSegment]) {
        try inner.loadState()
    }
    func persistAppended(_ entry: BASSovereignAuditLedger.AppendedEntry) throws {
        lock.lock(); let fail = failNextAppend; failNextAppend = false; lock.unlock()
        if fail { throw Boom() }
        try inner.persistAppended(entry)
    }
    func persistSegment(_ segment: BASSovereignLedgerSegment) throws {
        try inner.persistSegment(segment)
    }
}

/// H14:loadState 返回被截尾的 entries 但 segments entryCount 保持满 → reload 必 quarantine。
private struct TailTruncatingStorage: BASSovereignLedgerStorage {
    let inner: BASSovereignLedgerSQLiteStorage
    let dropTail: Int
    func loadState() throws -> (entries: [BASSovereignAuditLedger.AppendedEntry],
                                segments: [BASSovereignLedgerSegment]) {
        let s = try inner.loadState()
        let kept = Array(s.entries.dropLast(dropTail))   // 尾行被删,segments 不动
        return (kept, s.segments)
    }
    func persistAppended(_ entry: BASSovereignAuditLedger.AppendedEntry) throws {
        try inner.persistAppended(entry)
    }
    func persistSegment(_ segment: BASSovereignLedgerSegment) throws {
        try inner.persistSegment(segment)
    }
}

extension BASSovereignAuditLedgerReloadVerifyTests {

    func testH13_PersistFailureRollsBackSoNextAppendChainsCleanly() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = BASSovereignEd25519KeyPair.generate()
        let flaky = FlakyOnceStorage(try BASSovereignLedgerSQLiteStorage(path: path))

        let ledger = BASSovereignAuditLedger(ed25519KeyPair: key, storage: flaky)
        // append #1 持久化失败 → 必须抛 + 回滚(无相枢残留)。
        do { _ = try await ledger.append(entry("a1")); XCTFail("persist 失败应抛") }
        catch { /* expected */ }
        // append #2 成功——若 #1 未回滚,其 priorHash 会指向 #1 的幽灵 selfHash。
        _ = try await ledger.append(entry("a2"))

        // reload:H13 生效则盘上只有 a2、priorHash=GENESIS,链干净不 quarantine。
        let reloaded = BASSovereignAuditLedger(
            ed25519KeyPair: key, storage: try BASSovereignLedgerSQLiteStorage(path: path))
        let q = await reloaded.isIntegrityQuarantined
        XCTAssertFalse(q, "H13:persist 失败已回滚,盘链应干净不 quarantine")
        _ = try await reloaded.append(entry("a3"))   // 仍可 append
    }

    func testH14_TailTruncationOnReloadQuarantines() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = BASSovereignEd25519KeyPair.generate()
        let ledgerA = BASSovereignAuditLedger(
            ed25519KeyPair: key, storage: try BASSovereignLedgerSQLiteStorage(path: path))
        _ = try await ledgerA.append(entry("a1"))
        _ = try await ledgerA.append(entry("a2"))
        _ = try await ledgerA.append(entry("a3"))

        // 尾截断:攻击者删 audit_entries 尾行,segments entryCount 仍满(=3)。
        let truncating = TailTruncatingStorage(
            inner: try BASSovereignLedgerSQLiteStorage(path: path), dropTail: 1)
        let ledgerB = BASSovereignAuditLedger(ed25519KeyPair: key, storage: truncating)
        let q = await ledgerB.isIntegrityQuarantined
        XCTAssertTrue(q, "H14:entries(2) != Σsegment.entryCount(3) 必 quarantine")
        do {
            _ = try await ledgerB.append(entry("b1"))
            XCTFail("被 quarantine 的账本必须拒绝新 append")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry { /* expected */ }
    }

    func testH14_IntactReloadDoesNotFalseQuarantine() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = BASSovereignEd25519KeyPair.generate()
        let ledgerA = BASSovereignAuditLedger(
            ed25519KeyPair: key, storage: try BASSovereignLedgerSQLiteStorage(path: path))
        for i in 1...4 { _ = try await ledgerA.append(entry("a\(i)")) }
        let ledgerB = BASSovereignAuditLedger(
            ed25519KeyPair: key, storage: try BASSovereignLedgerSQLiteStorage(path: path))
        let q = await ledgerB.isIntegrityQuarantined
        XCTAssertFalse(q, "完好账本(count 对账通过)不得误 quarantine")
    }
}
