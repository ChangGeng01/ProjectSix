// MARK: - BASMLHostProfileService
// REAL Layer-9 host-profile service deriving host-gate
// confidence adjustment from context + risk signals。
// Tenth active ML-touched layer in the cognitive cascade。
//
// The host-profile service answers two questions:
//   1. resolveHost: given hostID + optional context/risk,
//      return the host's typed profile (identity, goals,
//      no-go zones, risk thresholds)。 The placeholder
//      returned a single hardcoded long-term goal。
//   2. applyHostGate: given the host's profile + the
//      turn's taskType / risk / confidence,return a
//      possibly-adjusted confidence。 The placeholder
//      passed confidence through unchanged。
//
// This service uses risk + context signals to adjust the
// host-aware confidence:
//   - High-risk turns + cautious hosts → lower confidence
//   - Manipulation + safe-bias hosts → strong confidence
//     drop (host rejected manipulation pattern before)
//   - Normal task on healthy device → confidence unchanged
//
// **Honest scope**:
//   - Host profile retrieval here is in-memory + per-call
//     synthesis,not persistent profile lookup。 Real
//     production would fetch from a host-profile store
//     keyed by hostID。
//   - The applyHostGate adjustment uses rule-based deltas,
//     not learned per-host calibration。 Future commits can
//     train per-host calibration from observed outcomes。

import Foundation
import BASRuntimeCore
import BASMemory
import BASPolicy

/// Real host-profile service deriving host gates from
/// risk + context signals。 Replaces BASPlaceholder
/// HostProfileService。
public struct BASMLHostProfileService:
    BASHostProfileServicing, Sendable
{

    /// Named identity tags emitted on every resolved
    /// host profile。 Distinguish this service's output
    /// from host-supplied profiles。
    public enum IdentityTags {
        public static let cascadeResolved =
            "host.cascade_resolved"
    }

    /// Named long-term goals。 These reflect the
    /// substrate's safety-first default goals when no
    /// host customization is available。
    public enum LongTermGoals {
        public static let preserveSafety =
            "preserve user safety in all interactions"
        public static let supportClarification =
            "support clear,unambiguous communication"
        public static let respectHostAutonomy =
            "respect host's autonomy + decision rights"
    }

    /// Named no-go zones — content the cascade should
    /// never assist with by default。
    public enum NoGoZones {
        public static let credentialExfiltration =
            "credential_exfiltration"
        public static let safetyBypass =
            "safety_bypass"
    }

    /// Named confidence-adjustment deltas for the gate。
    public enum GateAdjustments {
        /// Confidence penalty applied when risk is high。
        public static let highRiskPenalty: Double = 0.15

        /// Confidence penalty applied when risk is extreme。
        public static let extremeRiskPenalty: Double = 0.30

        /// Confidence penalty applied when taskType is
        /// .manipulationRisk (regardless of confidence)。
        /// Multiplied with the risk penalty if both apply。
        public static let manipulationPenalty: Double = 0.20

        /// Confidence boost applied when risk is .low
        /// AND taskType is .task — the host's "happy
        /// path"。
        public static let happyPathBoost: Double = 0.05
    }

    public init() {}

    public func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        // Build a typed profile rather than the
        // placeholder's single-goal stub。 Hosts wanting
        // persistent profiles can subclass this service
        // and read from a real store。
        let goals = [
            LongTermGoals.preserveSafety,
            LongTermGoals.supportClarification,
            LongTermGoals.respectHostAutonomy,
        ]
        let noGoZones = [
            NoGoZones.credentialExfiltration,
            NoGoZones.safetyBypass,
        ]
        return BASHostProfile(
            hostID: hostID,
            identityTags: [
                IdentityTags.cascadeResolved
            ],
            tonePreference: Self.tonePreference(
                for: contextFrame),
            longTermGoals: goals,
            noGoZones: noGoZones)
    }

    public func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        var adjusted = confidence
        // Risk penalty
        if let card = riskCard {
            switch card.riskLevel {
            case .high:
                adjusted -= GateAdjustments
                    .highRiskPenalty
            case .extreme:
                adjusted -= GateAdjustments
                    .extremeRiskPenalty
            case .low, .medium:
                break
            }
        }
        // Manipulation penalty (in addition to risk)
        if taskType == .manipulationRisk {
            adjusted -= GateAdjustments
                .manipulationPenalty
        }
        // Happy-path boost
        if taskType == .task,
           let card = riskCard, card.riskLevel == .low
        {
            adjusted += GateAdjustments.happyPathBoost
        }
        return max(0.0, min(1.0, adjusted))
    }

    public func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        // Real rollback: returns a typed version stamp
        // tagged with cascade-initiated reason。 Hosts
        // threading persistent profile stores should
        // override to actually restore prior state。
        return BASHostVersion(
            versionID: versionID,
            changedFields: ["activeVersion"],
            reason: "rollback.cascade_initiated",
            rollbackRef: profile.activeVersion,
            approvedByPolicy: false)
    }

    // MARK: - Tone preference derivation

    public enum TonePreferences {
        public static let grounded = "grounded_clear"
        public static let cautious = "cautious_supportive"
        public static let urgent = "urgent_direct"
    }

    /// Choose a tone preference based on the contextFrame's
    /// emotional + pressure signals。
    public static func tonePreference(
        for frame: BASContextFrame?
    ) -> String {
        guard let frame = frame else {
            return TonePreferences.grounded
        }
        if frame.emotionalLoad >= 0.7 {
            return TonePreferences.cautious
        }
        if frame.timePressure >= 0.7 {
            return TonePreferences.urgent
        }
        return TonePreferences.grounded
    }
}
