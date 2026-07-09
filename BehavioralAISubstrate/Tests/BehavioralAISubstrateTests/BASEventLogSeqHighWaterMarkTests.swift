import XCTest
import Foundation
@testable import BASRuntimeCore

/// audit runtimecore-b MED-2 — a whole-session prune must NOT reset the sequence
/// number. The old nextSequenceNumber derived from SURVIVING rows only, so after
/// a full prune it restarted at 0 — colliding with already-exported
/// (session_id, seq) keys. A never-pruned high-water mark now keeps it monotone.
final class BASEventLogSeqHighWaterMarkTests: XCTestCase {

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("seqhwm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func entry(_ id: String, ts: Int64, session: String) -> BASEventLogEntry {
        BASEventLogEntry(eventID: id, timestampMs: ts, kind: .substrateAudit,
                         sessionID: session, sequenceNumber: 0, actions: ["x"])
    }

    func testFullPruneDoesNotResetSequenceNumber() async throws {
        let store = try BASSQLiteEventLogStorage(
            databaseURL: dir.appendingPathComponent("evt.sqlite"))
        let s = "session-X"
        let s0 = try await store.append(entry("e0", ts: 1000, session: s)).assignedSequenceNumber
        let s1 = try await store.append(entry("e1", ts: 1001, session: s)).assignedSequenceNumber
        let s2 = try await store.append(entry("e2", ts: 1002, session: s)).assignedSequenceNumber
        XCTAssertEqual([s0, s1, s2], [0, 1, 2])

        let pruned = try await store.pruneEventsBefore(timestampMs: 2000)
        XCTAssertEqual(pruned, 3, "all 3 events pruned (whole-session erasure)")
        let empty = try await store.eventsOrThrow(forSession: s)
        XCTAssertTrue(empty.isEmpty, "the session is empty after the full prune")

        // The fix: the next seq continues past the pruned max, never resets to 0.
        let s3 = try await store.append(entry("e3", ts: 3000, session: s)).assignedSequenceNumber
        XCTAssertEqual(s3, 3,
            "seq must NOT reset after a full prune (was 0 → collides with exported (session,seq) keys)")
        XCTAssertGreaterThan(s3, s2, "the new seq is strictly greater than the pre-prune max")
    }

    func testHighWaterMarkIsPerSession() async throws {
        let store = try BASSQLiteEventLogStorage(
            databaseURL: dir.appendingPathComponent("evt2.sqlite"))
        _ = try await store.append(entry("a0", ts: 1000, session: "A")).assignedSequenceNumber
        _ = try await store.append(entry("a1", ts: 1001, session: "A")).assignedSequenceNumber
        let b0 = try await store.append(entry("b0", ts: 1002, session: "B")).assignedSequenceNumber
        XCTAssertEqual(b0, 0, "a different session's sequence is independent of another's high-water mark")
    }
}
