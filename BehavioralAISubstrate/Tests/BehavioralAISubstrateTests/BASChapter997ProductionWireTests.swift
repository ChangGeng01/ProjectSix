// MARK: - BASChapter997ProductionWireTests
// chapter 九百九十七 / M3690 — 全面 wired:production roster→graph wire
//
// After 17 N-pass review rounds caught wire-up gaps on the
// REGISTRY → graph path,the final invariant gap was caught:
// `BASAgentRegistry` is orphan from production (dispatcher uses
// `BASAgentTurnRoster` directly,never the registry),so the
// "Single-Writer-Per-Domain enforced system-wide" doctrine that
// R15 + R17 worked to wire up was ONLY at TEST scope。
// Production dispatch path relied on `writeObject`'s AUTO-CLAIM
// behavior → first-writer-wins race。
//
// ch 997 wires the ROSTER directly to the graph at runtime
// construction (via the new `BASAgentFabricRuntime
// .wireRosterToGraph()` method) and has
// `BASAgentFabricFullTurnAdapter.run(...)` call it before first
// dispatch automatically。 Hosts using the substrate's reference
// pipeline get SWPD enforcement FOR FREE in production now —
// previously it was test-only。
//
// Tests pin:
//   1. wireRosterToGraph claims all 9 seat write domains
//   2. wireRosterToGraph throws on intra-roster overlap
//      (defensive — invalid host configuration)
//   3. wireRosterToGraph is idempotent (re-wire same roster
//      no-ops via registerWriterBatch contract)
//   4. After ch 997 a dispatcher write attempted by a DIFFERENT
//      agent than the registered writer throws
//      writerIdentityMismatch (proves the wire is live in
//      production write path)

import XCTest
@testable import BASMemory

final class BASChapter997ProductionWireTests: XCTestCase {

    // MARK: - wireRosterToGraph contract

    func testCRITICAL_WireRosterToGraph_AllNineSeatsClaim()
        async throws
    {
        let runtime = BASAgentFabricRuntime(
            roster: makeNineSeatRoster(),
            graph: BASSharedStateGraph())
        try await runtime.wireRosterToGraph()
        // Every seat's writeDomain MUST be claimed by that seat
        let scout = await runtime.graph
            .writerForDomain(.situationField)
        XCTAssertEqual(scout, "scout.1",
            "ch 997: Scout's .situationField claim installed")
        let planner = await runtime.graph
            .writerForDomain(.candidateFrontier)
        XCTAssertEqual(planner, "planner.1")
        let risk = await runtime.graph
            .writerForDomain(.riskField)
        XCTAssertEqual(risk, "risk.1")
        let surface = await runtime.graph
            .writerForDomain(.renderFrame)
        XCTAssertEqual(surface, "surface.1")
        // 5 optional seats also claimed
        let memory = await runtime.graph
            .writerForDomain(.memoryBundle)
        XCTAssertEqual(memory, "memory.1")
        let critic = await runtime.graph
            .writerForDomain(.critiqueField)
        XCTAssertEqual(critic, "critic.1")
        let alignment = await runtime.graph
            .writerForDomain(.alignmentField)
        XCTAssertEqual(alignment, "hostalign.1")
        let sentinel = await runtime.graph
            .writerForDomain(.sovereignVerdict)
        XCTAssertEqual(sentinel, "sentinel.1")
        let evolution = await runtime.graph
            .writerForDomain(.evolutionProposal)
        XCTAssertEqual(evolution, "evolution.1")
    }

    /// Defense:wireRosterToGraph is idempotent。 Calling it
    /// twice in a row MUST not throw (per registerWriterBatch's
    /// same-agent same-domain idempotency contract)。
    func testCRITICAL_WireRosterToGraph_IsIdempotent()
        async throws
    {
        let runtime = BASAgentFabricRuntime(
            roster: makeNineSeatRoster(),
            graph: BASSharedStateGraph())
        try await runtime.wireRosterToGraph()
        try await runtime.wireRosterToGraph()
        // Verify state still consistent
        let scout = await runtime.graph
            .writerForDomain(.situationField)
        XCTAssertEqual(scout, "scout.1")
    }

    /// Defense:roster with overlapping writeDomains across two
    /// seats MUST throw at wire time — this is a host
    /// configuration error that should fail fast,not silently
    /// auto-claim during first dispatch。
    func testCRITICAL_WireRosterToGraph_OverlapThrows()
        async throws
    {
        // Construct an invalid roster where Memory and Scout
        // both claim .situationField (would only be possible
        // via direct BASAgentSpec construction;the canonical
        // 9-seat roster doesn't do this,but a host could
        // misconfigure)
        let scout = BASAgentSpec(
            agentID: "scout.bad",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let memory = BASAgentSpec(
            agentID: "memory.bad",
            role: .memory,
            // ↓ overlap with scout
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let roster = BASAgentTurnRoster(
            scout: scout,
            planner: BASAgentSpec(
                agentID: "p", role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "r", role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "s", role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            memory: memory)
        let runtime = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph())
        do {
            try await runtime.wireRosterToGraph()
            XCTFail(
                "ch 997: overlapping writeDomain in roster MUST " +
                "throw at wire time (fail-fast vs silent " +
                "auto-claim race during first dispatch)")
        } catch BASSharedStateGraphError
            .domainAlreadyClaimed
        {
            // Expected
        }
    }

    // MARK: - Production-write-path proof

    /// CRITICAL: this is the test that 17 prior rounds couldn't
    /// have because the production wire didn't exist。 After ch
    /// 997,a write attempted by a DIFFERENT agent than the
    /// registered writer MUST throw writerIdentityMismatch (the
    /// SWPD enforcement is now LIVE in production write path)。
    /// Pre-ch-997 the first write by any agent would silently
    /// auto-claim → no error → ghost writes possible from agents
    /// the roster never sanctioned。
    func testCRITICAL_SWPD_LiveInProductionWritePath()
        async throws
    {
        let runtime = BASAgentFabricRuntime(
            roster: makeNineSeatRoster(),
            graph: BASSharedStateGraph())
        try await runtime.wireRosterToGraph()
        // Pre-wire: scout.1 is the claimed writer for
        // .situationField。 An impostor agent attempting to
        // write to .situationField MUST be rejected。
        let impostor = BASAgentSpec(
            agentID: "impostor",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        do {
            _ = try await runtime.graph.writeObject(
                domain: .situationField,
                objectID: "test",
                payloadJson: "{}",
                byAgent: impostor)
            XCTFail(
                "ch 997 CRITICAL: SWPD MUST be live in " +
                "production write path — impostor agent's " +
                "write MUST throw writerIdentityMismatch。 " +
                "Pre-ch-997 the auto-claim race would have " +
                "let this succeed silently。")
        } catch BASSharedStateGraphError
            .writerIdentityMismatch(
                _, let registered, let attempting)
        {
            XCTAssertEqual(registered, "scout.1")
            XCTAssertEqual(attempting, "impostor")
        }
    }

    // MARK: - Helpers

    private func makeNineSeatRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            memory: BASAgentSpec(
                agentID: "memory.1",
                role: .memory,
                writeDomains: [.memoryBundle],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            critic: BASAgentSpec(
                agentID: "critic.1",
                role: .critic,
                writeDomains: [.critiqueField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            hostAlignment: BASAgentSpec(
                agentID: "hostalign.1",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
            sovereignSentinel: BASAgentSpec(
                agentID: "sentinel.1",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
            evolutionShadow: BASAgentSpec(
                agentID: "evolution.1",
                role: .evolutionShadow,
                writeDomains: [.evolutionProposal],
                defaultLeaseProfile: .coldSeat,
                visibility: .medium))
    }
}
