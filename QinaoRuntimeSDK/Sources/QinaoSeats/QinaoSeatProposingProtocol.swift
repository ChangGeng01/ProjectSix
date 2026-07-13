import Foundation

// 六十五.4 — opt-in proposing protocol bridging seat verdicts
// to v4 typed proposals.
//
// ## Why this exists
//
// Existing `QinaoSeatProtocol.contribute(snapshotID:)`
// returns `SeatVerdict` (urgency / reasonCodes / note).
// Manifesto v4 八.4 wants seats to **proposeDelta** instead
// of directly committing — the typed shape is
// `QinaoAgentProposal`. 六十四.3 ship 了 typed shape; 六十五.4
// ship 了 runtime opt-in path so seats can emit proposals.
//
// **Backward compatible**: existing seats keep `contribute`;
// proposing seats opt into `QinaoSeatProposingProtocol` and
// emit `[QinaoAgentProposal]` instead of (or in addition to)
// a verdict.
//
// ## Doctrine
//
// - **Opt-in.** Default seats keep emitting `SeatVerdict`.
//   Proposing seats opt in by conforming to the new
//   protocol.
// - **Validation at registry.** Registry's
//   `dispatchProposals` walks proposing seats, validates
//   each proposal against canonical capability + lease
//   enforcer, returns typed `QinaoAgentProposalBoard`.
// - **Single commit mouth preserved.** Even valid proposals
//   require ActionPermit + SovereignWarrant via
//   `QinaoAgentCommitGate.canCommit` — proposals alone
//   never produce side effects.

public protocol QinaoSeatProposingProtocol: Sendable {
    /// Which seat this proposing implementer represents.
    var seat: QinaoSeat { get }

    /// Read state, emit zero or more proposals. Empty list
    /// means "no proposal this turn".
    func proposeDeltas(
        snapshotID: String
    ) async throws -> [QinaoAgentProposal]
}

/// Typed dispatch board carrying validated proposals +
/// per-seat issues.
public struct QinaoAgentProposalBoard:
    Sendable, Equatable, Hashable, Codable
{
    public let validProposals: [QinaoAgentProposal]
    public let rejectedProposals: [
        QinaoAgentRejectedProposal
    ]
    public let failedSeats: [QinaoSeat: String]

    public init(
        validProposals: [QinaoAgentProposal],
        rejectedProposals: [
            QinaoAgentRejectedProposal
        ],
        failedSeats: [QinaoSeat: String]
    ) {
        self.validProposals = validProposals
        self.rejectedProposals = rejectedProposals
        self.failedSeats = failedSeats
    }
}

public struct QinaoAgentRejectedProposal:
    Sendable, Equatable, Hashable, Codable
{
    public let proposal: QinaoAgentProposal
    public let issues: [QinaoAgentProposalIssue]

    public init(
        proposal: QinaoAgentProposal,
        issues: [QinaoAgentProposalIssue]
    ) {
        self.proposal = proposal
        self.issues = issues
    }
}

/// Actor managing proposing seats. Parallels
/// `QinaoSeatRegistry` but for the v4 proposal path.
public actor QinaoAgentProposalRegistry {
    private var seatsByID: [
        QinaoSeat: any QinaoSeatProposingProtocol
    ] = [:]
    private let leaseEnforcer:
        QinaoAgentLeaseEnforcer?

    public init(
        leaseEnforcer: QinaoAgentLeaseEnforcer? = nil
    ) {
        self.leaseEnforcer = leaseEnforcer
    }

    public func register(
        _ seat: any QinaoSeatProposingProtocol
    ) {
        seatsByID[seat.seat] = seat
    }

    public func clear() {
        seatsByID.removeAll()
    }

    public func registeredSeats() -> [QinaoSeat] {
        Array(seatsByID.keys).sorted {
            $0.rawValue < $1.rawValue
        }
    }

    /// Dispatch all registered proposing seats in parallel,
    /// collect proposals, validate each, return typed
    /// board. Validation includes canonical capability
    /// check + (if enforcer present) lease validity.
    public func dispatchProposals(
        snapshotID: String
    ) async -> QinaoAgentProposalBoard {
        let seats = seatsByID.values

        // audit F12: keep the (emitting seat, proposal) association so each proposal's
        // self-reported agent can be bound to the seat that actually sent it.
        var allProposals: [(emitter: QinaoSeat, proposal: QinaoAgentProposal)] = []
        var failedSeats: [QinaoSeat: String] = [:]

        // Each task returns (seat, proposals?, error?).
        // Tuples + optional error keep type inference simple.
        await withTaskGroup(
            of: (
                seat: QinaoSeat,
                proposals: [QinaoAgentProposal],
                errorMessage: String?
            ).self
        ) { group in
            for seat in seats {
                group.addTask {
                    do {
                        let proposals =
                            try await seat
                                .proposeDeltas(
                                    snapshotID:
                                        snapshotID)
                        return (
                            seat.seat, proposals, nil)
                    } catch {
                        return (
                            seat.seat,
                            [],
                            String(describing: error))
                    }
                }
            }
            for await item in group {
                if let msg = item.errorMessage {
                    failedSeats[item.seat] = msg
                } else {
                    for p in item.proposals {
                        allProposals.append((emitter: item.seat, proposal: p))
                    }
                }
            }
        }

        // Validate each proposal.
        var valid: [QinaoAgentProposal] = []
        var rejected: [
            QinaoAgentRejectedProposal
        ] = []
        for (emitter, proposal) in allProposals {
            let cap = proposal.agent
                .canonicalCapability
            var issues =
                QinaoAgentProposalGate.validate(
                    proposal, capability: cap)
            // audit F12: bind the self-reported agent to the seat that actually emitted the
            // proposal — a seat cannot propose deltas claiming another agent's identity /
            // capability. Fail closed on mismatch.
            if proposal.agent != emitter {
                issues.append(
                    .seatIdentityMismatch(claimed: proposal.agent, actual: emitter))
            }
            // Lease validity check. audit F12: if a leaseRef is present but NO enforcer is
            // wired, the lease is unverifiable — fail closed rather than trust it. With an
            // enforcer, forward the typed reasons (expired / writesExhausted / … ).
            if let leaseRef = proposal.leaseRef {
                if let enforcer = leaseEnforcer {
                    // deep-audit P1-8: bind the lease to the seat that ACTUALLY emitted the
                    // proposal (not the self-reported proposal.agent) — a seat cannot present
                    // another agent's leaseRef to spend its budget/scope. Fail closed on mismatch.
                    let report =
                        await enforcer.validity(
                            leaseRef: leaseRef,
                            agent: emitter,
                            target: proposal.delta.target)
                    if !report.isValid {
                        issues.append(
                            .leaseInvalid(
                                agent: proposal.agent,
                                reasons: report.reasons))
                    }
                } else {
                    issues.append(.leaseUnverifiable(agent: proposal.agent))
                }
            }
            if issues.isEmpty {
                valid.append(proposal)
            } else {
                rejected.append(
                    QinaoAgentRejectedProposal(
                        proposal: proposal,
                        issues: issues))
            }
        }

        return QinaoAgentProposalBoard(
            validProposals: valid,
            rejectedProposals: rejected,
            failedSeats: failedSeats)
    }
}
