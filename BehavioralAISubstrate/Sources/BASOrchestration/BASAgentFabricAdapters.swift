// MARK: - BASAgentFabricAdapters
// chapter 九百六十 / M3505 — Phase 2 ch1:DTO adapters
//
// Pure-function adapters that convert existing per-turn types
// (BASDecomposeFrame from L7,BASCandidatePath from L9) into the
// slim DTOs the Agent Fabric seats consume。 Lives in
// BASOrchestration because that module already imports BASMemory
// (the reverse direction is a dep cycle per ch 957)。
//
// Per the ch 957 design comment:"Coordinator adapter (ch 958+)
// builds these DTOs from the live L7 / L9 outputs in one line"
// — this file delivers that one-line。
//
// Pure functions:no I/O,no actor isolation,trivially testable。

import Foundation
import BASMemory

public enum BASAgentFabricAdapters {

    /// Build a `BASScoutInput` from the L7 decompose frame。 Maps
    /// each signal cluster the Scout seat reads:pressure /
    /// manipulation / boundary / contradiction。
    public static func scoutInput(
        from frame: BASDecomposeFrame
    ) -> BASScoutInput {
        BASScoutInput(
            pressureSignals: frame.pressureSignals,
            pressureVectorCount: frame.pressureVectors.count,
            manipulationSignals: frame.manipulationSignals,
            manipulationPatternCount:
                frame.manipulationPatterns.count,
            boundaryTouchCount: frame.boundaryTouches.count,
            contradictionRecordCount:
                frame.contradictionRecords.count,
            bareContradictions: frame.contradictions)
    }

    /// Build `[BASPlannerCandidate]` from the L9 loopService
    /// output。 One DTO per candidate path,carrying only the
    /// fields the Planner seat needs。 No mutation of the
    /// original paths。
    public static func plannerCandidates(
        from paths: [BASCandidatePath]
    ) -> [BASPlannerCandidate] {
        paths.map { p in
            BASPlannerCandidate(
                candidateID: p.candidateID,
                title: p.title,
                actionSummary: p.actionSummary,
                confidence: p.confidence,
                expectedBenefit: p.expectedBenefit,
                expectedCost: p.expectedCost,
                reversibility: p.reversibility)
        }
    }

    /// Build a `BASRiskInput` from the L7 frame + candidate paths。
    /// The pressureLevel signal is derived from Scout's pressure-
    /// signal count (≥ 5 signals = high pressure 1.0;linear scale
    /// below)。 manipulation/boundary flags mirror Scout's cluster
    /// detection。
    public static func riskInput(
        from frame: BASDecomposeFrame,
        candidates: [BASCandidatePath]
    ) -> BASRiskInput {
        let scoutPressureCount =
            frame.pressureSignals.count +
            frame.pressureVectors.count
        // Linear pressure level:0 signals → 0.0,5+ signals → 1.0
        let pressureLevel = min(
            1.0, Double(scoutPressureCount) / 5.0)
        let manipulation =
            !frame.manipulationSignals.isEmpty ||
            !frame.manipulationPatterns.isEmpty
        let boundary = !frame.boundaryTouches.isEmpty
        let riskCandidates: [BASRiskCandidate] = candidates.map { p in
            BASRiskCandidate(
                candidateID: p.candidateID,
                reversibility: p.reversibility,
                expectedBenefit: p.expectedBenefit,
                expectedCost: p.expectedCost)
        }
        return BASRiskInput(
            candidates: riskCandidates,
            pressureLevel: pressureLevel,
            manipulationDetected: manipulation,
            boundaryTouched: boundary)
    }

    /// Build a `BASSurfaceInput` for observation-only mode (ch 960)。
    /// Defaults are SAFE — permit granted,no veto,low risk —
    /// because in observation mode the surface delta doesn't
    /// drive any UI;it's recorded for trace replay only。
    /// Future fabric-authoritative mode (ch 961+) will derive
    /// these from the live risk gate + sovereign sentinel state。
    public static func surfaceInputObservationMode(
        acceptedCandidateID: String?,
        riskBand: BASRiskAssessmentBand = .low
    ) -> BASSurfaceInput {
        BASSurfaceInput(
            acceptedCandidateID: acceptedCandidateID,
            actionPermitGranted: true,
            riskBand: riskBand,
            reversibility: 1.0,
            sovereignVetoed: false,
            userRequestsCompare: false)
    }

    /// Build a complete `BASAgentTurnInput` from L7/L9 outputs +
    /// turn metadata。 Convenience over the per-seat adapters。
    /// `acceptedCandidateID` is typically the L9 winner's id (or
    /// nil for turns with no candidate)。
    ///
    /// chapter 九百六十四.5 USER-PASS-5 D2 fix:added optional
    /// `memory`,`critic`,`hostAlignment`,`sovereignSentinel`
    /// parameters。 Previously the coordinator's
    /// `runAgentFabricObservation` could only wire 4 seats —
    /// Memory/Critic/HostAlign/Sovereign were unreachable through
    /// the coordinator even when their roster slots were set。
    /// Now coordinators can pass pre-built DTOs from their L8/
    /// triSelf/host-constitution/sovereign-state adapters。
    /// Defaulted nil preserves prior 4-seat caller compat。
    ///
    /// chapter 九百八十五 / M3630 — Cross-Module Integration Arc ch3:
    /// added optional `evolutionShadow` parameter,closing
    /// ch 982.5 META-REVIEW Gap 8。 Before this chapter the
    /// 9th seat (ch 965 EvolutionShadow) was unreachable
    /// through coordinator adapter even when its roster slot
    /// was set。 Defaulted nil preserves all prior callers
    /// byte-equal。
    public static func turnInput(
        turnID: String,
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String?,
        memory: BASMemorySeatInput? = nil,
        critic: BASCriticSeatInput? = nil,
        hostAlignment: BASHostAlignmentInput? = nil,
        sovereignSentinel:
            BASSovereignSentinelInput? = nil,
        evolutionShadow:
            BASEvolutionShadowInput? = nil,
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) -> BASAgentTurnInput {
        BASAgentTurnInput(
            turnID: turnID,
            scout: scoutInput(from: decomposeFrame),
            plannerCandidates: plannerCandidates(
                from: candidatePaths),
            risk: riskInput(
                from: decomposeFrame,
                candidates: candidatePaths),
            surface: surfaceInputObservationMode(
                acceptedCandidateID: acceptedCandidateID),
            memory: memory,
            critic: critic,
            hostAlignment: hostAlignment,
            sovereignSentinel: sovereignSentinel,
            evolutionShadow: evolutionShadow,
            priorityContext: priorityContext,
            nowNanos: nowNanos)
    }

    /// Build a `BASCriticSeatInput` from candidate paths + a
    /// caller-supplied superego activity level。 Maps 1:1 from
    /// `BASCandidatePath` benefit/cost/reversibility to
    /// `BASCriticCandidate` fields。
    public static func criticInput(
        from paths: [BASCandidatePath],
        superegoActiveLevel: Double = 0.5
    ) -> BASCriticSeatInput {
        BASCriticSeatInput(
            candidates: paths.map { p in
                BASCriticCandidate(
                    candidateID: p.candidateID,
                    title: p.title,
                    expectedBenefit: p.expectedBenefit,
                    expectedCost: p.expectedCost,
                    reversibility: p.reversibility)
            },
            superegoActiveLevel: superegoActiveLevel)
    }
}
