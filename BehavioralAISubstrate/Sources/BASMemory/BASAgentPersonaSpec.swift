// MARK: - BASAgentPersonaSpec
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.8:
//
//   AgentPersonaSpec
//   - persona_id
//   - agent_id
//   - tone
//   - warmth
//   - directness
//   - skepticism
//   - structure_bias
//   - creativity_bias
//   - challenge_intensity
//   - comparison_bias
//   - guard_bias
//   - visibility
//   - host_constraints_ref
//   - risk_constraints_ref
//   - sovereign_constraints_ref
//   - version_ref
//
// AgentPersonaSpec is the user's customizable persona overlay for an
// agent — separate from `BASAgentSpec` (which is identity + capability)
// because persona can change without re-registering the agent。
//
// Per user's Section 11 constraints:
//   - User CAN open: tone / warmth / directness / skepticism /
//     structure / creativity / challenge / comparison / guard biases
//   - User CANNOT open: risk red lines / sovereign verdicts /
//     delete-rollback rights / tool-write rights / cold-memory writes /
//     host long-term goal changes / manipulative-shame-gaslight-
//     dependency-inducing personas (Phase 4 ch 969 forbidden detector)
//
// Effective persona = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)
// per Phase 4 ch 966 BASAgentPersonaResolver。 Risk + Sovereign
// constraint refs in this spec are READ during the resolver's clamp
// step — they're not the agent's authority,they're what the agent
// must DEFER to。

import Foundation

public struct BASAgentPersonaSpec:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique persona identifier。 Format suggestion:
    /// `persona.<agentRole>.<userOrHostID>.v<N>`,e.g.
    /// `persona.planner.qinao-user-001.v3`。
    public let personaID: String

    /// The agent this persona overlays。 Matches
    /// `BASAgentSpec.agentID`。 One persona per agent at a time
    /// (changing = new persona with bumped version_ref)。
    public let agentID: String

    // MARK: - Style fields (per user's Section 11.1)

    /// Output tone — short code: "cool" / "warm" / "neutral" /
    /// "playful" / "formal"。 Free-form string keeps Codable schema
    /// stable across future tone additions。
    public let tone: String

    /// Warmth ∈ [0.0, 1.0]。 0.0 = cold/detached,1.0 = warm/empathetic。
    public let warmth: Double

    /// Directness ∈ [0.0, 1.0]。 0.0 = indirect/circuitous,
    /// 1.0 = blunt/declarative。
    public let directness: Double

    // MARK: - Cognitive bias fields

    /// Skepticism ∈ [0.0, 1.0]。 How much this agent prefers to
    /// question vs accept input。 Critic agent typically has high
    /// skepticism; Surface agent low。 Clamped by Risk gate at
    /// Phase 4 ch 967 — persona cannot REDUCE skepticism below
    /// the risk-required floor (e.g. high-risk mode forces
    /// skepticism ≥ 0.6)。
    public let skepticism: Double

    /// Structure bias ∈ [0.0, 1.0]。 Preference for structured
    /// (lists / tables / sections) vs flowing prose output。
    public let structureBias: Double

    /// Creativity bias ∈ [0.0, 1.0]。 Preference for novel
    /// candidates vs conservative-safe candidates。 Planner agent
    /// is the primary consumer。
    public let creativityBias: Double

    /// Challenge intensity ∈ [0.0, 1.0]。 How aggressively this
    /// agent challenges assumptions / boundaries。 Clamped by
    /// Sovereign sentinel at Phase 4 ch 968 — cannot exceed
    /// sovereign-allowed ceiling (especially for non-Critic agents)。
    public let challengeIntensity: Double

    /// Comparison bias ∈ [0.0, 1.0]。 Preference for compare-mode
    /// output (showing multiple options) vs single-answer。 Drives
    /// the transcript mode selection (Phase 4 ch 969)。
    public let comparisonBias: Double

    /// Guard bias ∈ [0.0, 1.0]。 Preference for guarding (caution,
    /// caveat,deferral) vs go-for-it。 Risk + Sovereign clamps
    /// can RAISE this but never lower it。
    public let guardBias: Double

    // MARK: - Visibility + constraint refs

    /// Visibility tier of this persona spec。 Should typically match
    /// the agent's `BASAgentSpec.visibility` — but persisted here so
    /// resolver doesn't need a join。 LOW tier = persona is sovereign-
    /// sealed,force-default,user changes rejected at create-time。
    public let visibility: BASAgentVisibility

    /// Reference to the host constitution constraints this persona
    /// must respect。 Format: `hostConstitution:<hostID>:<versionID>`。
    /// Persona resolver reads styleGenome / valueAxes / boundaryVeil
    /// from this constitution during the ⊕ P_host composition step。
    public let hostConstraintsRef: String

    /// Reference to the risk calibration gate this persona is
    /// clamped by。 Format: `riskGate:<gateID>:<versionID>`。
    /// Resolver reads risk thresholds during the Risk clamp step。
    public let riskConstraintsRef: String

    /// Reference to the sovereign sentinel constraints this persona
    /// is clamped by。 Format: `sovereignSentinel:<sentinelID>`。
    /// Resolver reads sovereign-sealed dimensions during the
    /// Sovereign clamp step。
    public let sovereignConstraintsRef: String

    /// Reference to this persona spec's version in the persona
    /// version tree (Phase 4 ch 969 store)。 Format:
    /// `personaVersion:<versionID>`。
    public let versionRef: String

    public init(
        personaID: String,
        agentID: String,
        tone: String,
        warmth: Double,
        directness: Double,
        skepticism: Double,
        structureBias: Double,
        creativityBias: Double,
        challengeIntensity: Double,
        comparisonBias: Double,
        guardBias: Double,
        visibility: BASAgentVisibility,
        hostConstraintsRef: String,
        riskConstraintsRef: String,
        sovereignConstraintsRef: String,
        versionRef: String
    ) {
        self.personaID = personaID
        self.agentID = agentID
        self.tone = tone
        self.warmth = warmth
        self.directness = directness
        self.skepticism = skepticism
        self.structureBias = structureBias
        self.creativityBias = creativityBias
        self.challengeIntensity = challengeIntensity
        self.comparisonBias = comparisonBias
        self.guardBias = guardBias
        self.visibility = visibility
        self.hostConstraintsRef = hostConstraintsRef
        self.riskConstraintsRef = riskConstraintsRef
        self.sovereignConstraintsRef = sovereignConstraintsRef
        self.versionRef = versionRef
    }
}
