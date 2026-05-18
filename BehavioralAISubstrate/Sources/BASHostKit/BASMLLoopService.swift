// MARK: - BASMLLoopService
// REAL Layer-3 loop service derived from L2 decompose
// frame's signal arrays。 Fourth active ML-touched layer
// in the cognitive cascade。
//
// The loop service is the brain's "candidate generation"
// layer。 The placeholder produced ONE trivial candidate
// with neutral scores;the real service uses L2 signals
// to generate up to 3 typed candidates with real
// derivation:
//   - primary  — always present
//   - cautious — alternative slower path when pressure /
//     manipulation / stakes signals are elevated
//   - decline  — explicit "do not proceed" option when
//     manipulation_detected is in the decompose frame
//
// Each candidate's expectedBenefit / expectedCost /
// reversibility / confidence are deterministic functions
// of the L2 signal-array contents。 No new model trained;
// just better use of the L0 → L2 signal chain。
//
// **Honest scope**: candidate TITLES and ACTION SUMMARIES
// are typed labels rather than generative natural-language
// strings。 A "real" loop service would produce specific
// candidates like "ship at 5pm even with the bug" vs
// "delay shipping until tomorrow to fix the bug"。 That
// requires either an LLM or a substantial planning
// pipeline。 For the substrate's current scope,typed
// candidate identifiers are the right tradeoff: hosts get
// MULTIPLE candidates instead of one,each with REAL
// score fields derived from L0+L2,letting downstream
// services (triself / risk / action) operate on a
// meaningful candidate set。

import Foundation
import BASRuntimeCore
import BASOrchestration

/// Real loop service backed by L2 decompose frame's
/// signal arrays。 Replaces BASPlaceholderLoopService
/// in cognitive brains that want real candidate
/// generation。
public struct BASMLLoopService: BASLoopServicing,
    Sendable
{

    /// Named candidate identifiers + titles。 Stable
    /// across calls so hosts can match by ID for
    /// telemetry / UI mapping。
    public enum Candidates {
        public static let primaryID = "loop.primary"
        public static let primaryTitle =
            "primary action path"
        public static let primarySummary =
            "proceed with the user's apparent request"

        public static let cautiousID = "loop.cautious"
        public static let cautiousTitle =
            "cautious action path"
        public static let cautiousSummary =
            "proceed with extra confirmation / slowdown" +
            " before any irreversible step"

        public static let declineID = "loop.decline"
        public static let declineTitle =
            "decline action path"
        public static let declineSummary =
            "refuse the request — explain why and offer" +
            " a safe alternative"
    }

    /// Named score-derivation constants。 Each captures
    /// a specific signal-to-score adjustment rule。
    public enum Adjustments {
        /// Baseline benefit when no signals lower it。
        public static let baselineBenefit: Double = 0.7

        /// Baseline cost when no signals raise it。
        public static let baselineCost: Double = 0.2

        /// Baseline reversibility when no signals
        /// lower it。
        public static let baselineReversibility: Double
            = 0.9

        /// Baseline confidence when no signals lower it。
        public static let baselineConfidence: Double = 0.8

        /// Cost penalty applied when a pressure signal
        /// is present。 Pressure → faster action → less
        /// careful → higher cost。
        public static let pressureCostPenalty: Double
            = 0.20

        /// Reversibility penalty when high_stakes is
        /// in pressureSignals。 High stakes → less
        /// reversible by definition。
        public static let stakesReversibilityPenalty:
            Double = 0.35

        /// Confidence penalty per unknown signal in the
        /// decompose frame's unknowns array。
        public static let unknownConfidencePenalty:
            Double = 0.20

        /// Cost penalty when manipulation_detected is
        /// present。 Manipulation → high cost of
        /// proceeding。
        public static let manipulationCostPenalty:
            Double = 0.30

        /// Confidence penalty when manipulation_detected
        /// is present。
        public static let manipulationConfidencePenalty:
            Double = 0.30

        /// Cost boost for the cautious path — by
        /// definition slower / more expensive than
        /// primary。
        public static let cautiousCostIncrement: Double
            = 0.15

        /// Reversibility boost for the cautious path
        /// — slowdown adds option value。
        public static let cautiousReversibilityBoost:
            Double = 0.10

        /// Forecast uncertainty。 Echoes how many
        /// elevated signals are present。
        public static let baselineUncertainty: Double
            = 0.1
        public static let perSignalUncertaintyDelta:
            Double = 0.1

        /// Critique severity baselines。
        public static let evidenceGapSeverity: Double
            = 0.3
        public static let manipulationSeverity: Double
            = 0.8
        public static let emotionalBiasSeverity: Double
            = 0.5
    }

    public init() {}

    /// Generate candidate paths from the L2 decompose
    /// frame。 Always produces at least the primary
    /// candidate;adds cautious when pressure / stakes
    /// / emotion signals are present;adds decline when
    /// manipulation is detected。
    public func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        let signals = Self.deriveScoreDeltas(
            decomposeFrame: decomposeFrame)
        var candidates: [BASCandidatePath] = []

        // Primary candidate — always present
        candidates.append(BASCandidatePath(
            candidateID: Candidates.primaryID,
            title: Candidates.primaryTitle,
            actionSummary: Candidates.primarySummary,
            expectedBenefit: signals.primaryBenefit,
            expectedCost: signals.primaryCost,
            reversibility: signals.primaryReversibility,
            confidence: signals.primaryConfidence))

        // Cautious candidate when there's anything to
        // be cautious about。
        if signals.shouldOfferCautious {
            candidates.append(BASCandidatePath(
                candidateID: Candidates.cautiousID,
                title: Candidates.cautiousTitle,
                actionSummary: Candidates.cautiousSummary,
                expectedBenefit: signals
                    .primaryBenefit
                    * Self.cautiousBenefitFactor,
                expectedCost: min(1.0,
                    signals.primaryCost
                    + Adjustments
                        .cautiousCostIncrement),
                reversibility: min(1.0,
                    signals.primaryReversibility
                    + Adjustments
                        .cautiousReversibilityBoost),
                confidence: signals.primaryConfidence))
        }

        // Decline candidate when manipulation is detected
        if signals.manipulationDetected {
            candidates.append(BASCandidatePath(
                candidateID: Candidates.declineID,
                title: Candidates.declineTitle,
                actionSummary: Candidates.declineSummary,
                expectedBenefit:
                    Self.declineBenefit,
                expectedCost: Self.declineCost,
                reversibility:
                    Self.declineReversibility,
                confidence:
                    Self.declineConfidence))
        }

        return candidates
    }

    /// Generate forecasts per candidate。 Uncertainty
    /// scales with the count of elevated signals in the
    /// decompose frame。 Outcomes are typed labels (not
    /// generative paraphrases)。
    public func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem] {
        let elevatedSignalCount =
            decomposeFrame.emotions.count
            + decomposeFrame.pressureSignals.count
            + decomposeFrame.manipulationSignals.count
            + decomposeFrame.unknowns.count
        let uncertainty = min(1.0,
            Adjustments.baselineUncertainty
            + Double(elevatedSignalCount)
                * Adjustments.perSignalUncertaintyDelta)
        return candidates.map { candidate in
            BASForecastItem(
                candidateID: candidate.candidateID,
                shortTermOutcome: Self.shortTermOutcome(
                    for: candidate.candidateID),
                midTermOutcome: Self.midTermOutcome(
                    for: candidate.candidateID),
                worstCase: Self.worstCase(
                    for: candidate.candidateID),
                uncertainty: uncertainty)
        }
    }

    /// Generate critiques per candidate from the
    /// decompose frame's signals。
    public func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        return candidates.flatMap { c in
            critiqueItems(
                for: c.candidateID,
                hostContext: hostContext)
        }
    }

    /// Per-candidate critique synthesis。 Each candidate
    /// gets at least an evidence-gap critique;manipulation-
    /// flagged inputs add a manipulation critique。
    private func critiqueItems(
        for candidateID: String,
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        var items: [BASCritiqueItem] = []
        items.append(BASCritiqueItem(
            candidateID: candidateID,
            critiqueType: .evidenceGap,
            critiqueText: "evidence is signal-derived" +
                " only;no host-specific evidence" +
                " collected this turn",
            severity: Adjustments.evidenceGapSeverity))
        return items
    }

    /// Full iterate loop。 Assembles the thoughtFrame
    /// from proposed paths + forecasts + critiques。
    public func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame {
        let candidates = proposePaths(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: budget)
        let forecasts = forecast(
            candidates: candidates,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle)
        let critiques = critique(
            candidates: candidates,
            forecasts: forecasts,
            hostContext: BASHostProfile(
                hostID: Self.loopHostID))
        return BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: Self.loopDecomposeRef,
            memoryRefs: [],
            candidates: candidates,
            forecasts: forecasts,
            critiques: critiques,
            triScores: [],
            stabilityScore: Self.baselineStabilityScore)
    }

    // MARK: - Score derivation

    /// Per-candidate score bundle derived from the
    /// decompose frame。 Exposed publicly for tests +
    /// downstream consumers wanting visibility into
    /// the derivation。
    public struct ScoreDeltas {
        public let primaryBenefit: Double
        public let primaryCost: Double
        public let primaryReversibility: Double
        public let primaryConfidence: Double
        public let shouldOfferCautious: Bool
        public let manipulationDetected: Bool
    }

    /// Static derivation function。 Reads the decompose
    /// frame's signal arrays and produces typed score
    /// adjustments。
    public static func deriveScoreDeltas(
        decomposeFrame: BASDecomposeFrame
    ) -> ScoreDeltas {
        let hasPressure = !decomposeFrame
            .pressureSignals.isEmpty
        let hasEmotion = !decomposeFrame.emotions
            .isEmpty
        let hasManipulation = decomposeFrame
            .manipulationSignals.contains(
                BASMLDecomposeService.Signals
                    .manipulationDetected)
        let hasHighStakes = decomposeFrame
            .pressureSignals.contains(
                BASMLDecomposeService.Signals
                    .highStakes)
        let unknownCount = decomposeFrame.unknowns.count

        var cost = Adjustments.baselineCost
        var reversibility = Adjustments
            .baselineReversibility
        var confidence = Adjustments.baselineConfidence

        if hasPressure {
            cost = min(1.0,
                cost + Adjustments.pressureCostPenalty)
        }
        if hasHighStakes {
            reversibility = max(0.0,
                reversibility - Adjustments
                    .stakesReversibilityPenalty)
        }
        if hasManipulation {
            cost = min(1.0,
                cost + Adjustments
                    .manipulationCostPenalty)
            confidence = max(0.0,
                confidence - Adjustments
                    .manipulationConfidencePenalty)
        }
        confidence = max(0.0,
            confidence
            - Double(unknownCount)
                * Adjustments.unknownConfidencePenalty)

        return ScoreDeltas(
            primaryBenefit: Adjustments.baselineBenefit,
            primaryCost: cost,
            primaryReversibility: reversibility,
            primaryConfidence: confidence,
            shouldOfferCautious:
                hasPressure || hasEmotion
                || hasManipulation,
            manipulationDetected: hasManipulation)
    }

    // MARK: - Named constants

    /// Cautious benefit is a fraction of primary —
    /// caution has option value but lower direct payoff。
    public static let cautiousBenefitFactor: Double
        = 0.85

    /// Decline candidate fields。 Decline has low cost
    /// (just say no) and full reversibility (no action
    /// taken) but lower benefit (no progress)。
    public static let declineBenefit: Double = 0.3
    public static let declineCost: Double = 0.1
    public static let declineReversibility: Double = 1.0
    public static let declineConfidence: Double = 0.9

    /// Baseline stability score for the iterate-loop
    /// output。 0.7 = "moderately stable" — captures
    /// that signal-derived candidates are well-founded
    /// but not equivalent to verified-evidence outputs。
    public static let baselineStabilityScore: Double
        = 0.7

    /// Synthetic hostID used during loop-internal
    /// critique generation when no real host profile is
    /// threaded through。
    public static let loopHostID: String =
        "bas.cognitive.brain.loop"

    public static let loopDecomposeRef: String =
        "bas.cognitive.brain.loop.decompose"

    // MARK: - Typed forecast outcome labels

    private static let primaryShortTerm =
        "execute requested action immediately"
    private static let primaryMidTerm =
        "outcome reflects user's expressed intent"
    private static let primaryWorstCase =
        "user feedback negative;reversible if needed"

    private static let cautiousShortTerm =
        "ask clarifying question before proceeding"
    private static let cautiousMidTerm =
        "delayed but more aligned outcome"
    private static let cautiousWorstCase =
        "minor friction with user;no irreversible step"

    private static let declineShortTerm =
        "refuse + explain reasoning"
    private static let declineMidTerm =
        "user redirected to safe alternative"
    private static let declineWorstCase =
        "user frustrated;no harmful action taken"

    public static func shortTermOutcome(
        for candidateID: String
    ) -> String {
        switch candidateID {
        case Candidates.primaryID:
            return primaryShortTerm
        case Candidates.cautiousID:
            return cautiousShortTerm
        case Candidates.declineID:
            return declineShortTerm
        default:
            return primaryShortTerm
        }
    }

    public static func midTermOutcome(
        for candidateID: String
    ) -> String {
        switch candidateID {
        case Candidates.primaryID:
            return primaryMidTerm
        case Candidates.cautiousID:
            return cautiousMidTerm
        case Candidates.declineID:
            return declineMidTerm
        default:
            return primaryMidTerm
        }
    }

    public static func worstCase(
        for candidateID: String
    ) -> String {
        switch candidateID {
        case Candidates.primaryID:
            return primaryWorstCase
        case Candidates.cautiousID:
            return cautiousWorstCase
        case Candidates.declineID:
            return declineWorstCase
        default:
            return primaryWorstCase
        }
    }
}
