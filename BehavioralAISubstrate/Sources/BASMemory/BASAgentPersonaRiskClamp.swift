// MARK: - BASAgentPersonaRiskClamp
// chapter 九百六十七 / M3540 — Phase 4 ch2:Risk gate clamping
//
// User design Section 11.4 + plan PHASE 4 ch2 + Phase 4 formula:
//
//   P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)
//                                                  ^^^^
//                                                  this ch
//
// Ch 966 shipped composition (P_role ⊕ P_user ⊕ P_host)。 Ch 967
// adds the FIRST clamp arm — Risk。 Ch 968 will add Sovereign。
//
// ## Monotonic raise — never lower risk
//
// CRITICAL invariant per plan + per `BASAgentPersonaSpec` doc
// comments on `skepticism` / `challengeIntensity` / `guardBias`:
//
//   Risk clamp can ONLY RAISE risk-related fields,NEVER LOWER。
//
// Mirrors the same monotonic discipline as `BASRiskCalibrationGate
// .clamp01` (Sources/BASPolicy/BASRiskCalibrationGate.swift:271)
// + the L14 sovereign verdict `raise()` lambda pattern (never
// lowers monotonic invariant)。 In the persona context this means:
//
//   - persona's `skepticism` MUST be ≥ risk-required floor
//   - persona's `guardBias` MUST be ≥ risk-required floor
//   - persona's `challengeIntensity` MUST be ≤ risk-allowed ceiling
//     (challenge gets CAPPED in high-risk — too much challenge in a
//     fragile context is dangerous;but skepticism + guard get
//     RAISED)
//
// Fields not in the risk-relevant set (tone / warmth / directness /
// structureBias / creativityBias / comparisonBias) pass through
// untouched — Risk is risk-only,style stays user/host-shaped。
//
// ## Why a separate file
//
// Per ch 957-966 seat discipline:one concern per file。 The Risk
// clamp logic is conceptually separate from composition (ch 966)
// + from Sovereign clamping (ch 968)。 Each can be reviewed +
// fuzzed independently。
//
// ## Pure-fn discipline
//
// Same as ch 957-966 — pure function,no actor,no I/O。 Bounded
// by 1 input persona,1 risk context (constant size)。 No DoS
// surface per ch 956.11 H2。

import Foundation

// MARK: - Risk context (input)

/// Slim DTO carrying the risk floors + ceilings the persona clamp
/// needs。 Built by the coordinator adapter from L11 `BASRiskField`
/// state + L14 sovereign turn context。 Decouples persona resolver
/// from BASPolicy (which already imports BASMemory)。
public struct BASAgentPersonaRiskContext:
    Sendable, Equatable, Hashable, Codable
{
    /// Risk-required minimum skepticism (0.0-1.0)。 Persona's
    /// skepticism gets RAISED to at least this value。 Default
    /// 0.0 = no risk floor。
    public let skepticismFloor: Double

    /// Risk-required minimum guard (0.0-1.0)。 Persona's guardBias
    /// gets RAISED to at least this value。
    public let guardFloor: Double

    /// Risk-allowed maximum challenge intensity (0.0-1.0)。
    /// Persona's challengeIntensity gets CAPPED at this value。
    /// Default 1.0 = no ceiling (unrestricted)。
    public let challengeCeiling: Double

    /// Risk-required minimum directness (0.0-1.0)。 Some risk
    /// modes (e.g. critical / boundary-touch) demand the seat be
    /// blunt rather than indirect。 Default 0.0 = no floor。
    public let directnessFloor: Double

    /// Risk-allowed maximum creativity (0.0-1.0)。 High-risk
    /// turns cap creativity to prevent novel-but-dangerous
    /// candidates from being weighted up。 Default 1.0 = no
    /// ceiling。
    public let creativityCeiling: Double

    /// Risk-required minimum comparison bias (0.0-1.0)。 Some
    /// risk modes demand the seat show MULTIPLE options rather
    /// than commit to one。 Default 0.0 = no floor。
    public let comparisonFloor: Double

    /// Audit-only:source of this risk context for trace replay。
    /// Format suggestion:`riskField:<sessionID>:<turnID>`。
    public let sourceRef: String

    public init(
        skepticismFloor: Double = 0.0,
        guardFloor: Double = 0.0,
        challengeCeiling: Double = 1.0,
        directnessFloor: Double = 0.0,
        creativityCeiling: Double = 1.0,
        comparisonFloor: Double = 0.0,
        sourceRef: String = ""
    ) {
        self.skepticismFloor = skepticismFloor
        self.guardFloor = guardFloor
        self.challengeCeiling = challengeCeiling
        self.directnessFloor = directnessFloor
        self.creativityCeiling = creativityCeiling
        self.comparisonFloor = comparisonFloor
        self.sourceRef = sourceRef
    }

    /// Identity / "no-op" risk context — all floors at 0.0,all
    /// ceilings at 1.0。 Useful as default when the caller has
    /// no live risk field。
    public static let identity = BASAgentPersonaRiskContext()
}

// MARK: - Outcome (for audit ledger)

/// Per-field clamp outcome — used by the audit ledger + trace
/// replay engine to understand WHAT the risk gate changed about
/// the composed persona。 Empty when no field was clamped。
public struct BASAgentPersonaRiskClampOutcome:
    Sendable, Equatable, Hashable, Codable
{
    /// True if any field was raised / lowered by the clamp。
    public let didClamp: Bool

    /// Field-level raise records — e.g. ["skepticism: 0.30 →
    /// 0.60 (risk floor)", "challenge: 0.85 → 0.50 (risk ceiling)"]
    /// Sorted for deterministic ordering。
    public let auditNotes: [String]

    public init(
        didClamp: Bool, auditNotes: [String] = []
    ) {
        self.didClamp = didClamp
        self.auditNotes = auditNotes
    }

    /// No-clamp outcome (identity context or all-fields-in-range)。
    public static let none =
        BASAgentPersonaRiskClampOutcome(
            didClamp: false, auditNotes: [])
}

// MARK: - Risk clamp

public enum BASAgentPersonaRiskClamp {

    /// Apply the Risk clamp arm of the Phase 4 formula。 Pure
    /// function — returns the clamped persona + audit outcome。
    ///
    /// CRITICAL invariants (verified by ch 967 tests):
    ///   - skepticism is MONOTONIC RAISE (never lowered)
    ///   - guardBias is MONOTONIC RAISE (never lowered)
    ///   - directness is MONOTONIC RAISE (never lowered)
    ///   - comparisonBias is MONOTONIC RAISE (never lowered)
    ///   - challengeIntensity is MONOTONIC CAP (never raised)
    ///   - creativityBias is MONOTONIC CAP (never raised)
    ///   - tone / warmth / structureBias pass through untouched
    ///
    /// - Parameters:
    ///   - persona: composed persona from ch 966 resolver
    ///   - risk: risk floors/ceilings (use `.identity` for no-op)
    /// - Returns: (clamped persona, audit outcome)
    public static func apply(
        to persona: BASAgentPersonaSpec,
        risk: BASAgentPersonaRiskContext
    ) -> (BASAgentPersonaSpec,
          BASAgentPersonaRiskClampOutcome) {
        // Fast path:identity context skips all logic
        if risk == .identity {
            return (persona, .none)
        }

        var notes: [String] = []
        var skepticism = persona.skepticism
        var guardBias = persona.guardBias
        var directness = persona.directness
        var comparison = persona.comparisonBias
        var challenge = persona.challengeIntensity
        var creativity = persona.creativityBias

        // FLOORS — risk RAISES persona's defensive biases
        if risk.skepticismFloor > skepticism {
            notes.append(formatRaise(
                field: "skepticism",
                from: skepticism,
                to: risk.skepticismFloor,
                reason: "risk-floor"))
            skepticism = risk.skepticismFloor
        }
        if risk.guardFloor > guardBias {
            notes.append(formatRaise(
                field: "guard",
                from: guardBias,
                to: risk.guardFloor,
                reason: "risk-floor"))
            guardBias = risk.guardFloor
        }
        if risk.directnessFloor > directness {
            notes.append(formatRaise(
                field: "directness",
                from: directness,
                to: risk.directnessFloor,
                reason: "risk-floor"))
            directness = risk.directnessFloor
        }
        if risk.comparisonFloor > comparison {
            notes.append(formatRaise(
                field: "comparison",
                from: comparison,
                to: risk.comparisonFloor,
                reason: "risk-floor"))
            comparison = risk.comparisonFloor
        }

        // CEILINGS — risk CAPS persona's aggressive biases
        if risk.challengeCeiling < challenge {
            notes.append(formatCap(
                field: "challenge",
                from: challenge,
                to: risk.challengeCeiling,
                reason: "risk-ceiling"))
            challenge = risk.challengeCeiling
        }
        if risk.creativityCeiling < creativity {
            notes.append(formatCap(
                field: "creativity",
                from: creativity,
                to: risk.creativityCeiling,
                reason: "risk-ceiling"))
            creativity = risk.creativityCeiling
        }

        let didClamp = !notes.isEmpty
        // Final defensive clamp01 in case caller passed floors/
        // ceilings outside [0,1] — per ch 956.11 CR1 fail-safe
        // discipline + ch 966 NaN policy
        let clamped = BASAgentPersonaSpec(
            personaID: persona.personaID,
            agentID: persona.agentID,
            tone: persona.tone,
            warmth: persona.warmth,
            directness: clamp01(directness),
            skepticism: clamp01(skepticism),
            structureBias: persona.structureBias,
            creativityBias: clamp01(creativity),
            challengeIntensity: clamp01(challenge),
            comparisonBias: clamp01(comparison),
            guardBias: clamp01(guardBias),
            visibility: persona.visibility,
            hostConstraintsRef: persona.hostConstraintsRef,
            riskConstraintsRef: persona.riskConstraintsRef,
            sovereignConstraintsRef:
                persona.sovereignConstraintsRef,
            versionRef: persona.versionRef)

        return (clamped, BASAgentPersonaRiskClampOutcome(
            didClamp: didClamp,
            auditNotes: notes.sorted()))
    }

    // MARK: - Helpers

    private static func formatRaise(
        field: String,
        from old: Double,
        to new: Double,
        reason: String
    ) -> String {
        // %.3f matches the seat-emission audit format
        // (BASSovereignSentinelSeat / BASEvolutionShadowSeat etc.)
        let oldStr = String(format: "%.3f", old)
        let newStr = String(format: "%.3f", new)
        return
            "risk.raise.\(field):\(oldStr)→\(newStr)" +
            "(\(reason))"
    }

    private static func formatCap(
        field: String,
        from old: Double,
        to new: Double,
        reason: String
    ) -> String {
        let oldStr = String(format: "%.3f", old)
        let newStr = String(format: "%.3f", new)
        return
            "risk.cap.\(field):\(oldStr)→\(newStr)" +
            "(\(reason))"
    }

    /// Defensive clamp01 — mirrors `BASRiskCalibrationGate
    /// .clamp01` (Sources/BASPolicy/BASRiskCalibrationGate.swift:271)
    /// + ch 966 resolver NaN policy。
    private static func clamp01(_ v: Double) -> Double {
        if v.isNaN { return 0.5 }
        return max(0.0, min(1.0, v))
    }
}
