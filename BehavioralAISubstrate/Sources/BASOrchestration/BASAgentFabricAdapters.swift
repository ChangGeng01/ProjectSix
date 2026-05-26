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
import BASPolicy

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

    // MARK: - chapter 九百八十六 / M3635 — Cross-Module Integration
    //                                       Arc ch4:Gap 1 close
    //
    // BASHostAlignmentInput from live BASHostConstitution。 Was:
    // `BASHostAlignmentSeat` had a free-form `hostConstraintsRef`
    // String parameter — caller could pass any string,no validation,
    // no actual coupling to the host's live L5 constitution。 Per
    // ch 982.5 META-REVIEW Gap 1,this meant the fabric's host-
    // alignment seat was orthogonal to the live host constitution
    // — a major design intent violation。
    //
    // This adapter closes the gap:given a live `BASHostConstitution`
    // (already available on the coordinator),build a
    // `BASHostAlignmentInput` that:
    //   - Derives `hostBoundaryAxes` from the union of
    //     `valueAxes.axes` + `boundaryVeil.hardNoGo` (the two
    //     fields that ARE the user's host-level "what's protected"
    //     declarations per the L5 whitepaper)
    //   - Pulls `hostID` directly from the constitution
    //   - Derives `styleStrictness` from `styleGenome.structureBias`
    //     (higher structureBias → stricter alignment) unless caller
    //     overrides (host may have a more nuanced computed measure)
    //   - Accepts caller-supplied `candidates` since the fabric
    //     doesn't yet know which axes each candidate touches —
    //     that semantic mapping is host-app responsibility
    //
    // Deterministic:`hostBoundaryAxes` sorted lex so two calls
    // with the same constitution produce byte-equal output。

    // MARK: - chapter 九百八十七 / M3640 — Cross-Module Integration
    //                                       Arc ch5:Gap 3 close
    //
    // Enrich BASRiskInput from a live BASRiskCard。 Was:
    // `BASRiskSeat` consumed `BASRiskInput.pressureLevel /
    // manipulationDetected / boundaryTouched` derived ONLY from
    // L7 Scout output — completely orthogonal to the host's live
    // `BASRiskServicing.calibrateRisk(...)` which produces a
    // `BASRiskCard` with totalRisk / uncertainty / irreversibility
    // / manipulationStrength / gsiScore。 Per ch 982.5 META-REVIEW
    // Gap 3,this meant the substrate had TWO PARALLEL risk
    // computations:the existing host risk service (L11) AND the
    // fabric's risk seat,with no path connecting them。
    //
    // This adapter closes the gap:given a `BASRiskCard` produced
    // by the live risk service,enrich an existing `BASRiskInput`:
    //   - `pressureLevel` is RAISED (max) to the card's totalRisk
    //     value。 Per ch 967 monotonic-raise discipline,risk
    //     CANNOT be lowered by enrichment。
    //   - `manipulationDetected` is OR-ed with the card's
    //     manipulationStrength >= 0.5 trigger
    //   - `boundaryTouched` is preserved as-is (the card doesn't
    //     have a direct "boundary touched" signal — that signal
    //     comes from L7 Scout's boundaryTouchCount per ch 957
    //     design,which already feeds the base input)
    //   - candidates pass through unchanged
    //
    // Per Root Law 4 (单主权) + ch 967 monotonic raise — the
    // adapter NEVER reduces risk。 Enrichment is union not
    // intersection。

    /// Enrich a `BASRiskInput` with signals from a live
    /// `BASRiskCard`。 Closes ch 982.5 META-REVIEW Gap 3
    /// (fabric risk seat orthogonal to live BASRiskServicing)。
    ///
    /// Monotonic raise discipline:
    ///   - `pressureLevel` only goes UP (max of input + card)
    ///   - `manipulationDetected` only flips ON (input || card-signal)
    ///   - `boundaryTouched` unchanged (signal source is L7 Scout)
    ///
    /// - Parameters:
    ///   - card: live `BASRiskCard` from `BASRiskServicing
    ///     .calibrateRisk(...)`
    ///   - baseRiskInput: existing `BASRiskInput` built by
    ///     `riskInput(from:candidates:)` from L7 decompose output
    /// - Returns: enriched `BASRiskInput` with the union of
    ///   risk signals
    public static func enrichRiskInput(
        from card: BASRiskCard,
        baseRiskInput: BASRiskInput
    ) -> BASRiskInput {
        // Monotonic raise:risk only goes UP per ch 967。
        let mergedPressure = max(
            baseRiskInput.pressureLevel,
            max(0.0, min(1.0, card.totalRisk)))
        // Card's manipulationStrength >= 0.5 considered triggering。
        let cardManipulationTrigger =
            card.manipulationStrength >= 0.5
        let mergedManipulation =
            baseRiskInput.manipulationDetected ||
            cardManipulationTrigger
        return BASRiskInput(
            candidates: baseRiskInput.candidates,
            pressureLevel: mergedPressure,
            manipulationDetected: mergedManipulation,
            boundaryTouched: baseRiskInput.boundaryTouched)
    }

    /// Build a `BASHostAlignmentInput` from a live
    /// `BASHostConstitution`。 Closes ch 982.5 META-REVIEW Gap 1
    /// (host alignment seat orthogonal to live host constitution)。
    ///
    /// - Parameters:
    ///   - constitution: live L5 host constitution from the
    ///     coordinator's `hostConstitution` slot
    ///   - candidates: per-turn candidates with their axis touches
    ///     (caller computes since axis-touch is host-app
    ///     semantics)
    ///   - styleStrictnessOverride: if non-nil,used instead of
    ///     the derived `styleGenome.structureBias` value
    /// - Returns: well-formed `BASHostAlignmentInput`
    public static func hostAlignmentInput(
        from constitution: BASHostConstitution,
        candidates: [BASHostAlignmentCandidate] = [],
        styleStrictnessOverride: Double? = nil
    ) -> BASHostAlignmentInput {
        // Boundary axes = union of valueAxes.axes + boundaryVeil
        // .hardNoGo,sorted lex for determinism。 Per L5 whitepaper
        // §6 these are the two distinct "what's protected"
        // declarations:valueAxes carries the host's articulated
        // value structure;boundaryVeil.hardNoGo is the explicit
        // never-cross list。 Both qualify as alignment-significant
        // axes per ch 963 design intent。
        let unionAxes = Set(
            constitution.valueAxes.axes +
            constitution.boundaryVeil.hardNoGo)
        let boundaryAxes = Array(unionAxes).sorted()
        // styleStrictness derived from structureBias which is
        // already in [0.0, 1.0] per BASStyleGenome contract。
        // Defensive clamp anyway。
        let derivedStrictness = max(0.0, min(1.0,
            constitution.styleGenome.structureBias))
        let strictness =
            styleStrictnessOverride ?? derivedStrictness
        return BASHostAlignmentInput(
            candidates: candidates,
            hostBoundaryAxes: boundaryAxes,
            styleStrictness: max(0.0, min(1.0, strictness)),
            hostID: constitution.hostID)
    }
}
