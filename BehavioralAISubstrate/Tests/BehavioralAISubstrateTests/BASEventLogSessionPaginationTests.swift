import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// H10 (mega-audit, 2026-07-08): the Swift session read now PAGINATES the full history via a
/// sequence_number cursor, so a late removed/quarantined event is never dropped (the old
/// single-shot read capped at the oldest 100k events, resurrecting deleted atoms). These
/// gates exercise the multi-page loop over a small corpus by lowering the page size.
final class BASEventLogSessionPaginationTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bas-evlog-page-\(UUID().uuidString).sqlite")
    }

    private func makeEvent(id: String, session: String, ts: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id, timestampMs: ts, kind: .chat, sessionID: session,
            sequenceNumber: 0, source: "user", riskBand: .low, confidence: 0.5)
    }

    override func tearDown() {
        BASRoutedEventLogStorage.sessionPageSize = 10_000   // restore production default
        super.tearDown()
    }

    func testPaginatedReadReturnsFullHistoryAcrossPages() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try BASRoutedEventLogStorage(databaseURL: url)

        // Force the multi-page loop: page size 2 over 7 events → 4 batches (2,2,2,1).
        BASRoutedEventLogStorage.sessionPageSize = 2
        for i in 0..<7 {
            _ = try await store.append(makeEvent(id: "ev-\(i)", session: "long", ts: Int64(100 + i)))
        }
        // A late event in a separate append — the exact shape that lands past a cap.
        _ = try await store.append(makeEvent(id: "late-removed", session: "long", ts: 999))

        let all = await store.events(forSession: "long")
        XCTAssertEqual(all.count, 8, "pagination must return EVERY event across page boundaries")
        // Ascending by sequence_number, no duplicates, and the late event is present.
        let ids = all.map(\.eventID)
        XCTAssertEqual(Set(ids).count, 8, "no event read twice across pages")
        XCTAssertTrue(ids.contains("late-removed"), "the late event must not be dropped (H10)")
        let seqs = all.map(\.sequenceNumber)
        XCTAssertEqual(seqs, seqs.sorted(), "events returned in ascending sequence order")

        // Different session does not bleed across the cursor.
        _ = try await store.append(makeEvent(id: "other", session: "short", ts: 1))
        let other = await store.events(forSession: "short")
        XCTAssertEqual(other.count, 1)
        XCTAssertEqual(other.first?.eventID, "other")
    }

    func testEmptySessionPaginatesToEmpty() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try BASRoutedEventLogStorage(databaseURL: url)
        BASRoutedEventLogStorage.sessionPageSize = 2
        let none = await store.events(forSession: "never-seen")
        XCTAssertTrue(none.isEmpty)
    }
}
