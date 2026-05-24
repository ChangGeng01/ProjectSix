// MARK: - BASChapter934AtomLifecycleFullRowTests
// chapter 九百三十四 / M3375
//
// SUBSTANCE chapter (not meta) following the USER-PASS finding
// at chapter 933:the routed AtomLifecycle bridge was labeled
// 「Full」 in L8_ROUTED_OVERVIEW.md but `events(forAtom:)` and
// `events(forSession:)` returned `[]` stubs。
//
// Ch 934 ships the actual full-row Rust FFI + Swift bridge
// wiring。 This test file verifies the round-trip:
//   1. append events via the routed bridge
//   2. read them back via the now-implemented events(forAtom:)
//   3. assert byte-for-byte field equality with the input
//
// Per ch 927「EVERY ASSERTION MUST FAIL ON REVERT」 discipline:
// if the bridge's events(forAtom:) is reverted to `return []`,
// these tests fail with empty-array assertion mismatch。

import XCTest
@testable import BASMemory

final class BASChapter934AtomLifecycleFullRowTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch934-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    /// USER-PASS finding regression guard:if `events(forAtom:)`
    /// is reverted to `return []`, this test fails immediately
    /// because we appended 2 events and assert the read returns
    /// both of them with full field equality。
    func testEventsForAtomRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)

        let event1 = BASAtomLifecycleEvent(
            eventID: "evt-RT-1",
            atomID: "atom-A",
            sessionID: "sess-1",
            fromPhaseByte: 0,    // created
            toPhaseByte: 1,      // admitted
            actionByte: 0,       // admit
            outcome: 0,          // advanced
            recordedAtMs: 1_700_000_000_000,
            actorRef: "reducer")
        let event2 = BASAtomLifecycleEvent(
            eventID: "evt-RT-2",
            atomID: "atom-A",
            sessionID: "sess-1",
            fromPhaseByte: 1,
            toPhaseByte: 2,      // linked
            actionByte: 1,       // link
            outcome: 0,
            recordedAtMs: 1_700_000_001_000,
            actorRef: nil)

        _ = try await store.appendEvent(event1)
        _ = try await store.appendEvent(event2)

        let read = await store.events(forAtom: "atom-A")
        XCTAssertEqual(read.count, 2,
            "events(forAtom:) must return both appended events " +
            "(REGRESSION:if this fails with 0,the ch 933 USER-" +
            "PASS finding has recurred — bridge is back to stub)")

        // Verify ordering (recorded_at_ms ASC)
        XCTAssertEqual(read[0].eventID, "evt-RT-1")
        XCTAssertEqual(read[1].eventID, "evt-RT-2")

        // Full-field equality on event 1
        XCTAssertEqual(read[0].atomID, "atom-A")
        XCTAssertEqual(read[0].sessionID, "sess-1")
        XCTAssertEqual(read[0].fromPhaseByte, 0)
        XCTAssertEqual(read[0].toPhaseByte, 1)
        XCTAssertEqual(read[0].actionByte, 0)
        XCTAssertEqual(read[0].outcome, 0)
        XCTAssertEqual(read[0].recordedAtMs, 1_700_000_000_000)
        XCTAssertEqual(read[0].actorRef, "reducer")

        // Full-field equality on event 2 (esp. actorRef = nil)
        XCTAssertEqual(read[1].actorRef, nil,
            "nil actorRef must round-trip as nil (not empty string)")
    }

    /// Empty-atom lookup must return empty array,not error
    func testEventsForAtomEmptyResult() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)
        let read = await store.events(forAtom: "atom-NONE")
        XCTAssertEqual(read.count, 0,
            "unknown atom_id must return empty array")
    }

    /// events(forSession:) parallel test
    func testEventsForSessionRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)

        // Append 3 events across 2 atoms in same session
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "s-evt-1", atomID: "atom-X",
            sessionID: "sess-shared",
            fromPhaseByte: 0, toPhaseByte: 1, actionByte: 0,
            outcome: 0, recordedAtMs: 1_000, actorRef: nil))
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "s-evt-2", atomID: "atom-Y",
            sessionID: "sess-shared",
            fromPhaseByte: 0, toPhaseByte: 1, actionByte: 0,
            outcome: 0, recordedAtMs: 2_000, actorRef: nil))
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "s-evt-3", atomID: "atom-X",
            sessionID: "sess-OTHER",
            fromPhaseByte: 1, toPhaseByte: 2, actionByte: 1,
            outcome: 0, recordedAtMs: 3_000, actorRef: nil))

        // forSession sess-shared should return 2 (s-evt-1 + s-evt-2)
        let shared = await store.events(forSession: "sess-shared")
        XCTAssertEqual(shared.count, 2)
        XCTAssertEqual(shared.map { $0.eventID },
                       ["s-evt-1", "s-evt-2"])
        // chapter 九百四十三 / M3420 (15P-HIGH-5) — full-field
        // backfill on both events (was only eventID before)。
        // Sister-test field-assertion gap shipped by ch 942 only
        // covered ch 936;ch 943 closes the gap for ch 934。
        XCTAssertEqual(shared[0].atomID, "atom-X")
        XCTAssertEqual(shared[0].sessionID, "sess-shared")
        XCTAssertEqual(shared[0].fromPhaseByte, 0)
        XCTAssertEqual(shared[0].toPhaseByte, 1)
        XCTAssertEqual(shared[0].actionByte, 0)
        XCTAssertEqual(shared[0].outcome, 0)
        XCTAssertEqual(shared[0].recordedAtMs, 1_000)
        XCTAssertEqual(shared[0].actorRef, nil)
        XCTAssertEqual(shared[1].atomID, "atom-Y")
        XCTAssertEqual(shared[1].recordedAtMs, 2_000)
        XCTAssertEqual(shared[1].actorRef, nil)

        // forSession sess-OTHER should return 1
        let other = await store.events(forSession: "sess-OTHER")
        XCTAssertEqual(other.count, 1)
        XCTAssertEqual(other[0].eventID, "s-evt-3")
        // chapter 九百四十三 / M3420 — also assert s-evt-3 fields
        XCTAssertEqual(other[0].atomID, "atom-X")
        XCTAssertEqual(other[0].sessionID, "sess-OTHER")
        XCTAssertEqual(other[0].fromPhaseByte, 1)
        XCTAssertEqual(other[0].toPhaseByte, 2)
        XCTAssertEqual(other[0].actionByte, 1)
        XCTAssertEqual(other[0].outcome, 0)
        XCTAssertEqual(other[0].recordedAtMs, 3_000)
    }

    /// JSON escape correctness — actorRef with special chars
    func testEventsForAtomEscapesSpecialCharsInActorRef()
        async throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedAtomLifecycleStore(
            databaseURL: url)

        let tricky = "actor \"quoted\" \\with\nnewline\ttabs"
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "esc-evt",
            atomID: "atom-esc", sessionID: "sess-esc",
            fromPhaseByte: 0, toPhaseByte: 1, actionByte: 0,
            outcome: 0, recordedAtMs: 1,
            actorRef: tricky))
        let read = await store.events(forAtom: "atom-esc")
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read[0].actorRef, tricky,
            "JSON escape + decode must round-trip special chars " +
            "byte-for-byte")
    }
}
