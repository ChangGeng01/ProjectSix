// MARK: - BASAgentFabricFuzzScenarios
// chapter 九百六十二 / M3515 — Phase 2 close:procedural fuzz
//
// Per ch 952.2 BASFuzzInputGenerator pattern + plan Phase 2 close
// goal "fuzz harness extension for Memory/Critic interactions":
// canonical adversarial scenarios that exercise the full 9-seat
// dispatcher under realistic + edge inputs。
//
// chapter 九百六十四.5 USER-PASS-5 C3+D4 fix:was "6-seat" — ch 963
// added HostAlignment + ch 964 added SovereignSentinel,but this
// file's roster + scenarios never extended,leaving the new seats
// with ZERO adversarial coverage despite being load-bearing。
// Now `standardRoster()` includes all 8 + new scenarios exercise
// the sovereign-axis-lockdown + multi-axis-boundary paths。
//
// chapter 九百八十二.5 META-REVIEW H1 fix:was "8-seat" — ch 965
// added EvolutionShadow as the 9th seat,but this file's roster +
// scenarios were never extended,leaving the shadow seat with ZERO
// adversarial coverage despite being load-bearing for the
// never-effective-same-turn invariant。 Now `standardRoster()`
// includes all 9 + a new `evolutionShadowProposalsTurn` scenario
// exercises the 3-cluster proposal path (tickets + rules +
// host-change candidates),and `allSignalsActiveTurn` includes a
// non-empty evolutionShadow input。
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

    /// Common roster used by all scenarios。 chapter 九百六十四.5
    /// USER-PASS-5 C3 fix:was 6-seat — extended to 8 to
    /// cover ch 963 HostAlignment + ch 964 SovereignSentinel。
    /// chapter 九百八十二.5 META-REVIEW H1 fix:now 9-seat — adds
    /// ch 965 EvolutionShadow which was missed during cascade。
    /// All writers distinct per Single-Writer-Per-Domain。
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
                writeDomain: .critiqueField),
            hostAlignment: BASAgentSpec(
                agentID: "fuzz.hostalign",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
            sovereignSentinel: BASAgentSpec(
                agentID: "fuzz.sentinel",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
            // chapter 九百八十二.5 META-REVIEW H1:9th seat。 The
            // shadow agent ONLY writes `.evolutionProposal` — never
            // `.hostVersion`,never `.sovereignVerdict`。 The graph
            // applier enforces this at write time。 LeaseProfile
            // `.coldSeat` matches ch 965 EvolutionShadow tests since
            // the shadow is debounced / slow per design。
            evolutionShadow: BASAgentSpec(
                agentID: "fuzz.evolution",
                role: .evolutionShadow,
                writeDomains: [.evolutionProposal],
                defaultLeaseProfile: .coldSeat,
                visibility: .medium))
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
            candidateID: "safe1",
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
                    candidateID: "safe1",
                    reversibility: 1.0,
                    expectedBenefit: 0.7,
                    expectedCost: 0.05)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "safe1",
                riskBand: .low,
                reversibility: 1.0),
            critic: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "safe1",
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
            candidateID: "manip1",
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
                    candidateID: "manip1",
                    reversibility: 0.3,
                    expectedBenefit: 0.4,
                    expectedCost: 0.3)],
                manipulationDetected: true),
            // Surface ALSO sees high risk (from prior Risk pass
            // or external signal)
            surface: BASSurfaceInput(
                acceptedCandidateID: "manip1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.3))
    }

    /// Adversarial:cost > 2× benefit + low reversibility →
    /// Critic flags SEVERE。
    public static func irreversibleHighStakesTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "highstakes1",
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
                    candidateID: "highstakes1",
                    reversibility: 0.05,
                    expectedBenefit: 0.1,
                    expectedCost: 0.8)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "highstakes1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.05),
            critic: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "highstakes1",
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
                candidateID: "csev1",
                title: "drastic-1",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.1,
                expectedCost: 0.5,
                reversibility: 0.5),
            BASPlannerCandidate(  // SEVERE: irrev + weak benefit
                candidateID: "csev2",
                title: "drastic-2",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.3,
                expectedCost: 0.2,
                reversibility: 0.1),
            BASPlannerCandidate(  // STRONG: cost > benefit
                candidateID: "cstrong",
                title: "moderate-bad",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.3,
                expectedCost: 0.4,
                reversibility: 0.8),
            BASPlannerCandidate(  // STRONG: low reversibility
                candidateID: "cstrong2",
                title: "irrev-mid",
                actionSummary: "a",
                confidence: 0.5,
                expectedBenefit: 0.6,
                expectedCost: 0.3,
                reversibility: 0.3),
            BASPlannerCandidate(  // NONE: safe baseline
                candidateID: "csafe",
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
                acceptedCandidateID: "csafe",
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
            candidateID: "recall1",
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
                    candidateID: "recall1",
                    reversibility: 0.8)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "recall1",
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
                    candidateID: "recall1",
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
            candidateID: "mild1",
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
                    candidateID: "mild1",
                    reversibility: 0.9)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "mild1",
                riskBand: .low,
                reversibility: 0.9),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "mild1",
                    title: "Moderate-cost",
                    expectedBenefit: 0.9,
                    expectedCost: 0.6,
                    reversibility: 0.9)],
                superegoActiveLevel: 0.8))  // ≥0.7 strict
    }

    /// chapter 九百六十四.5 NEW:host-alignment multi-axis turn —
    /// candidate touches 2+ host boundary axes → HostAlignment
    /// emits MULTI_AXIS_TOUCH severity。 Tests the ch 963 path。
    public static func hostAlignmentMultiAxisTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "halign1",
            title: "Touches multiple values",
            actionSummary: "a",
            confidence: 0.7,
            expectedBenefit: 0.5,
            expectedCost: 0.3,
            reversibility: 0.7)
        return BASAgentTurnInput(
            turnID: "fuzz.halign",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "halign1",
                    reversibility: 0.7)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "halign1",
                riskBand: .low,
                reversibility: 0.7),
            hostAlignment: BASHostAlignmentInput(
                candidates: [BASHostAlignmentCandidate(
                    candidateID: "halign1",
                    title: "Multi-axis touch",
                    touchesAxes: [
                        "financial",
                        "relational",
                        "privacy",
                    ])],
                hostBoundaryAxes: [
                    "financial",
                    "relational",
                    "privacy",
                ]))
    }

    /// chapter 九百六十四.5 NEW:sovereign-axis lockdown turn —
    /// candidate touches a sovereign-locked axis → Sentinel emits
    /// LOCKDOWN severity + a turn-level LOCKDOWN delta。 Tests
    /// the ch 964 most-critical path。
    public static func sovereignAxisLockdownTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "sov1",
            title: "Mutates host constitution",
            actionSummary: "edit host values",
            confidence: 0.5,
            expectedBenefit: 0.2,
            expectedCost: 0.6,
            reversibility: 0.1)
        return BASAgentTurnInput(
            turnID: "fuzz.sovereign",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "sov1",
                    reversibility: 0.1)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "sov1",
                actionPermitGranted: true,
                riskBand: .high,
                reversibility: 0.1),
            sovereignSentinel:
                BASSovereignSentinelInput(
                    candidates: [
                        BASSovereignSentinelCandidate(
                            candidateID: "sov1",
                            title: "Mutates host",
                            reversibility: 0.1,
                            touchesSovereignLockedAxis:
                                true)]))
    }

    /// chapter 九百八十二.5 META-REVIEW H1 NEW:evolution-shadow
    /// proposal cluster — 1 update ticket + 1 rule candidate +
    /// 1 host-change candidate。 Tests the ch 965 3-cluster
    /// emission path + never-effective-same-turn invariant
    /// (deltas land in `.evolutionProposal` only,never
    /// `.hostVersion`)。
    public static func evolutionShadowProposalsTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "evo1",
            title: "ordinary candidate",
            actionSummary: "a",
            confidence: 0.6,
            expectedBenefit: 0.5,
            expectedCost: 0.3,
            reversibility: 0.7)
        return BASAgentTurnInput(
            turnID: "fuzz.evolution",
            plannerCandidates: [cand],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "evo1",
                    reversibility: 0.7)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "evo1",
                riskBand: .low,
                reversibility: 0.7),
            evolutionShadow: BASEvolutionShadowInput(
                updateTickets: [
                    BASEvolutionUpdateTicket(
                        ticketID: "tk1",
                        targetRef: "rule.skepticism.floor",
                        summary: "raise floor by 0.05",
                        scopeImpact: 0.4)],
                ruleCandidates: [
                    BASEvolutionRuleCandidate(
                        candidateID: "rc1",
                        ruleBody:
                            "if pressure>0.7 then guard.bias+=0.2",
                        supportStrength: 0.65)],
                hostChangeCandidates: [
                    BASEvolutionHostChangeCandidate(
                        candidateID: "hc1",
                        targetAxis: "valueAxis.balance",
                        proposedSummary:
                            "loosen by 0.03 toward exploration",
                        directionScore: 0.3)]))
    }

    /// Stress:every signal active simultaneously,now including
    /// HostAlignment + Sovereign per ch 964.5 fix +
    /// EvolutionShadow per ch 九百八十二.5 META-REVIEW H1。 Tests
    /// that the full 9-seat dispatcher handles maximum input
    /// without crashing,deterministically,with sensible
    /// aggregation。
    public static func allSignalsActiveTurn(
    ) -> BASAgentTurnInput {
        let cand = BASPlannerCandidate(
            candidateID: "all1",
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
                    candidateID: "all1",
                    reversibility: 0.3,
                    expectedBenefit: 0.4,
                    expectedCost: 0.5)],
                pressureLevel: 1.0,
                manipulationDetected: true,
                boundaryTouched: true),
            surface: BASSurfaceInput(
                acceptedCandidateID: "all1",
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
                    candidateID: "all1",
                    title: "Stress",
                    expectedBenefit: 0.4,
                    expectedCost: 0.5,
                    reversibility: 0.3)],
                superegoActiveLevel: 0.9),
            // chapter 九百六十四.5 USER-PASS-5 C3 fix:add
            // HostAlign + Sovereign inputs so the all-active
            // scenario actually exercises all 8 seats
            hostAlignment: BASHostAlignmentInput(
                candidates: [BASHostAlignmentCandidate(
                    candidateID: "all1",
                    title: "Stress",
                    touchesAxes: [
                        "financial",
                        "privacy",
                    ])],
                hostBoundaryAxes: [
                    "financial",
                    "privacy",
                ],
                styleStrictness: 0.85),
            sovereignSentinel:
                BASSovereignSentinelInput(
                    candidates: [
                        BASSovereignSentinelCandidate(
                            candidateID: "all1",
                            title: "Stress",
                            reversibility: 0.3,
                            touchesAxesCount: 2,
                            touchesSovereignLockedAxis:
                                false)],
                    manipulationDetected: true,
                    boundaryTouched: true,
                    heightenedProtection: true),
            // chapter 九百八十二.5 META-REVIEW H1:include the 9th
            // seat's input。 Without this the "all signals active"
            // scenario was misnamed since ch 965。 Minimal cluster
            // (1 ticket only) keeps the scenario stable for any
            // existing tests that pin delta counts but exercises
            // the EvolutionShadow path under stress aggregation。
            evolutionShadow: BASEvolutionShadowInput(
                updateTickets: [
                    BASEvolutionUpdateTicket(
                        ticketID: "all-tk1",
                        targetRef: "rule.stress.aggregation",
                        summary: "stress-test entry",
                        scopeImpact: 0.5)]))
    }
}
