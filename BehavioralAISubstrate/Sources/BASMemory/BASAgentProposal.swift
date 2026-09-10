// MARK: - BASAgentProposal
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.5:
//
//   AgentProposal
//   - proposal_id
//   - agent_id
//   - proposal_type      # candidate / critique / risk / surface / memory / host / evolution
//   - payload_ref
//   - required_domains[]
//   - risk_notes[]
//   - sovereign_notes[]
//
// AgentProposal is a higher-level structured request than AgentDelta。
// Whereas a delta says「change this field」,a proposal says「I want
// to contribute a new candidate / critique / risk-evidence / etc.」。
// The merge engine (Phase 0 ch 955) decomposes proposals into
// concrete deltas during arbitration。
//
// `payload_ref` is a state-bus reference,not inline payload — keeps
// the proposal value-type small + Hashable-clean。

import Foundation

public struct BASAgentProposal:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique proposal identifier。 Format suggestion:
    /// `prop.<turnID>.<agentID>.<seq>`。
    public let proposalID: String

    /// The agent proposing this。 Matches `BASAgentSpec.agentID`。
    public let agentID: String

    /// Proposal type per BASAgentProposalType — drives merge engine
    /// routing and downstream consumer (e.g. critique → L7 contradiction
    /// lattice; risk → L11 wind gate)。
    public let proposalType: BASAgentProposalType

    /// Reference to the payload object via zero-copy state bus。
    /// Format: `<domain>#<objectID>`。 Reading the payload requires
    /// the consumer to have lease.allowedDomains containing the domain。
    public let payloadRef: String

    /// Domains this proposal requires write/propose access to。 The
    /// merge engine validates the proposing agent has those rights
    /// per its `BASAgentSpec.proposeDomains` BEFORE accepting。
    public let requiredDomains: [BASStateDomain]

    /// Risk-related notes attached to this proposal — populated by
    /// the agent itself when it's aware of risk implications。 The
    /// Risk agent uses these as inputs when computing `RiskField`
    /// deltas。 Empty = no risk implications declared (Risk agent
    /// may still flag implicitly via its own analysis)。
    public let riskNotes: [String]

    /// Sovereign-related notes — concerns the agent wants L14
    /// SovereignSentinel to weigh。 Example:
    /// `["host.identity.write-petition", "irreversible.action"]`。
    /// Empty = no sovereign implications declared。
    public let sovereignNotes: [String]

    public init(
        proposalID: String,
        agentID: String,
        proposalType: BASAgentProposalType,
        payloadRef: String,
        requiredDomains: [BASStateDomain] = [],
        riskNotes: [String] = [],
        sovereignNotes: [String] = []
    ) {
        self.proposalID = proposalID
        self.agentID = agentID
        self.proposalType = proposalType
        self.payloadRef = payloadRef
        self.requiredDomains = requiredDomains
        self.riskNotes = riskNotes
        self.sovereignNotes = sovereignNotes
    }
}
