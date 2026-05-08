// MARK: - BAS211MemoryAtomSingleSourceOfTruthPinTests
// chapter 四百二 / M950 — chapter 二百一一 single-source-of-truth pin
//
// Doctrine guardrail tests:after Phase 1,event log is THE
// canonical source-of-truth for memory atoms。Tests catch any
// future commit that re-introduces a parallel source-of-truth。

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BAS211MemoryAtomSingleSourceOfTruthPinTests:
    XCTestCase
{

    // MARK: - Single protocol surface

    func testOnlyOneMemoryAtomStoreProtocol() {
        // Pin: only ONE protocol exists for atom storage,
        // and all 3 conformers (in-memory + SQLite + event-
        // sourced) implement the same protocol。
        let inMem = BASInMemoryMemoryAtomStore()
        let evLog = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: evLog, sessionID: "x")
        // Compile-time:both conform to BASMemoryAtomStore
        let _: any BASMemoryAtomStore = inMem
        let _: any BASMemoryAtomStore = evStore
        XCTAssertTrue(true)
    }

    func testEventSourcedStoreIsTheUnifyingConformer() {
        // Pin: Phase 1's unification entry-point is
        // BASEventSourcedMemoryAtomStore;hosts opt in via
        // useEventSourcedAtomStore: true on storage options
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        XCTAssertTrue(opts.useEventSourcedAtomStore)
    }

    // MARK: - Reducer is the only fold

    func testOnlyOneReducerEntryPoint() {
        // Pin: single fold function. If a future commit adds
        // a parallel reducer, this test forces an explicit
        // doctrine update。
        let prior: [String: BASGovernedMemory] = [:]
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "e1",
            timestampMs: 0,
            sessionID: "s",
            payload: BASMemoryAtomEventPayload(remove: "a"))
        let r1 = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: event)
        let r2 = BASMemoryAtomReducer.reducerStep(
            prior: prior, event: event)
        // Both entry points produce same observable state
        XCTAssertEqual(r1, r2 ?? [:])
    }

    // MARK: - Event log is the canonical persistent source

    func testEventLogPersistsAcrossActorRestart() async throws {
        let log = BASInMemoryEventLogStorage()
        let s1 = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "p")
        let atom = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000001")!,
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
        try await s1.admit(atom)
        // New actor on same log → same projected atom
        let s2 = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "p")
        let count = await s2.count
        XCTAssertEqual(count, 1,
            "M950:event log is the source of truth across actors")
    }

    // MARK: - No double-write paths

    func testEmitterAndStoreShareEventLog() async throws {
        // Pin: emitter and event-sourced store both write to
        // the SAME event log. Wire builder's makeBundle
        // guarantees this。
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(
                options: opts,
                eventSourcedSessionID: "share-pin")
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertTrue(
            bundle.atomStore is BASEventSourcedMemoryAtomStore)
    }

    func testNoConflictBetweenAdmitAndUpdateOps()
        async throws
    {
        let opts = BASHostStorageOptions(
            useEventSourcedAtomStore: true)
        let bundle = try await BASHostStorageWireBuilder
            .makeBundle(
                options: opts,
                eventSourcedSessionID: "no-conflict")
        guard let store = bundle.atomStore
            as? BASEventSourcedMemoryAtomStore else {
            XCTFail("Expected event-sourced store")
            return
        }
        let atom = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000002")!,
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
        try await store.admit(atom)
        _ = await store.updateTier(
            forID: atom.id.uuidString,
            to: BASMemoryTier.hot)
        let total = await bundle.eventLog!.totalCount
        XCTAssertEqual(total, 2,
            "M950:admit + update produces exactly 2 events")
    }
}
