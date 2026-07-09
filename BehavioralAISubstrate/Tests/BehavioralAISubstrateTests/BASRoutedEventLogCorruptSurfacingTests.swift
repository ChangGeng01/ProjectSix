import XCTest
import Foundation
import SQLite3
@testable import BASMemory
import BASRuntimeCore

// audit memory-b F12 — BASRoutedEventLogStorage read path used to return []
// on a corrupt / unreadable event log, indistinguishable from a genuinely
// empty session (the reducer projection would be all-empty = false total-
// amnesia), with NO error channel. It now mirrors the SQLite sibling: the
// non-throwing events(...) route a swallowed error to onSilentFailure before
// defaulting to [], and eventsOrThrow(...) surfaces it.
#if os(iOS) || os(macOS)
final class BASRoutedEventLogCorruptSurfacingTests: XCTestCase {

    private func url(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("routedevt-\(UUID().uuidString)-\(name)")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    private func entry(_ id: String, session: String, seq: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id, timestampMs: 1_700_000_000_000, kind: .substrateAudit,
            sessionID: session, sequenceNumber: seq, actions: ["x"])
    }
    private final class Box: @unchecked Sendable {
        let lock = NSLock(); var fired = 0
        func bump() { lock.lock(); fired += 1; lock.unlock() }
    }

    /// Healthy: eventsOrThrow returns the event, events() returns it, hook never fires.
    func testHealthyReadNeitherThrowsNorFires() async throws {
        let u = url("healthy.sqlite"); defer { cleanup(u) }
        let store = try BASRoutedEventLogStorage(databaseURL: u)
        _ = try await store.append(entry("e1", session: "s", seq: 0))
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.eventsOrThrow(forSession: "s")
        XCTAssertEqual(viaThrow.map(\.eventID), ["e1"])
        let viaDefault = await store.events(forSession: "s")
        XCTAssertEqual(viaDefault.map(\.eventID), ["e1"])
        XCTAssertEqual(box.fired, 0, "a healthy read must not fire the corruption hook")
    }

    /// A genuinely empty session stays [] in BOTH accessors — empty is NOT corruption.
    func testGenuineEmptyStaysEmpty() async throws {
        let u = url("empty.sqlite"); defer { cleanup(u) }
        let store = try BASRoutedEventLogStorage(databaseURL: u)
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.eventsOrThrow(forSession: "none")
        XCTAssertTrue(viaThrow.isEmpty)
        let viaDefault = await store.events(forSession: "none")
        XCTAssertTrue(viaDefault.isEmpty)
        XCTAssertEqual(box.fired, 0, "a genuinely empty session must not fire the hook or throw")
    }

    /// THE teeth — drop the table under the store (WAL ⇒ the engine sees it on the
    /// next read). events() still returns [] BUT fires onSilentFailure; eventsOrThrow
    /// THROWS instead of the old silent corrupt-as-empty.
    func testCorruptReadFiresHookAndOrThrowThrows() async throws {
        let u = url("dropped.sqlite"); defer { cleanup(u) }
        let store = try BASRoutedEventLogStorage(databaseURL: u)
        _ = try await store.append(entry("e1", session: "s", seq: 0))

        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw, "DROP TABLE event_log;", nil, nil, nil), SQLITE_OK)
        sqlite3_close_v2(raw)

        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaDefault = await store.events(forSession: "s")
        XCTAssertTrue(viaDefault.isEmpty,
            "the swallowing accessor still returns [] on a read failure (byte-equal default)")
        XCTAssertGreaterThan(box.fired, 0,
            "onSilentFailure fires — a host can now tell CORRUPT from a genuinely empty session")
        do {
            _ = try await store.eventsOrThrow(forSession: "s")
            XCTFail("eventsOrThrow must throw on a corrupt read, not present it as an empty session")
        } catch {
            XCTAssertTrue(error is BASRoutedEventLogStorage.StoreError,
                "eventsOrThrow surfaces the typed StoreError, got \(error)")
        }
    }
}
#endif
