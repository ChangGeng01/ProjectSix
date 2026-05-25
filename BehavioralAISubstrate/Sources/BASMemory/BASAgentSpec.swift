// MARK: - BASAgentSpec
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.1:
//
//   AgentSpec
//   - agent_id
//   - role
//   - layer_affinity[]          # L6 / L7 / L8 / L9 / L11 ...
//   - read_domains[]
//   - write_domains[]
//   - propose_domains[]
//   - forbidden_domains[]
//   - default_lease_profile
//   - persona_ref
//   - visibility
//   - commit_capability         # normally false
//
// This struct is the agent identity + capability declaration。 Each
// agent in the registry (Phase 0 ch 956) is registered with a spec。
// The Agent Router consults spec.read/write/propose/forbidden domains
// to enforce Single-Writer-Per-Domain invariant per turn。
//
// Sendable value type — safe to pass across actor boundaries。
// Equatable + Hashable enable change detection + caching keys。
// Codable enables persistence + replay (Phase 0 ch 955 trace log)。

import Foundation

public struct BASAgentSpec:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique identifier for this agent within the fabric。
    /// Format suggestion: `<role>.<host>.v<N>`,e.g.
    /// `planner.qinao-host.v1`,`watcher-anomaly.qinao-host.v3`。
    public let agentID: String

    /// The semantic role this agent plays per BASAgentRole enum。
    /// Drives default behavior + visibility tier + writer rights。
    public let role: BASAgentRole

    /// Which L1-L14 layers this agent reads from。 Empty = layer-agnostic
    /// (rare; mostly LOW-tier sovereign agents)。
    public let layerAffinity: [Int]

    /// State domains this agent can READ from。 The Agent Router enforces
    /// this per turn — agent attempting to read outside this set gets
    /// a hard error (not a silent zero-result)。
    public let readDomains: [BASStateDomain]

    /// State domains this agent owns as single writer。 Per Single-Writer
    /// invariant,exactly 0 or 1 domain typically (more = composite role)。
    /// Empty = read-only / propose-only agent (e.g. watchers, critic)。
    public let writeDomains: [BASStateDomain]

    /// State domains this agent can propose deltas against (without
    /// being the writer)。 Merge engine routes proposals to the writer
    /// owner of each domain。 Critic agent typically has
    /// `propose: [candidateFrontier]` but NO write rights。
    public let proposeDomains: [BASStateDomain]

    /// State domains this agent must NEVER touch — defense in depth。
    /// Enforced at proposal-emit time + at merge time + at state-read
    /// time。 Useful for sovereign-sealed agents (e.g. SovereignSentinel
    /// has `forbidden: [hostVersion, memoryBundle]` — only reads sovereign
    /// state)。
    public let forbiddenDomains: [BASStateDomain]

    /// Reference to one of the canned BASAgentLeaseProfile values。
    /// The Agent Lease Manager (Phase 0 ch 956) materializes a per-turn
    /// `BASAgentLease` from this profile + the current turn budget。
    public let defaultLeaseProfile: BASAgentLeaseProfile

    /// Optional reference to a `BASAgentPersonaSpec.personaID`。 nil
    /// = use role-template default per Phase 4 ch 966。 Decoupled from
    /// spec so persona can change without re-registering the agent。
    public let personaRef: String?

    /// Default visibility tier — driven by role but explicitly recorded
    /// so the resolver doesn't need to maintain a role→tier map in two
    /// places。 HIGH = user-customizable persona overlay; MED = partial;
    /// LOW = sovereign-sealed,no overlay。
    public let visibility: BASAgentVisibility

    /// Whether this agent can call `BASUnifiedCommitGate.commit()`。
    /// Per user's design,this is normally FALSE for all agents — only
    /// L14 SovereignSentinel + the unified commit gate itself may
    /// commit。 Set true ONLY for the SovereignSentinel role。
    public let commitCapability: Bool

    public init(
        agentID: String,
        role: BASAgentRole,
        layerAffinity: [Int] = [],
        readDomains: [BASStateDomain] = [],
        writeDomains: [BASStateDomain] = [],
        proposeDomains: [BASStateDomain] = [],
        forbiddenDomains: [BASStateDomain] = [],
        defaultLeaseProfile: BASAgentLeaseProfile,
        personaRef: String? = nil,
        visibility: BASAgentVisibility,
        commitCapability: Bool = false
    ) {
        self.agentID = agentID
        self.role = role
        self.layerAffinity = layerAffinity
        self.readDomains = readDomains
        self.writeDomains = writeDomains
        self.proposeDomains = proposeDomains
        self.forbiddenDomains = forbiddenDomains
        self.defaultLeaseProfile = defaultLeaseProfile
        self.personaRef = personaRef
        self.visibility = visibility
        self.commitCapability = commitCapability
    }
}
