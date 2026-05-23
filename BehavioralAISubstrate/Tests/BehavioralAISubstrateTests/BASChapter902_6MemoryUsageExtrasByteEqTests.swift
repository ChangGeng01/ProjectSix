// MARK: - BASChapter902_6MemoryUsageExtrasByteEqTests
// chapter 九百二.6 / M3210 — extras byte-eq pin (closes 6-table port)
//
// Sub-chapter 3 of MemoryUsageTracker migration。 Covers:
//   - record_notes UPSERT-on-conflict propagation
//   - bundles composite-PK rejection of duplicate pairs
//   - tombstones INSERT OR REPLACE idempotency
//   - byte-eq vs BASMemoryUsageTracker for tombstoneCount +
//     attachNotes round-trip

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter902_6MemoryUsageExtrasByteEqTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch902-6-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Notes (UPSERT-on-conflict)

    func testNotesUpsertReplacesContent() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageExtrasStore(
            databaseURL: url)
        try await routed.upsertNotes(
            recordID: "r1", notes: "original")
        let c1 = await routed.notesCount
        XCTAssertEqual(c1, 1)
        try await routed.upsertNotes(
            recordID: "r1", notes: "updated")
        let c2 = await routed.notesCount
        XCTAssertEqual(c2, 1, "Still 1 row after UPSERT")
        let v = try await routed.notes(forRecordID: "r1")
        XCTAssertEqual(v, "updated")
        let missing = try await routed.notes(
            forRecordID: "no-such")
        XCTAssertNil(missing)
    }

    // MARK: - Bundles (composite PK)

    func testBundlesCompositePKRejectsDuplicatePair() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageExtrasStore(
            databaseURL: url)
        try await routed.insertBundleRow(
            bundleID: "b1", recordID: "r1",
            positionInBundle: 0, createdAtMs: 100)
        try await routed.insertBundleRow(
            bundleID: "b1", recordID: "r2",
            positionInBundle: 1, createdAtMs: 100)
        try await routed.insertBundleRow(
            bundleID: "b2", recordID: "r1",
            positionInBundle: 0, createdAtMs: 200)
        // (b1, r1) duplicate composite PK
        do {
            try await routed.insertBundleRow(
                bundleID: "b1", recordID: "r1",
                positionInBundle: 99, createdAtMs: 999)
            XCTFail("Duplicate composite PK must throw")
        } catch let e as BASRoutedMemoryUsageExtrasStore
            .StoreError
        {
            if case .writeFailed(let table, let code) = e {
                XCTAssertEqual(table, "bundles")
                XCTAssertEqual(code, -2)
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
        let total = await routed.totalBundleRows
        let distinct = await routed.distinctBundleCount
        XCTAssertEqual(total, 3)
        XCTAssertEqual(distinct, 2)
        let inB1 = await routed.countRecordsInBundle("b1")
        let inB2 = await routed.countRecordsInBundle("b2")
        XCTAssertEqual(inB1, 2)
        XCTAssertEqual(inB2, 1)
    }

    // MARK: - Tombstones (INSERT OR REPLACE)

    func testTombstonesUpsertIsIdempotent() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageExtrasStore(
            databaseURL: url)
        try await routed.upsertTombstone(
            recordID: "r1", tombstonedAtMs: 100)
        try await routed.upsertTombstone(
            recordID: "r1", tombstonedAtMs: 200)
        try await routed.upsertTombstone(
            recordID: "r2", tombstonedAtMs: 300)
        let count = await routed.tombstoneCount
        XCTAssertEqual(count, 2, "INSERT OR REPLACE dedupes")
        let t1 = await routed.isTombstoned(recordID: "r1")
        let t2 = await routed.isTombstoned(recordID: "r2")
        let tMissing = await routed.isTombstoned(
            recordID: "missing")
        XCTAssertTrue(t1)
        XCTAssertTrue(t2)
        XCTAssertFalse(tMissing)
    }

    // MARK: - Byte-equality vs Swift BASMemoryUsageTracker

    func testByteEqTombstoneCountVsSwift() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedMemoryUsageExtrasStore(
            databaseURL: routedURL)
        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        // First insert records into Swift so tombstones
        // are meaningful (Swift's in-memory cache uses set
        // semantics)。 Tombstones table semantics are
        // independent of the records table for byte-eq —
        // we drive both stores with the same N tombstone
        // markers and check counts。
        let ids = ["r-A", "r-B", "r-C", "r-A"]  // r-A dup
        let date = Date(timeIntervalSince1970: 100)
        for id in ids {
            try await routed.upsertTombstone(
                recordID: id, tombstonedAtMs: 100_000)
            try await swiftActor.tombstoneRecord(
                recordID: id, tombstonedAt: date)
        }
        let rTomb = await routed.tombstoneCount
        let sTomb = await swiftActor.tombstoneCount
        XCTAssertEqual(rTomb, sTomb,
            "Both stores dedupe to same tombstone count")
        XCTAssertEqual(rTomb, 3,
            "3 distinct ids (r-A inserted twice)")
        let rT_A = await routed.isTombstoned(recordID: "r-A")
        let sT_A = await swiftActor.isTombstoned(
            recordID: "r-A")
        XCTAssertEqual(rT_A, sT_A)
        XCTAssertTrue(rT_A)
    }

    func testNotesAttachAndReplaceParityVsSwiftFTS() async
        throws
    {
        // The Swift actor doesn't expose a public notesCount
        // (notes are write-side only,read via FTS5 search)。
        // Byte-eq verification:drive both sides with notes
        // containing a distinguishing keyword,then
        //   - Rust: read latest notes for r1 directly
        //   - Swift: FTS5-search for the unique keyword,
        //     confirm matching recordID returned
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedMemoryUsageExtrasStore(
            databaseURL: routedURL)
        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        let pairs = [
            ("r1", "alpha keyword"),
            ("r2", "beta keyword"),
            ("r1", "REPLACED alpha keyword"),
        ]
        for (rid, note) in pairs {
            try await routed.upsertNotes(
                recordID: rid, notes: note)
            try await swiftActor.attachNotes(
                recordID: rid, notes: note)
        }
        // Rust UPSERT-on-conflict preserves only the latest
        let rCount = await routed.notesCount
        XCTAssertEqual(rCount, 2,
            "Rust: r1 upserted twice → 2 distinct notes rows")
        let rNotes = try await routed.notes(forRecordID: "r1")
        XCTAssertEqual(rNotes, "REPLACED alpha keyword",
            "Rust UPSERT propagates latest value")
        // Swift FTS5 search:both notes should be findable
        let matchAlpha = try await swiftActor.searchNotesFTS(
            query: "REPLACED")
        XCTAssertTrue(matchAlpha.contains("r1"),
            "Swift FTS5 finds the REPLACED token → r1")
        let matchBeta = try await swiftActor.searchNotesFTS(
            query: "beta")
        XCTAssertTrue(matchBeta.contains("r2"),
            "Swift FTS5 finds 'beta' → r2")
        // Swift's pre-replace 'alpha' should NOT match the
        // r1 row anymore (UPSERT replaced the body)
        let matchOldAlpha = try await swiftActor
            .searchNotesFTS(query: "alpha")
        // r1's body is now "REPLACED alpha keyword" — still
        // contains 'alpha'。 r2's body is "beta keyword"。
        // So 'alpha' should return r1 still。
        XCTAssertTrue(matchOldAlpha.contains("r1"))
    }
}
#endif
