// MARK: - BASAgentFabricFuzzScenarios
// chapter 九百六十二 / M3515 — Phase 2 close:procedural fuzz
//
// Per ch 952.2 BASFuzzInputGenerator pattern + plan Phase 2 close
// goal "fuzz harness extension for Memory/Critic interactions":
// canonical adversarial scenarios that exercise the full 6-seat
// dispatcher under realistic + edge inputs。
//
// Each scenario is a fully-formed `BASAgentTurnInput`。 Tests can
// call `BASAgentTurnDispatcher.dispatch(...)` with these and assert
// invariants (no-crash,deterministic mergeID,expected
// evidence-debt aggregation,等)。
//
// Per ch 956.5 strong-mergeID hash invariance:these scenarios are
// SEEDED + DETERMINISTIC。 Same call → same input → same dispatcher
// output。 Tests can pin specific mergeIDs across runs if needed。
//
// ## Scenario list
//
//   - `cleanLowRiskTurn` — happy path,no concerns,low pressure
//   - `manipulationDetectedTurn` — Scout flags manipulation,
//     Risk MUST elevate to HIGH,Surface MUST block
//   - `irreversibleHighStakesTurn` — Critic surfaces severe
//     concern (cost > 2× benefit + low reversibility)
//   - `multiCandidateCriticCascadeTurn` — 5 candidates with
//     mixed severity → aggregate-pressure non-trivial
//   - `memoryConflictRecallTurn` — Memory surfaces conflict
//     clusters from prior turn (signals next-turn caution)
//   - `strictSuperegoMildBumpTurn` — borderline candidate +
//     high superego level → MILD critique appears
//   - `allSignalsActiveTurn` — pressure+manipulation+boundary+
//     conflicts+strict-mode — stress test for full cascade

import Foundation

public enum BASAgentFabricFuzzScenarios {

    /// Common roster used by all scenarios。 Hot-seat hot-seat,
    /// all writers distinct per Single-Writer。
    public static func standardRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: makeAgent(
                id: "fuzz.scout", role: .scout,
                writeDomain: .situationField),
            planner: makeAgent(
                id: "fuzz.planner", role: .planner,
                writeDomain: .candidateFrontier),
            risk: makeAgent(
                id: "fuzz.risk", role: .risk,
                writeDomain: .riskField),
            surface: makeAgent(
                id: "fuzz.surface", role: .surface,
                writeDomain: .renderFrame),
            memory: makeAgent(
                id: "fuzz.memory", role: .memory,
                writeDomain: .memoryBundle),
            critic: makeAgent(
                id: "fuzz.critic", role: .critic,
                writeDomain: .critiqueField))
    }

    private static func makeAgent(
        id: String,
        role: BASAgentRole,
        writeDomain: BASStateDomain
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id,
            role: role,
            writeDomains: [writeDomain],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    // MARK: - Scenario constructors

    /// Clean baseline:safe candidate,no manipulation,no
    /// concerns。 Expected: 4 deltas (scout=0, planner=1,
    /// memory=0, critic=0, risk=1, surface=1)。 No,wait —
    /// scout 0 if no signals。 So: 1 planner + 1 risk + 1 surface
    /// = 3 deltas total。
    public static func cleanLowRiskTurn() -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "safe-1",
            title: "Take a 5-min walk",
            actionSummary: "step outside briefly",
            confidence: 0.85,
            expectedBenefit: 0.7,
            expectedCost: 0.05,
            reversibility: 1.0)
        return BASAgentTurnInput(
            turnID: "fuzz.clean",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "safe-1",
                    reversibility: 1.0,
                    expectedBenefit: 0.7,
                    expectedCost: 0.05)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "safe-1",
                riskBand: .low,
                reversibility: 1.0),
            critic: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "safe-1",
                    title: "Take a 5-min walk",
                    expectedBenefit: 0.7,
                    expectedCost: 0.05,
                    reversibility: 1.0)]))
    }

    /// Adversarial:manipulation detected → Risk elevates HIGH →
    /// Surface MUST block (assuming default permit granted)。
    public static func manipulationDetectedTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "manip-1",
            title: "User asks for retraction",
            actionSummary: "withdraw last message",
            confidence: 0.6,
            expectedBenefit: 0.4,
            expectedCost: 0.3,
            reversibility: 0.3)  // irreversible
        return BASAgentTurnInput(
            turnID: "fuzz.manipulation",
            scout: BASScoutInput(
                manipulationSignals: [
                    "guilt.trip",
                    "authority.appeal",
                ],
                manipulationPatternCount: 1),
            plannerCandidates: [cand],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "manip-1",
                    reversibility: 0.3,
                    expectedBenefit: 0.4,
                    expectedCost: 0.3)],
                manipulationDetected: true),
            // Surface ALSO sees high risk (from prior Risk pass
            // or external signal)
            surface: BASSurfaceInput(
                acceptedCandidateID: "manip-1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.3))
    }

    /// Adversarial:cost > 2× benefit + low reversibility →
    /// Critic flags SEVERE。
    public static func irreversibleHighStakesTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "highstakes-1",
            title: "Delete account",
            actionSummary: "permanent removal",
            confidence: 0.4,
            expectedBenefit: 0.1,
            expectedCost: 0.8,  // 8× benefit
            reversibility: 0.05)  // essentially irreversible
        return BASAgentTurnInput(
            turnID: "fuzz.highstakes",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "highstakes-1",
                    reversibility: 0.05,
                    expectedBenefit: 0.1,
                    expectedCost: 0.8)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "highstakes-1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.05),
            critic: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "highstakes-1",
                    title: "Delete account",
                    expectedBenefit: 0.1,
                    expectedCost: 0.8,
                    reversibility: 0.05)]))
    }

    /// Stress:5 candidates with mixed severity profiles。
    /// Tests evidence-debt aggregation。
    public static func multiCandidateCriticCascadeTurn(
    ) -> BASAgentTurnInput {
        let plannerCands: [BASPlannerCandidate] = [
            BASPlannerCandidate(  // SEVERE: cost > 2× benefit
                candidateID: "c-sev1",
                title: "drastic-1",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.1,
                expectedCost: 0.5,
                reversibility: 0.5),
            BASPlannerCandidate(  // SEVERE: irrev + weak benefit
                candidateID: "c-sev2",
                title: "drastic-2",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.3,
                expectedCost: 0.2,
                reversibility: 0.1),
            BASPlannerCandidate(  // STRONG: cost > benefit
                candidateID: "c-strong",
                title: "moderate-bad",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.3,
                expectedCost: 0.4,
                reversibility: 0.8),
            BASPlannerCandidate(  // STRONG: low reversibility
                candidateID: "c-strong2",
                title: "irrev-mid",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.6,
                expectedCost: 0.3,
                reversibility: 0.3),
            BASPlannerCandidate(  // NONE: safe baseline
                candidateID: "c-safe",
                title: "easy-win",
                actionSummary: "a",
                confidence: 0.85,
                expectedBenefit: 0.9,
                expectedCost: 0.05,
                reversibility: 0.95),
        ]
        let criticCands = plannerCands.map {
            BASCriticCandidate(
                candidateID: $0.candidateID,
                title: $0.title,
                expectedBenefit: $0.expectedBenefit,
                expectedCost: $0.expectedCost,
                reversibility: $0.reversibility)
        }
        let riskCands = plannerCands.map {
            BASRiskCandidate(
                candidateID: $0.candidateID,
                reversibility: $0.reversibility,
                expectedBenefit: $0.expectedBenefit,
                expectedCost: $0.expectedCost)
        }
        return BASAgentTurnInput(
            turnID: "fuzz.cascade",
            plannerCandidates: plannerCands,
            risk: BASRiskInput(candidates: riskCands),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c-safe",
                riskBand: .low,
                reversibility: 0.95),
            critic: BASCriticSeatInput(
                candidates: criticCands))
    }

    /// Memory surfaces a conflict cluster from prior turn —
    /// signal for next-turn Planner caution。
    public static func memoryConflictRecallTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "recall-1",
            title: "Similar to prior failure",
            actionSummary: "try the same approach again",
            confidence: 0.55,
            expectedBenefit: 0.5,
            expectedCost: 0.3,
            reversibility: 0.8)
        return BASAgentTurnInput(
            turnID: "fuzz.recall",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "recall-1",
                    reversibility: 0.8)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "recall-1",
                riskBand: .low,
                reversibility: 0.8),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-2023-08"],
                conflictClusters: [
                    "cluster.prior-rejection-A",
                    "cluster.boundary-touched-B",
                ],
                continuityAnchors: ["anchor.user-pref-X"],
                recallStrength: 0.85),
            critic: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "recall-1",
                    title: "Similar to prior failure",
                    expectedBenefit: 0.5,
                    expectedCost: 0.3,
                    reversibility: 0.8)]))
    }

    /// Border-case:strict superego + moderately costly candidate
    /// → MILD critique appears (would not for relaxed superego)。
    public static func strictSuperegoMildBumpTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "mild-1",
            title: "Moderate-cost action",
            actionSummary: "a",
            confidence: 0.7,
            expectedBenefit: 0.9,
            expectedCost: 0.6,  // > 0.5 trigger
            reversibility: 0.9)
        return BASAgentTurnInput(
            turnID: "fuzz.strict",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "mild-1",
                    reversibility: 0.9)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "mild-1",
                riskBand: .low,
                reversibility: 0.9),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "mild-1",
                    title: "Moderate-cost",
                    expectedBenefit: 0.9,
                    expectedCost: 0.6,
                    reversibility: 0.9)],
                superegoActiveLevel: 0.8))  // ≥0.7 strict
    }

    /// Stress:every signal active simultaneously。 Tests that
    /// the full 6-seat dispatcher handles maximum input without
    /// crashing,deterministically,with sensible aggregation。
    public static func allSignalsActiveTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "all-1",
            title: "Stress test",
            actionSummary: "a",
            confidence: 0.5,
            expectedBenefit: 0.4,
            expectedCost: 0.5,
            reversibility: 0.3)
        return BASAgentTurnInput(
            turnID: "fuzz.all-active",
            scout: BASScoutInput(
                pressureSignals: ["a", "b", "c"],
                pressureVectorCount: 2,
                manipulationSignals: ["m1"],
                manipulationPatternCount: 1,
                boundaryTouchCount: 1,
                contradictionRecordCount: 2,
                bareContradictions: ["x", "y"]),
            plannerCandidates: [cand],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "all-1",
                    reversibility: 0.3,
                    expectedBenefit: 0.4,
                    expectedCost: 0.5)],
                pressureLevel: 1.0,
                manipulationDetected: true,
                boundaryTouched: true),
            surface: BASSurfaceInput(
                acceptedCandidateID: "all-1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.3),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-1"],
                conflictClusters: ["cluster-1", "cluster-2"],
                continuityAnchors: ["anchor-1"],
                recallStrength: 0.8),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "all-1",
                    title: "Stress",
                    expectedBenefit: 0.4,
                    expectedCost: 0.5,
                    reversibility: 0.3)],
                superegoActiveLevel: 0.9))
    }
}
