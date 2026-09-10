// MARK: - BASMLContextService
// Phase B-4 — REAL ML-backed BASContextServicing
//
// Replaces BASPlaceholderContextService in the cognitive
// cascade。 Uses BASContextClassifierMLAdapter (Phase B-3)
// for taskType inference. Other ContextFrame fields
// (emotionalLoad, timePressure, etc.) remain heuristic
// placeholders because no model has been trained for them
// yet — that's Phase C/D/E work.

import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

/// ML-backed BASContextServicing that uses CoreML for
/// taskType classification。 Falls back to documented
/// constant placeholders for the other ContextFrame fields
/// (see `Placeholders` enum below)。
///
/// ## What's REAL (ML-backed)
///   - taskType: classified by trained CoreML model
///     (BASContextClassifierMLAdapter, Phase B-3)
///   - utterance: echoes the input directly
///   - ambiguityScore: 1 - softmax confidence
///   - manipulationHints: populated when taskType ==
///     .manipulationRisk (real ML evidence)
///
/// ## What's STILL placeholder (typed constants, not
/// magic numbers — see `BASMLContextService.Placeholders`)
///   - emotionalLoad: neutralEmotionalLoad
///   - timePressure: neutralTimePressure
///   - relationPattern: neutralRelationPattern
///   - consequenceLevel: neutralConsequenceLevel
///   - hostRelevance: neutralHostRelevance
///
/// Phase C+ will train models for these and ship more
/// real-ML services。 Naming the placeholders as constants
/// (not inline magic numbers) makes the boundary between
/// real-ML and placeholder explicit + audit-able。
public struct BASMLContextService: BASContextServicing,
    Sendable
{
    /// Named constants for placeholder field values used
    /// when no ML model exists for a given ContextFrame
    /// field。 Each constant carries a rationale + the
    /// Phase that will replace it with real ML。
    public enum Placeholders {
        /// Neutral emotional-load value emitted when no
        /// emotion-classifier ML is present。 Slightly
        /// non-zero to indicate "small but present" baseline
        /// arousal rather than a vacuous zero。 Replaced by
        /// Phase C+ emotional-load regression。
        public static let neutralEmotionalLoad: Double = 0.1

        /// Neutral time-pressure value when no urgency-
        /// classifier ML is present。 Replaced by Phase C+。
        public static let neutralTimePressure: Double = 0.1

        /// String tag for the relation-pattern field when
        /// no relation-classifier exists。 Replaced by
        /// Phase C+ relational embedding。
        public static let neutralRelationPattern: String =
            "neutral"

        /// Neutral consequence-level when no consequence-
        /// estimator ML is present。 Replaced by Phase C+。
        public static let neutralConsequenceLevel: Double = 0.1

        /// Default host-relevance score when no per-host
        /// retrieval ML is present。 0.5 = "neutral relevance"
        /// (vs 0 or 1 which assert strong (ir)relevance)。
        /// Replaced by Phase C+ host-relevance ranker。
        public static let neutralHostRelevance: Double = 0.5

        /// Ambiguity-score on classifier failure。 1.0 =
        /// MAXIMUM ambiguity = "we have no information"。
        /// Previously 0.5 ("medium uncertainty") which
        /// was wrong — when the classifier throws,we
        /// have no output, not partial output, so the
        /// honest value is maximum ambiguity。 This
        /// translates to confidence = 0 which keeps the
        /// safety-verdict below the threshold (= .safe)
        /// while accurately representing the failure。
        public static let fallbackAmbiguityOnClassifierFailure:
            Double = 1.0

        /// Manipulation-hint emitted when the ML
        /// classifier throws。 Hosts can grep for this
        /// prefix in `contextFrame.manipulationHints` to
        /// distinguish "model returned .chat with low
        /// confidence" from "model died, defaulted to
        /// .chat"。
        public static let classifierErrorHintPrefix:
            String = "ml.classifier.error="

        /// Manipulation-hint prefix surfaced when the
        /// classifier successfully labels input as
        /// .manipulationRisk。 Carries the confidence
        /// value for downstream gating logic。
        public static let manipulationConfidenceHintPrefix:
            String = "ml.classifier.confidence="

        /// Manipulation-hint prefix surfaced when the
        /// classifier returns a label outside the 7-class
        /// pinned set。 Carries the actual unexpected
        /// label for telemetry。 Indicates model
        /// corruption,version drift,or coremltools
        /// output-naming bug — never produced under
        /// normal operation but surfaced when it
        /// happens so hosts can detect it。
        public static let classifierUnknownLabelHintPrefix:
            String = "ml.classifier.unknown_label="
    }

    /// Lower bound for the clamped ambiguity-score range。
    /// ambiguityScore is mathematically in [0, 1] (since it
    /// equals 1 - softmax probability)。
    private static let ambiguityScoreMin: Double = 0.0
    private static let ambiguityScoreMax: Double = 1.0

    /// Multiplicative constant used to derive ambiguity
    /// from confidence: ambiguity = 1 - confidence。 Named
    /// to make the inversion semantics explicit at the
    /// call site。
    private static let confidenceToAmbiguityComplement:
        Double = 1.0

    /// Probability threshold above which the .conflict
    /// class is considered to dominate the relation-
    /// pattern signal。 0.3 = well above the 1/7 ≈ 0.143
    /// uniform-random baseline but below the "model is
    /// sure" range (0.6+);captures elevated-but-not-
    /// dominant conflict signal。
    private static let relationTenseThreshold: Double = 0.3

    /// Tag emitted for relationPattern when conflict
    /// probability exceeds the threshold。 Distinct from
    /// the neutral default so downstream consumers can
    /// distinguish "model saw conflict signal" from
    /// "model is neutral / didn't see conflict"。
    private static let relationTenseTag: String = "tense"

    private let adapter: BASContextClassifierMLAdapter

    public init(adapter: BASContextClassifierMLAdapter) {
        self.adapter = adapter
    }

    /// Maps the adapter's String label back to the typed
    /// BASContextTaskType enum + an optional audit hint
    /// for the unknown-label fallback path。
    ///
    /// When the model outputs a label outside the 7-class
    /// pinned set,we fall back to .chat (don't crash the
    /// cascade) AND emit a typed audit hint via
    /// `manipulationHints` so hosts can detect the
    /// failure mode without scanning logs。 This was
    /// previously a silent "deferred" TODO — the model
    /// could degenerate to an unknown label and the
    /// substrate would silently classify as chat,
    /// hiding the corruption from hosts。
    /// `internal static` (not private) so the unknown-label audit-hint
    /// branch — the whole reason this fn exists — is directly testable
    /// without a real .mlmodel-backed adapter. Uses no instance state
    /// (only the label + a static hint prefix), so `static` is exact.
    static func mapLabel(
        _ label: String
    ) -> (taskType: BASContextTaskType,
          unknownLabelHint: String?)
    {
        switch label {
        case "chat": return (.chat, nil)
        case "task": return (.task, nil)
        case "choice": return (.choice, nil)
        case "conflict": return (.conflict, nil)
        case "highPressure": return (.highPressure, nil)
        case "manipulationRisk":
            return (.manipulationRisk, nil)
        case "highConsequence":
            return (.highConsequence, nil)
        default:
            // Real product visibility: surface the unknown
            // label via a typed hint so hosts can grep for
            // `ml.classifier.unknown_label=` in
            // manipulationHints and detect model
            // corruption / version drift。
            let hint = Placeholders
                .classifierUnknownLabelHintPrefix
                + label
            return (.chat, hint)
        }
    }

    /// Compute softmax probabilities from raw logits。
    /// Numerical-stable form (subtract max before exp)
    /// mirroring BASContextClassifierMLAdapter's internal
    /// softmax + Python trainer。
    private func softmax(_ logits: [Float]) -> [Double] {
        guard !logits.isEmpty else { return [] }
        let maxLogit = logits.max() ?? 0
        var exps = [Double]()
        exps.reserveCapacity(logits.count)
        var sum: Double = 0
        for l in logits {
            let e = exp(Double(l - maxLogit))
            exps.append(e)
            sum += e
        }
        if sum == 0 {
            // Degenerate guard:return uniform。
            return Array(
                repeating: 1.0 / Double(logits.count),
                count: logits.count)
        }
        return exps.map { $0 / sum }
    }

    /// Index of a label in the model's output order。
    /// Pinned at the adapter's `labels` array (chat/task/
    /// choice/conflict/highPressure/manipulationRisk/
    /// highConsequence)。 Returns nil if label is not
    /// found — caller must handle defensively。
    private func probabilityFor(
        _ label: String,
        in probs: [Double]
    ) -> Double {
        let labels = BASContextClassifierMLAdapter.labels
        guard let idx = labels.firstIndex(of: label),
              idx < probs.count
        else { return 0.0 }
        return probs[idx]
    }

    public func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        // Try to classify via ML; on any failure fall back
        // to .chat (honest degradation, not a crash).
        let taskType: BASContextTaskType
        let ambiguityScore: Double
        let manipulationHints: [String]
        let emotionalLoad: Double
        let timePressure: Double
        let consequenceLevel: Double
        let relationPattern: String
        do {
            let (label, confidence, logits) =
                try adapter.classify(text: userInput)
            let (mappedType, unknownHint) =
                Self.mapLabel(label)
            taskType = mappedType
            // REAL ML-derived ambiguity:high confidence
            // ⇒ low ambiguity, low confidence ⇒ high
            // ambiguity。 1 - confidence is the standard
            // proxy。 Clamped to [ambiguityScoreMin,
            // ambiguityScoreMax]。
            ambiguityScore = max(
                Self.ambiguityScoreMin,
                min(Self.ambiguityScoreMax,
                    Self.confidenceToAmbiguityComplement
                        - confidence))
            // REAL ML-derived manipulation signal:if the
            // top class is .manipulationRisk, surface its
            // confidence as a hint。 Otherwise empty —
            // unless the unknown-label fallback fired,
            // in which case surface the audit hint so
            // hosts can detect model corruption。
            var hints: [String] = []
            if taskType == .manipulationRisk {
                hints.append(
                    Placeholders
                        .manipulationConfidenceHintPrefix
                    + String(format: "%.3f", confidence))
            }
            if let unknownHint = unknownHint {
                hints.append(unknownHint)
            }
            manipulationHints = hints
            // REAL ML-derived contextual signals computed
            // from the full softmax distribution。 Previously
            // hardcoded to neutral placeholders;now they
            // vary with input semantics。 No new model —
            // just better use of the existing 7-class output。
            let probs = softmax(logits)
            // emotionalLoad ≈ P(non-calm classes) =
            //   P(highPressure) + P(highConsequence)
            //   + P(conflict) + P(manipulationRisk)
            // Intuition:these are the four classes whose
            // inputs ARE emotionally charged。 Sum gives
            // a 0..1 score。 Clamped defensively。
            let nonCalm =
                probabilityFor("highPressure", in: probs)
                + probabilityFor("highConsequence",
                    in: probs)
                + probabilityFor("conflict", in: probs)
                + probabilityFor("manipulationRisk",
                    in: probs)
            emotionalLoad = max(0.0, min(1.0, nonCalm))
            // timePressure ≈ P(highPressure) — the model's
            // direct signal for urgency。 Clamped。
            timePressure = max(0.0, min(1.0,
                probabilityFor("highPressure", in: probs)))
            // consequenceLevel ≈ P(highConsequence) — the
            // model's direct signal for stakes。 Clamped。
            consequenceLevel = max(0.0, min(1.0,
                probabilityFor("highConsequence",
                    in: probs)))
            // relationPattern:if conflict probability is
            // appreciable,signal "tense"。 Threshold 0.3
            // is well above uniform-random (1/7 ≈ 0.143)
            // and well below "model is sure" (~0.6+) —
            // captures elevated-but-not-dominant conflict
            // signal。 Otherwise neutral (model has no
            // relation-classifier;this is the best we can
            // derive from the existing classifier)。
            let conflictProb = probabilityFor(
                "conflict", in: probs)
            relationPattern = conflictProb
                >= Self.relationTenseThreshold
                ? Self.relationTenseTag
                : Placeholders.neutralRelationPattern
        } catch {
            // Honest fallback: model failed。 Surface the
            // failure via manipulationHints so hosts can
            // distinguish "real .chat classification" from
            // "model died, defaulted to .chat"。 Maximum
            // ambiguity → confidence 0 → safety verdict
            // remains .safe (no false block on infra failure)。
            taskType = .chat
            ambiguityScore = Placeholders
                .fallbackAmbiguityOnClassifierFailure
            manipulationHints = [
                Placeholders.classifierErrorHintPrefix
                + "\(error)"
            ]
            // Failure path:fall back to neutral placeholders
            // for the derived signals since we have no
            // logits to work with。
            emotionalLoad = Placeholders.neutralEmotionalLoad
            timePressure = Placeholders.neutralTimePressure
            consequenceLevel = Placeholders
                .neutralConsequenceLevel
            relationPattern = Placeholders
                .neutralRelationPattern
        }

        return BASContextFrame(
            utterance: userInput,
            taskType: taskType,
            // ML-derived (REAL):
            emotionalLoad: emotionalLoad,
            // ML-derived (REAL):
            timePressure: timePressure,
            // ML-derived (REAL conflict-threshold flag):
            relationPattern: relationPattern,
            // ML-derived (REAL):
            ambiguityScore: ambiguityScore,
            // ML-derived (REAL):
            consequenceLevel: consequenceLevel,
            // ML-derived (REAL, .manipulationRisk only):
            manipulationHints: manipulationHints,
            // PHASE B-4 placeholder (needs per-host
            // retrieval ML — out of scope here):
            hostRelevance: Placeholders.neutralHostRelevance)
    }
}
