import Foundation

/// Per-(source × purpose) acceptance statistics for the Universal Draft Layer router — the substrate's "brain"
/// that learns which draft SOURCE is actually paying off on each lane, online, from the decode telemetry
/// (`accepted / proposed / rounds` that `BASPromptLookupDecoder.Result` already surfaces). Generalizes the single
/// `emaAccept` EMA that lives inside the decoder today into a keyed, persistable table.
///
/// PURE + IMMUTABLE (coding-style rule): every update returns a NEW profiler — `observing(...)` never mutates.
/// Framework-free (BASOrgan, no MLX) → host-unit-testable. Intended to live as actor-isolated state in
/// `MLXOrganAdapter` (or host-side), folded after each accelerated turn.
public struct BASAcceptanceProfiler: Sendable, Equatable {

    /// Smoothed statistics for one (sourceID, purpose) cell.
    public struct Stat: Sendable, Equatable {
        /// EMA of accepted draft tokens per round (the speedup signal; drives `recommendedK`).
        public let emaAccepted: Double
        /// EMA of accepted/proposed (the hit-rate; drives the `worthSpeculating` fallback decision).
        public let emaHitRate: Double
        /// Number of folded observations (rounds-bearing turns) — distinguishes cold from warm.
        public let observations: Int
    }

    private let stats: [String: Stat]
    /// EMA weight on the newest observation. 0.4 reuses the decoder's EMA *constant*, but this profiler folds
    /// PER-TURN over the turn's mean accepted-per-round — a different cadence + statistic than the decoder's
    /// PER-ROUND in-loop `emaAccept`. `recommendedK` is a turn-level warm-start CAP that seeds the decoder's K;
    /// the decoder then re-derives its own round-level ramp. (Not the same smoothed quantity, just the same α.)
    public let alpha: Double

    public init(alpha: Double = 0.4) {
        self.stats = [:]
        self.alpha = min(1, max(0.01, alpha))
    }

    private init(stats: [String: Stat], alpha: Double) {
        self.stats = stats
        self.alpha = alpha
    }

    private static func key(_ sourceID: String, _ purpose: BASDecodeLanePolicy.Purpose) -> String {
        "\(sourceID)|\(purpose.rawValue)"
    }

    /// The learned cell for a (source, purpose), or `nil` if never observed (cold).
    public func stat(_ sourceID: String, _ purpose: BASDecodeLanePolicy.Purpose) -> Stat? {
        stats[Self.key(sourceID, purpose)]
    }

    /// Fold one turn's decode telemetry into the (sourceID, purpose) EMAs and return a NEW profiler. A turn with
    /// no speculation rounds is ignored (it carries no acceptance signal).
    public func observing(
        sourceID: String, purpose: BASDecodeLanePolicy.Purpose,
        accepted: Int, proposed: Int, rounds: Int
    ) -> BASAcceptanceProfiler {
        guard rounds > 0 else { return self }
        let acceptedPerRound = Double(accepted) / Double(rounds)
        let hit = proposed > 0 ? Double(accepted) / Double(proposed) : 0
        let k = Self.key(sourceID, purpose)
        let updated: Stat
        if let s = stats[k] {
            updated = Stat(
                emaAccepted: (1 - alpha) * s.emaAccepted + alpha * acceptedPerRound,
                emaHitRate: (1 - alpha) * s.emaHitRate + alpha * hit,
                observations: s.observations + 1)
        } else {
            updated = Stat(emaAccepted: acceptedPerRound, emaHitRate: hit, observations: 1)
        }
        var copy = stats
        copy[k] = updated
        return BASAcceptanceProfiler(stats: copy, alpha: alpha)
    }

    /// Recommended draft length for a (source, purpose) via the decoder's proven ramp
    /// (`max(1, min(cap, round(emaAccepted)+1))`). Cold → optimistic full `cap` (speculate, gather data).
    public func recommendedK(sourceID: String, purpose: BASDecodeLanePolicy.Purpose, cap: Int) -> Int {
        let c = max(1, cap)
        guard let s = stats[Self.key(sourceID, purpose)] else { return c }
        return max(1, min(c, Int(s.emaAccepted.rounded()) + 1))
    }

    /// Whether speculating with this source on this purpose is worth it (smoothed hit-rate ≥ floor); else the
    /// router falls back to plain AR (never pay the per-round scan tax where nothing is accepted — 亏的不要).
    /// Cold → `true` (try it once to gather a measurement).
    public func worthSpeculating(
        sourceID: String, purpose: BASDecodeLanePolicy.Purpose, minHitRate: Double
    ) -> Bool {
        guard let s = stats[Self.key(sourceID, purpose)] else { return true }
        return s.emaHitRate >= minHitRate
    }
}
