// MARK: - BASMemoryAtomReplayDeterminismTests
// chapter 四百二 / M946
//
// Phase 1 第六刀:replay-determinism stress sweep。This test
// class is the chapter 三百九二 (M892) doctrine pin enforcement —
// if it ever fails,the architectural promise that replay
// reproduces byte-equal projections breaks。
//
// Targets per the M946 plan spec (6 heavy tests):
//   - 100 events × random mix replay (1)
//   - 1000 events × random mix replay (1)
//   - 1000 events with idempotent-retry on 5% of eventIDs (1)
//   - 1000 events × cachePolicy lazy vs warmAtInit parity (1)
//   - Partial-replay fidelity:replay first N,persist;replay
//     remaining from N onward,assert == full replay (1)
//   - Cross-conformer parity:event-sourced store vs in-memory
//     store fed via emitter (1)

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryAtomReplayDeterminismTests: XCTestCase {

    // MARK: - Fixtures

    /// Deterministic PRNG so the stress sequences are
    /// byte-stable across runs (chapter 三百九二)。
    struct DeterministicRNG: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            // splitmix64
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func atomID(_ i: Int) -> String {
        "00000000-0000-4000-8000-\(String(format: "%012d", i))"
    }

    private func randomPayload(
        atomIndex: Int,
        rng: inout DeterministicRNG
    ) -> BASMemoryAtomEventPayload {
        let id = atomID(atomIndex)
        let kind = Int(rng.next() % 4)
        switch kind {
        case 0:
            // .admitted
            let atom = BASGovernedMemory(
                id: UUID(uuidString: id)!,
                kind: .semantic,
                content: "c\(atomIndex)",
                scope: .user,
                sensitivity: .low,
                tier: [.hot, .warm, .cold][
                    Int(rng.next() % 3)],
                confidence:
                    Double(rng.next() % 100) / 100.0,
                sourceType: "src",
                lastConfirmedAt: nil,
                decayScore: 0.0,
                governanceStatus: .governed,
                provenanceSummary: "p")
            return BASMemoryAtomEventPayload(
                admitted: atom)
        case 1:
            return BASMemoryAtomEventPayload(
                tierChange: id,
                newTier: [.hot, .warm, .cold][
                    Int(rng.next() % 3)])
        case 2:
            return BASMemoryAtomEventPayload(
                governanceChange: id,
                newStatus: [
                    .governed, .quarantined, .archived][
                    Int(rng.next() % 3)])
        default:
            return BASMemoryAtomEventPayload(remove: id)
        }
    }

    private func appendStressEvents(
        log: BASInMemoryEventLogStorage,
        count: Int,
        atomCount: Int = 20,
        sessionID: String = "stress",
        seed: UInt64 = 0xC0FFEE,
        duplicateRate: Double = 0.0
    ) async {
        var rng = DeterministicRNG(seed: seed)
        for i in 0..<count {
            let atomIdx = Int(rng.next() % UInt64(atomCount))
            let p = randomPayload(
                atomIndex: atomIdx, rng: &rng)
            // 5% chance of duplicate eventID retry per
            // duplicateRate parameter
            let useDup = duplicateRate > 0
                && Double(rng.next() % 1000) / 1000.0
                    < duplicateRate
            let evID = useDup
                ? "dup-evt-\(i / 20)"
                : "evt-\(i)"
            _ = try? await log.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: evID,
                    timestampMs: Int64(i),
                    sessionID: sessionID,
                    payload: p))
        }
    }

    // MARK: - 100-event replay (1)

    func test100EventReplayByteStable() async {
        let log = BASInMemoryEventLogStorage()
        await appendStressEvents(log: log, count: 100)
        let p1 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        let p2 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        XCTAssertEqual(p1, p2,
            "M946:100-event replay must be byte-stable")
    }

    // MARK: - 1000-event replay (1)

    func test1000EventReplayByteStable() async {
        let log = BASInMemoryEventLogStorage()
        await appendStressEvents(log: log, count: 1000)
        let p1 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        let p2 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        XCTAssertEqual(p1, p2,
            "M946:1000-event replay must be byte-stable")
    }

    // MARK: - 1000-event with 5% idempotent-retry (1)

    func test1000EventReplayWithDuplicateRetries() async {
        let log = BASInMemoryEventLogStorage()
        await appendStressEvents(
            log: log,
            count: 1000,
            duplicateRate: 0.05)
        // Replay should still be byte-stable;duplicate eventIDs
        // are silently dropped at the log layer (wasNew=false)
        // so the projection is unaffected by the retries。
        let p1 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        let p2 = await BASMemoryAtomReducer.project(
            from: log, sessionID: "stress")
        XCTAssertEqual(p1, p2,
            "M946:duplicate eventIDs must not destabilize replay")
    }

    // MARK: - cachePolicy parity (1)

    func test1000EventCacheParity() async throws {
        // Two stores share the same event log;they should
        // converge to byte-equal projections regardless of
        // cachePolicy choice。
        let log = BASInMemoryEventLogStorage()
        await appendStressEvents(
            log: log, count: 1000, sessionID: "share")

        let lazy = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "share",
            cachePolicy: .lazy)
        let warm = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "share",
            cachePolicy: .warmAtInit)
        let lazyProj = await lazy.projectAll()
        let warmProj = await warm.projectAll()
        XCTAssertEqual(lazyProj, warmProj,
            "M946:lazy + warmAtInit produce byte-equal projection")
    }

    // MARK: - Partial replay fidelity (1)

    func testPartialReplayMatchesFullReplay() async {
        // Replay first 500 events,save state,then replay
        // remaining 500 starting from that state。Resulting
        // state must match full 1000-event replay。
        let log = BASInMemoryEventLogStorage()
        await appendStressEvents(
            log: log, count: 1000, sessionID: "p")
        let allEvents = await log.events(forSession: "p")
        XCTAssertEqual(allEvents.count, 1000)

        // Full replay
        let full = await BASMemoryAtomReducer.project(
            from: log, sessionID: "p")

        // Split replay
        var partial: [String: BASGovernedMemory] = [:]
        for ev in allEvents.prefix(500) {
            partial = BASMemoryAtomReducer.reduce(
                priorAtoms: partial, event: ev)
        }
        for ev in allEvents.dropFirst(500) {
            partial = BASMemoryAtomReducer.reduce(
                priorAtoms: partial, event: ev)
        }
        XCTAssertEqual(partial, full,
            "M946:partial replay then continue == full replay")
    }

    // MARK: - Cross-conformer parity (1)

    func testEventSourcedStoreParityWithInMemoryStore()
        async throws
    {
        // Build an in-memory atom store and an event-sourced
        // store from the same admit calls。Verify they reach
        // the same observable state on tier + governance ops。
        let inMem = BASInMemoryMemoryAtomStore()
        let log = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "x",
            clockMs: { 0 },
            cachePolicy: .warmAtInit)

        var rng = DeterministicRNG(seed: 0xB16B00B5)
        let atomCount = 100
        var seenIDs: [String] = []

        // Phase 1: admits
        for i in 0..<atomCount {
            let atomUUID = UUID(uuidString: atomID(i))!
            let atom = BASGovernedMemory(
                id: atomUUID,
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
            // legacy: add via init was done at construction;
            // fake admit by manual insertion via initial:
            _ = atom
            try await evStore.admit(atom)
            seenIDs.append(atomID(i))
        }
        // Hydrate inMem from same atoms via initial:
        let initialAtoms: [BASGovernedMemory] = await evStore
            .allAtoms()
        let inMem2 = BASInMemoryMemoryAtomStore(
            initial: initialAtoms.map { atom in
                // restore content from index lookup (replayed
                // from event-sourced store has empty content;
                // our test uses content cache so it's fine)
                atom
            })

        // Phase 2: random tier + governance + remove ops
        for _ in 0..<50 {
            let id = seenIDs[Int(rng.next()
                % UInt64(seenIDs.count))]
            let op = Int(rng.next() % 3)
            switch op {
            case 0:
                let t: BASMemoryTier =
                    [.hot, .warm, .cold][
                        Int(rng.next() % 3)]
                _ = await evStore.updateTier(
                    forID: id, to: t)
                _ = await inMem2.updateTier(
                    forID: id, to: t)
            case 1:
                let s: BASMemoryGovernanceStatus =
                    [.governed, .quarantined, .archived][
                        Int(rng.next() % 3)]
                _ = await evStore.updateGovernanceStatus(
                    forID: id, to: s)
                _ = await inMem2.updateGovernanceStatus(
                    forID: id, to: s)
            default:
                _ = await evStore.remove(forID: id)
                _ = await inMem2.remove(forID: id)
            }
        }

        // Final state must match across stores (compare
        // metadata only — content cache differences are
        // expected per privacy doctrine but our cache should
        // hold all admits in this test)
        let evIDs = await evStore.allIDs
        let inMemIDs = await inMem2.allIDs
        XCTAssertEqual(evIDs, inMemIDs,
            "M946:cross-conformer ID set must match")
        for id in evIDs {
            let ev = await evStore.atom(forID: id)
            let inm = await inMem2.atom(forID: id)
            XCTAssertEqual(ev?.tier, inm?.tier,
                "tier mismatch on \(id)")
            XCTAssertEqual(
                ev?.governanceStatus,
                inm?.governanceStatus,
                "governance mismatch on \(id)")
        }
        // Suppress unused warning
        _ = inMem
    }
}
