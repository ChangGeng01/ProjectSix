// MARK: - BASChapter792SQLiteAtomStoreTests
// chapter 七百九十二 + 七百九十三 / M2611-M2620
//
// SQLite-backed BASAtomLifecycleStore verification + cold-restart
// integration test。 Completes the L8 storage layer end-to-end:
//
//   Rust transition gate → BASAtomLifecycleEvent → SQLite schema 023
//   → close DB → reopen → reconstruct identical atom state
//
// All tests use a temp-directory SQLite file that is created
// fresh per test + cleaned up in tearDown。

import XCTest
@testable import BASMemory
#if os(iOS) || os(macOS)
@testable import BASRuntimeCore
#endif

final class BASChapter792SQLiteAtomStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        let dir = FileManager.default.temporaryDirectory
        tempURL = dir.appendingPathComponent(
            "bas-test-atom-lifecycle-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        if let url = tempURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try await super.tearDown()
    }

    // MARK: - Basic SQLite store lifecycle

    func testStoreOpensAndCloses() async throws {
        let store = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let count = await store.count()
        XCTAssertEqual(count, 0,
            "Fresh DB starts at 0 events")
    }

    func testStoreOpensExistingDB() async throws {
        // Open store, write 1 event, close, reopen, verify
        let event = BASAtomLifecycleEvent(
            eventID: "evt-persist",
            atomID: "atom-persist",
            sessionID: "sess-persist",
            fromPhaseByte: 0,
            toPhaseByte: 1,
            actionByte: 0,
            outcome: 0,
            recordedAtMs: 1_000)
        do {
            let store = try BASSQLiteAtomLifecycleStore(
                databaseURL: tempURL)
            _ = try await store.appendEvent(event)
        }
        // store deinit closes DB

        let reopened = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let count = await reopened.count()
        XCTAssertEqual(count, 1, "DB persists across actor reopens")

        let events = await reopened.events(forAtom: "atom-persist")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0], event)
    }

    func testStoreRejectsDuplicateEventID() async throws {
        let store = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let event = BASAtomLifecycleEvent(
            eventID: "evt-dup",
            atomID: "a",
            sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 1,
            actionByte: 0, outcome: 0,
            recordedAtMs: 1)
        _ = try await store.appendEvent(event)
        do {
            _ = try await store.appendEvent(event)
            XCTFail("expected duplicateEventID throw")
        } catch BASSQLiteAtomLifecycleStore.StorageError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "evt-dup")
        }
    }

    // MARK: - Per-atom + per-session queries

    func testQueriesReturnInsertionOrder() async throws {
        let store = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        // Insert 3 events for same atom with increasing timestamps
        for i in 0..<3 {
            _ = try await store.appendEvent(BASAtomLifecycleEvent(
                eventID: "evt-\(i)",
                atomID: "atom-order",
                sessionID: "sess",
                fromPhaseByte: 0,
                toPhaseByte: 1,
                actionByte: 0,
                outcome: 0,
                recordedAtMs: Int64(i * 100)))
        }
        let events = await store.events(forAtom: "atom-order")
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map { $0.eventID },
            ["evt-0", "evt-1", "evt-2"])
    }

    func testQueriesFilterByAtomNotLeak() async throws {
        let store = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "e1", atomID: "atom-A", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 1,
            actionByte: 0, outcome: 0, recordedAtMs: 1))
        _ = try await store.appendEvent(BASAtomLifecycleEvent(
            eventID: "e2", atomID: "atom-B", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 1,
            actionByte: 0, outcome: 0, recordedAtMs: 2))
        let aEvents = await store.events(forAtom: "atom-A")
        XCTAssertEqual(aEvents.count, 1)
        XCTAssertEqual(aEvents[0].eventID, "e1")
    }

    // MARK: - Cold-restart cross-mirror with InMemory

    func testColdRestartReplayMatchesInMemoryStore() async throws {
        // Phase 1: write 4 events through Rust gate → SQLite
        do {
            let sqliteStore = try BASSQLiteAtomLifecycleStore(
                databaseURL: tempURL)
            try await driveFullLifecycle(into: sqliteStore,
                atomID: "atom-cold")
        }
        // SQLite file is now closed

        // Phase 2: reopen SQLite + reconstruct phase
        let reopened = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let sqlPhase = await reopened.reconstructCurrentPhaseByte(
            forAtom: "atom-cold")
        XCTAssertEqual(sqlPhase, 4,
            "SQLite store reconstructs to Tombstoned after restart")

        // Phase 3: cross-mirror with in-memory store using the
        // same event sequence
        let memStore = BASInMemoryAtomLifecycleStore()
        try await driveFullLifecycle(into: memStore,
            atomID: "atom-cold-mem")
        let memPhase = await memStore.reconstructCurrentPhaseByte(
            forAtom: "atom-cold-mem")
        XCTAssertEqual(sqlPhase, memPhase,
            "SQLite reconstruction MUST match in-memory reconstruction " +
            "byte-for-byte (chapter 392 replay-determinism invariant)")
    }

    func testMultiAtomColdRestart() async throws {
        // Write 10 atoms × 1 advance each → close → reopen → verify
        do {
            let sqliteStore = try BASSQLiteAtomLifecycleStore(
                databaseURL: tempURL)
            for i in 0..<10 {
                _ = try await driveTransition(
                    into: sqliteStore,
                    eventID: "multi-\(i)",
                    atomID: "atom-multi-\(i)",
                    sessionID: "multi-sess",
                    currentPhase: 0, action: 0,
                    recordedAtMs: Int64(i * 100))
            }
        }
        let reopened = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let total = await reopened.count()
        XCTAssertEqual(total, 10)
        for i in 0..<10 {
            let phase = await reopened.reconstructCurrentPhaseByte(
                forAtom: "atom-multi-\(i)")
            XCTAssertEqual(phase, 1,
                "atom-multi-\(i) reconstructs to Admitted (1)")
        }
    }

    // MARK: - Test helpers

    private func driveTransition(
        into store: BASAtomLifecycleStore,
        eventID: String,
        atomID: String,
        sessionID: String,
        currentPhase: UInt8,
        action: UInt8,
        recordedAtMs: Int64
    ) async throws -> BASAtomLifecycleEvent {
        #if os(iOS) || os(macOS)
        let result = BASAtomLifecycleBridge.transition(
            currentPhaseByte: currentPhase, actionByte: action)
        let event = BASAtomLifecycleEvent(
            eventID: eventID,
            atomID: atomID,
            sessionID: sessionID,
            fromPhaseByte: currentPhase,
            toPhaseByte: result.nextPhaseByte,
            actionByte: action,
            outcome: result.outcome,
            recordedAtMs: recordedAtMs,
            actorRef: nil)
        return try await store.appendEvent(event)
        #else
        // watchOS fallback — Swift-inline transition decision
        let nextPhase: UInt8 = currentPhase == 0 && action == 0
            ? 1 : currentPhase
        let event = BASAtomLifecycleEvent(
            eventID: eventID,
            atomID: atomID,
            sessionID: sessionID,
            fromPhaseByte: currentPhase,
            toPhaseByte: nextPhase,
            actionByte: action,
            outcome: 0,
            recordedAtMs: recordedAtMs,
            actorRef: nil)
        return try await store.appendEvent(event)
        #endif
    }

    private func driveFullLifecycle(
        into store: BASAtomLifecycleStore,
        atomID: String
    ) async throws {
        _ = try await driveTransition(into: store,
            eventID: "\(atomID)-e1",
            atomID: atomID, sessionID: "lifecycle-sess",
            currentPhase: 0, action: 0,  // Created → Admitted
            recordedAtMs: 100)
        _ = try await driveTransition(into: store,
            eventID: "\(atomID)-e2",
            atomID: atomID, sessionID: "lifecycle-sess",
            currentPhase: 1, action: 1,  // Admitted → Linked
            recordedAtMs: 200)
        _ = try await driveTransition(into: store,
            eventID: "\(atomID)-e3",
            atomID: atomID, sessionID: "lifecycle-sess",
            currentPhase: 2, action: 2,  // Linked → Archived
            recordedAtMs: 300)
        _ = try await driveTransition(into: store,
            eventID: "\(atomID)-e4",
            atomID: atomID, sessionID: "lifecycle-sess",
            currentPhase: 3, action: 3,  // Archived → Tombstoned
            recordedAtMs: 400)
    }
}
