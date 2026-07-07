import XCTest
@testable import BASMemory

/// 大审计本周层·梯次2 gates(2026-07-07)——删除教义 vs 物理字节。
/// H11:tombstone 跨重启存活 + 已删记录不复活;H12:purge 清 notes+FTS(第四红腿)。
final class BASMemoryTombstonePurgeTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-\(UUID().uuidString).sqlite")
    }

    // MARK: - H11 tombstone reload + read filter

    func testH11_TombstoneSurvivesRestart() async throws {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let rid: String
        do {
            let t = try BASMemoryUsageTracker(databaseURL: url)
            rid = try await t.record(atomID: "a1", sessionRef: "s", turnRef: "t", permitMode: "answer")
            try await t.tombstoneRecord(recordID: rid)
            let live = await t.isTombstoned(recordID: rid)
            XCTAssertTrue(live)
        }
        // 新进程(重开同 DB):tombstone 必须仍在,记录不得复活。
        let t2 = try BASMemoryUsageTracker(databaseURL: url)
        let stillTomb = await t2.isTombstoned(recordID: rid)
        XCTAssertTrue(stillTomb, "H11:tombstone 必须跨重启存活(曾 init 不回灌)")
        let rec = await t2.record(forID: rid)
        XCTAssertNil(rec, "H11:已 tombstone 记录不得作为 live 返回")
        let all = await t2.allRecords()
        XCTAssertFalse(all.contains { $0.recordID == rid }, "H11:allRecords 必须过滤 tombstoned")
        let active = await t2.activeRecordCount
        XCTAssertEqual(active, 0, "H11:activeRecordCount 不得把 forgotten 记录算活")
    }

    func testH11_PurgeCountCorrectAcrossRestart() async throws {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let rid: String
        do {
            let t = try BASMemoryUsageTracker(databaseURL: url)
            rid = try await t.record(atomID: "a1", sessionRef: "s", turnRef: "t", permitMode: "answer")
            try await t.tombstoneRecord(recordID: rid)
        }
        let t2 = try BASMemoryUsageTracker(databaseURL: url)
        let purged = try await t2.purgeTombstoned()
        XCTAssertEqual(purged, 1, "H11:重启后 purge 计数应为 1(曾返回 0)")
        _ = rid
    }

    // MARK: - H12 purge clears notes + FTS (4th red leg)

    func testH12_PurgeClearsNotesAndFTS() async throws {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let t = try BASMemoryUsageTracker(databaseURL: url)
        let rid = try await t.record(atomID: "a1", sessionRef: "s", turnRef: "t", permitMode: "answer")
        try await t.attachNotes(recordID: rid, notes: "MERIDIAN secret atom content")
        // 命中确认(purge 前可搜)。
        let before = try await t.searchNotesFTS(query: "MERIDIAN")
        XCTAssertTrue(before.contains(rid), "purge 前应可搜到")
        // tombstone → purge → notes/FTS 必须一并清除(第四红腿)。
        try await t.tombstoneRecord(recordID: rid)
        _ = try await t.purgeTombstoned()
        let after = try await t.searchNotesFTS(query: "MERIDIAN")
        XCTAssertFalse(after.contains(rid),
                       "H12:物理清除后 notes/FTS 不得仍命中(第四残留通道)")
    }

    func testH12_TimeGCClearsNotesAndFTS() async throws {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let t = try BASMemoryUsageTracker(databaseURL: url)
        let old = Date(timeIntervalSince1970: 1000)
        let rid = try await t.record(atomID: "a1", sessionRef: "s", turnRef: "t", permitMode: "answer", retrievedAt: old)
        try await t.attachNotes(recordID: rid, notes: "STALE content to be GC'd")
        _ = try await t.purge(olderThan: Date(timeIntervalSince1970: 2000))
        let after = try await t.searchNotesFTS(query: "STALE")
        XCTAssertFalse(after.contains(rid), "H12:时间 GC 也须清 notes/FTS")
    }
}
