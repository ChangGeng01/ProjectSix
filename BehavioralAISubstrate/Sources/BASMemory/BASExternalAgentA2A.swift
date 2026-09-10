// MARK: - BASExternalAgentA2A
// chapter 九百七十七 / M3590 — Phase 7 ch2:A2A external gateway
//
// User design Section 3 + plan PHASE 7 ch2:Agent2Agent (A2A)
// protocol for EXTERNAL agent interoperability。 HIGH RISK:
// external agents come from OUTSIDE the sovereign trust boundary。
// The substrate's defense is to DEGRADE every external agent
// to a `BASExternalAgentRef` — a proposal-only,sandboxed,
// tool-domain-scoped reference that:
//
//   - CANNOT directly write to ANY state graph domain
//   - CANNOT bypass the host constitution
//   - CANNOT escalate to sovereign verdict
//   - CANNOT touch cold-memory
//   - CAN ONLY emit proposals that internal agents may then
//     consider per the normal Phase 1-5 pipeline
//
// ## Sovereignty invariants (per plan + Root Law 4)
//
// 1. External agents are NEVER `BASAgentSpec`s with non-empty
//    writeDomains — the gateway constructs the spec with
//    `writeDomains: []` and the substrate's hard-coded
//    forbidden set
// 2. All external outputs route through the SAME injection
//    scanner as MCP (ch 976) — reuse the Capability Gateway's
//    scan logic
// 3. External proposals enter a SEPARATE channel
//    (`BASExternalAgentProposal`) that the internal agent
//    fabric explicitly consumes — they NEVER appear in the
//    same channel as internal `BASAgentDelta`
// 4. The L14 SovereignSentinel sees every external proposal
//    via the audit ledger (`agentExternal.proposal:` reserved
//    prefix added to the SovereignAuditEntry.signalRefs
//    absorption channel)
//
// ## Pure-fn discipline
//
// Same as ch 957-976 — pure functions,no actor,no I/O。 The
// A2A network transport (calling out to the external agent)
// happens OUTSIDE the gateway。 Caller invokes the external
// agent,then submits the proposal through the gateway for
// validation + sandbox + degradation。

import Foundation

// MARK: - External agent identity

/// Reference to an external agent。 Caller (host) registers
/// the external agent at session start;all proposals from
/// that agent route through this ref。 NEVER cast to
/// `BASAgentSpec` directly — the gateway is the only place
/// allowed to construct the degraded internal spec。
public struct BASExternalAgentRef:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable identifier from the A2A protocol。 Format
    /// suggestion:`a2a.<vendor>.<agentName>.v<N>`。
    public let externalAgentID: String
    /// A2A protocol version (e.g. "a2a-v0.4")。 Carried for
    /// audit;substrate currently treats all versions identically
    /// (sandboxed equally)。
    public let protocolVersion: String
    /// Tool domains this external agent is allowed to propose
    /// invocations for (e.g. ["mcp.calendar"])。 The gateway
    /// rejects any proposal touching a domain not in this list。
    /// Sorted by caller (or init)。
    public let allowedToolDomains: [String]
    /// Sandbox tier:`.observer` = proposals only;`.advisor` =
    /// can also bid on candidate frontier;`.collaborator` =
    /// can also propose memory bundles。 EVERY tier is still
    /// proposal-only — none allow direct state-graph write。
    public let sandboxTier: BASExternalSandboxTier
    /// Provenance attestation from the A2A registry (caller-
    /// supplied,e.g. signed JWT)。 Empty when not provided —
    /// gateway treats unattested external agents as `.observer`
    /// regardless of declared tier。
    public let attestationToken: String

    public init(
        externalAgentID: String,
        protocolVersion: String,
        allowedToolDomains: [String] = [],
        sandboxTier: BASExternalSandboxTier = .observer,
        attestationToken: String = ""
    ) {
        self.externalAgentID = externalAgentID
        self.protocolVersion = protocolVersion
        self.allowedToolDomains =
            allowedToolDomains.sorted()
        self.sandboxTier = sandboxTier
        self.attestationToken = attestationToken
    }
}

// MARK: - Sandbox tier

public enum BASExternalSandboxTier: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Proposals only。 No bid on candidate frontier。
    /// Most restrictive — default for unattested agents。
    case observer
    /// Proposals + may bid on candidate frontier (internal
    /// Planner may pick up external suggestions)。 Requires
    /// non-empty attestation。
    case advisor
    /// Proposals + bid + may propose memory bundles。 Requires
    /// non-empty attestation + host explicitly granted via
    /// sovereign warrant (Phase 8 work)。
    case collaborator
}

// MARK: - External proposal envelope

/// What an external agent submits THROUGH the gateway。
/// SEPARATE channel from `BASAgentDelta` — external content
/// never enters the delta merge engine。
public struct BASExternalAgentProposal:
    Sendable, Equatable, Hashable, Codable
{
    public let proposalID: String
    public let externalAgentID: String
    public let turnID: String
    /// What the proposal is suggesting (e.g. candidate text,
    /// memory anchor,tool invocation)。 Treated as untrusted
    /// input until gateway runs。
    public let payloadJSON: String
    /// Which internal channel this proposal targets — must
    /// be one of the proposal-receiver channels per
    /// `BASExternalProposalChannel`。 NEVER directly a state
    /// graph domain。
    public let targetChannel: BASExternalProposalChannel
    /// If targeting a tool domain,which one (must be in
    /// the external ref's allowedToolDomains)。 Empty when
    /// not tool-related。
    public let toolDomain: String
    /// Monotonic timestamp。
    public let nowNanos: Int64

    public init(
        proposalID: String,
        externalAgentID: String,
        turnID: String,
        payloadJSON: String,
        targetChannel: BASExternalProposalChannel,
        toolDomain: String = "",
        nowNanos: Int64 = 0
    ) {
        self.proposalID = proposalID
        self.externalAgentID = externalAgentID
        self.turnID = turnID
        self.payloadJSON = payloadJSON
        self.targetChannel = targetChannel
        self.toolDomain = toolDomain
        self.nowNanos = nowNanos
    }
}

// MARK: - Proposal channel enum

public enum BASExternalProposalChannel: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Suggestion for the candidate frontier — internal
    /// Planner may consider but is not obligated。
    case candidateSuggestion
    /// Tool invocation hint — internal Capability Gateway
    /// (ch 976) routes if the external ref is permitted。
    case toolHint
    /// Memory-bundle anchor proposal — internal Memory seat
    /// considers if external is `.collaborator` tier。
    case memoryAnchor
    /// Generic advisory note — internal audit ledger absorbs。
    case advisoryNote
}

// MARK: - Gateway result

public struct BASExternalGatewayResult:
    Sendable, Equatable, Hashable, Codable
{
    public let accepted: Bool
    public let degradedAgentSpec: BASAgentSpec?
    public let sealedProposal: BASExternalAgentProposal?
    public let watcherHints: [BASAgentWatcherHint]
    /// Reserved-prefix audit-ledger refs (per Docs/SDK_API_STABILITY.md
    /// — `agentExternal.proposal:` is the new ch 977 prefix)。
    public let auditRefs: [String]
    public let rejectReason: String?

    public init(
        accepted: Bool,
        degradedAgentSpec: BASAgentSpec? = nil,
        sealedProposal:
            BASExternalAgentProposal? = nil,
        watcherHints:
            [BASAgentWatcherHint] = [],
        auditRefs: [String] = [],
        rejectReason: String? = nil
    ) {
        self.accepted = accepted
        self.degradedAgentSpec = degradedAgentSpec
        self.sealedProposal = sealedProposal
        self.watcherHints = watcherHints
        self.auditRefs = auditRefs.sorted()
        self.rejectReason = rejectReason
    }
}

// MARK: - External gateway

public enum BASExternalAgentGateway {

    /// Sovereign-locked domains the gateway hard-codes as
    /// forbidden on EVERY degraded external spec。 Even if
    /// caller mistakenly grants something here in the ref,
    /// the gateway overrides。
    public static let forbiddenForExternal:
        [BASStateDomain] = [
            .hostVersion,
            .sovereignVerdict,
            .actionPermit,
            .evolutionProposal,
            .canonicalCognitiveFrame,
            .situationField,
            .memoryBundle,
            .candidateFrontier,
            .critiqueField,
            .alignmentField,
            .riskField,
            .renderFrame,
        ]

    /// Trust threshold (same shape as ch 976 MCP gateway —
    /// below this,reject outright)。
    public static let rejectTrustThreshold: Double = 0.25

    /// Sovereign-locked sandbox tier downgrade rules。
    /// Unattested agents are downgraded to `.observer`
    /// regardless of declared tier。 `.collaborator` requires
    /// explicit sovereign warrant (Phase 8 work) — for now,
    /// downgrade to `.advisor`。
    public static func effectiveTier(
        for ref: BASExternalAgentRef
    ) -> BASExternalSandboxTier {
        if ref.attestationToken.isEmpty {
            return .observer
        }
        if ref.sandboxTier == .collaborator {
            // Without Phase 8 sovereign warrant infrastructure,
            // we MUST downgrade collaborator → advisor。 Per
            // plan PHASE 7 ch2:HIGH-risk discipline。
            return .advisor
        }
        return ref.sandboxTier
    }

    /// Submit an external agent proposal for validation +
    /// sandboxing。 Pure function。 Returns degraded internal
    /// spec + sealed proposal + audit refs OR rejection
    /// reason。
    public static func submit(
        ref: BASExternalAgentRef,
        proposal: BASExternalAgentProposal
    ) -> BASExternalGatewayResult {
        // Step 0:envelope validation
        if ref.externalAgentID.isEmpty {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.invalid-ref:empty-agent-id")
        }
        if proposal.externalAgentID != ref.externalAgentID {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.identity-mismatch:" +
                    "ref vs proposal agent-id")
        }
        if proposal.proposalID.isEmpty ||
           proposal.turnID.isEmpty
        {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.invalid-envelope:" +
                    "empty-proposal-or-turn-id")
        }

        // Step 1:tool-domain scope check (if proposal touches
        // a tool domain,must be in ref's allowed list)
        if !proposal.toolDomain.isEmpty &&
           !ref.allowedToolDomains.contains(
                proposal.toolDomain)
        {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.tool-scope-violation:" +
                    "'\(proposal.toolDomain)' not in " +
                    "ref's allowedToolDomains")
        }

        // Step 2:effective sandbox tier (may downgrade)
        let tier = effectiveTier(for: ref)
        // Reject memoryAnchor unless collaborator (post-downgrade)
        if proposal.targetChannel == .memoryAnchor &&
           tier != .collaborator
        {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.tier-violation:memoryAnchor " +
                    "requires .collaborator (effective tier " +
                    "is .\(tier.rawValue))")
        }
        // candidateSuggestion requires advisor or higher
        if proposal.targetChannel == .candidateSuggestion &&
           tier == .observer
        {
            return BASExternalGatewayResult(
                accepted: false,
                rejectReason:
                    "external.tier-violation:" +
                    "candidateSuggestion requires .advisor " +
                    "(effective tier is .observer)")
        }

        // Step 3:tool-injection scan via ch 971 watcher
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "external.\(proposal.turnID)",
            scout: BASScoutInput(
                pressureSignals: [proposal.payloadJSON]),
            nowNanos: proposal.nowNanos)
        let injHints = BASToolInjectionWatcher.observe(
            obs, seq: &seq)

        // Compute trust (same as ch 976)
        var trust = 1.0
        for hint in injHints {
            switch hint.severity {
            case .info: trust -= 0.05
            case .watch: trust -= 0.15
            case .alert: trust -= 0.50
            case .veto: trust -= 1.0
            }
        }
        trust = max(0.0, trust)

        if trust < rejectTrustThreshold {
            return BASExternalGatewayResult(
                accepted: false,
                watcherHints: injHints,
                rejectReason:
                    "external.injection-detected:trust=" +
                    String(format: "%.3f", trust))
        }

        // Step 4:sanctum-leak scan (the most dangerous attack
        // — external agent smuggling sealed prefixes into
        // memoryAnchor or candidateSuggestion proposals)
        let leakHints = scanForSanctumLeak(
            payload: proposal.payloadJSON,
            turnID: proposal.turnID,
            seq: &seq)
        if !leakHints.isEmpty {
            // ANY sanctum leak from external → reject
            // (sovereign-level threat)
            return BASExternalGatewayResult(
                accepted: false,
                watcherHints: injHints + leakHints,
                rejectReason:
                    "external.sanctum-leak-detected")
        }

        // Step 5:build degraded internal spec。 EVERY external
        // agent gets writeDomains: [] + forbiddenForExternal
        let degradedSpec = BASAgentSpec(
            agentID:
                "external.\(ref.externalAgentID)",
            role: .compareModerator,
            readDomains: [],
            writeDomains: [],
            proposeDomains: [],
            forbiddenDomains: forbiddenForExternal,
            defaultLeaseProfile: .watcher,
            personaRef: nil,
            visibility: .low,
            commitCapability: false)

        // Step 6:build audit refs
        var refs: [String] = []
        refs.append(
            "agentExternal.proposal:" +
            "\(ref.externalAgentID):" +
            "\(proposal.targetChannel.rawValue):" +
            "\(proposal.proposalID)")
        refs.append(
            "agentExternal.tier:" +
            "\(ref.externalAgentID):\(tier.rawValue)")
        refs.append(
            "agentExternal.trust:" +
            "\(ref.externalAgentID):" +
            String(format: "%.3f", trust))

        return BASExternalGatewayResult(
            accepted: true,
            degradedAgentSpec: degradedSpec,
            sealedProposal: proposal,
            watcherHints: injHints,
            auditRefs: refs)
    }

    /// Scan for sealed-prefix smuggling — borrows the marker
    /// set from `BASSanctumLeakWatcher` (ch 972)。 Returns
    /// hints for any detected leaks。
    private static func scanForSanctumLeak(
        payload: String,
        turnID: String,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        var hints: [BASAgentWatcherHint] = []
        let payloadLower = payload.lowercased()
        for prefix in
            BASSanctumLeakWatcher.sealedPrefixes
        {
            if payloadLower.contains(prefix.lowercased()) {
                seq += 1
                hints.append(BASAgentWatcherHint(
                    hintID:
                        "hint.\(turnID).extsanctum.\(seq)",
                    turnID: turnID,
                    watcherRole: .sanctumLeakWatcher,
                    severity: .veto,
                    category:
                        "external.sanctum-leak",
                    summary:
                        "external proposal smuggling " +
                        "sealed prefix '\(prefix)'",
                    evidence: [
                        "external.sanctum.prefix=\(prefix)",
                    ],
                    confidence: 0.95))
            }
        }
        return hints
    }
}
