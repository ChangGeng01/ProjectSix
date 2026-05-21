// MARK: - BASChapter800L8AtomLifecycleRecordingActivationTests
// chapter 八百 / M2651-M2655
//
// Verifies the L8 recorder activation against the L8 storage
// adapters (chapter 七百八十九 InMemory + chapter 七百九十二
// SQLite)。 Five invariants pinned:
//
//   1. `recordTransition(...)` persists exactly the event the
//      caller specified — byte-faithful schema-023 column shape。
//   2. `transitionAndRecord(...)` on iOS/macOS invokes the Rust
//      bridge AND writes the event with from/to phases reflecting
//      the bridge's state-machine decision。
//   3. Rejected transitions (outcome 1 = illegal,outcome 2 =
//      terminal) STILL produce an event row,with toPhase ==
//      fromPhase per schema 023's audit-of-attempts invariant。
//   4. Invalid input bytes (out-of-range phase/action) raise
//      `RecordingError.invalidTransitionByte` and leave the store
//      empty — no half-written audit rows。
//   5. Cold restart through the SQLite store recovers all events
//      written via either recorder entry point。

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASChapter800L8AtomLifecycleRecordingActivationTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-test-atom-record-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        if let url = tempURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try await super.tearDown()
    }

    // MARK: - Pure recorder (all platforms)

    func testRecordTransitionPersistsExplicitBytes() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        let recorded = try await BASRoutedAtomLifecycleRecording
            .recordTransition(
                eventID: "ev-1",
                atomID: "atom-A",
                sessionID: "sess-1",
                fromPhaseByte: 0,    // Created
                toPhaseByte: 1,      // Admitted
                actionByte: 0,       // Admit
                outcome: 0,          // Advanced
                store: store,
                nowMs: 100,
                actorRef: "sovereign")
        XCTAssertEqual(recorded.eventID, "ev-1")
        XCTAssertEqual(recorded.fromPhaseByte, 0)
        XCTAssertEqual(recorded.toPhaseByte, 1)
        XCTAssertEqual(recorded.actionByte, 0)
        XCTAssertEqual(recorded.outcome, 0)
        XCTAssertTrue(recorded.advanced)
        XCTAssertEqual(recorded.actorRef, "sovereign")

        let live = await store.events(forAtom: "atom-A")
        XCTAssertEqual(live, [recorded])
    }

    func testRecordTransitionDuplicateEventIDThrows() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        _ = try await BASRoutedAtomLifecycleRecording
            .recordTransition(
                eventID: "ev-dup",
                atomID: "atom-A",
                sessionID: "sess",
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0,
                store: store, nowMs: 0)
        do {
            _ = try await BASRoutedAtomLifecycleRecording
                .recordTransition(
                    eventID: "ev-dup",
                    atomID: "atom-A",
                    sessionID: "sess",
                    fromPhaseByte: 0, toPhaseByte: 1,
                    actionByte: 0, outcome: 0,
                    store: store, nowMs: 1)
            XCTFail("Expected duplicate-eventID throw")
        } catch BASInMemoryAtomLifecycleStore.StoreError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "ev-dup")
        }
    }

    // MARK: - Composite recorder (iOS / macOS only)

    #if os(iOS) || os(macOS)

    func testTransitionAndRecordAdvancesAndPersists() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        // Phase 0 (Created) + Action 0 (Admit) → Phase 1 (Admitted)
        let result = try await BASRoutedAtomLifecycleRecording
            .transitionAndRecord(
                eventID: "ev-advance",
                atomID: "atom-A",
                sessionID: "sess",
                currentPhaseByte: 0,
                actionByte: 0,
                store: store,
                nowMs: 500)
        XCTAssertTrue(result.bridgeResult.advanced)
        XCTAssertEqual(result.bridgeResult.outcome, 0)
        XCTAssertEqual(result.bridgeResult.nextPhaseByte, 1)
        XCTAssertEqual(result.event.fromPhaseByte, 0)
        XCTAssertEqual(result.event.toPhaseByte, 1)
        XCTAssertEqual(result.event.outcome, 0)

        // Bridge result + persisted event in sync
        let restored = await store.events(forAtom: "atom-A")
        XCTAssertEqual(restored, [result.event])
    }

    func testTransitionAndRecordIllegalKeepsPhaseSamePersistsAttempt() async throws {
        // chapter 七百八十二 contract: Phase 0 (Created) + Action 1
        // (Link) is illegal — must Admit before Link。 Bridge
        // returns outcome=1 (RejectedIllegal),nextPhase unchanged。
        let store = BASInMemoryAtomLifecycleStore()
        let result = try await BASRoutedAtomLifecycleRecording
            .transitionAndRecord(
                eventID: "ev-illegal",
                atomID: "atom-B",
                sessionID: "sess",
                currentPhaseByte: 0,    // Created
                actionByte: 1,          // Link (illegal from Created)
                store: store,
                nowMs: 1)
        XCTAssertFalse(result.bridgeResult.advanced)
        XCTAssertEqual(result.bridgeResult.outcome, 1,
            "Phase 0 + Action 1 → RejectedIllegal")
        // Event row reflects attempt: toPhase == fromPhase
        XCTAssertEqual(result.event.fromPhaseByte, 0)
        XCTAssertEqual(result.event.toPhaseByte, 0,
            "Illegal transition pins toPhase == fromPhase")
        XCTAssertEqual(result.event.outcome, 1)

        let persisted = await store.events(forAtom: "atom-B")
        XCTAssertEqual(persisted.count, 1,
            "Audit row written even though state machine refused")
    }

    func testTransitionAndRecordInvalidBytesThrowAndLeaveStoreEmpty() async throws {
        let store = BASInMemoryAtomLifecycleStore()
        do {
            _ = try await BASRoutedAtomLifecycleRecording
                .transitionAndRecord(
                    eventID: "ev-bad",
                    atomID: "atom-C",
                    sessionID: "sess",
                    currentPhaseByte: 99,  // out-of-range phase
                    actionByte: 0,
                    store: store,
                    nowMs: 0)
            XCTFail("Expected invalidTransitionByte throw")
        } catch BASRoutedAtomLifecycleRecording.RecordingError
            .invalidTransitionByte(let phase, let action) {
            XCTAssertEqual(phase, 99)
            XCTAssertEqual(action, 0)
        }
        let count = await store.count()
        XCTAssertEqual(count, 0,
            "Invalid bytes must NOT write a row")
    }

    func testReconstructionFromRecordedTransitions() async throws {
        // Drive a 3-step legal sequence:
        //   0 (Created) -[Admit]-> 1 (Admitted)
        //   1 (Admitted) -[Link]-> 2 (Linked)
        //   2 (Linked) -[Archive]-> 3 (Archived)
        let store = BASInMemoryAtomLifecycleStore()
        let steps: [(UInt8, UInt8)] = [(0, 0), (1, 1), (2, 2)]
        for (idx, (phase, action)) in steps.enumerated() {
            _ = try await BASRoutedAtomLifecycleRecording
                .transitionAndRecord(
                    eventID: "ev-\(idx)",
                    atomID: "atom-life",
                    sessionID: "sess",
                    currentPhaseByte: phase,
                    actionByte: action,
                    store: store,
                    nowMs: Int64(idx))
        }
        let latest = await store.reconstructCurrentPhaseByte(
            forAtom: "atom-life")
        XCTAssertEqual(latest, 3,
            "Replay reconstructs Archived (phase 3) as latest")
    }

    func testTransitionAndRecordSurvivesSQLiteColdRestart() async throws {
        do {
            let store = try BASSQLiteAtomLifecycleStore(
                databaseURL: tempURL)
            _ = try await BASRoutedAtomLifecycleRecording
                .transitionAndRecord(
                    eventID: "ev-cold",
                    atomID: "atom-cold",
                    sessionID: "sess",
                    currentPhaseByte: 0,
                    actionByte: 0,
                    store: store,
                    nowMs: 9_000,
                    actorRef: "sovereign")
        }
        let reopened = try BASSQLiteAtomLifecycleStore(
            databaseURL: tempURL)
        let restored = await reopened.events(forAtom: "atom-cold")
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].fromPhaseByte, 0)
        XCTAssertEqual(restored[0].toPhaseByte, 1)
        XCTAssertEqual(restored[0].outcome, 0)
        XCTAssertEqual(restored[0].actorRef, "sovereign")
        XCTAssertEqual(restored[0].recordedAtMs, 9_000)
    }

    #endif  // os(iOS) || os(macOS)
}
