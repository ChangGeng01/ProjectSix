// MARK: - BASAgentLease
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.2:
//
//   AgentLease
//   - lease_id
//   - agent_id
//   - turn_id
//   - max_ms
//   - max_tokens
//   - max_state_reads
//   - max_delta_writes
//   - allowed_domains[]
//   - expires_at
//   - priority
//
// Per-turn instance materialized by the Agent Lease Manager (Phase 0
// ch 956) from `BASAgentSpec.defaultLeaseProfile` + current turn budget。
// Enforces resource budgets per user's Root Law: no agent may run
// unbounded。
//
// Lease is immutable per turn — if an agent exhausts budget,it gets
// a clean cut,no extension。 Sovereign agents have effectively-unlimited
// budgets (via large max_* values),not nil — keeps the invariant
// uniform。

import Foundation

public struct BASAgentLease:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable identifier for this lease。 Format suggestion:
    /// `<agentID>.turn-<turnID>.<seqInTurn>`。
    public let leaseID: String

    /// The agent this lease belongs to。 Matches `BASAgentSpec.agentID`。
    public let agentID: String

    /// The turn this lease is scoped to。 Lease becomes invalid as
    /// soon as the turn closes。 Format: host-supplied turn ID。
    public let turnID: String

    /// Maximum wall-clock milliseconds this agent may execute in this
    /// turn。 Watcher agents typically get 10-20ms; core agents 200-500ms;
    /// sovereign sentinel gets several thousand。
    public let maxMs: Int

    /// Maximum tokens this agent may produce/consume (when wrapping LLM
    /// adapter)。 Non-LLM agents use 0。 Per user's Section 13.6 budgets。
    public let maxTokens: Int

    /// Maximum number of reads from shared state graph。 Prevents
    /// runaway loops。 Typical 50-500。
    public let maxStateReads: Int

    /// Maximum number of `BASAgentDelta` writes this agent may emit
    /// in this turn。 Per Single-Writer invariant,deltas against
    /// non-owned domains become proposals routed to the writer。
    public let maxDeltaWrites: Int

    /// Subset of `BASAgentSpec.readDomains` that the lease grants this
    /// turn。 Useful for risk-state-driven lease tightening (e.g. in
    /// critical state,sovereign sentinel can revoke memory access)。
    /// Empty array = no domain reads,not all domains。
    public let allowedDomains: [BASStateDomain]

    /// Unix epoch nanoseconds when this lease expires。 After this
    /// instant any state access by the agent throws。 Set to turn-end
    /// boundary by default; sovereign concerns may revoke earlier。
    public let expiresAtMs: Int64

    /// Lease priority for merge engine conflict resolution。 Higher =
    /// stronger preference。 Default 0; SovereignSentinel uses Int.max。
    /// Per user's Section 9.4 conflict resolution priority。
    public let priority: Int

    public init(
        leaseID: String,
        agentID: String,
        turnID: String,
        maxMs: Int,
        maxTokens: Int,
        maxStateReads: Int,
        maxDeltaWrites: Int,
        allowedDomains: [BASStateDomain],
        expiresAtMs: Int64,
        priority: Int = 0
    ) {
        self.leaseID = leaseID
        self.agentID = agentID
        self.turnID = turnID
        self.maxMs = maxMs
        self.maxTokens = maxTokens
        self.maxStateReads = maxStateReads
        self.maxDeltaWrites = maxDeltaWrites
        self.allowedDomains = allowedDomains
        self.expiresAtMs = expiresAtMs
        self.priority = priority
    }
}
