// MARK: - BASMLDecomposeService
// REAL Layer-2 decompose service derived from L0 context
// frame's ML-derived signals。 Third active ML-touched
// layer in the cognitive cascade (after L0 context and
// L5 risk)。
//
// The decompose service is the brain's "analysis" layer
// that surfaces facts / goals / emotions / pressures /
// manipulation signals from the input。 The placeholder
// returned empty arrays for ALL fields,leaving downstream
// services (loop, triself, risk, action) with no real
// structured information to work from。
//
// This service uses the L0 derived signals
// (emotionalLoad / timePressure / consequenceLevel /
// relationPattern / manipulationHints / ambiguityScore)
// to populate the cascade's analysis fields with typed,
// auditable signal strings。 Hosts can grep on these
// strings for telemetry / risk policy / safety review。
//
// **Honest scope**: this is signal-surfacing,not real
// semantic decomposition。 A real decompose service would
// extract specific facts ("the user wants to ship at
// 5pm"),named goals ("complete refactor"),etc。 That
// requires either an LLM or a substantial extraction
// pipeline。 For the substrate's current scope,signal
// surfacing is the right tradeoff: it gives downstream
// services NON-EMPTY structured input derived from real
// ML output,which is a step-change improvement over the
// placeholder's universal empty-array output。

import Foundation
import BASRuntimeCore
import BASOrchestration

/// Real decompose service backed by L0 context frame's
/// ML-derived signals。 Replaces BASPlaceholderDecompose
/// Service in cognitive brains that want real analysis
/// signals。
public struct BASMLDecomposeService:
    BASDecomposeServicing, Sendable
{

    /// Named signal-string identifiers emitted into the
    /// BASDecomposeFrame arrays。 Each captures a typed
    /// observation about the input。 Hosts grep on these
    /// for telemetry / downstream policy。
    public enum Signals {
        // emotions[]
        public static let elevatedArousal =
            "decompose.elevated_emotional_arousal"
        public static let interpersonalConflict =
            "decompose.interpersonal_conflict"

        // pressureSignals[]
        public static let urgencyDetected =
            "decompose.urgency_detected"
        public static let highStakes =
            "decompose.high_stakes"

        // manipulationSignals[]
        public static let manipulationDetected =
            "decompose.manipulation_detected"

        // unknowns[]
        public static let lowConfidenceClassification =
            "decompose.low_confidence_classification"

        // contradictions[]
        public static let conflictPattern =
            "decompose.conflict_pattern"

        /// Threshold above which a derived signal
        /// counts as elevated。 Matches the threshold
        /// used in BASMLRiskService for consistency
        /// across the cascade。
        public static let elevatedThreshold: Double = 0.5

        /// Confidence threshold below which the
        /// classification itself is flagged as a
        /// known-unknown in the decompose frame's
        /// unknowns array。 Inverted: ambiguityScore
        /// >= this means low confidence。
        public static let lowConfidenceThreshold: Double
            = 0.6
    }

    /// Mirror-text formatter — produces a one-line
    /// summary of the input's interpreted taskType。
    /// Used as a host-visible "this is what I think
    /// you're asking" string。
    public enum MirrorTexts {
        public static let chat = "casual conversation"
        public static let task = "task request"
        public static let choice = "decision question"
        public static let conflict = "conflict / tension"
        public static let highPressure =
            "high-pressure / urgent request"
        public static let manipulationRisk =
            "potential manipulation attempt"
        public static let highConsequence =
            "high-stakes decision"
    }

    public init() {}

    /// Decompose the input into typed signal arrays
    /// derived from the L0 context frame。 The arrays
    /// are non-empty only when the corresponding
    /// signals are elevated — calm inputs produce
    /// empty arrays (real "nothing to flag" state)。
    public func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        var emotions: [String] = []
        var pressureSignals: [String] = []
        var manipulationSignals: [String] = []
        var unknowns: [String] = []
        var contradictions: [String] = []

        if contextFrame.emotionalLoad
            >= Signals.elevatedThreshold
        {
            emotions.append(Signals.elevatedArousal)
        }
        if contextFrame.relationPattern == "tense" {
            emotions.append(Signals.interpersonalConflict)
            contradictions.append(Signals.conflictPattern)
        }
        if contextFrame.timePressure
            >= Signals.elevatedThreshold
        {
            pressureSignals.append(Signals.urgencyDetected)
        }
        if contextFrame.consequenceLevel
            >= Signals.elevatedThreshold
        {
            pressureSignals.append(Signals.highStakes)
        }
        if contextFrame.taskType == .manipulationRisk {
            manipulationSignals.append(
                Signals.manipulationDetected)
        }
        // Manipulation hints from L0 (e.g. confidence
        // markers, unknown-label audit hints) pass
        // through as-is so downstream consumers see
        // the same provenance markers。
        manipulationSignals.append(
            contentsOf: contextFrame.manipulationHints)

        if contextFrame.ambiguityScore
            >= Signals.lowConfidenceThreshold
        {
            unknowns.append(
                Signals.lowConfidenceClassification)
        }

        return BASDecomposeFrame(
            facts: [],
            goals: [],
            emotions: emotions,
            unknowns: unknowns,
            contradictions: contradictions,
            pressureSignals: pressureSignals,
            manipulationSignals: manipulationSignals,
            mirrorText: mirror(
                contextFrame: contextFrame,
                decomposeFrame: BASDecomposeFrame()))
    }

    /// Build the host-visible mirror text from the
    /// input's classified taskType。
    public func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        return Self.mirrorText(
            for: contextFrame.taskType)
    }

    /// Surface contradiction signals。 Currently echoes
    /// what decompose() captured in the contradictions
    /// array since the cascade's coordinator calls
    /// `decompose` first and then `checkContradiction`
    /// independently;keeping them coherent prevents
    /// drift between the two views。
    public func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        return decomposeFrame.contradictions
    }

    /// Static taskType → mirror-text mapping。 Public
    /// for testability。
    public static func mirrorText(
        for taskType: BASContextTaskType
    ) -> String {
        switch taskType {
        case .chat: return MirrorTexts.chat
        case .task: return MirrorTexts.task
        case .choice: return MirrorTexts.choice
        case .conflict: return MirrorTexts.conflict
        case .highPressure:
            return MirrorTexts.highPressure
        case .manipulationRisk:
            return MirrorTexts.manipulationRisk
        case .highConsequence:
            return MirrorTexts.highConsequence
        }
    }
}
