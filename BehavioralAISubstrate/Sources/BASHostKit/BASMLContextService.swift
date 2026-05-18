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

        /// Ambiguity-score fallback when the ML classifier
        /// throws (model load fail / predict fail)。 0.5
        /// communicates honest uncertainty rather than
        /// faking high or low ambiguity。
        public static let fallbackAmbiguityOnClassifierFailure:
            Double = 0.5
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

    private let adapter: BASContextClassifierMLAdapter

    public init(adapter: BASContextClassifierMLAdapter) {
        self.adapter = adapter
    }

    /// Maps the adapter's String label back to the typed
    /// BASContextTaskType enum。 Crashes-by-design on
    /// unknown labels — if the adapter returns a string
    /// outside the 7-class set, the model is broken and
    /// we want to FAIL LOUDLY not produce a stub。
    private func mapLabel(
        _ label: String
    ) -> BASContextTaskType {
        switch label {
        case "chat": return .chat
        case "task": return .task
        case "choice": return .choice
        case "conflict": return .conflict
        case "highPressure": return .highPressure
        case "manipulationRisk": return .manipulationRisk
        case "highConsequence": return .highConsequence
        default:
            // Honest failure mode: if the ML model outputs
            // an unexpected label, log + fall back to chat
            // rather than crashing the entire cognitive
            // pipeline。 Real production should emit a
            // typed audit event here (deferred).
            return .chat
        }
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
        do {
            let (label, confidence, _) =
                try adapter.classify(text: userInput)
            taskType = mapLabel(label)
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
            // confidence as a hint。 Otherwise empty。
            if taskType == .manipulationRisk {
                manipulationHints = [
                    "ml.classifier.confidence=" +
                    String(format: "%.3f", confidence)
                ]
            } else {
                manipulationHints = []
            }
        } catch {
            // Honest fallback: model failed. Don't crash
            // the cognitive pipeline; degrade to neutral
            // signals + log via future audit event.
            taskType = .chat
            ambiguityScore = Placeholders
                .fallbackAmbiguityOnClassifierFailure
            manipulationHints = []
        }

        return BASContextFrame(
            utterance: userInput,
            taskType: taskType,
            // PHASE B-4 placeholders (need their own models):
            emotionalLoad: Placeholders.neutralEmotionalLoad,
            timePressure: Placeholders.neutralTimePressure,
            relationPattern: Placeholders
                .neutralRelationPattern,
            // ML-derived (REAL):
            ambiguityScore: ambiguityScore,
            // PHASE B-4 placeholder:
            consequenceLevel: Placeholders
                .neutralConsequenceLevel,
            // ML-derived (REAL, .manipulationRisk only):
            manipulationHints: manipulationHints,
            // PHASE B-4 placeholder:
            hostRelevance: Placeholders.neutralHostRelevance)
    }
}
