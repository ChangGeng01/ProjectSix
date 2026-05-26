// MARK: - BASAgentRoundTable
// chapter 九百八十一.7 / M3610.7 — ARC FINALIZE deferred item #1
//
// Per `Docs/ARC_SEAL_953_981.md` deferred item #1:round-table
// mode (.roundtable) — N-way agent collaboration with quorum
// voting。 Phase 4 ships compare mode (3 transcript modes:
// singleAgent / compareAll / compareSelected);round-table is
// **N²-coordination** (each agent considers every other agent's
// proposal),which is structurally different from compare mode
// (each agent independently produces its own output)。
//
// ## Scope of this module
//
// This module ships the SCAFFOLD types for round-table
// collaboration WITHOUT wiring it into the dispatcher。 Callers
// who want round-table mode today:
//   1. Run the dispatcher normally to get per-agent outputs
//   2. Pass those outputs through this module's collect / vote /
//      consense pure-fns to produce the round-table consensus
//
// Full dispatcher integration (transcript mode `.roundtable`,
// dedicated runRoundTable entry point on the dispatcher) is
// deferred to Phase 9+ if the round-table use case proves
// valuable in real consumer integrations。 Per plan + ch 974
// SDK stability,we DO NOT add a 4th transcript mode case
// (would break the count pin)。
//
// ## What round-table adds beyond compare mode
//
//   - **Quorum voting**:agents vote on each other's proposals
//     instead of independently producing
//   - **Dissent tracking**:agents that voted against the
//     consensus get their dissent recorded for the audit ledger
//   - **Consensus output**:single output combining majority +
//     dissent records,vs compare mode's "show each agent's
//     answer separately"
//
// ## Pure-fn discipline
//
// Same as ch 957-981.6 — pure functions,no actor,no I/O。
// Caller owns the dispatcher invocation;this module owns the
// post-dispatch aggregation。 No new state graph domain (votes
// + consensus are turn-level audit records,not persistent
// state)。

import Foundation

// MARK: - Per-agent proposal

/// One agent's proposal in a round-table session。 Caller
/// (host) constructs this from a `BASAgentDelta` or directly
/// from the agent's emitted output。 Slim DTO — payload is
/// already-rendered text/JSON,not embedded structure。
public struct BASRoundTableProposal:
    Sendable, Equatable, Hashable, Codable
{
    public let proposalID: String
    public let proposingAgentID: String
    /// Caller-rendered summary of the proposal (text / JSON /
    /// other format the consensus presenter can show)。
    public let summary: String
    /// 0.0-1.0 — proposing agent's confidence in this proposal。
    public let confidence: Double
    /// Optional ref into the dispatcher's emitted-delta list
    /// (e.g. `delta.<turnID>.<seat>.<seq>`) for audit replay。
    public let sourceDeltaRef: String?

    public init(
        proposalID: String,
        proposingAgentID: String,
        summary: String,
        confidence: Double,
        sourceDeltaRef: String? = nil
    ) {
        self.proposalID = proposalID
        self.proposingAgentID = proposingAgentID
        self.summary = summary
        self.confidence =
            max(0.0, min(1.0, confidence))
        self.sourceDeltaRef = sourceDeltaRef
    }
}

// MARK: - Vote

/// One agent's vote on a proposal in a round-table session。
public struct BASRoundTableVote:
    Sendable, Equatable, Hashable, Codable
{
    public enum Direction: String,
        Sendable, Equatable, Hashable, Codable,
        CaseIterable
    {
        case approve
        case dissent
        case abstain
    }
    public let votingAgentID: String
    public let proposalID: String
    public let direction: Direction
    /// 0.0-1.0 — voter's confidence in their direction
    /// (high-confidence approve carries more weight than
    /// abstain-leaning)。
    public let confidence: Double
    /// Caller-rendered reason for the vote。 Audit trail。
    public let reason: String

    public init(
        votingAgentID: String,
        proposalID: String,
        direction: Direction,
        confidence: Double,
        reason: String = ""
    ) {
        self.votingAgentID = votingAgentID
        self.proposalID = proposalID
        self.direction = direction
        self.confidence =
            max(0.0, min(1.0, confidence))
        self.reason = reason
    }
}

// MARK: - Quorum state + consensus

/// Round-table quorum state for one turn。 Pure-data view of
/// all proposals + votes received。
public struct BASRoundTableQuorum:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    public let proposals: [BASRoundTableProposal]
    public let votes: [BASRoundTableVote]
    /// Quorum threshold — minimum approve-weight as fraction
    /// of total participating-agent count for consensus to
    /// form。 Default 0.5 (simple majority by count);some
    /// host policies want 0.66 (2/3 supermajority)。 Clamped
    /// to [0, 1]。
    public let quorumThreshold: Double

    public init(
        turnID: String,
        proposals: [BASRoundTableProposal] = [],
        votes: [BASRoundTableVote] = [],
        quorumThreshold: Double = 0.5
    ) {
        self.turnID = turnID
        // Sort proposals by ID for deterministic ordering
        self.proposals = proposals.sorted {
            $0.proposalID < $1.proposalID
        }
        self.votes = votes.sorted {
            ($0.proposalID, $0.votingAgentID) <
                ($1.proposalID, $1.votingAgentID)
        }
        self.quorumThreshold =
            max(0.0, min(1.0, quorumThreshold))
    }
}

/// Consensus output for one turn。 If no proposal achieves
/// quorum,`winnerProposalID` is nil and caller falls back to
/// compare mode or single-agent mode at their discretion。
public struct BASRoundTableConsensus:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    /// Proposal that reached quorum,nil if none did。
    public let winnerProposalID: String?
    /// Approve-weight of the winner (sum of approve-vote
    /// confidences / total participating agent count)。
    public let winnerScore: Double
    /// Dissent records:agentID + proposalID + their reason,
    /// for audit ledger (sorted)。
    public let dissents: [BASRoundTableDissent]
    /// Sorted audit notes:
    ///   roundTable.proposals=<count>
    ///   roundTable.votes=<count>
    ///   roundTable.winner=<id> | roundTable.no-quorum
    ///   roundTable.dissent.count=<count>
    public let auditNotes: [String]

    public init(
        turnID: String,
        winnerProposalID: String? = nil,
        winnerScore: Double = 0.0,
        dissents: [BASRoundTableDissent] = [],
        auditNotes: [String] = []
    ) {
        self.turnID = turnID
        self.winnerProposalID = winnerProposalID
        self.winnerScore =
            max(0.0, min(1.0, winnerScore))
        // Sort dissents by (proposalID, agentID)
        self.dissents = dissents.sorted {
            ($0.proposalID, $0.dissentingAgentID) <
                ($1.proposalID, $1.dissentingAgentID)
        }
        self.auditNotes = auditNotes.sorted()
    }
}

/// One dissent record — a vote that went against the
/// consensus winner。 Audit ledger discipline:every dissent
/// MUST be recorded so the L14 sentinel can see if a
/// systematically-dissenting agent is being routinely
/// overruled (potential persona / role conflict)。
public struct BASRoundTableDissent:
    Sendable, Equatable, Hashable, Codable
{
    public let dissentingAgentID: String
    public let proposalID: String
    public let reason: String
    public let confidence: Double

    public init(
        dissentingAgentID: String,
        proposalID: String,
        reason: String,
        confidence: Double
    ) {
        self.dissentingAgentID = dissentingAgentID
        self.proposalID = proposalID
        self.reason = reason
        self.confidence =
            max(0.0, min(1.0, confidence))
    }
}

// MARK: - Round-table session (pure-fn)

public enum BASRoundTableSession {

    /// FP-equality epsilon for tie-detection on proposal
    /// scores。 Per ch 981.8 USER-PASS-9 MED-FP-tie fix:
    /// using strict `!=` on Doubles was fragile when scores
    /// derive from accumulated confidence sums (FP error can
    /// produce 1-ULP drift between bit-identical-by-math
    /// values)。
    public static let tieEpsilon: Double = 1e-12

    /// Compute consensus from a quorum state。 Pure function。
    ///
    /// chapter 九百八十一.8 USER-PASS-9 algorithm fix:
    /// addresses 2 HIGH bugs from round 6 review:
    ///
    ///   HIGH-1 BALLOT STUFFING — previously summed vote
    ///   confidences without per-agent-per-proposal dedup,
    ///   letting one agent submit multiple approve votes for
    ///   the same proposal to unilaterally inflate score。
    ///   Fix:dedupe at vote-ingestion via (agentID,
    ///   proposalID) key,keeping only the HIGHEST-confidence
    ///   vote per agent per proposal (matches typical voting
    ///   systems where each voter casts one ballot per
    ///   choice)。
    ///
    ///   HIGH-2 DROPPED DISSENTS — previously the dissent
    ///   collection filtered `.proposalID == winnerID` so
    ///   dissents against LOSING proposals were silently
    ///   discarded。 Per the type doc + ch 944 audit
    ///   discipline,every dissent MUST land in the audit
    ///   ledger so L14 can detect systematically-overruled
    ///   agents。 Fix:collect ALL `.dissent` votes,not just
    ///   winner-targeted ones (each dissent carries its own
    ///   proposalID so L14 can correlate)。
    ///
    /// Algorithm:
    ///   1. **Dedup votes by (agentID, proposalID)** — keep
    ///      highest-confidence vote per agent per proposal
    ///   2. Group approve votes by proposalID,sum confidences
    ///   3. For each proposal,score = sum / total participants
    ///   4. Highest score IFF ≥ threshold → winner
    ///      (lex tie-break by proposalID,using `tieEpsilon`
    ///      for FP-equality)
    ///   5. Dissent records = ALL `.dissent` votes (not just
    ///      winner-targeted)
    public static func consense(
        _ quorum: BASRoundTableQuorum
    ) -> BASRoundTableConsensus {
        // HIGH-1 FIX:dedup votes by (agentID, proposalID)
        // keeping only highest-confidence per pair。 If same
        // agent voted N times for the same proposal,only the
        // most-confident vote counts。 Different-proposal
        // votes from same agent still all count (an agent
        // CAN have an opinion on each proposal,but only
        // ONE opinion per proposal)。
        var dedupedVotes:
            [String: BASRoundTableVote] = [:]
        for vote in quorum.votes {
            let key =
                "\(vote.votingAgentID)|\(vote.proposalID)"
            if let existing = dedupedVotes[key] {
                if vote.confidence > existing.confidence {
                    dedupedVotes[key] = vote
                }
            } else {
                dedupedVotes[key] = vote
            }
        }
        let dedupedList =
            Array(dedupedVotes.values)

        // Count distinct participating agent IDs (from the
        // deduped pool)
        let participatingAgents = Set(
            dedupedList.map { $0.votingAgentID })
        let totalAgents = participatingAgents.count
        if totalAgents == 0 {
            return BASRoundTableConsensus(
                turnID: quorum.turnID,
                winnerProposalID: nil,
                winnerScore: 0.0,
                dissents: [],
                auditNotes: [
                    "roundTable.no-quorum:no-participants",
                    "roundTable.proposals=" +
                        "\(quorum.proposals.count)",
                    "roundTable.votes=0",
                ])
        }

        // Group approve votes by proposalID + sum confidences
        var approveWeight: [String: Double] = [:]
        for vote in dedupedList
            where vote.direction == .approve
        {
            approveWeight[vote.proposalID, default: 0.0]
                += vote.confidence
        }
        // Normalize to fraction of participating agents
        var proposalScores: [(String, Double)] = []
        for proposal in quorum.proposals {
            let weight =
                approveWeight[proposal.proposalID] ?? 0.0
            let score = weight / Double(totalAgents)
            proposalScores.append(
                (proposal.proposalID, score))
        }
        // MED-FP-tie fix:use epsilon-based equality for
        // tie detection instead of strict !=。 Bitwise-equal
        // scores via different summation orders could differ
        // by 1-ULP in pathological cases。
        proposalScores.sort {
            if abs($0.1 - $1.1) > tieEpsilon {
                return $0.1 > $1.1
            }
            return $0.0 < $1.0
        }
        let topProposalID = proposalScores.first?.0
        let topScore = proposalScores.first?.1 ?? 0.0

        // HIGH-2 FIX:collect ALL dissents,not just winner-
        // targeted。 Each dissent already carries its own
        // proposalID — L14 can correlate against winner if
        // it cares,but the audit ledger sees every dissent。
        let allDissents = dedupedList
            .filter { $0.direction == .dissent }
            .map { vote in
                BASRoundTableDissent(
                    dissentingAgentID:
                        vote.votingAgentID,
                    proposalID: vote.proposalID,
                    reason: vote.reason,
                    confidence: vote.confidence)
            }

        // Dedup-audit:report how many votes were dropped by
        // the ballot-stuffing dedup (audit-trail visibility)
        let droppedDupCount =
            quorum.votes.count - dedupedList.count

        var notes: [String] = [
            "roundTable.proposals=" +
                "\(quorum.proposals.count)",
            "roundTable.votes=\(dedupedList.count)",
            "roundTable.participants=\(totalAgents)",
        ]
        if droppedDupCount > 0 {
            notes.append(
                "roundTable.duplicate-votes-dropped=" +
                "\(droppedDupCount)")
        }
        // Threshold check
        if topScore >= quorum.quorumThreshold,
           let winnerID = topProposalID
        {
            notes.append(
                "roundTable.winner=\(winnerID)")
            notes.append(
                "roundTable.winner-score=" +
                String(format: "%.3f", topScore))
            notes.append(
                "roundTable.dissent.count=" +
                "\(allDissents.count)")
            return BASRoundTableConsensus(
                turnID: quorum.turnID,
                winnerProposalID: winnerID,
                winnerScore: topScore,
                dissents: allDissents,
                auditNotes: notes)
        } else {
            // No quorum — but STILL record all dissents
            // (HIGH-2 fix:audit captures dissents regardless
            // of consensus outcome)
            notes.append("roundTable.no-quorum")
            notes.append(
                "roundTable.top-score=" +
                String(format: "%.3f", topScore))
            notes.append(
                "roundTable.threshold=" +
                String(format: "%.3f",
                    quorum.quorumThreshold))
            notes.append(
                "roundTable.dissent.count=" +
                "\(allDissents.count)")
            return BASRoundTableConsensus(
                turnID: quorum.turnID,
                winnerProposalID: nil,
                winnerScore: topScore,
                dissents: allDissents,
                auditNotes: notes)
        }
    }
}
