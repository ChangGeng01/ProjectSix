// MARK: - BASMLTriSelfService
// REAL Layer-4 tri-self service deriving id/ego/superego
// scores from L3 loop candidate fields。 Fifth active
// ML-touched layer in the cognitive cascade。
//
// The tri-self service implements a Freudian-inspired
// "three voices" arbitration:
//   - id      — impulse / desire / "what does the user
//               want?"。 Aligned with candidate's
//               confidence in the user's expressed need。
//   - ego     — reality / pragmatism / "what's feasible?"。
//               Aligned with candidate's expectedBenefit
//               minus expectedCost。
//   - superego — morality / safety / "what should we do?"。
//                Aligned with candidate's reversibility
//                (safer = more reversible = more right)。
//
// The placeholder emitted neutral 0.5 across all three
// voices for every candidate。 This service derives
// each voice from real signals threaded up from L0 →
// L2 → L3。
//
// **Merged choice selection**: picks the candidate with
// the highest mergedScore that isn't veto'd。 The
// merged score is a weighted average of the three voices
// (each voice contributes 1/3)。 A candidate is veto'd
// when its superegoScore falls below the named
// vetoThreshold — high-risk irreversible candidates
// can't dominate over moral concerns。
//
// **Honest scope**:
//   - This is a deterministic arbitration over the
//     L3 candidates' typed fields。 A "real" tri-self
//     would maintain three persistent voice models
//     trained on tri-voice-labeled examples。 For the
//     substrate's current scope,deriving each voice
//     from a single signal each is the right tradeoff:
//     it converts the placeholder's neutral 0.5 into
//     candidate-discriminating scores that vary with
//     input。

import Foundation
import BASRuntimeCore
import BASOrchestration

/// Real tri-self service deriving the three voices from
/// L3 candidate fields。 Replaces BASPlaceholderTriSelf
/// Service in cognitive brains that want real merged
/// choice selection。
public struct BASMLTriSelfService: BASTriSelfServicing,
    Sendable
{

    /// Named voice-weight constants。 Each voice
    /// contributes 1/3 to the merged score by default
    /// — equal weighting captures the Freudian-inspired
    /// "balanced tribunal" model。 Future commits can
    /// tune these against ground-truth merged-decision
    /// labels。
    public enum Weights {
        public static let id: Double = 1.0 / 3.0
        public static let ego: Double = 1.0 / 3.0
        public static let superego: Double = 1.0 / 3.0
    }

    /// Named threshold defaults for the arbitration。
    public enum Thresholds {
        /// Superego score below which the candidate is
        /// veto'd — moral / safety floor。 0.3 means a
        /// candidate must have at least 30% safety
        /// support to be considered。
        public static let veto: Double = 0.3

        /// Lower bound for ego score derivation。 The
        /// raw value (expectedBenefit - expectedCost +
        /// 0.5) is clamped to [0, 1]。
        public static let egoOffset: Double = 0.5
    }

    public init() {}

    public func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let scores = thoughtFrame.candidates.map {
            candidate -> BASTriSelfScore in
            return Self.score(for: candidate)
        }
        let merged = Self.mergedChoice(
            candidates: thoughtFrame.candidates,
            scores: scores)
        return (scores, merged)
    }

    /// Compute the typed tri-self score for a single
    /// candidate。 Exposed publicly for testability。
    public static func score(
        for candidate: BASCandidatePath
    ) -> BASTriSelfScore {
        // id: how well does this candidate satisfy the
        // user's expressed desire? Aligns with the L0
        // confidence signal threaded into the candidate
        // by L3 (candidate.confidence already reflects
        // how certain the loop is in this path)。
        let idScore = max(0.0, min(1.0,
            candidate.confidence))
        // ego: pragmatic feasibility = benefit minus
        // cost + a baseline offset。 Offset keeps the
        // result in [0, 1] even when benefit < cost。
        let egoRaw = candidate.expectedBenefit
            - candidate.expectedCost
            + Thresholds.egoOffset
        let egoScore = max(0.0, min(1.0, egoRaw))
        // superego: safety / morality / "is this
        // reversible enough to be right?" Reversibility
        // is the cleanest single signal — irreversible
        // candidates carry moral weight by definition。
        let superegoScore = max(0.0, min(1.0,
            candidate.reversibility))
        let mergedScore = max(0.0, min(1.0,
            Weights.id * idScore
            + Weights.ego * egoScore
            + Weights.superego * superegoScore))
        let veto = superegoScore < Thresholds.veto
        return BASTriSelfScore(
            candidateID: candidate.candidateID,
            idScore: idScore,
            egoScore: egoScore,
            superegoScore: superegoScore,
            mergedScore: mergedScore,
            veto: veto)
    }

    /// Pick the merged choice from the candidates +
    /// scores。 Algorithm:
    ///   1. Filter out veto'd candidates
    ///   2. Sort by mergedScore descending
    ///   3. Pick the top
    ///   4. If all are veto'd,fall back to highest
    ///      mergedScore + emit vetoApplied=true
    public static func mergedChoice(
        candidates: [BASCandidatePath],
        scores: [BASTriSelfScore]
    ) -> BASMergedChoice {
        guard !candidates.isEmpty else {
            return BASMergedChoice(
                candidateID: Self.fallbackCandidateID,
                title: Self.fallbackTitle,
                actionSummary: Self.fallbackSummary)
        }
        // Build score lookup by candidateID。
        var scoreByID: [String: BASTriSelfScore] = [:]
        for s in scores {
            scoreByID[s.candidateID] = s
        }
        // Filter non-veto'd + sort by merged score。
        let viable = candidates.filter {
            scoreByID[$0.candidateID]?.veto == false
        }
        let allCandidatesVeto = viable.isEmpty
        let working = allCandidatesVeto
            ? candidates
            : viable
        // chapter 八百四十 / M2851 — sort routed to Rust per
        // chapter 837 STRONG-FLIP framework (Rust ~100× faster on
        // closure-heavy sorts)。 This site has the
        // dict-lookup-per-compare antipattern (scoreByID[id])
        // making Swift closure overhead exceptionally expensive —
        // primary motivation for the flip cascade in chapters
        // 八百四十-八百四十二。 The Swift body remains as the
        // FALLBACK path per 「依旧 不删除 只 comment」。
        // chapter 八百四十七 / M2887 — upgraded to f64 + precondition
        // per strict-review HIGH #1 + M1。
        let sorted: [BASCandidatePath] = {
            let scores: [Double] = working.map {
                scoreByID[$0.candidateID]?.mergedScore ?? 0
            }
            if let indices = BASAutoRouteRanker
                .dreamLoopDominanceOrderDouble(scores: scores) {
                return indices.map { idx -> BASCandidatePath in
                    let i = Int(idx)
                    precondition(i >= 0 && i < working.count,
                        "Rust dominance_order_f64 returned " +
                        "out-of-bounds index \(i) for n=" +
                        "\(working.count)")
                    return working[i]
                }
            }
            // Swift legacy fallback (V1 implementation,kept active
            // per 「依旧 不删除 只 comment」 + cross-platform safety)
            return working.sorted { a, b in
                let aScore = scoreByID[a.candidateID]?
                    .mergedScore ?? 0
                let bScore = scoreByID[b.candidateID]?
                    .mergedScore ?? 0
                return aScore > bScore
            }
        }()
        let pick = sorted.first ?? candidates[0]
        let vetoReasonCodes: [String] = allCandidatesVeto
            ? [Self.allVetoFallbackReasonCode]
            : []
        return BASMergedChoice(
            candidateID: pick.candidateID,
            title: pick.title,
            actionSummary: pick.actionSummary,
            vetoApplied: allCandidatesVeto,
            vetoReasonCodes: vetoReasonCodes)
    }

    // MARK: - Named fallback constants

    /// Reason code emitted when the tribunal had to fall
    /// back because EVERY candidate hit the veto
    /// threshold。 Distinct so hosts can detect this
    /// edge case in telemetry。
    public static let allVetoFallbackReasonCode: String
        = "trisself.all_candidates_veto"

    /// Synthetic candidate identifier used when the
    /// thoughtFrame has no candidates at all。 Defensive
    /// — should not occur under the L3 loop service。
    public static let fallbackCandidateID: String =
        "trisself.no_candidates"

    public static let fallbackTitle: String =
        "no candidates available"

    public static let fallbackSummary: String =
        "downstream pipeline produced no candidates" +
        " — tribunal emitted defensive fallback"
}
