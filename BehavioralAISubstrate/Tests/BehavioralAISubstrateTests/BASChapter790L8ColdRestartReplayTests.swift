// MARK: - BASChapter790L8ColdRestartReplayTests
// chapter 七百九十 / M2601-M2605
//
// Integration test demonstrating that the L8 atom-lifecycle
// store (chapter 七百八十九) supports cold-restart replay:
// events written → process simulated to restart → events read
// back → atom state reconstructed identically。
//
// Validates the chapter 392 replay-determinism invariant for
// the new L8 storage seam。

import XCTest
@testable import BASMemory
#if os(iOS) || os(macOS)
@testable import BASRuntimeCore
#endif

final class BASChapter790L8ColdRestartReplayTests: XCTestCase {

    // MARK: - End-to-end cold-restart replay

    func testColdRestartReconstructsAtomPhase() async throws {
        // Phase 1: original session writes events through the
        // Rust transition gate
        let session1Events = try await runOriginalSession()

        // Phase 2: simulate process restart by serializing all
        // events + loading into a fresh store
        let snapshot = try JSONEncoder().encode(session1Events)
        let coldStore = BASInMemoryAtomLifecycleStore()
        let replayedEvents = try JSONDecoder().decode(
            [BASAtomLifecycleEvent].self, from: snapshot)
        try await coldStore.bulkImport(replayedEvents)

        // Phase 3: reconstruct phases from the cold store
        let phaseAfterRestart = await coldStore
            .reconstructCurrentPhaseByte(forAtom: "atom-replay-1")
        XCTAssertEqual(phaseAfterRestart, 4,
            "After 4-step lifecycle, atom-replay-1 ends at " +
            "Tombstoned (4) — survives process restart")

        let phaseUntouched = await coldStore
            .reconstructCurrentPhaseByte(forAtom: "atom-replay-2")
        XCTAssertEqual(phaseUntouched, 1,
            "atom-replay-2 only got Created→Admitted before " +
            "session ended — restart preserves that as Admitted (1)")
    }

    private func runOriginalSession() async throws -> [BASAtomLifecycleEvent] {
        let store = BASInMemoryAtomLifecycleStore()
        let sessionID = "sess-cold-restart-790"

        // Atom 1: full 4-step lifecycle (Created → Admitted →
        // Linked → Archived → Tombstoned)
        try await driveTransition(store: store,
            eventID: "ar1-e1",
            atomID: "atom-replay-1",
            sessionID: sessionID,
            currentPhase: 0, action: 0, // Created + Admit
            recordedAtMs: 100)
        try await driveTransition(store: store,
            eventID: "ar1-e2",
            atomID: "atom-replay-1",
            sessionID: sessionID,
            currentPhase: 1, action: 1, // Admitted + Link
            recordedAtMs: 200)
        try await driveTransition(store: store,
            eventID: "ar1-e3",
            atomID: "atom-replay-1",
            sessionID: sessionID,
            currentPhase: 2, action: 2, // Linked + Archive
            recordedAtMs: 300)
        try await driveTransition(store: store,
            eventID: "ar1-e4",
            atomID: "atom-replay-1",
            sessionID: sessionID,
            currentPhase: 3, action: 3, // Archived + Tombstone
            recordedAtMs: 400)

        // Atom 2: partial lifecycle (Created → Admitted, then
        // session ends mid-way)
        try await driveTransition(store: store,
            eventID: "ar2-e1",
            atomID: "atom-replay-2",
            sessionID: sessionID,
            currentPhase: 0, action: 0, // Created + Admit
            recordedAtMs: 500)

        return await store.events(forSession: sessionID)
    }

    /// Drive a single transition through the Rust gate + write
    /// to the store。 Mirrors the pattern a real production
    /// adapter would use。
    private func driveTransition(
        store: BASInMemoryAtomLifecycleStore,
        eventID: String,
        atomID: String,
        sessionID: String,
        currentPhase: UInt8,
        action: UInt8,
        recordedAtMs: Int64
    ) async throws {
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
        _ = try await store.appendEvent(event)
        #else
        // Non-Apple fallback: Swift-side transition table.
        // Used by watchOS test path。
        let nextPhase = swiftFallbackTransition(
            phase: currentPhase, action: action)
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
        _ = try await store.appendEvent(event)
        #endif
    }

    private func swiftFallbackTransition(
        phase: UInt8, action: UInt8
    ) -> UInt8 {
        // Swift-side equivalent of the Rust transition matrix
        // for cross-platform fallback。 Same shape as
        // bas-atom-lifecycle/src/lib.rs transition fn。
        if phase == 4 { return 4 }  // terminal stays
        switch (phase, action) {
        case (0, 0): return 1  // Created+Admit→Admitted
        case (0, 3): return 4  // Created+Tombstone→Tombstoned
        case (1, 1): return 2  // Admitted+Link→Linked
        case (1, 2): return 3  // Admitted+Archive→Archived
        case (1, 3): return 4  // Admitted+Tombstone→Tombstoned
        case (2, 2): return 3  // Linked+Archive→Archived
        case (2, 3): return 4  // Linked+Tombstone→Tombstoned
        case (3, 3): return 4  // Archived+Tombstone→Tombstoned
        default: return phase  // rejected → no change
        }
    }

    // MARK: - Cross-session replay isolation

    func testReplayIsolatesAcrossSessions() async throws {
        let store = BASInMemoryAtomLifecycleStore()

        // Two distinct sessions touching different atoms
        try await driveTransition(store: store,
            eventID: "s1-e1",
            atomID: "atom-sess1",
            sessionID: "session-A",
            currentPhase: 0, action: 0,
            recordedAtMs: 100)
        try await driveTransition(store: store,
            eventID: "s2-e1",
            atomID: "atom-sess2",
            sessionID: "session-B",
            currentPhase: 0, action: 0,
            recordedAtMs: 200)

        let sessAEvents = await store.events(forSession: "session-A")
        let sessBEvents = await store.events(forSession: "session-B")
        XCTAssertEqual(sessAEvents.count, 1)
        XCTAssertEqual(sessBEvents.count, 1)
        XCTAssertEqual(sessAEvents[0].atomID, "atom-sess1")
        XCTAssertEqual(sessBEvents[0].atomID, "atom-sess2")
    }

    // MARK: - Multi-atom snapshot serialization

    func testMultiAtomSnapshotRoundTrip() async throws {
        let original = BASInMemoryAtomLifecycleStore()
        for i in 0..<10 {
            try await driveTransition(store: original,
                eventID: "multi-e\(i)",
                atomID: "atom-\(i)",
                sessionID: "multi-sess",
                currentPhase: 0, action: 0,
                recordedAtMs: Int64(i * 100))
        }
        let originalCount = await original.count()
        XCTAssertEqual(originalCount, 10)

        // Snapshot + cold replay
        let allEvents = await original.events(forSession: "multi-sess")
        let snapshot = try JSONEncoder().encode(allEvents)
        let restored = BASInMemoryAtomLifecycleStore()
        let replayed = try JSONDecoder().decode(
            [BASAtomLifecycleEvent].self, from: snapshot)
        try await restored.bulkImport(replayed)
        let restoredCount = await restored.count()
        XCTAssertEqual(restoredCount, 10,
            "Cold restart preserves all 10 atom events")

        // Each atom reconstructs to Admitted (1)
        for i in 0..<10 {
            let phase = await restored
                .reconstructCurrentPhaseByte(forAtom: "atom-\(i)")
            XCTAssertEqual(phase, 1,
                "atom-\(i) reconstructs to Admitted after restart")
        }
    }
}
