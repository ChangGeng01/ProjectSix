// MARK: - BASChapter789L8AtomStoreScaffoldTests
// chapter 七百八十九 / M2596-M2600
//
// L8 atom-lifecycle store scaffold verification + Rust transition
// gate integration tests。

import XCTest
@testable import BASMemory
#if os(iOS) || os(macOS)
@testable import BASRuntimeCore
#endif

final class BASChapter789L8AtomStoreScaffoldTests: XCTestCase {

    // MARK: - BASAtomLifecycleEvent struct

    func testEventInitFullCoverage() {
        let event = BASAtomLifecycleEvent(
            eventID: "evt-1",
            atomID: "atom-1",
            sessionID: "sess-1",
            fromPhaseByte: 0,
            toPhaseByte: 1,
            actionByte: 0,
            outcome: 0,
            recordedAtMs: 1_700_000_000_000,
            actorRef: "reducer")
        XCTAssertEqual(event.eventID, "evt-1")
        XCTAssertTrue(event.advanced)
    }

    func testEventCodableRoundTrip() throws {
        let event = BASAtomLifecycleEvent(
            eventID: "evt-codable",
            atomID: "atom-codable",
            sessionID: "sess-codable",
            fromPhaseByte: 1,
            toPhaseByte: 2,
            actionByte: 1,
            outcome: 0,
            recordedAtMs: 1_700_000_001_000,
            actorRef: nil)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(
            BASAtomLifecycleEvent.self, from: data)
        XCTAssertEqual(event, decoded)
    }

    func testEventAdvancedComputedProperty() {
        let advanced = BASAtomLifecycleEvent(
            eventID: "e1", atomID: "a", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 1,
            actionByte: 0, outcome: 0,
            recordedAtMs: 0)
        XCTAssertTrue(advanced.advanced)

        let rejected = BASAtomLifecycleEvent(
            eventID: "e2", atomID: "a", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 0,
            actionByte: 1, outcome: 1,
            recordedAtMs: 0)
        XCTAssertFalse(rejected.advanced)
    }

    // MARK: - BASInMemoryAtomLifecycleStore basics

    func testInMemoryStoreAppendsAndRetrieves() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        let event = BASAtomLifecycleEvent(
            eventID: "evt-A",
            atomID: "atom-X",
            sessionID: "sess-Y",
            fromPhaseByte: 0,
            toPhaseByte: 1,
            actionByte: 0,
            outcome: 0,
            recordedAtMs: 1000)
        _ = try await store.appendEvent(event)
        let count = await store.count()
        XCTAssertEqual(count, 1)
        let events = await store.events(forAtom: "atom-X")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0], event)
    }

    func testInMemoryStoreRejectsDuplicateEventID() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        let event = BASAtomLifecycleEvent(
            eventID: "evt-dup",
            atomID: "a", sessionID: "s",
            fromPhaseByte: 0, toPhaseByte: 1,
            actionByte: 0, outcome: 0,
            recordedAtMs: 0)
        _ = try await store.appendEvent(event)
        do {
            _ = try await store.appendEvent(event)
            XCTFail("expected duplicateEventID throw")
        } catch BASInMemoryAtomLifecycleStore.StoreError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "evt-dup")
        }
    }

    func testInMemoryStoreFiltersByAtom() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        try await store.bulkImport([
            BASAtomLifecycleEvent(
                eventID: "e1", atomID: "atom-A", sessionID: "s",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 1),
            BASAtomLifecycleEvent(
                eventID: "e2", atomID: "atom-B", sessionID: "s",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 2),
            BASAtomLifecycleEvent(
                eventID: "e3", atomID: "atom-A", sessionID: "s",
                fromPhaseByte: 1, toPhaseByte: 2,
                actionByte: 1, outcome: 0, recordedAtMs: 3),
        ])
        let aEvents = await store.events(forAtom: "atom-A")
        XCTAssertEqual(aEvents.count, 2)
        XCTAssertEqual(aEvents.map { $0.eventID },
            ["e1", "e3"], "insertion order preserved")
    }

    func testInMemoryStoreFiltersBySession() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        try await store.bulkImport([
            BASAtomLifecycleEvent(
                eventID: "e1", atomID: "a", sessionID: "sess-A",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 1),
            BASAtomLifecycleEvent(
                eventID: "e2", atomID: "b", sessionID: "sess-B",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 2),
        ])
        let aSession = await store.events(forSession: "sess-A")
        XCTAssertEqual(aSession.count, 1)
        XCTAssertEqual(aSession[0].eventID, "e1")
    }

    // MARK: - reconstructCurrentPhaseByte cold-restart helper

    func testReconstructEmptyHistoryReturnsNil() async {
        let store = BASInMemoryAtomLifecycleStore()
        let phase = await store.reconstructCurrentPhaseByte(
            forAtom: "atom-untouched")
        XCTAssertNil(phase)
    }

    func testReconstructFullLifecycleEndsAtTombstoned() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        try await store.bulkImport([
            // Created → Admitted
            BASAtomLifecycleEvent(
                eventID: "e1", atomID: "atom-life", sessionID: "s",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 1),
            // Admitted → Linked
            BASAtomLifecycleEvent(
                eventID: "e2", atomID: "atom-life", sessionID: "s",
                fromPhaseByte: 1, toPhaseByte: 2,
                actionByte: 1, outcome: 0, recordedAtMs: 2),
            // Linked → Archived
            BASAtomLifecycleEvent(
                eventID: "e3", atomID: "atom-life", sessionID: "s",
                fromPhaseByte: 2, toPhaseByte: 3,
                actionByte: 2, outcome: 0, recordedAtMs: 3),
            // Archived → Tombstoned
            BASAtomLifecycleEvent(
                eventID: "e4", atomID: "atom-life", sessionID: "s",
                fromPhaseByte: 3, toPhaseByte: 4,
                actionByte: 3, outcome: 0, recordedAtMs: 4),
        ])
        let phase = await store.reconstructCurrentPhaseByte(
            forAtom: "atom-life")
        XCTAssertEqual(phase, 4, "Tombstoned (4) is latest advanced")
    }

    func testReconstructIgnoresRejectedTransitions() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        try await store.bulkImport([
            // Created → Admitted (advance)
            BASAtomLifecycleEvent(
                eventID: "e1", atomID: "atom-rej", sessionID: "s",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0, recordedAtMs: 1),
            // Admitted + Admit again → REJECTED (no advance)
            BASAtomLifecycleEvent(
                eventID: "e2", atomID: "atom-rej", sessionID: "s",
                fromPhaseByte: 1, toPhaseByte: 1,
                actionByte: 0, outcome: 1, recordedAtMs: 2),
        ])
        let phase = await store.reconstructCurrentPhaseByte(
            forAtom: "atom-rej")
        XCTAssertEqual(phase, 1, "Stays at Admitted; rejected " +
            "event doesn't advance the reconstructed phase")
    }

    // MARK: - Rust transition gate integration

    #if os(iOS) || os(macOS)
    func testRustGateProducesValidEvents() async throws {
        // End-to-end:use the Rust transition fn to compute next
        // phase, then write the event to the store。 This is the
        // pattern a real adapter would use。
        let store = BASInMemoryAtomLifecycleStore()
        let currentPhase: UInt8 = 0  // Created
        let action: UInt8 = 0         // Admit

        let result = BASAtomLifecycleBridge.transition(
            currentPhaseByte: currentPhase,
            actionByte: action)
        let event = BASAtomLifecycleEvent(
            eventID: "rust-gate-1",
            atomID: "atom-gated",
            sessionID: "sess-gated",
            fromPhaseByte: currentPhase,
            toPhaseByte: result.nextPhaseByte,
            actionByte: action,
            outcome: result.outcome,
            recordedAtMs: 1000)
        _ = try await store.appendEvent(event)

        let reconstructed = await store
            .reconstructCurrentPhaseByte(forAtom: "atom-gated")
        XCTAssertEqual(reconstructed, 1,
            "Rust-gated event reconstructs to Admitted (1)")
    }
    #endif
}
