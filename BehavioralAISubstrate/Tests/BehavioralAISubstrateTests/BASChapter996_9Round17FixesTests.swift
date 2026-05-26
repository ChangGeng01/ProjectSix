// MARK: - BASChapter996_9Round17FixesTests
// chapter 九百九十六.9 / M3685.9 — META-REVIEW Round-17 cascade
//
// Round-17 caught 2 CRITICALs (same-class one-layer-deeper):
//   - CRITICAL-1: registry.unregister(agentID:) leaves stale
//     graph writer claim → ghost claims block re-binding
//   - CRITICAL-2: two concurrent wire() calls from different
//     registries on the same graph can race in Phase 2
//
// Fixes:
//   - Added graph.registerWriterBatch(claims:) atomic transaction
//   - Added graph.unregisterWriter(agentID:domain:) tear-down
//   - Added registry.unregister(agentID:fromGraph:) overload
//   - registry.wire(toGraph:) delegates to atomic batch

import XCTest
@testable import BASMemory

final class BASChapter996_9Round17FixesTests: XCTestCase {

    // MARK: - CRITICAL-1: unregister releases graph claim

    /// Defense:after `unregister(agentID:fromGraph:)`,the graph
    /// MUST release the writer claim → a different agent can
    /// claim the same domain。 Pre-fix unregister only touched
    /// the registry,leaving graph with stale claim → re-bind
    /// failed permanently with domainAlreadyClaimed against
    /// the dead agent。
    func testCRITICAL_C1_UnregisterReleasesGraphClaim()
        async throws
    {
        let registry = BASAgentRegistry(
            strictRoleUniqueness: false)
        let graph = BASSharedStateGraph()
        let scoutA = BASAgentSpec(
            agentID: "scout.A",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(scoutA)
        try await registry.wire(toGraph: graph)
        // Verify claim installed
        let preUnregister = await graph
            .writerForDomain(.situationField)
        XCTAssertEqual(preUnregister, "scout.A",
            "ch 996.9 C-1 setup: claim installed by wire")
        // Unregister with graph cleanup
        try await registry.unregister(
            agentID: "scout.A",
            fromGraph: graph)
        // Verify claim released
        let postUnregister = await graph
            .writerForDomain(.situationField)
        XCTAssertNil(postUnregister,
            "ch 996.9 CRITICAL-1: unregister(fromGraph:) MUST " +
            "release the graph claim — was ghost-blocking " +
            "re-binding pre-fix")
        // Re-bind a different agent to the same domain MUST
        // succeed (closes the actual user-facing symptom)
        let scoutB = BASAgentSpec(
            agentID: "scout.B",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(scoutB)
        try await registry.wire(toGraph: graph)
        let reboundWriter = await graph
            .writerForDomain(.situationField)
        XCTAssertEqual(reboundWriter, "scout.B",
            "ch 996.9 C-1: domain freed by unregister MUST " +
            "accept new claim from different agent")
    }

    /// Defense:`unregister(agentID:fromGraph:)` is idempotent
    /// w.r.t. graph state — calling it twice for the same agent
    /// + graph pair (after the first succeeded) should throw
    /// `unknownAgent` from the registry side (registry is the
    /// authoritative entry list) but NOT corrupt graph state。
    func testC1_DoubleUnregister_RegistryRejectsButGraphSafe()
        async throws
    {
        let registry = BASAgentRegistry()
        let graph = BASSharedStateGraph()
        let agent = BASAgentSpec(
            agentID: "scout.1",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry.register(agent)
        try await registry.wire(toGraph: graph)
        try await registry.unregister(
            agentID: "scout.1", fromGraph: graph)
        // Second unregister: registry side throws unknownAgent
        do {
            try await registry.unregister(
                agentID: "scout.1", fromGraph: graph)
            XCTFail(
                "ch 996.9 C-1: double-unregister MUST throw " +
                "unknownAgent on the SECOND call")
        } catch BASAgentRegistry.RegistryError.unknownAgent {
            // Expected
        }
        // Graph state still consistent (no claim for the domain)
        let writer = await graph
            .writerForDomain(.situationField)
        XCTAssertNil(writer)
    }

    // MARK: - CRITICAL-2: atomic registerWriterBatch

    /// Defense:two `wire(toGraph:)` calls from different
    /// registries on the same graph,with overlapping write
    /// domains,MUST serialize through the graph actor's
    /// mailbox。 Either one wins entirely (other throws + graph
    /// unchanged) OR both succeed if domains are distinct。
    /// Pre-fix Phase 1 / Phase 2 race could let partial state
    /// from BOTH calls land。
    func testCRITICAL_C2_ConcurrentWires_AtomicSerialization()
        async throws
    {
        let registry1 = BASAgentRegistry()
        let registry2 = BASAgentRegistry()
        let graph = BASSharedStateGraph()
        // Both registries claim .candidateFrontier (overlap)
        let plannerA = BASAgentSpec(
            agentID: "planner.A",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let plannerB = BASAgentSpec(
            agentID: "planner.B",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        try await registry1.register(plannerA)
        try await registry2.register(plannerB)
        // Run both wires concurrently
        let results: (Result<Void, Error>, Result<Void, Error>) =
            await withTaskGroup(
                of: (Int, Result<Void, Error>).self
            ) { group in
                group.addTask {
                    do {
                        try await registry1.wire(toGraph: graph)
                        return (0, .success(()))
                    } catch {
                        return (0, .failure(error))
                    }
                }
                group.addTask {
                    do {
                        try await registry2.wire(toGraph: graph)
                        return (1, .success(()))
                    } catch {
                        return (1, .failure(error))
                    }
                }
                var r0: Result<Void, Error> = .success(())
                var r1: Result<Void, Error> = .success(())
                for await result in group {
                    if result.0 == 0 { r0 = result.1 }
                    else { r1 = result.1 }
                }
                return (r0, r1)
            }
        // Exactly ONE must succeed,the other MUST throw
        let success0 = (try? results.0.get()) != nil
        let success1 = (try? results.1.get()) != nil
        XCTAssertTrue(
            success0 != success1,
            "ch 996.9 CRITICAL-2: exactly one wire MUST succeed " +
            "the other MUST throw domainAlreadyClaimed " +
            "(serialization through actor mailbox)。 " +
            "Pre-fix: BOTH could partially install。 " +
            "success0=\(success0) success1=\(success1)")
        // Graph state matches the winner
        let writer = await graph
            .writerForDomain(.candidateFrontier)
        let expectedWinner = success0 ? "planner.A" : "planner.B"
        XCTAssertEqual(writer, expectedWinner,
            "ch 996.9 CRITICAL-2: graph claim MUST match the " +
            "wire() that succeeded")
    }

    /// Defense:atomic batch with intra-batch conflict throws
    /// IMMEDIATELY,no partial install。
    func testCRITICAL_C2_IntraBatchConflict_NoPartialInstall()
        async throws
    {
        let graph = BASSharedStateGraph()
        // Two agents claiming same domain — should throw
        let claims: [(agentID: String, domain: BASStateDomain)] =
            [
                ("agent.A", .situationField),
                ("agent.B", .candidateFrontier),
                ("agent.C", .situationField),  // conflict with A
            ]
        do {
            try await graph.registerWriterBatch(claims: claims)
            XCTFail(
                "ch 996.9 C-2: intra-batch conflict MUST throw")
        } catch BASSharedStateGraphError
            .domainAlreadyClaimed
        {
            // Expected
        }
        // After throw: NO claims installed (atomic)
        let aClaim = await graph
            .writerForDomain(.situationField)
        let bClaim = await graph
            .writerForDomain(.candidateFrontier)
        XCTAssertNil(aClaim,
            "ch 996.9 CRITICAL-2: atomic — A's earlier valid " +
            "claim MUST NOT install when B/C conflict later " +
            "in batch")
        XCTAssertNil(bClaim,
            "ch 996.9 CRITICAL-2: B's distinct claim also MUST " +
            "NOT install on intra-batch throw")
    }

    /// Defense:atomic batch idempotent for same-agent same-
    /// domain claims (re-batch should not throw)
    func testC2_AtomicBatch_IsIdempotent() async throws {
        let graph = BASSharedStateGraph()
        let claims: [(agentID: String, domain: BASStateDomain)] =
            [
                ("agent.A", .situationField),
                ("agent.B", .candidateFrontier),
            ]
        try await graph.registerWriterBatch(claims: claims)
        // Second batch with same claims — must not throw
        try await graph.registerWriterBatch(claims: claims)
        let aClaim = await graph
            .writerForDomain(.situationField)
        XCTAssertEqual(aClaim, "agent.A")
    }
}
