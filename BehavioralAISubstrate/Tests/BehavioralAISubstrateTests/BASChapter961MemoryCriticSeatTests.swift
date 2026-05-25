// MARK: - BASChapter961MemoryCriticSeatTests
// chapter 九百六十一 / M3510 — Phase 2 ch2 tests
//
// Tests for:
//   - BASMemorySeat (3 cluster types, recall-strength confidence)
//   - BASCriticSeat (6-rule critique ladder + severity scaling)
//   - BASAgentTurnRoster + BASAgentTurnInput backward compat with
//     nil Memory/Critic slots (4-seat callers still work)
//   - Dispatcher 6-seat mode (all 6 seats emit in canonical order)
//   - .critiqueField domain proves Single-Writer-Per-Domain holds
//     (Critic owns it, no overlap with Planner's candidateFrontier)

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter961MemoryCriticSeatTests: XCTestCase {

    // MARK: - Helpers

    private func memoryAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "memory.1",
            role: .memory,
            writeDomains: [.memoryBundle],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    private func criticAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "critic.1",
            role: .critic,
            writeDomains: [.critiqueField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    private func makeSixSeatRoster() -> BASAgentTurnRoster {
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
            memory: memoryAgent(),
            critic: criticAgent())
    }

    // MARK: - Memory seat

    func testMemory_EmptyInputZeroDeltas() {
        var seq = 0
        let d = BASMemorySeat.emit(
            from: BASMemorySeatInput(),
            turnID: "t1",
            agentSpec: memoryAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0)
        XCTAssertEqual(seq, 0)
    }

    func testMemory_EpisodeArcsOnlyEmitsOne() {
        var seq = 0
        let d = BASMemorySeat.emit(
            from: BASMemorySeatInput(
                episodeArcs: ["arc-1", "arc-2"],
                recallStrength: 0.6),
            turnID: "t1",
            agentSpec: memoryAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(
            d[0].targetObjectRef,
            "memoryBundle#episodes-t1")
        // 0.6 + 0.05*2 = 0.7
        XCTAssertEqual(d[0].confidence, 0.7, accuracy: 0.001)
        XCTAssertTrue(d[0].reasonCodes.contains("memory.episodes"))
    }

    func testMemory_AllThreeClustersEmitThree() {
        var seq = 0
        let d = BASMemorySeat.emit(
            from: BASMemorySeatInput(
                episodeArcs: ["a"],
                conflictClusters: ["c"],
                continuityAnchors: ["anchor"],
                recallStrength: 0.5),
            turnID: "t1",
            agentSpec: memoryAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 3)
        XCTAssertEqual(seq, 3)
        let refs = Set(d.map { $0.targetObjectRef })
        XCTAssertTrue(refs.contains(
            "memoryBundle#episodes-t1"))
        XCTAssertTrue(refs.contains(
            "memoryBundle#conflicts-t1"))
        XCTAssertTrue(refs.contains(
            "memoryBundle#anchors-t1"))
    }

    func testMemory_ConfidenceCappedAtOne() {
        var seq = 0
        let d = BASMemorySeat.emit(
            from: BASMemorySeatInput(
                conflictClusters: (1...10).map { "c\($0)" },
                recallStrength: 0.9),
            turnID: "t1",
            agentSpec: memoryAgent(),
            seq: &seq)
        // 0.9 + 0.1*10 = 1.9 → clamped to 1.0
        XCTAssertEqual(d[0].confidence, 1.0)
    }

    func testMemory_DeterministicPayloadSortedIDs() {
        var seq1 = 0, seq2 = 0
        let input = BASMemorySeatInput(
            episodeArcs: ["c", "a", "b"],
            recallStrength: 0.5)
        let d1 = BASMemorySeat.emit(
            from: input, turnID: "t1",
            agentSpec: memoryAgent(), seq: &seq1)
        let d2 = BASMemorySeat.emit(
            from: input, turnID: "t1",
            agentSpec: memoryAgent(), seq: &seq2)
        XCTAssertEqual(d1, d2)
        // IDs sorted in payload — ch 956.5 strong-mergeID invariance
        XCTAssertEqual(
            d1[0].patchJson,
            "{\"episode_arcs\":[\"a\",\"b\",\"c\"],\"count\":3}")
    }

    func testMemory_IsEmpty() {
        XCTAssertTrue(BASMemorySeatInput().isEmpty)
        XCTAssertFalse(BASMemorySeatInput(
            episodeArcs: ["a"]).isEmpty)
        XCTAssertFalse(BASMemorySeatInput(
            conflictClusters: ["c"]).isEmpty)
        XCTAssertFalse(BASMemorySeatInput(
            continuityAnchors: ["anchor"]).isEmpty)
        // recallStrength alone does NOT make it non-empty —
        // isEmpty only checks collection fields (no point
        // emitting a delta if there's no ID to reference)
        XCTAssertTrue(BASMemorySeatInput(
            recallStrength: 0.9).isEmpty,
            "ch 961: recallStrength alone is not enough — " +
            "isEmpty only checks collection fields")
    }

    // MARK: - Critic seat

    func testCritic_EmptyEmitsZero() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(),
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0)
    }

    func testCritic_CostFarExceedsBenefitIsSevere() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.1,
                    expectedCost: 0.5,  // 5× benefit
                    reversibility: 0.9)]),
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].confidence, 0.95)
        XCTAssertEqual(
            d[0].targetObjectRef,
            "critiqueField#cf-t1-c1")
        XCTAssertTrue(d[0].reasonCodes.contains(
            "critic.cost-far-exceeds-benefit"))
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"severe\""))
    }

    func testCritic_IrreversibleWeakUpsideIsSevere() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.3,  // < 0.5
                    expectedCost: 0.2,
                    reversibility: 0.1)]),  // < 0.2
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.95)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "critic.irreversible-weak-upside"))
    }

    func testCritic_CostExceedsBenefitIsStrong() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.3,
                    expectedCost: 0.4,  // cost > benefit but not 2×
                    reversibility: 0.8)]),
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.80)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"strong\""))
    }

    func testCritic_LowReversibilityIsStrong() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.8,
                    expectedCost: 0.3,
                    reversibility: 0.3)]),
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.80)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "critic.reversibility-low"))
    }

    func testCritic_StrictModeCostIsMild() {
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.9,
                    expectedCost: 0.6,
                    reversibility: 0.8)],
                superegoActiveLevel: 0.8),  // ≥ 0.7
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.60)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"mild\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "critic.strict-mode-cost"))
    }

    func testCritic_NoConcernEmitsZero() {
        // Cheap, reversible, benefit > cost, lax mode
        var seq = 0
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "Take a break",
                    expectedBenefit: 0.8,
                    expectedCost: 0.1,
                    reversibility: 0.95)],
                superegoActiveLevel: 0.3),  // not strict
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0,
            "ch 961: no concern → no delta emitted")
    }

    func testCritic_MultipleCandidatesOnlyConcerning() {
        var seq = 100
        let d = BASCriticSeat.emit(
            from: BASCriticSeatInput(candidates: [
                BASCriticCandidate(  // concern: cost > benefit
                    candidateID: "bad",
                    title: "t",
                    expectedBenefit: 0.3,
                    expectedCost: 0.5,
                    reversibility: 0.8),
                BASCriticCandidate(  // no concern
                    candidateID: "good",
                    title: "t",
                    expectedBenefit: 0.9,
                    expectedCost: 0.1,
                    reversibility: 0.9),
            ]),
            turnID: "t1",
            agentSpec: criticAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1,
            "ch 961: only concerning candidate gets a delta")
        XCTAssertEqual(d[0].targetObjectRef,
            "critiqueField#cf-t1-bad")
    }

    // MARK: - Backward compat (4-seat roster + nil Memory/Critic)

    func testRoster_FourSeatBackwardCompat() {
        // Existing 4-seat caller pattern still compiles + works
        let roster = BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "s", role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
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
                agentID: "su", role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high))
        XCTAssertNil(roster.memory)
        XCTAssertNil(roster.critic)
        XCTAssertEqual(roster.agentMap.count, 4)
    }

    func testInput_FourSeatBackwardCompat() {
        let input = BASAgentTurnInput(turnID: "t1")
        XCTAssertNil(input.memory)
        XCTAssertNil(input.critic)
    }

    // MARK: - 6-seat dispatcher end-to-end

    func testDispatcher_SixSeats_AllEmit() async {
        let roster = makeSixSeatRoster()
        let input = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["stress"]),
            plannerCandidates: [BASPlannerCandidate(
                candidateID: "c1",
                title: "t",
                actionSummary: "a",
                confidence: 0.8,
                reversibility: 0.9)],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.9)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-1"],
                recallStrength: 0.6),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.2,
                    expectedCost: 0.5,  // concern: cost>benefit
                    reversibility: 0.5)]))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Scout 1 + Planner 1 + Memory 1 + Critic 1 + Risk 1 + Surface 1 = 6
        XCTAssertEqual(result.emittedDeltas.count, 6,
            "ch 961: 6-seat full emission")
        XCTAssertEqual(
            result.mergeResult.acceptedDeltaIDs.count, 6,
            "ch 961: all 6 deltas accepted (different targets)")
        let objCount = await graph.objectCount()
        XCTAssertEqual(objCount, 6)
        // Verify each writer claimed its expected domain
        let critWriter = await graph.writerForDomain(
            .critiqueField)
        XCTAssertEqual(critWriter, "critic.1",
            "ch 961: Critic is sole writer of .critiqueField")
        let memWriter = await graph.writerForDomain(
            .memoryBundle)
        XCTAssertEqual(memWriter, "memory.1")
    }

    func testDispatcher_RosterHasMemoryButInputNil_Skips() async {
        let roster = makeSixSeatRoster()
        let input = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(),
            plannerCandidates: [],
            // memory NOT set
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.1,
                    expectedCost: 0.5,
                    reversibility: 0.5)]))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Critic emits 1 (concern) + Surface emits 1 (silentStub)
        // Memory skipped because input.memory == nil
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.agentID == "memory.1"
        }, "ch 961: nil memory input → no memory delta even " +
           "with roster slot set")
    }

    func testDispatcher_InputHasMemoryButRosterNil_Skips() async {
        // 4-seat roster but caller passes memory input → skip
        let roster = BASAgentTurnRoster(
            scout: makeSixSeatRoster().scout,
            planner: makeSixSeatRoster().planner,
            risk: makeSixSeatRoster().risk,
            surface: makeSixSeatRoster().surface)
        let input = BASAgentTurnInput(
            turnID: "t1",
            memory: BASMemorySeatInput(
                episodeArcs: ["a"],
                recallStrength: 0.6))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.targetObjectRef.contains("memoryBundle")
        })
    }

    // MARK: - Single-Writer-Per-Domain verification

    func testCriticDomainIsDistinctFromCandidateFrontier() {
        // Verify .critiqueField and .candidateFrontier are
        // distinct domains in the enum
        XCTAssertNotEqual(
            BASStateDomain.critiqueField,
            BASStateDomain.candidateFrontier)
        // Critic writes to .critiqueField, NOT .candidateFrontier
        let critic = criticAgent()
        XCTAssertTrue(critic.writeDomains.contains(.critiqueField))
        XCTAssertFalse(
            critic.writeDomains.contains(.candidateFrontier))
    }

    func testCriticCannotWriteCandidateFrontier() async {
        // Even if Critic tried to write candidateFrontier, the
        // graph actor rejects it (per ch 956.5 USER-PASS gap #1
        // Single-Writer enforcement)
        let critic = criticAgent()
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .candidateFrontier,
                objectID: "cf-1",
                payloadJson: "{}",
                byAgent: critic)
            XCTFail("ch 961: Critic write to .candidateFrontier " +
                "MUST be rejected by Single-Writer enforcement")
        } catch let e as BASSharedStateGraphError {
            guard case .unauthorizedWriter = e else {
                XCTFail("expected unauthorizedWriter,got \(e)")
                return
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
