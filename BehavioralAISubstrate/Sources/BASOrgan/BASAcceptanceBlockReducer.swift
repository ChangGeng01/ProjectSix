import Foundation

/// Reduces a per-position draft↔target AGREEMENT pattern into the speculative-decode acceptance statistics, by
/// simulating the real greedy block-K accept rule. Pure + framework-free + host-testable — the measurement core of
/// the Gate-2 "does a draft model help free-form" experiment (`MLXOrganAdapter+TeacherForcedAccept`).
///
/// WHY teacher-forced agreement is the faithful α: for greedy argmax-equality accept, the accepted prefix is always the
/// target's own greedy sequence T, so the draft at each proposal position is conditioned on the TRUE prefix. Hence
/// `agreement[i] = (draftArgmax_i == T[i])` — computed once by teacher-forcing the draft over `prompt + T` — equals the
/// real-rollout accept event at position i (validated against the accept loops in `BASSaguaroLoop` / `BASPromptLookupDecoder`).
public enum BASAcceptanceBlockReducer {

    /// Acceptance statistics for one generation under block size K.
    public struct Result: Equatable, Sendable {
        /// Number of verify rounds the block-K rollout would run over this sequence.
        public let rounds: Int
        /// Total DRAFT tokens accepted across all rounds (the correction/bonus tokens are NOT counted here).
        public let accepted: Int
        /// The decision number `a`: mean accepted draft tokens per verify round.
        public var meanAcceptedPerRound: Double { rounds > 0 ? Double(accepted) / Double(rounds) : 0 }
        /// Tokens produced per round = `a + 1` (the accepted draft tokens + the 1 target correction/bonus). With the
        /// draft cost hidden (f→0), the net speedup over plain AR ≈ this value.
        public var tokensPerRound: Double { meanAcceptedPerRound + 1 }

        public init(rounds: Int, accepted: Int) {
            self.rounds = rounds
            self.accepted = accepted
        }
    }

    /// Simulate greedy block-K speculative decode over a per-position agreement pattern.
    ///
    /// Each round, starting at the current committed position: accept the longest run of consecutive agreements, capped
    /// at `k` (the draft proposes only `k` per round); then ALWAYS consume one more position (the target's correction
    /// token if the run broke before `k`, or the bonus token if all `k` were accepted) — so the frontier advances by
    /// `accepted + 1`. The trailing partial block at the sequence end is a real round too (a generation that stops by
    /// EOS ends mid-block).
    ///
    /// - Parameters:
    ///   - agreement: `agreement[i] == true` iff the draft's argmax at generated position `i` equals the target token there.
    ///   - k: draft tokens proposed per round (block size), `k >= 1`.
    public static func reduce(agreement: [Bool], k: Int) -> Result {
        precondition(k >= 1, "block size k must be >= 1")
        let n = agreement.count
        var pos = 0
        var rounds = 0
        var totalAccepted = 0
        while pos < n {
            rounds += 1
            var acc = 0
            while acc < k, pos + acc < n, agreement[pos + acc] { acc += 1 }
            totalAccepted += acc
            pos += acc + 1   // accepted draft tokens + the 1 target correction/bonus token
        }
        return Result(rounds: rounds, accepted: totalAccepted)
    }
}
