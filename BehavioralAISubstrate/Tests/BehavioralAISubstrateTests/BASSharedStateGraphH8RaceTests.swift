import XCTest
@testable import BASMemory

/// audit H8 (2026-07-07) — Single-Writer-Per-Domain invariant punched through by the
/// validate→await→commit window in `registerWriter`, `registerWriterBatch`, and
/// `writeObject`'s auto-claim.
///
/// The pre-fix order was SQL-first: check `domainWriters[domain]` is free, then
/// `await storage.upsertWriter` (SUSPENSION), then set `domainWriters[domain]`. Two agents
/// both passed the free-check during each other's await → last-wins, and the loser believed
/// it owned a domain that was actually the winner's.
///
/// The existing ch996.9 regression only used a NIL storage — `storage?.upsertWriter` on nil
/// never suspends, so the race window never opened and the test passed vacuously. These tests
/// inject a storage whose `upsertWriter` genuinely suspends (`Task.yield()`), so the graph
/// actor releases its executor at the await and a second caller can interleave — exactly the
/// production condition (a real SQLite adapter suspends). With the fix (reserve in-memory in
/// the same suspension-free region as validation, then persist with rollback) exactly one
/// caller wins; the others are rejected.
final class BASSharedStateGraphH8RaceTests: XCTestCase {

    /// Storage whose `upsertWriter` SUSPENDS before recording — widens the validate→commit
    /// window so the race is deterministically reachable if the fix regresses.
    private actor SuspendingStorage: BASSharedStateGraphStorage {
        private(set) var writers: [BASStateDomain: String] = [:]
        func upsertObject(_ obj: BASStateGraphObject) async throws {}
        func loadObject(ref: String) async throws -> BASStateGraphObject? { nil }
        func loadAllObjects() async throws -> [BASStateGraphObject] { [] }
        func deleteObject(ref: String) async throws {}
        func upsertWriter(domain: BASStateDomain, agentID: String) async throws {
            await Task.yield()          // real suspension → opens the reentrancy window
            writers[domain] = agentID
        }
        func loadAllWriters() async throws -> [(domain: BASStateDomain, agentID: String)] {
            writers.map { (domain: $0.key, agentID: $0.value) }
        }
        func deleteWriter(domain: BASStateDomain) async throws { writers[domain] = nil }
    }

    /// Storage whose `upsertWriter` always throws — for the rollback post-condition.
    private actor FailingStorage: BASSharedStateGraphStorage {
        struct Boom: Error {}
        func upsertObject(_ obj: BASStateGraphObject) async throws {}
        func loadObject(ref: String) async throws -> BASStateGraphObject? { nil }
        func loadAllObjects() async throws -> [BASStateGraphObject] { [] }
        func deleteObject(ref: String) async throws {}
        func upsertWriter(domain: BASStateDomain, agentID: String) async throws {
            await Task.yield(); throw Boom()
        }
        func loadAllWriters() async throws -> [(domain: BASStateDomain, agentID: String)] { [] }
        func deleteWriter(domain: BASStateDomain) async throws {}
    }

    private func spec(_ id: String) -> BASAgentSpec {
        BASAgentSpec(agentID: id, role: .planner, writeDomains: [.candidateFrontier],
                     defaultLeaseProfile: .hotSeat, visibility: .high)
    }

    /// Run two throwing operations concurrently; return whether each succeeded.
    private func race(
        _ a: @escaping @Sendable () async throws -> Void,
        _ b: @escaping @Sendable () async throws -> Void
    ) async -> (Bool, Bool) {
        await withTaskGroup(of: (Int, Bool).self) { group in
            group.addTask { do { try await a(); return (0, true) } catch { return (0, false) } }
            group.addTask { do { try await b(); return (1, true) } catch { return (1, false) } }
            var r = (false, false)
            for await (i, ok) in group { if i == 0 { r.0 = ok } else { r.1 = ok } }
            return r
        }
    }

    // MARK: - Site 1: registerWriter

    func testConcurrentRegisterWriterSuspendingStorageExactlyOneWins() async throws {
        let graph = BASSharedStateGraph(storage: SuspendingStorage())
        let (okA, okB) = await race(
            { try await graph.registerWriter(agentID: "agent.A", domain: .candidateFrontier) },
            { try await graph.registerWriter(agentID: "agent.B", domain: .candidateFrontier) })

        XCTAssertNotEqual(okA, okB,
            "H8: exactly one registerWriter must win under a suspending storage — " +
            "pre-fix both passed the free-check during each other's await (last-wins)")
        let winner = await graph.writerForDomain(.candidateFrontier)
        XCTAssertEqual(winner, okA ? "agent.A" : "agent.B",
            "graph claim must equal the caller that reported success")
    }

    // MARK: - Site 2: writeObject auto-claim

    func testConcurrentAutoClaimWriteObjectExactlyOneOwns() async throws {
        let graph = BASSharedStateGraph(storage: SuspendingStorage())
        let a = spec("agent.A"), b = spec("agent.B")
        let (okA, okB) = await race(
            { _ = try await graph.writeObject(domain: .candidateFrontier, objectID: "o",
                                              payloadJson: "{}", byAgent: a) },
            { _ = try await graph.writeObject(domain: .candidateFrontier, objectID: "o",
                                              payloadJson: "{}", byAgent: b) })
        XCTAssertNotEqual(okA, okB,
            "H8: two agents auto-claiming the same domain on first write must not both win")
        let winner = await graph.writerForDomain(.candidateFrontier)
        XCTAssertEqual(winner, okA ? "agent.A" : "agent.B")
    }

    // MARK: - Site 3: registerWriterBatch

    func testConcurrentRegisterWriterBatchSuspendingStorageExactlyOneWins() async throws {
        let graph = BASSharedStateGraph(storage: SuspendingStorage())
        let claimsA: [(agentID: String, domain: BASStateDomain)] = [("agent.A", .candidateFrontier)]
        let claimsB: [(agentID: String, domain: BASStateDomain)] = [("agent.B", .candidateFrontier)]
        let (okA, okB) = await race(
            { try await graph.registerWriterBatch(claims: claimsA) },
            { try await graph.registerWriterBatch(claims: claimsB) })
        XCTAssertNotEqual(okA, okB,
            "H8: exactly one batch must win under a suspending storage (was: nil-storage test " +
            "never suspended, so the Phase-1/Phase-2 race was untested)")
        let winner = await graph.writerForDomain(.candidateFrontier)
        XCTAssertEqual(winner, okA ? "agent.A" : "agent.B")
    }

    // MARK: - Rollback post-condition (crash-consistency preserved without SQL-first ordering)

    func testRegisterWriterRollsBackInMemoryOnPersistFailure() async throws {
        let graph = BASSharedStateGraph(storage: FailingStorage())
        do {
            try await graph.registerWriter(agentID: "agent.A", domain: .candidateFrontier)
            XCTFail("persist failure must propagate")
        } catch {
            // expected
        }
        let claim = await graph.writerForDomain(.candidateFrontier)
        XCTAssertNil(claim,
            "H8: on persist failure the in-memory reservation must roll back — no phantom claim " +
            "(the property SQL-first ordering used to give, now via explicit rollback)")
    }
}
