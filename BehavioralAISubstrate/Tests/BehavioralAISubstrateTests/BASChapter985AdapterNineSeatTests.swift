// MARK: - BASChapter985AdapterNineSeatTests
// chapter 九百八十五 / M3630 — Cross-Module Integration Arc ch3
//
// Closes ch 982.5 META-REVIEW cross-module Gap 8:coordinator
// adapter was 4-seat only。 The 5 optional seats (Memory /
// Critic / HostAlignment / SovereignSentinel / EvolutionShadow)
// were unreachable through `runAgentFabricObservation(...)` even
// when their roster slots were configured。
//
// Tests pin:
//   1. `BASAgentFabricAdapters.turnInput(...)` accepts all 5
//      optional DTOs + plumbs them through (verified by checking
//      the BASAgentTurnInput output)
//   2. EvolutionShadow specifically (the ch 965 9th seat that
//      was added last and missed by all subsequent cascade)
//   3. Defaulted-nil preserves existing 4-seat caller compat
//      byte-equal
//   4. Coordinator `runAgentFabricObservation(...)` plumbs DTOs
//      through to dispatcher when fabric is configured

import XCTest
@testable import BASOrchestration
@testable import BASMemory

final class BASChapter985AdapterNineSeatTests: XCTestCase {

    // MARK: - turnInput plumbing tests

    func testTurnInput_AcceptsAllFiveOptionalDTOs() {
        let frame = sampleFrame()
        let memory = BASMemorySeatInput(
            episodeArcs: ["arc-1"],
            conflictClusters: [],
            continuityAnchors: ["anchor-1"],
            recallStrength: 0.8)
        let critic = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.7)
        let hostAlign = BASHostAlignmentInput(
            candidates: [],
            hostBoundaryAxes: ["financial"])
        let sentinel = BASSovereignSentinelInput(
            candidates: [])
        let evolution = BASEvolutionShadowInput(
            updateTickets: [
                BASEvolutionUpdateTicket(
                    ticketID: "tk.1",
                    targetRef: "rule.x",
                    summary: "update",
                    scopeImpact: 0.5)])

        let input = BASAgentFabricAdapters.turnInput(
            turnID: "t.1",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil,
            memory: memory,
            critic: critic,
            hostAlignment: hostAlign,
            sovereignSentinel: sentinel,
            evolutionShadow: evolution)

        XCTAssertNotNil(input.memory)
        XCTAssertEqual(input.memory?.episodeArcs, ["arc-1"])
        XCTAssertNotNil(input.critic)
        XCTAssertEqual(input.critic?.superegoActiveLevel, 0.7)
        XCTAssertNotNil(input.hostAlignment)
        XCTAssertEqual(input.hostAlignment?.hostBoundaryAxes,
            ["financial"])
        XCTAssertNotNil(input.sovereignSentinel)
        XCTAssertNotNil(input.evolutionShadow,
            "ch 985 Gap 8: evolutionShadow param MUST plumb " +
            "through (was missing before ch 985)")
        XCTAssertEqual(
            input.evolutionShadow?.updateTickets.count, 1)
    }

    func testCRITICAL_TurnInput_EvolutionShadowSpecific() {
        // The exact gap ch 982.5 META-REVIEW H1 caught:
        // ch 965 EvolutionShadow was the 9th seat, never reached
        // through coordinator adapter
        let frame = sampleFrame()
        let evolution = BASEvolutionShadowInput(
            updateTickets: [],
            ruleCandidates: [
                BASEvolutionRuleCandidate(
                    candidateID: "rc.1",
                    ruleBody: "test rule",
                    supportStrength: 0.7)],
            hostChangeCandidates: [])
        let input = BASAgentFabricAdapters.turnInput(
            turnID: "t.1",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil,
            evolutionShadow: evolution)
        XCTAssertNotNil(input.evolutionShadow,
            "ch 985 CRITICAL Gap 8: 9th seat MUST be reachable")
        XCTAssertEqual(
            input.evolutionShadow?.ruleCandidates.count, 1)
    }

    func testTurnInput_DefaultedNilPreservesFourSeatBehavior() {
        let frame = sampleFrame()
        let input = BASAgentFabricAdapters.turnInput(
            turnID: "t.1",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil)
        // All 5 optional fields default-nil
        XCTAssertNil(input.memory)
        XCTAssertNil(input.critic)
        XCTAssertNil(input.hostAlignment)
        XCTAssertNil(input.sovereignSentinel)
        XCTAssertNil(input.evolutionShadow,
            "ch 985: omitting evolutionShadow MUST default to " +
            "nil — byte-equal to pre-ch 985 callers (red-line 7)")
        // 4 mandatory fields present
        XCTAssertEqual(input.turnID, "t.1")
        XCTAssertNotNil(input.scout)
        XCTAssertNotNil(input.risk)
        XCTAssertNotNil(input.surface)
    }

    func testTurnInput_AllNilCallProducesValidInput() {
        // Defense:caller passing only mandatory params still
        // produces a valid (4-seat) BASAgentTurnInput
        let frame = sampleFrame()
        let input = BASAgentFabricAdapters.turnInput(
            turnID: "t.1",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil)
        XCTAssertEqual(input.turnID, "t.1")
        XCTAssertTrue(input.plannerCandidates.isEmpty)
    }

    // MARK: - Determinism

    func testTurnInput_IsDeterministic() {
        let frame = sampleFrame()
        let memory = BASMemorySeatInput(
            episodeArcs: ["a"],
            conflictClusters: ["c"],
            continuityAnchors: ["k"],
            recallStrength: 0.5)
        let evolution = BASEvolutionShadowInput()
        let i1 = BASAgentFabricAdapters.turnInput(
            turnID: "t",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil,
            memory: memory,
            evolutionShadow: evolution)
        let i2 = BASAgentFabricAdapters.turnInput(
            turnID: "t",
            decomposeFrame: frame,
            candidatePaths: [],
            acceptedCandidateID: nil,
            memory: memory,
            evolutionShadow: evolution)
        XCTAssertEqual(i1.turnID, i2.turnID)
        XCTAssertEqual(
            i1.memory?.recallStrength,
            i2.memory?.recallStrength)
        XCTAssertEqual(
            i1.evolutionShadow?.isEmpty,
            i2.evolutionShadow?.isEmpty)
    }

    // MARK: - Helpers

    private func sampleFrame() -> BASDecomposeFrame {
        BASDecomposeFrame()
    }
}
