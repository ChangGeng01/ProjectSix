import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore

/// audit memory-b F3 — admit() used to overwrite the in-process content cache on EVERY new event,
/// including a conflicting re-admit of the same id with LOWER confidence. The M942 reducer keeps
/// the higher-confidence winner's METADATA, but the cache then held the loser's CONTENT, so
/// atom(forID:) returned a winner-metadata + loser-content HYBRID. (The prior "close" was a
/// docs-only comment fix — the behavioral defect was still live.)
final class BASEventSourcedContentCachePollutionTests: XCTestCase {

    private func atom(id: UUID, confidence: Double, content: String) -> BASGovernedMemory {
        BASGovernedMemory(id: id, kind: .episodic, content: content, scope: .session,
                          sensitivity: .low, tier: .warm, confidence: confidence,
                          sourceType: "t", governanceStatus: .governed, provenanceSummary: "p")
    }

    func testLowerConfidenceReAdmitDoesNotPolluteWinnerContent() async throws {
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(), sessionID: "s")
        let id = UUID()
        _ = try await store.admit(atom(id: id, confidence: 0.9, content: "WINNER"))
        _ = try await store.admit(atom(id: id, confidence: 0.3, content: "LOSER"))  // loses the tiebreak
        let got = await store.atom(forID: id.uuidString)
        XCTAssertEqual(got?.confidence, 0.9, "the reducer keeps the higher-confidence winner's metadata")
        XCTAssertEqual(got?.content, "WINNER",
            "content must be the WINNER's — a lower-confidence re-admit must NOT pollute it (the F3 hybrid)")
    }

    func testHigherConfidenceReAdmitDoesUpdateContent() async throws {
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: BASInMemoryEventLogStorage(), sessionID: "s")
        let id = UUID()
        _ = try await store.admit(atom(id: id, confidence: 0.3, content: "OLD"))
        _ = try await store.admit(atom(id: id, confidence: 0.9, content: "NEW"))    // strictly wins
        let got = await store.atom(forID: id.uuidString)
        XCTAssertEqual(got?.confidence, 0.9)
        XCTAssertEqual(got?.content, "NEW",
            "a strictly-higher-confidence re-admit IS the new winner — its content must be cached")
    }

    // MARK: - audit memory-b F3 (2nd clause) — reentrancy hybrid

    /// Wraps an in-memory log but PARKS the FIRST `append` on a test-held gate, so two concurrent
    /// same-id admits interleave: the loser reads/decides mid-flight while the winner lands. Every
    /// later append passes straight through.
    private actor GatedAppendEventLog: BASEventLogStorage {
        private let inner = BASInMemoryEventLogStorage()
        private var firstAppendGated = false
        private var gate: CheckedContinuation<Void, Never>?
        private var parkedWaiter: CheckedContinuation<Void, Never>?
        private var parked = false

        @discardableResult
        func append(_ entry: BASEventLogEntry) async throws -> (wasNew: Bool, assignedSequenceNumber: Int64) {
            if !firstAppendGated {
                firstAppendGated = true
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    gate = c; parked = true; parkedWaiter?.resume(); parkedWaiter = nil
                }
            }
            return try await inner.append(entry)
        }
        func events(forSession sessionID: String) async -> [BASEventLogEntry] {
            await inner.events(forSession: sessionID)
        }
        func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] {
            await inner.events(sinceTimestampMs: since, limit: limit)
        }
        var totalCount: Int { get async { await inner.totalCount } }
        func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int {
            try await inner.pruneEventsBefore(timestampMs: cutoff)
        }
        func waitUntilParked() async {
            if parked { return }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in parkedWaiter = c }
        }
        func releaseGate() { gate?.resume(); gate = nil }
    }

    /// The reentrancy teeth: a LOSER admit parks mid-append while a WINNER admit runs to completion,
    /// then the loser lands last. Under the OLD pre-append snapshot both saw an empty projection, so
    /// the loser wrote its content LAST → a winner-metadata + loser-content hybrid. The post-append
    /// re-read makes the loser observe the real winner and skip its write. Reverting the fix reds this.
    func testConcurrentReAdmitDoesNotPolluteWinnerUnderReentrancy() async throws {
        let log = GatedAppendEventLog()
        let store = BASEventSourcedMemoryAtomStore(eventLog: log, sessionID: "s")
        let id = UUID()

        // Hoist the atoms to locals so the `async let` captures only Sendable values (store + atom),
        // not `self` via the `atom(...)` instance helper (Swift-6 sending-self data-race).
        let loser = atom(id: id, confidence: 0.3, content: "LOSER")
        let winner = atom(id: id, confidence: 0.9, content: "WINNER")

        // Task A (LOSER, 0.3) starts first; its append parks before landing.
        async let aResult: Bool = store.admit(loser)
        await log.waitUntilParked()

        // Task B (WINNER, 0.9) runs to completion while A is parked mid-append.
        _ = try await store.admit(winner)

        // Release A: it lands its LOSER event last.
        await log.releaseGate()
        _ = try await aResult

        let got = await store.atom(forID: id.uuidString)
        XCTAssertEqual(got?.confidence, 0.9, "the reducer keeps the higher-confidence winner's metadata")
        XCTAssertEqual(got?.content, "WINNER",
            "even under a concurrent re-admit interleaving, the loser's content must NOT pollute the "
            + "winner (F3 2nd clause — the reentrancy hybrid)")
    }
}
