import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASMemory
@testable import BASSovereign
@testable import BASPolicy

/// audit hostkit-rest HIGH-2 — the `.all`-tier watcher observation was built with critic:nil /
/// hostAlignment:nil HARDCODED (permanently blinding the axis/hostDrift watchers) and RAW
/// memory/sovereign/evolution inputs instead of the EFFECTIVE (seat-filtered) ones the turn ran
/// on — so memoryPollutionWatcher fired on a seat that had been filtered OUT (false L14 evidence).
final class BASAgentFabricWatcherObservationTests: XCTestCase {

    private func cands() -> [BASCandidatePath] {
        [BASCandidatePath(candidateID: "c1", title: "walk", actionSummary: "outside",
                          expectedBenefit: 0.7, expectedCost: 0.1, reversibility: 0.9, confidence: 0.8)]
    }
    private func triScores() -> [BASTriSelfScore] {
        [BASTriSelfScore(candidateID: "c1", idScore: 0.5, egoScore: 0.6,
                         superegoScore: 0.7, mergedScore: 0.6, veto: false)]
    }
    private func memory() -> BASMemorySeatInput {
        BASMemorySeatInput(episodeArcs: ["a"], conflictClusters: [],
                           continuityAnchors: ["c"], recallStrength: 0.7)
    }
    private func sovereign() -> BASSovereignSentinelInput {
        BASSovereignSentinelInput(candidates: [
            BASSovereignSentinelCandidate(candidateID: "c1", title: "t",
                                          reversibility: 0.5, touchesSovereignLockedAxis: false)])
    }
    private func evolution() -> BASEvolutionShadowInput {
        BASEvolutionShadowInput(updateTickets: [
            BASEvolutionUpdateTicket(ticketID: "tk1", targetRef: "r", summary: "s", scopeImpact: 0.3)])
    }

    func testFilteredOutSeatsDoNotReachTheWatcher() {
        // Every seat filtered out ⇒ the watcher must see NOTHING from them (no false-fire).
        let obs = BASAgentFabricHostPipeline.makeAllTierWatcherObservation(
            turnID: "t", candidatePaths: cands(),
            effectiveMemory: nil, effectiveTriScores: [],
            effectiveHostConstitution: nil, effectiveSovereignInput: nil,
            effectiveEvolutionInput: nil, emittedDeltas: [], nowNanos: 0)
        XCTAssertNil(obs.memory, "a filtered-out memory seat must NOT reach memoryPollutionWatcher")
        XCTAssertNil(obs.critic)
        XCTAssertNil(obs.hostAlignment)
        XCTAssertNil(obs.sovereignSentinel)
        XCTAssertNil(obs.evolutionShadow)
    }

    func testActiveSeatsBuildCriticAndHostAlignmentAndUseEffectiveInputs() {
        // All seats active ⇒ critic + hostAlignment are BUILT (were hardcoded nil = blind), and
        // memory/sovereign/evolution carry the effective inputs.
        let obs = BASAgentFabricHostPipeline.makeAllTierWatcherObservation(
            turnID: "t", candidatePaths: cands(),
            effectiveMemory: memory(), effectiveTriScores: triScores(),
            effectiveHostConstitution: BASHostConstitution(hostID: "u"),
            effectiveSovereignInput: sovereign(), effectiveEvolutionInput: evolution(),
            emittedDeltas: [], nowNanos: 0)
        XCTAssertNotNil(obs.critic,
            "triScores present ⇒ the critic input must be BUILT — the axis watcher was blind on nil")
        XCTAssertNotNil(obs.hostAlignment,
            "a constitution present ⇒ hostAlignment must be BUILT — the hostDrift watcher was blind on nil")
        XCTAssertNotNil(obs.memory)
        XCTAssertNotNil(obs.sovereignSentinel)
        XCTAssertNotNil(obs.evolutionShadow)
    }
}
