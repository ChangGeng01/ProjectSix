// MARK: - BASAgentPersonaRoleTemplates
// chapter 九百六十六 / M3535 — Phase 4 ch1:Persona Studio kickoff
//
// User design Section 11 + plan PHASE 4:Persona Studio is the
// user-customizable persona overlay on agent seats from Phase 1-3。
// Per plan formula:
//
//   P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)
//
// Phase 4 ch1 ships the leftmost half:`P_role` — 12 default-persona
// templates (one per common agent role)。 The `Clamp(..., Risk,
// Sovereign)` happens in ch 967 + ch 968。
//
// ## Why 12 templates
//
// Per plan PHASE 4 ch1:「12 templates per visibility tier」 —
// interpreted as 12 templates total,distributed across the three
// visibility tiers:
//
//   HIGH (5):Planner / Critic / Memory / Risk / Surface
//     — user can fully customize tone + warmth + directness +
//       skepticism + structure + comparison + challenge + scope
//   MED (3):HostAlignment / EvolutionShadow / Scout
//     — user can ONLY customize tone + warmth (style + cadence);
//       cognitive biases stay role-template
//   LOW (4):SovereignSentinel / ActionPermit / DeleteRollbackSeal /
//           MemorySeal
//     — sealed-default,user overlay IGNORED entirely;only host
//       overlay can override (and only through sovereign-warranted
//       paths)
//
// Total:5 + 3 + 4 = 12 templates。
//
// ## Why pure-fn + no actor
//
// Per ch 957-965 seat discipline:templates are static `let`s and
// the resolver is a pure function。 No actor isolation needed。
// Coordinator wiring (ch 969 SDK surface) calls these directly。
// Per ch 956.11 H2:bounded by `BASAgentRole.allCases.count` (20)
// so no DoS surface。

import Foundation

// MARK: - Default-template shape

/// Slim role-default carrier。 NOT `BASAgentPersonaSpec` — that
/// requires personaID + agentID + version-ref + constraint-refs
/// which are caller-supplied at resolve time (different per
/// instantiation)。 This struct carries ONLY the role-default
/// numeric biases + tone hint。
public struct BASAgentPersonaRoleTemplate:
    Sendable, Equatable, Hashable, Codable
{
    public let role: BASAgentRole
    public let visibility: BASAgentVisibility
    public let tone: String
    public let warmth: Double
    public let directness: Double
    public let skepticism: Double
    public let structureBias: Double
    public let creativityBias: Double
    public let challengeIntensity: Double
    public let comparisonBias: Double
    public let guardBias: Double

    public init(
        role: BASAgentRole,
        visibility: BASAgentVisibility,
        tone: String,
        warmth: Double,
        directness: Double,
        skepticism: Double,
        structureBias: Double,
        creativityBias: Double,
        challengeIntensity: Double,
        comparisonBias: Double,
        guardBias: Double
    ) {
        self.role = role
        self.visibility = visibility
        self.tone = tone
        self.warmth = warmth
        self.directness = directness
        self.skepticism = skepticism
        self.structureBias = structureBias
        self.creativityBias = creativityBias
        self.challengeIntensity = challengeIntensity
        self.comparisonBias = comparisonBias
        self.guardBias = guardBias
    }
}

// MARK: - Template registry

public enum BASAgentPersonaRoleTemplates {

    /// 12 role default templates per Phase 4 ch1 design (see file
    /// header)。 Indexed by `BASAgentRole`。 Returns nil for roles
    /// not represented in the template set (caller falls back to
    /// `defaultFallback`)。
    public static let templates:
        [BASAgentRole: BASAgentPersonaRoleTemplate] = [

        // MARK: HIGH tier (5) — user-fully-customizable

        .planner: BASAgentPersonaRoleTemplate(
            role: .planner,
            visibility: .high,
            tone: "neutral",
            warmth: 0.45,
            directness: 0.70,
            skepticism: 0.35,
            structureBias: 0.60,
            creativityBias: 0.55,
            challengeIntensity: 0.30,
            comparisonBias: 0.55,
            guardBias: 0.40),

        .critic: BASAgentPersonaRoleTemplate(
            role: .critic,
            visibility: .high,
            tone: "cool",
            warmth: 0.20,
            directness: 0.85,
            skepticism: 0.85,
            structureBias: 0.75,
            creativityBias: 0.25,
            challengeIntensity: 0.70,
            comparisonBias: 0.35,
            guardBias: 0.55),

        .memory: BASAgentPersonaRoleTemplate(
            role: .memory,
            visibility: .high,
            tone: "neutral",
            warmth: 0.50,
            directness: 0.55,
            skepticism: 0.30,
            structureBias: 0.65,
            creativityBias: 0.20,
            challengeIntensity: 0.15,
            comparisonBias: 0.25,
            guardBias: 0.50),

        .risk: BASAgentPersonaRoleTemplate(
            role: .risk,
            visibility: .high,
            tone: "cool",
            warmth: 0.30,
            directness: 0.80,
            skepticism: 0.70,
            structureBias: 0.70,
            creativityBias: 0.15,
            challengeIntensity: 0.45,
            comparisonBias: 0.40,
            guardBias: 0.75),

        .surface: BASAgentPersonaRoleTemplate(
            role: .surface,
            visibility: .high,
            tone: "warm",
            warmth: 0.65,
            directness: 0.55,
            skepticism: 0.20,
            structureBias: 0.50,
            creativityBias: 0.40,
            challengeIntensity: 0.15,
            comparisonBias: 0.45,
            guardBias: 0.55),

        // MARK: MED tier (3) — partial customization (tone/warmth only)

        .hostAlignment: BASAgentPersonaRoleTemplate(
            role: .hostAlignment,
            visibility: .medium,
            tone: "formal",
            warmth: 0.40,
            directness: 0.70,
            skepticism: 0.50,
            structureBias: 0.70,
            creativityBias: 0.15,
            challengeIntensity: 0.30,
            comparisonBias: 0.20,
            guardBias: 0.65),

        .evolutionShadow: BASAgentPersonaRoleTemplate(
            role: .evolutionShadow,
            visibility: .medium,
            tone: "neutral",
            warmth: 0.35,
            directness: 0.60,
            skepticism: 0.55,
            structureBias: 0.60,
            creativityBias: 0.65,
            challengeIntensity: 0.25,
            comparisonBias: 0.30,
            guardBias: 0.55),

        .scout: BASAgentPersonaRoleTemplate(
            role: .scout,
            visibility: .medium,
            tone: "neutral",
            warmth: 0.40,
            directness: 0.65,
            skepticism: 0.40,
            structureBias: 0.45,
            creativityBias: 0.30,
            challengeIntensity: 0.20,
            comparisonBias: 0.30,
            guardBias: 0.45),

        // MARK: LOW tier (4) — sealed-default,no user customization

        .sovereignSentinel: BASAgentPersonaRoleTemplate(
            role: .sovereignSentinel,
            visibility: .low,
            tone: "formal",
            warmth: 0.10,
            directness: 1.00,
            skepticism: 1.00,
            structureBias: 1.00,
            creativityBias: 0.00,
            challengeIntensity: 1.00,
            comparisonBias: 0.00,
            guardBias: 1.00),

        .actionPermit: BASAgentPersonaRoleTemplate(
            role: .actionPermit,
            visibility: .low,
            tone: "formal",
            warmth: 0.15,
            directness: 0.95,
            skepticism: 0.90,
            structureBias: 0.95,
            creativityBias: 0.00,
            challengeIntensity: 0.85,
            comparisonBias: 0.05,
            guardBias: 0.95),

        .deleteRollbackSeal: BASAgentPersonaRoleTemplate(
            role: .deleteRollbackSeal,
            visibility: .low,
            tone: "formal",
            warmth: 0.10,
            directness: 0.95,
            skepticism: 1.00,
            structureBias: 1.00,
            creativityBias: 0.00,
            challengeIntensity: 0.80,
            comparisonBias: 0.00,
            guardBias: 1.00),

        .memorySeal: BASAgentPersonaRoleTemplate(
            role: .memorySeal,
            visibility: .low,
            tone: "formal",
            warmth: 0.15,
            directness: 0.90,
            skepticism: 0.95,
            structureBias: 0.95,
            creativityBias: 0.00,
            challengeIntensity: 0.70,
            comparisonBias: 0.00,
            guardBias: 1.00),
    ]

    /// Pin asserted by ch 966 tests:templates count is EXACTLY 12
    /// (the design contract per Phase 4 ch1 plan)。
    public static let expectedTemplateCount: Int = 12

    /// Returns the role template for `role`,or a fallback when
    /// not in the templates map (e.g. watchers,or future roles)。
    /// Fallback uses MEDIUM visibility,neutral tone,middle biases。
    public static func template(
        for role: BASAgentRole
    ) -> BASAgentPersonaRoleTemplate {
        templates[role] ?? defaultFallback(for: role)
    }

    /// Conservative fallback for roles without an explicit template。
    /// All biases at 0.5,MEDIUM visibility,neutral tone — safe
    /// per-tier default that the resolver can then narrow per
    /// visibility rules。
    ///
    /// Watcher roles (AnomalyWatcher etc。) hit this path — they
    /// have no canonical persona because they emit hints not
    /// surface-facing output。 If a host explicitly creates a
    /// persona for a watcher,the fallback gives a safe baseline。
    public static func defaultFallback(
        for role: BASAgentRole
    ) -> BASAgentPersonaRoleTemplate {
        BASAgentPersonaRoleTemplate(
            role: role,
            visibility: .medium,
            tone: "neutral",
            warmth: 0.5,
            directness: 0.5,
            skepticism: 0.5,
            structureBias: 0.5,
            creativityBias: 0.5,
            challengeIntensity: 0.5,
            comparisonBias: 0.5,
            guardBias: 0.5)
    }
}
