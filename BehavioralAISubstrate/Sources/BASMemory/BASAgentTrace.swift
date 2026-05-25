// MARK: - BASAgentTrace
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.7:
//
//   AgentTrace
//   - trace_id
//   - agent_id
//   - lease_ref
//   - read_refs[]
//   - write_refs[]
//   - proposals[]
//   - accepted
//   - rejected_reason
//   - latency_ms
//
// Per-agent-per-turn execution trace。 Written to the Trace / Replay
// Engine (Phase 0 ch 959) via `BASRoutedEventLogStorage`。 Enables
// Root Law 7 (可回放) — every agent observation,proposal,delta,
// reject reason is replayable。
//
// `accepted` is a per-agent verdict (was the agent's overall
// contribution accepted into the resulting state)。 Aggregates
// per-delta acceptance at agent-level for user-visible audit panel
// (Phase 4 ch 969 transcript compare mode)。

import Foundation

public struct BASAgentTrace:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique trace identifier。 Format suggestion:
    /// `trace.<turnID>.<agentID>.<seq>`。
    public let traceID: String

    /// The agent this trace belongs to。 Matches `BASAgentSpec.agentID`。
    public let agentID: String

    /// Reference to the lease that authorized this turn's work。
    /// Format: `lease:<leaseID>`。 Replay uses this to re-create
    /// budget context。
    public let leaseRef: String

    /// References to state objects the agent READ during this turn。
    /// Format: `<domain>#<objectID>`。 Includes objects read via
    /// observations + direct state graph queries。
    public let readRefs: [String]

    /// References to state objects the agent WROTE during this turn
    /// (only for write-domain-owning agents per Single-Writer)。
    /// Format: `<domain>#<objectID>`。 Empty = propose-only / read-only
    /// agent (most non-writer agents)。
    public let writeRefs: [String]

    /// Proposal IDs this agent submitted during this turn。
    /// Format: `prop:<proposalID>`。
    public let proposalIDs: [String]

    /// Per-agent overall verdict — was this agent's contribution
    /// accepted into the resulting state? Computed by merge engine
    /// from per-delta acceptance ratio。
    public let accepted: Bool

    /// If not accepted,short reason code (parseable for replay audits)。
    /// Example: `"out-of-lease"`, `"sovereign-veto"`,
    /// `"single-writer-violation"`, `"forbidden-domain"`,
    /// `"evidence-debt"`。 Empty when `accepted == true`。
    public let rejectedReason: String

    /// Wall-clock milliseconds this agent consumed in this turn。
    /// Compared against `BASAgentLease.maxMs` — if equal-or-greater,
    /// agent was timed-out。
    public let latencyMs: Int

    public init(
        traceID: String,
        agentID: String,
        leaseRef: String,
        readRefs: [String] = [],
        writeRefs: [String] = [],
        proposalIDs: [String] = [],
        accepted: Bool,
        rejectedReason: String = "",
        latencyMs: Int
    ) {
        self.traceID = traceID
        self.agentID = agentID
        self.leaseRef = leaseRef
        self.readRefs = readRefs
        self.writeRefs = writeRefs
        self.proposalIDs = proposalIDs
        self.accepted = accepted
        self.rejectedReason = rejectedReason
        self.latencyMs = latencyMs
    }
}
