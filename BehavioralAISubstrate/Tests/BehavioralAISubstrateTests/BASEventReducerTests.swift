// MARK: - BASEventReducerTests — chapter 四百三 / M955
//
// Tests the BASEventReducer<State> typed protocol formalization。
// Verifies BASMemoryAtomReducer conformance + replay adapter
// + replay-determinism invariants per chapter 三百九二。

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASEventReducerTests: XCTestCase {

    // MARK: - Fixtures

    private func makeAtom(
        idString: String =
            "00000000-0000-4000-8000-000000000001"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString: idString)!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "src",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
    }

    // MARK: - Protocol conformance (4)

    func testBASMemoryAtomReducerConformsToBASEventReducer() {
        // Compile-time check: type-level conformance via
        // existential
        let _: any BASEventReducer.Type =
            BASMemoryAtomReducer.self
        XCTAssertTrue(true,
            "M955:BASMemoryAtomReducer conforms to BASEventReducer")
    }

    func testStateTypealiasMatchesProjectionMap() {
        // typealias State = [String: BASGovernedMemory]
        let _: BASMemoryAtomReducer.State =
            [String: BASGovernedMemory]()
        // Compile-time proof only — the typed binding above IS the contract (a conformance/type change fails compilation, not a runtime assertion). M824 doctrine: no XCTAssertTrue(true) tautology.
    }

    func testReduceStepWrapsExistingReducerStep() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "e1",
            timestampMs: 0,
            sessionID: "s",
            payload: payload)
        let viaProtocol = BASMemoryAtomReducer.reduceStep(
            prior: [:], event: event)
        let viaLegacy = BASMemoryAtomReducer.reducerStep(
            prior: [:], event: event)
        XCTAssertEqual(viaProtocol, viaLegacy,
            "M955:protocol method must mirror legacy method")
    }

    // audit memory-b F10: a non-UUID atomID must be DROPPED deterministically, not minted at a
    // fresh random UUID (which broke replay determinism — the same event reduced differently each run).
    func testMalformedAtomIDIsDroppedNotMintedAtRandomUUID() {
        let payload = BASMemoryAtomEventPayload(
            op: .admitted, atomID: "not-a-uuid",
            kind: .episodic, scope: .session, sensitivity: .low, tier: .warm,
            confidence: 0.5, sourceType: "t",
            governanceStatus: .governed, provenanceSummary: "p")
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "bad", timestampMs: 0, sessionID: "s", payload: payload)
        let r1 = BASMemoryAtomReducer.reduce(priorAtoms: [:], event: event)
        let r2 = BASMemoryAtomReducer.reduce(priorAtoms: [:], event: event)
        XCTAssertTrue(r1.isEmpty, "a malformed atomID must be dropped, not minted at a random UUID")
        XCTAssertEqual(r1, r2, "reduction must be deterministic (was: two different random UUIDs)")
    }

    func testReduceStepReturnsNilForNonMemoryEvent() {
        let chat = BASEventLogEntry(
            eventID: "c", timestampMs: 0, kind: .chat,
            sessionID: "s", sequenceNumber: 0)
        let r = BASMemoryAtomReducer.reduceStep(
            prior: [:], event: chat)
        XCTAssertNil(r,
            "M955:nil for non-memory events (skip semantics)")
    }

    // MARK: - Replay adapter (3)

    func testReplayAdapterIsAvailable() {
        let adapter = BASMemoryAtomReducer.replayAdapter
        let chat = BASEventLogEntry(
            eventID: "c", timestampMs: 0, kind: .chat,
            sessionID: "s", sequenceNumber: 0)
        XCTAssertNil(adapter([:], chat))
    }

    func testReplayAdapterFunctionallyEqualsReduceStep() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "e", timestampMs: 0, sessionID: "s",
            payload: payload)
        let viaAdapter = BASMemoryAtomReducer
            .replayAdapter([:], event)
        let viaDirect = BASMemoryAtomReducer.reduceStep(
            prior: [:], event: event)
        XCTAssertEqual(viaAdapter, viaDirect)
    }

    func testReplayAdapterUsableWithBASEventReplayRunner()
        async throws
    {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    admitted: atom)))
        let result = await BASEventReplayRunner.replay(
            storage: storage,
            range: .singleSession(sessionID: "s"),
            initial: [String: BASGovernedMemory](),
            reducer: BASMemoryAtomReducer.replayAdapter)
        XCTAssertEqual(result.eventsConsumed, 1)
        XCTAssertEqual(result.finalState.count, 1)
    }

    // MARK: - Replay-determinism via protocol (chapter 三百九二) (2)

    func testReducerProducesSameOutputForSameInputs() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "fixed", timestampMs: 0,
            sessionID: "s",
            payload: payload)
        let r1 = BASMemoryAtomReducer.reduceStep(
            prior: [:], event: event)
        let r2 = BASMemoryAtomReducer.reduceStep(
            prior: [:], event: event)
        XCTAssertEqual(r1, r2,
            "M955:protocol-level replay determinism")
    }

    func testReplayAdapterDeterministicAcrossRuns() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "fixed", timestampMs: 0,
            sessionID: "s",
            payload: payload)
        let a1 = BASMemoryAtomReducer.replayAdapter([:], event)
        let a2 = BASMemoryAtomReducer.replayAdapter([:], event)
        XCTAssertEqual(a1, a2)
    }
}
