// MARK: - BAS392MemoryAtomReplayDeterminismPinTests
// chapter 四百二 / M950 — chapter 三百九二 (M892) replay-determinism pin
//
// Doctrine guardrail tests:replay must produce byte-equal
// projections。M946 has the heavy stress sweep;this file pins
// the determinism doctrine via concise reflection / contract
// checks that fail loudly on regression。

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BAS392MemoryAtomReplayDeterminismPinTests:
    XCTestCase
{

    // MARK: - SHA256 helper determinism

    func testSha256HelperIsDeterministic() {
        let s = "fixed-content"
        let h1 = BASMemoryAtomEventPayload.sha256Hex(s)
        let h2 = BASMemoryAtomEventPayload.sha256Hex(s)
        XCTAssertEqual(h1, h2,
            "M950:SHA256 helper produces same digest for same input")
    }

    // MARK: - Codable byte stability

    func testPayloadCodableByteStable() throws {
        let atom = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000077")!,
            kind: .semantic,
            content: "fixed",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "src",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        let p1 = BASMemoryAtomEventPayload(admitted: atom)
        let p2 = BASMemoryAtomEventPayload(admitted: atom)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try encoder.encode(p1)
        let d2 = try encoder.encode(p2)
        XCTAssertEqual(d1, d2,
            "M950:payload encoding byte-stable for same input")
    }

    // MARK: - Reducer determinism over fixed input

    func testReducerByteStableForFixedSequence() {
        let atom = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000088")!,
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
        let p = BASMemoryAtomEventPayload(admitted: atom)
        let event = BASEventLogEntry.memoryAtomEvent(
            eventID: "stable-evt",
            timestampMs: 1_700_000_000_000,
            sessionID: "s",
            payload: p)
        var r1: [String: BASGovernedMemory] = [:]
        var r2: [String: BASGovernedMemory] = [:]
        for _ in 0..<3 {
            r1 = BASMemoryAtomReducer.reduce(
                priorAtoms: r1, event: event)
            r2 = BASMemoryAtomReducer.reduce(
                priorAtoms: r2, event: event)
        }
        XCTAssertEqual(r1, r2,
            "M950:reducer 3-cycle determinism")
    }

    // MARK: - Cross-conformer parity (event-sourced ↔ legacy)

    func testEventSourcedParityWithInMemoryStoreContract()
        async throws
    {
        // Both stores conform to BASMemoryAtomStore;feeding
        // them the same admit/update/remove sequence in the
        // same order must produce the same observable IDs。
        let log = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "x")
        let inMem = BASInMemoryMemoryAtomStore()

        for i in 0..<5 {
            let atom = BASGovernedMemory(
                id: UUID(uuidString:
                    "00000000-0000-4000-8000-\(String(format: "%012d", i))")!,
                kind: .semantic,
                content: "c\(i)",
                scope: .user,
                sensitivity: .low,
                tier: .warm,
                confidence: 0.5,
                sourceType: "s",
                lastConfirmedAt: nil,
                decayScore: 0.0,
                governanceStatus: .governed,
                provenanceSummary: "p")
            try await evStore.admit(atom)
        }
        let initialAtoms = await evStore.allAtoms()
        let inMem2 = BASInMemoryMemoryAtomStore(
            initial: initialAtoms)

        // Same updateTier sequence
        for i in 0..<5 {
            let id =
                "00000000-0000-4000-8000-\(String(format: "%012d", i))"
            _ = await evStore.updateTier(
                forID: id, to: BASMemoryTier.cold)
            _ = await inMem2.updateTier(
                forID: id, to: BASMemoryTier.cold)
        }
        let evIDs = await evStore.allIDs
        let inMemIDs = await inMem2.allIDs
        XCTAssertEqual(evIDs, inMemIDs)
        for id in evIDs {
            let evTier =
                await evStore.atom(forID: id)?.tier
            let inMemTier =
                await inMem2.atom(forID: id)?.tier
            XCTAssertEqual(evTier, inMemTier,
                "M950:cross-conformer tier parity for \(id)")
        }
    }

    // MARK: - Sequence-number monotonicity

    func testSequenceNumberMonotonic() async throws {
        let log = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "mono")
        let atomA = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000aaa")!,
            kind: .semantic,
            content: "a",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "s",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        try await store.admit(atomA)
        let s1 = await store.lastReplayedSequenceNumber
        let atomB = BASGovernedMemory(
            id: UUID(uuidString:
                "00000000-0000-4000-8000-000000000bbb")!,
            kind: .semantic,
            content: "b",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "s",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        try await store.admit(atomB)
        let s2 = await store.lastReplayedSequenceNumber
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s2)
        XCTAssertGreaterThan(s2!, s1!,
            "M950:sequence numbers strictly monotonic")
    }
}
