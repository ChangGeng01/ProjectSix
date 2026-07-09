import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// audit M-k F1 — turn serialization. BASTurnRuntimeEngine is a reentrant
/// actor: two turns driven concurrently on ONE engine interleave at every
/// await and cross-write the shared last*/sequenceCounter state. The
/// `turnSerializer` gate (default on; kill-switch BAS_TURN_SERIAL=0) enforces
/// the one-turn-per-engine invariant.
///
/// Teeth: a gated event log parks the FIRST envelope append, letting a second
/// turn attempt to start. With serialization ON, turn B cannot begin until
/// turn A fully completes → the two turns' envelope appends are GROUPED (A,A,
/// B,B). With serialization OFF, turn B runs ahead while A is parked →
/// INTERLEAVED (A,B,B,A). The distinguishing signal is whether the first two
/// appends belong to the SAME turn.
final class BASTurnRuntimeEngineTurnSerializationTests: XCTestCase {

    /// Records the sessionID of every append in ENTRY order (before parking),
    /// and parks the very first append until `release()`.
    private actor GatedEventLog: BASEventLogStorage {
        private(set) var entrySessions: [String] = []
        private var gate: CheckedContinuation<Void, Never>?
        private var parkedOnce = false

        @discardableResult
        func append(_ entry: BASEventLogEntry) async throws
            -> (wasNew: Bool, assignedSequenceNumber: Int64)
        {
            entrySessions.append(entry.sessionID)   // ENTRY order, before any park
            if !parkedOnce {
                parkedOnce = true
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    gate = c
                }
            }
            return (wasNew: true, assignedSequenceNumber: Int64(entrySessions.count))
        }
        func events(forSession sessionID: String) async -> [BASEventLogEntry] { [] }
        func events(sinceTimestampMs since: Int64, limit: Int) async -> [BASEventLogEntry] { [] }
        var totalCount: Int { entrySessions.count }
        @discardableResult
        func pruneEventsBefore(timestampMs cutoff: Int64) async throws -> Int { 0 }

        func isParked() -> Bool { gate != nil }
        func count() -> Int { entrySessions.count }
        func release() { gate?.resume(); gate = nil }
    }

    private func makeEngine(log: GatedEventLog, serialize: Bool) -> BASTurnRuntimeEngine {
        BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs.makeStub(),
            eventLog: log,
            eventIDFactory: { "evt-\(UUID().uuidString)" },
            clockMs: { 1000 },
            turnSerializationEnabled: serialize)
    }

    /// Drive two concurrent turns (distinct hostIDs ⇒ distinct sessionIDs),
    /// forcing the interleave window, and return the ENTRY-order sessionIDs.
    private func drive(serialize: Bool) async -> [String] {
        let log = GatedEventLog()
        let engine = makeEngine(log: log, serialize: serialize)
        let reqA = BASCoordinatorTestStubs.makeStubRequest(hostID: "hostA")
        let reqB = BASCoordinatorTestStubs.makeStubRequest(hostID: "hostB")

        async let a: BASEBrainTurnResult = engine.runTurn(reqA)
        // Wait until turn A has actually parked at its first append (a
        // guaranteed event — the gated log parks the first append).
        var guardIters = 0
        while await !log.isParked() {
            await Task.yield(); guardIters += 1
            if guardIters > 200_000 { break }
        }
        async let b: BASEBrainTurnResult = engine.runTurn(reqB)
        if serialize {
            // B is blocked at the turn gate; let it reach the acquire, then
            // release A. Grouping holds regardless of B's exact progress.
            for _ in 0..<200 { await Task.yield() }
        } else {
            // B runs ahead (no gate); wait until BOTH of B's appends land
            // (count 3 = A.start + B.start + B.complete) before releasing A.
            guardIters = 0
            while await log.count() < 3 {
                await Task.yield(); guardIters += 1
                if guardIters > 200_000 { break }
            }
        }
        await log.release()
        _ = await (a, b)
        return await log.entrySessions
    }

    func testSerializationGroupsConcurrentTurns() async {
        let sessions = await drive(serialize: true)
        XCTAssertEqual(sessions.count, 4, "2 turns × (start+complete) envelopes")
        XCTAssertEqual(sessions[0], sessions[1],
            "serialized: turn A's start+complete are contiguous — B could not "
            + "start until A finished (grouped A,A,B,B)")
        XCTAssertEqual(sessions[2], sessions[3])
        XCTAssertNotEqual(sessions[0], sessions[2], "the two turns are distinct")
    }

    /// Kill-switch OFF reverts to the reentrant (interleaved) behavior — the
    /// same run that groups above now interleaves, proving the gate is what
    /// serializes (the teeth: this is the pre-fix behavior).
    func testWithoutSerializationTurnsInterleave() async {
        let sessions = await drive(serialize: false)
        XCTAssertEqual(sessions.count, 4)
        XCTAssertNotEqual(sessions[0], sessions[1],
            "unserialized: turn B ran ahead while A was parked (interleaved A,B,B,A)")
    }
}
