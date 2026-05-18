// MARK: - BASMLRiskService
// REAL Layer-5 risk service derived from the L0 context
// frame's ML-derived signals。 This is the SECOND active
// ML-touched layer in the cognitive cascade — L0 context
// classification produces softmax distribution + derived
// signals (emotionalLoad / timePressure / consequenceLevel
// / ambiguityScore / relationPattern),and this service
// uses those typed inputs to compute typed risk verdicts
// deterministically。
//
// **Why deterministic, not new ML**: training a separate
// risk classifier would require its own corpus + model +
// adapter and would duplicate the signal already present
// in the context frame's softmax mass。 Computing risk as
// a typed weighted combination of L0 signals is auditable,
// deterministic, and Codable — every weight is named and
// documented so hosts can review WHY a particular input
// got a particular risk level。
//
// **Cognitive cascade now spans 2 ML-touched layers**:
//   L0 (context): real CoreML 7-class classifier
//   L5 (risk):    real derivation from L0 signals
//
// Other layers (L1 memory, L2 decompose, L3 loop, L4
// triself, L6 action, L7 evolution) remain placeholder.
//
// **Honest scope acknowledgments**:
//   - The weights below were chosen by hand to encode
//     a reasonable safety-first risk model。 They are NOT
//     tuned against ground-truth risk labels — that would
//     require a hand-labeled (input, risk) corpus and a
//     calibration sweep。 Subsequent commits can tune them。
//   - thoughtFrame / triScores / budget inputs are
//     ACCEPTED but NOT USED — the current derivation works
//     purely from contextFrame。 When real downstream
//     services (decompose, triself) come online, the
//     risk service can be extended to integrate their
//     signals。

import Foundation
import BASRuntimeCore
import BASPolicy

/// Real risk service backed by L0 context frame's
/// ML-derived signals。 Replaces the BASPlaceholder
/// RiskService in cognitive brains that want real
/// risk verdicts。
public struct BASMLRiskService: BASRiskServicing,
    Sendable
{

    /// Named weights for the totalRisk derivation。 Each
    /// weight is a non-negative contribution to the
    /// totalRisk Float in [0, 1]。 Sum of all weights
    /// equals 1.0 so the result naturally stays in range
    /// (assuming all inputs are clamped [0, 1])。
    public enum Weights {
        /// Manipulation signal weight。 Highest because
        /// detected manipulation is the most dangerous
        /// safety signal。 0.4 reserves the majority of
        /// the risk envelope for manipulation when the
        /// model surfaces it。
        public static let manipulation: Double = 0.4

        /// Consequence-level weight。 High-stakes inputs
        /// warrant elevated risk independent of
        /// manipulation。
        public static let consequence: Double = 0.25

        /// Emotional-load weight。 Inputs with high
        /// emotional charge are more error-prone for
        /// the model and warrant more caution。
        public static let emotion: Double = 0.20

        /// Urgency (time-pressure) weight。 Pressure
        /// produces narrow decision windows and elevated
        /// risk of skipping safety checks。
        public static let urgency: Double = 0.10

        /// Ambiguity weight。 Low confidence in the
        /// classification itself is a risk signal because
        /// the downstream decision rests on a shaky
        /// foundation。 Smallest weight because ambiguity
        /// is more "I don't know" than "this is dangerous"。
        public static let ambiguity: Double = 0.05
    }

    /// Named thresholds for mapping the totalRisk Float
    /// to the typed BASBrainRiskLevel enum。 Four-class
    /// staircase matching the enum order。
    public enum Thresholds {
        /// totalRisk < this → .low
        public static let low: Double = 0.25
        /// totalRisk < this → .medium
        public static let medium: Double = 0.50
        /// totalRisk < this → .high
        public static let high: Double = 0.75
        /// totalRisk >= 0.75 → .extreme
    }

    /// Named uncertainty defaults。 The risk frame carries
    /// uncertainty / irreversibility / manipulationStrength
    /// scores;these defaults are picked so the cascade
    /// stays meaningful without overasserting。
    public enum Defaults {
        /// Uncertainty echoes the context frame's
        /// ambiguityScore (when present)。 Default 0.3
        /// when no ambiguity is available。
        public static let uncertainty: Double = 0.3

        /// Irreversibility echoes the context frame's
        /// consequenceLevel (when present)。 Default 0.1
        /// when no consequence signal is available。
        public static let irreversibility: Double = 0.1

        /// Default GSI score — placeholder layer didn't
        /// compute this from any signal。 The ML risk
        /// service derives it from totalRisk。
        public static let gsiScore: Double = 0.3
    }

    /// Named risk-factor strings emitted into the
    /// BASRiskCard.factors array。 Each captures a
    /// specific signal that contributed to the risk
    /// assessment。 Hosts grep on these for telemetry。
    public enum Factors {
        public static let manipulationDetected =
            "manipulation_detected"
        public static let highConsequence =
            "high_consequence"
        public static let highPressure = "high_pressure"
        public static let emotionalCharge =
            "emotional_charge"
        public static let highAmbiguity = "high_ambiguity"
        public static let conflictSignal =
            "conflict_signal"

        /// Threshold above which a derived signal is
        /// considered a "factor"。 0.5 = "more than
        /// half" — clearly elevated rather than baseline。
        public static let elevatedThreshold: Double = 0.5
    }

    public init() {}

    /// Compute the BASRiskCard from the context frame's
    /// derived signals。 Inputs other than contextFrame
    /// are accepted but currently unused。
    public func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        let signals = Self.deriveSignals(
            contextFrame: contextFrame)
        let factors = Self.deriveFactors(
            contextFrame: contextFrame,
            signals: signals)
        let totalRisk = signals.totalRisk
        let level = riskLevel(for: totalRisk)
        let mode = Self.recommendedMode(for: level)
        return BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: level,
            factors: factors,
            uncertainty: signals.uncertainty,
            irreversibility: signals.irreversibility,
            manipulationStrength: signals
                .manipulationIndicator,
            gsiScore: totalRisk,
            recommendedMode: mode)
    }

    /// Aggregate severity index。 Currently equals the
    /// totalRisk score。 In a future commit this can
    /// diverge if hosts need a different aggregation。
    public func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        return Self.deriveSignals(
            contextFrame: contextFrame).totalRisk
    }

    /// Gate the action — produces the risk card + the
    /// action permit (with mode/scope) for downstream
    /// service consumers。 ML version derives the permit
    /// reason codes from the same factors as the card。
    public func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit) {
        let card = calibrateRisk(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: budget)
        let permit = BASActionPermit(
            mode: card.recommendedMode,
            reasonCodes: card.factors.isEmpty
                ? [Self.noElevatedFactorsReasonCode]
                : card.factors,
            outputLengthCap: Self.defaultOutputLengthCap,
            tonePolicy: Self.derivedTonePolicy(
                for: card.riskLevel),
            templatePolicy: Self.derivedTemplatePolicy(
                for: card.riskLevel))
        return (card, permit)
    }

    /// Score → typed level mapping using the named
    /// staircase thresholds。
    public func riskLevel(for score: Double)
        -> BASBrainRiskLevel
    {
        switch score {
        case ..<Thresholds.low:
            return .low
        case ..<Thresholds.medium:
            return .medium
        case ..<Thresholds.high:
            return .high
        default:
            return .extreme
        }
    }

    // MARK: - Static derivation helpers

    /// Reason code emitted when no risk factor exceeds
    /// the elevated threshold。 Distinct so hosts can
    /// distinguish "low risk because no factors" from
    /// "low risk because factors offset each other"。
    public static let noElevatedFactorsReasonCode:
        String = "risk.no_elevated_factors"

    /// Default output-length cap when the placeholder
    /// substituted nothing。 200 = reasonable budget for
    /// a typical brain response。
    public static let defaultOutputLengthCap: Int = 200

    /// Bundle of derived risk-relevant signals。
    public struct DerivedSignals {
        public let manipulationIndicator: Double
        public let totalRisk: Double
        public let uncertainty: Double
        public let irreversibility: Double
    }

    /// Derive the risk-relevant signal bundle from the
    /// context frame's typed fields。 Exposed as static
    /// for testability — callers can feed synthetic
    /// frames and verify the derivation。
    public static func deriveSignals(
        contextFrame: BASContextFrame
    ) -> DerivedSignals {
        let confidence = 1.0
            - contextFrame.ambiguityScore
        let manipulationIndicator: Double =
            contextFrame.taskType == .manipulationRisk
                ? max(0.0, min(1.0, confidence)) : 0.0
        let totalRisk =
            Weights.manipulation * manipulationIndicator
            + Weights.consequence
                * contextFrame.consequenceLevel
            + Weights.emotion
                * contextFrame.emotionalLoad
            + Weights.urgency
                * contextFrame.timePressure
            + Weights.ambiguity
                * contextFrame.ambiguityScore
        let clampedRisk = max(0.0, min(1.0, totalRisk))
        return DerivedSignals(
            manipulationIndicator: manipulationIndicator,
            totalRisk: clampedRisk,
            uncertainty: contextFrame.ambiguityScore,
            irreversibility:
                contextFrame.consequenceLevel)
    }

    /// Derive the factors array from elevated signals。
    /// Each factor appears at most once。 Order is stable
    /// (manipulation first if present,then others by
    /// severity)。
    public static func deriveFactors(
        contextFrame: BASContextFrame,
        signals: DerivedSignals
    ) -> [String] {
        var factors: [String] = []
        if contextFrame.taskType == .manipulationRisk {
            factors.append(Factors.manipulationDetected)
        }
        if contextFrame.consequenceLevel
            >= Factors.elevatedThreshold
        {
            factors.append(Factors.highConsequence)
        }
        if contextFrame.timePressure
            >= Factors.elevatedThreshold
        {
            factors.append(Factors.highPressure)
        }
        if contextFrame.emotionalLoad
            >= Factors.elevatedThreshold
        {
            factors.append(Factors.emotionalCharge)
        }
        if contextFrame.ambiguityScore
            >= Factors.elevatedThreshold
        {
            factors.append(Factors.highAmbiguity)
        }
        if contextFrame.relationPattern == "tense" {
            factors.append(Factors.conflictSignal)
        }
        return factors
    }

    /// Risk level → action permit mode mapping。
    /// Conservative: higher risk = less direct mode。
    public static func recommendedMode(
        for level: BASBrainRiskLevel
    ) -> BASActionPermitMode {
        switch level {
        case .low: return .answer
        case .medium: return .answer
        case .high: return .compare
        case .extreme: return .delay
        }
    }

    private static let standardTonePolicy: String =
        "standard"
    private static let cautiousTonePolicy: String =
        "cautious"
    private static let standardTemplatePolicy: String =
        "standard"
    private static let conservativeTemplatePolicy: String =
        "conservative"

    /// Derive a tone policy hint from risk level。
    /// Higher risk biases toward more cautious tone。
    public static func derivedTonePolicy(
        for level: BASBrainRiskLevel
    ) -> String {
        switch level {
        case .low, .medium: return standardTonePolicy
        case .high, .extreme: return cautiousTonePolicy
        }
    }

    /// Derive a template policy hint from risk level。
    /// Higher risk biases toward conservative templates。
    public static func derivedTemplatePolicy(
        for level: BASBrainRiskLevel
    ) -> String {
        switch level {
        case .low, .medium: return standardTemplatePolicy
        case .high, .extreme:
            return conservativeTemplatePolicy
        }
    }
}
