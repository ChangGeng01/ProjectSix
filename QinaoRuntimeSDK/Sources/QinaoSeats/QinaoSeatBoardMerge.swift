import Foundation

// M292.4 — cross-seat verdict merger.
//
// `SeatBoard` from M292.2 holds raw verdicts in deterministic order
// but doesn't say what the *board as a whole* is asking for. Hosts
// today have to walk verdicts and compute their own consensus —
// each host re-derives "loudest voice" / "do seats agree" / "who's
// silent" with subtly different rules. M292.4 picks one canonical
// merger so the answer is the same wherever audit walks.
//
// Doctrine
//
// - **Consensus = mean of all verdict urgencies, including 0.**
//   Silent seats lower the consensus (they're a real signal:
//   "no concern"). Mean is preferred over max because it
//   captures whether the whole council agrees something matters,
//   not just whether any one seat is loud.
// - **Loudest seat = highest urgency.** Ties break on seat raw
//   value ASC for determinism (matches `SeatBoard` ordering).
// - **Dissent = seats whose urgency deviates from consensus by
//   more than a fixed threshold (0.3).** Threshold pinned by
//   tests so future tuning is explicit.
// - **Silent seats = urgency == 0 exactly.** Strict zero, not
//   `< epsilon`, so a seat that intentionally returned 0 (e.g.
//   `no-veto`) is named silent — that's audit-useful. A seat
//   that returned 0.001 is *not* silent; it spoke quietly.
// - **Failed seats are not in the merge.** Failure is tracked on
//   the underlying `SeatBoard.failures`; the merger operates on
//   verdicts only. Hosts can still see failures via
//   `MergedSeatBoard.board.failures`.

public struct MergedSeatBoard:
    Sendable, Equatable, Hashable, Codable
{
    /// Raw board this merger was computed from. Preserved
    /// verbatim so hosts can drill in without recomputing.
    public let board: SeatBoard

    /// Mean of every verdict's urgency, including zeros. In [0,1].
    /// Returns 0 when the board has no verdicts.
    public let consensusUrgency: Double

    /// Seat with the highest urgency in the board, ties broken
    /// on seat raw-value ASC. `nil` when the board has no verdicts.
    public let loudestSeat: QinaoSeat?

    /// Seats whose urgency deviates from `consensusUrgency` by
    /// more than 0.3 (in either direction). Order: seat
    /// raw-value ASC for stable audit output.
    public let dissent: [QinaoSeat]

    /// Seats whose urgency is exactly 0. Strict equality —
    /// quiet but non-zero is *not* silent. Order: seat
    /// raw-value ASC.
    public let silentSeats: [QinaoSeat]

    public init(
        board: SeatBoard,
        consensusUrgency: Double,
        loudestSeat: QinaoSeat?,
        dissent: [QinaoSeat],
        silentSeats: [QinaoSeat]
    ) {
        self.board = board
        self.consensusUrgency = consensusUrgency
        self.loudestSeat = loudestSeat
        self.dissent = dissent
        self.silentSeats = silentSeats
    }
}

public extension SeatBoard {
    /// Compute the canonical merged view. See `MergedSeatBoard`
    /// doctrine for rules.
    func merge() -> MergedSeatBoard {
        guard !verdicts.isEmpty else {
            return MergedSeatBoard(
                board: self,
                consensusUrgency: 0,
                loudestSeat: nil,
                dissent: [],
                silentSeats: [])
        }
        let urgencies = verdicts.map(\.urgency)
        let mean = urgencies.reduce(0, +) / Double(urgencies.count)

        // Loudest: highest urgency, tie-break on seat raw asc.
        let loudest = verdicts
            .sorted { a, b in
                if a.urgency != b.urgency {
                    return a.urgency > b.urgency
                }
                return a.seat.rawValue < b.seat.rawValue
            }
            .first?
            .seat

        // Dissent: |urgency - mean| > 0.3
        let dissentSeats = verdicts
            .filter { abs($0.urgency - mean) > 0.3 }
            .map(\.seat)
            .sorted { $0.rawValue < $1.rawValue }

        // Silent: urgency == 0 exactly.
        let silent = verdicts
            .filter { $0.urgency == 0 }
            .map(\.seat)
            .sorted { $0.rawValue < $1.rawValue }

        return MergedSeatBoard(
            board: self,
            consensusUrgency: mean,
            loudestSeat: loudest,
            dissent: dissentSeats,
            silentSeats: silent)
    }
}
