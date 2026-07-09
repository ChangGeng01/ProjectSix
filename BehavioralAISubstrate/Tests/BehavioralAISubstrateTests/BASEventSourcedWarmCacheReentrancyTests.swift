import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore

/// audit memory-b F5 — the `.warmAtInit`/`.cachedWithTTL` warm path set `hasWarmedCache = true`
/// BEFORE the `await project(...)` that populates `stateCache`. A REENTRANT operation running during
/// that await saw the flag true but the cache still `[:]`; a concurrent `updateTier` whose existence
/// guard read the false-empty projection PERMANENTLY dropped its mutation. The fix computes the
/// projection into locals and flips the flag LAST (with a re-check), so a reentrant reader either
/// sees a fully-warmed cache or warms it correctly itself.
final class BASEventSourcedWarmCacheReentrancyTests: XCTestCase {

    private func atom(id: UUID, tier: BASMemoryTier) -> BASGovernedMemory {
        BASGovernedMemory(id: id, kind: .episodic, content: "c", scope: .session,
                          sensitivity: .low, tier: tier, confidence: 0.9,
                          sourceType: "t", governanceStatus: .governed, provenanceSummary: "p")
    }

    /// Wraps an in-memory log but PARKS the FIRST `events(forSession:)` call on a test-held gate,
    /// so a warm can be caught mid-flight. Every later read passes straight through.
    private actor GatedEventLog: BASEventLogStorage {
        private let inner = BASInMemoryEventLogStorage()
        private var firstReadGated = false
        private var gate: CheckedContinuation<Void, Never>?
        private var parkedWaiter: CheckedContinuation<Void, Never>?
        private var parked = false

        @discardableResult
        func append(_ entry: BASEventLogEntry) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
            try await inner.append(entry)
        }
        func events(forSession sessionID: String) async -> [BASEventLogEntry] {
            if !firstReadGated {
                firstReadGated = true
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    gate = c
                    parked = true
                    parkedWaiter?.resume(); parkedWaiter = nil
                }
            }
            return await inner.events(forSession: sessionID)
        }
        func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] {
            await inner.events(sinceTimestampMs: since, limit: limit)
        }
        var totalCount: Int { get async { await inner.totalCount } }
        func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int {
            try await inner.pruneEventsBefore(timestampMs: cutoff)
        }
        /// Seed WITHOUT going through the gated read path.
        func seedAdmit(_ a: BASGovernedMemory, sessionID: String) async throws {
            _ = try await inner.append(BASEventLogEntry.memoryAtomEvent(
                eventID: "seed-\(a.id.uuidString)", timestampMs: 1_700_000_000_000,
                sessionID: sessionID, payload: BASMemoryAtomEventPayload(admitted: a)))
        }
        func waitUntilParked() async {
            if parked { return }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in parkedWaiter = c }
        }
        func releaseGate() { gate?.resume(); gate = nil }
    }

    func testConcurrentUpdateDuringWarmIsNotDroppedByHalfWarmedCache() async throws {
        let log = GatedEventLog()
        let id = UUID()
        try await log.seedAdmit(atom(id: id, tier: .warm), sessionID: "s")
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "s", cachePolicy: .warmAtInit)

        // Task A triggers the first warm and parks inside project()'s events() read.
        async let readerParkedResult = store.atom(forID: id.uuidString)
        await log.waitUntilParked()

        // Task B mutates WHILE A is parked mid-warm. It must NOT read a half-warmed empty projection.
        let updated = await store.updateTier(forID: id.uuidString, to: .hot)

        await log.releaseGate()
        _ = await readerParkedResult

        XCTAssertTrue(updated,
            "a tier update issued during a concurrent warm must see the atom, not a half-warmed empty cache")
        let finalTier = await store.atom(forID: id.uuidString)?.tier
        XCTAssertEqual(finalTier, .hot,
            "the mutation must have landed (F5: a reentrant warm must not drop it)")
    }
}
