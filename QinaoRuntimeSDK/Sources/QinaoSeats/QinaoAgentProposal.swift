import Foundation

// 六十四.3 — typed proposal + lease + commit gate.
//
// ## Why this exists
//
// Manifesto v4 八.4-5 says:
//
//   - Agents propose deltas, NOT commits ("提案而非提交")
//   - Only ONE commit gate accepts proposals + ActionPermit
//     + SovereignWarrant ("统一提交接口")
//
// Existing code: `QinaoSeatProtocol.contribute(snapshotID:)`
// returns `SeatVerdict`. That's verdict-only, but the
// doctrine wants typed propose-vs-commit separation. This
// file ships the typed shapes.
//
// ## Doctrine
//
// - **Proposal validates write domain.** Agent cannot
//   propose write to a domain outside its capability.
// - **Lease requirement enforced.** If capability requires
//   lease, proposal without lease ref rejected.
// - **directCommit cannot bypass sovereignWarrant.** Even
//   if some capability has directCommit=true (none do per
//   doctrine), commit still requires warrant — typed-pinned.
// - **Commit gate is single.** All commit paths flow through
//   `QinaoAgentCommitGate.canCommit`.

// MARK: - Lease

public struct QinaoAgentLease:
    Sendable, Equatable, Hashable, Codable
{
    public let agent: QinaoSeat
    /// Max wall-clock milliseconds the lease is valid.
    public let maxMs: Int
    /// Max loops the agent can run within this lease.
    public let maxLoops: Int
    /// Max writes the agent can emit within this lease.
    public let maxWrites: Int
    /// Domains this lease scopes to.
    public let scope: Set<QinaoSeatDomain>

    public init(
        agent: QinaoSeat,
        maxMs: Int,
        maxLoops: Int,
        maxWrites: Int,
        scope: Set<QinaoSeatDomain>
    ) {
        self.agent = agent
        self.maxMs = max(0, maxMs)
        self.maxLoops = max(0, maxLoops)
        self.maxWrites = max(0, maxWrites)
        self.scope = scope
    }
}

// MARK: - Delta + Proposal

public struct QinaoAgentDelta:
    Sendable, Equatable, Hashable, Codable
{
    public let target: QinaoSeatDomain
    /// Opaque to the fabric — fabric only routes by `target`.
    /// Concrete domain modules deserialize.
    public let payload: String

    public init(
        target: QinaoSeatDomain,
        payload: String
    ) {
        self.target = target
        self.payload = payload
    }
}

public struct QinaoAgentProposal:
    Sendable, Equatable, Hashable, Codable
{
    public let agent: QinaoSeat
    public let delta: QinaoAgentDelta
    /// Lease ref the proposal was issued under, if any.
    /// Required if agent's canonical capability has
    /// `requiresLease == true`.
    public let leaseRef: String?

    public init(
        agent: QinaoSeat,
        delta: QinaoAgentDelta,
        leaseRef: String? = nil
    ) {
        self.agent = agent
        self.delta = delta
        self.leaseRef = leaseRef
    }
}

// MARK: - Proposal validation

public enum QinaoAgentProposalIssue:
    Sendable, Equatable, Hashable, Codable
{
    /// Agent's canonical capability does not list the
    /// target domain in writeDomains.
    case writeOutsideDomain(
        agent: QinaoSeat, target: QinaoSeatDomain)

    /// Capability requires a lease but proposal has no
    /// `leaseRef`.
    case leaseRequiredButMissing(agent: QinaoSeat)

    /// Capability has `directCommit = true` but commit
    /// path is being attempted without sovereign warrant.
    /// (Per doctrine, no canonical capability has this true,
    /// so this issue is structural — it pins the invariant
    /// at the validator layer.)
    case directCommitAttemptedWithoutSovereignWarrant(
        agent: QinaoSeat)

    /// Lease ref present but lease enforcer rejected it.
    /// Forwards the enforcer's typed reasons (expired /
    /// writesExhausted / loopsExhausted /
    /// targetOutsideScope / revoked / unknownLease) so
    /// telemetry preserves the actual cause.
    case leaseInvalid(
        agent: QinaoSeat,
        reasons: [QinaoAgentLeaseInvalidReason])
}

public enum QinaoAgentProposalGate {
    /// Validate a proposal against the agent's canonical
    /// capability. Returns issue list — empty means clean.
    public static func validate(
        _ proposal: QinaoAgentProposal,
        capability: QinaoSeatCapability
    ) -> [QinaoAgentProposalIssue] {
        var issues: [QinaoAgentProposalIssue] = []

        // 1. Write domain check.
        if !capability.writeDomains.contains(
            proposal.delta.target)
        {
            issues.append(
                .writeOutsideDomain(
                    agent: proposal.agent,
                    target: proposal.delta.target))
        }

        // 2. Lease requirement check.
        if capability.requiresLease,
           proposal.leaseRef == nil
        {
            issues.append(
                .leaseRequiredButMissing(
                    agent: proposal.agent))
        }

        // 3. **Single Commit Mouth invariant**: per
        //    manifesto v4 doctrine, no canonical capability
        //    has `directCommit = true`. This validator
        //    pins the invariant defensively — if a future
        //    typo or untyped construction sets
        //    `directCommit = true`, every proposal from
        //    that capability fails here, raising a typed
        //    issue that can be grep'd in audit logs.
        if capability.directCommit {
            issues.append(
                .directCommitAttemptedWithoutSovereignWarrant(
                    agent: proposal.agent))
        }

        return issues
    }

    /// Convenience: is this proposal acceptable?
    public static func isAcceptable(
        _ proposal: QinaoAgentProposal,
        capability: QinaoSeatCapability
    ) -> Bool {
        validate(proposal, capability: capability).isEmpty
    }
}

// MARK: - Single Commit Gate

public enum QinaoAgentCommitGate {
    /// **THE single commit mouth.** A commit is only legal
    /// when ALL three are present:
    ///
    /// 1. ≥ 1 valid proposal ref
    /// 2. ActionPermit ref (from L11 / Risk seat)
    /// 3. SovereignWarrant ref (from L14 / Sovereign Sentinel)
    ///
    /// directCommit cannot bypass. This is the doctrine A
    /// invariant from manifesto v4 八.5.
    public static func canCommit(
        proposalRefs: [String],
        actionPermitRef: String?,
        sovereignWarrantRef: String?
    ) -> Bool {
        guard !proposalRefs.isEmpty else { return false }
        guard let actionPermitRef,
            !actionPermitRef.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty
        else { return false }
        guard let sovereignWarrantRef,
            !sovereignWarrantRef.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty
        else { return false }
        return true
    }
}
