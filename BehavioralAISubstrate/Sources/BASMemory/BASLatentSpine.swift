// MARK: - BASLatentSpine
// chapter 九百七十九 / M3600 — Phase 8 ch1:shared latent spine
//
// User design Section 13.2 + plan PHASE 8 ch1:
//
//   Shared latent spine:agents share one encode pass instead
//   of N (avoid re-tokenize/re-embed);reuse via BASCandidateSeed
//   cache。 HIGH potential gain (10x for compare mode with 5
//   active agents)。
//
// ## What this layer DOES NOT do
//
// - DOES NOT perform ML encoding (that's L6/L7 / MLX / Gemma's
//   job upstream)
// - DOES NOT replace the existing decompose-frame / candidate-
//   path data structures
// - DOES NOT change the agent dispatcher's order or contract
//
// ## What this layer DOES do
//
// It provides a STRUCTURED CACHE that agents READ from instead
// of re-encoding。 Cache shape:
//
//   BASLatentSpine
//     ├─ encodedInput (tokens + embeddings + spans,one copy per
//     │  turn,shared across all 9 core + 7 watcher + N skill
//     │  agents)
//     ├─ encodedCandidates [BASCandidateSeed]   (per-candidate
//     │  encoded form — also reused by all agents that consider
//     │  candidates)
//     └─ encodedConcerns  [BASLatentConcernSeed] (per-concern
//        encoded form — reused by Critic + Surface + HostAlign +
//        Sentinel that all look at concerns)
//
// Caller (coordinator adapter) builds the spine ONCE per turn
// after L6/L7 finish。 Agents query the spine through
// `BASLatentSpineView` — a pure-fn read-only view that
// guarantees agents see byte-equal data across the turn。
//
// ## Why pure-fn + value-type
//
// Per ch 957-978 discipline:no actor / no I/O / pure data。
// Multiple agents reading concurrently can each receive the
// same value-typed spine without any synchronization cost。
// Swift's Copy-on-Write on Array means the underlying buffer
// is SHARED — no actual copy happens for read-only access。

import Foundation

// MARK: - Candidate seed

/// One candidate's slice of the latent spine — the cached
/// encoded form a Planner/Critic/Risk/Surface agent can reuse
/// instead of re-encoding。 Caller (host's L6/L7 wiring)
/// populates `tokenCount` + `embeddingDigest` from the actual
/// ML pass。
public struct BASCandidateSeed:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    /// Token count for this candidate (caller-supplied,from
    /// the actual encoder)。 Cached so agents don't re-tokenize。
    public let tokenCount: Int
    /// Stable digest of the embedding vector (e.g. SHA-256 of
    /// the vector bytes,truncated to first 16 hex chars)。
    /// Used as a cache key so agents can deduplicate identical
    /// candidates across compare mode。
    public let embeddingDigest: String
    /// Caller-supplied confidence in the encoded form (0.0-1.0)。
    /// 1.0 = encoder produced clean output;< 1.0 = encoder had
    /// to fall back (e.g. truncation,unknown tokens)。
    public let encoderConfidence: Double
    /// Caller-supplied summary of what dimensions the seed
    /// covers (e.g. "intent + tone + risk")。 Audit trail。
    public let coverageNotes: [String]

    public init(
        candidateID: String,
        tokenCount: Int,
        embeddingDigest: String,
        encoderConfidence: Double,
        coverageNotes: [String] = []
    ) {
        self.candidateID = candidateID
        self.tokenCount = max(0, tokenCount)
        self.embeddingDigest = embeddingDigest
        self.encoderConfidence =
            max(0.0, min(1.0, encoderConfidence))
        // Sort + dedupe for deterministic round-trip
        self.coverageNotes =
            Array(Set(coverageNotes)).sorted()
    }
}

// MARK: - Concern seed

/// One concern's (risk axis / boundary touch / contradiction
/// etc.) cached encoded form。 Shared across Critic + Surface
/// + HostAlignment + SovereignSentinel which all read concerns。
public struct BASLatentConcernSeed:
    Sendable, Equatable, Hashable, Codable
{
    public let concernID: String
    public let concernKind: String  // e.g. "risk.manipulation"
    public let tokenCount: Int
    public let embeddingDigest: String
    public let severityHint: Double  // 0.0-1.0

    public init(
        concernID: String,
        concernKind: String,
        tokenCount: Int,
        embeddingDigest: String,
        severityHint: Double
    ) {
        self.concernID = concernID
        self.concernKind = concernKind
        self.tokenCount = max(0, tokenCount)
        self.embeddingDigest = embeddingDigest
        self.severityHint =
            max(0.0, min(1.0, severityHint))
    }
}

// MARK: - Latent spine (the per-turn shared cache)

public struct BASLatentSpine:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    /// Input encoding (one copy per turn)。 Used by Scout +
    /// any agent that reads the situation field。
    public let inputTokenCount: Int
    public let inputEmbeddingDigest: String
    public let inputCoverageNotes: [String]
    /// Per-candidate seeds,sorted by candidateID for
    /// deterministic ordering。
    public let candidateSeeds: [BASCandidateSeed]
    /// Per-concern seeds,sorted by concernID。
    public let concernSeeds: [BASLatentConcernSeed]
    /// Build timestamp for trace replay。
    public let builtAtNanos: Int64

    public init(
        turnID: String,
        inputTokenCount: Int = 0,
        inputEmbeddingDigest: String = "",
        inputCoverageNotes: [String] = [],
        candidateSeeds: [BASCandidateSeed] = [],
        concernSeeds: [BASLatentConcernSeed] = [],
        builtAtNanos: Int64 = 0
    ) {
        self.turnID = turnID
        self.inputTokenCount = max(0, inputTokenCount)
        self.inputEmbeddingDigest = inputEmbeddingDigest
        self.inputCoverageNotes =
            Array(Set(inputCoverageNotes)).sorted()
        // Sort by ID for deterministic ordering
        self.candidateSeeds = candidateSeeds.sorted {
            $0.candidateID < $1.candidateID
        }
        self.concernSeeds = concernSeeds.sorted {
            $0.concernID < $1.concernID
        }
        self.builtAtNanos = builtAtNanos
    }

    /// O(log n) lookup by candidateID (using sorted property
    /// of `candidateSeeds`)。 Returns nil when not in spine。
    public func candidate(
        _ id: String
    ) -> BASCandidateSeed? {
        // Linear-scan keeping it simple — n is bounded by
        // candidate count per turn (≤ 50 per ch 970 anomaly
        // threshold)。 O(log n) binary search optimization
        // deferred to ch 980+ if profile shows it。
        candidateSeeds.first { $0.candidateID == id }
    }

    public func concern(
        _ id: String
    ) -> BASLatentConcernSeed? {
        concernSeeds.first { $0.concernID == id }
    }

    /// Cache-hit metric — how many of the caller's expected
    /// candidates are present in the spine。 Returns
    /// (hitCount, expectedCount) tuple。 Used by ch 980 hot/
    /// cold tier deciding when to skip cold-agent activation。
    public func hitMetric(
        expectedCandidateIDs: [String]
    ) -> (hits: Int, expected: Int) {
        let present = Set(candidateSeeds.map {
            $0.candidateID
        })
        let hits = expectedCandidateIDs.filter {
            present.contains($0)
        }.count
        return (hits, expectedCandidateIDs.count)
    }
}

// MARK: - Spine builder (pure fn)

public enum BASLatentSpineBuilder {

    /// Build a spine from the per-turn dispatcher input。 Pure
    /// function — caller supplies the encoder output via the
    /// `BASCandidateSeed` + `BASLatentConcernSeed` arrays (host
    /// constructs these from the actual ML pass results)。
    ///
    /// This builder does NOT call the encoder。 Caller is
    /// expected to:
    ///   1. Run the encoder ONCE for input + per candidate +
    ///      per concern
    ///   2. Build the seed arrays from encoder output
    ///   3. Call `build(...)` to produce the spine
    ///   4. Pass the spine to agents (e.g. via a new optional
    ///      `latentSpine` field on `BASAgentWatcherObservation`
    ///      or coordinator adapter — wired in ch 980+ if profile
    ///      shows benefit)
    public static func build(
        turnID: String,
        inputTokenCount: Int = 0,
        inputEmbeddingDigest: String = "",
        inputCoverageNotes: [String] = [],
        candidateSeeds: [BASCandidateSeed] = [],
        concernSeeds: [BASLatentConcernSeed] = [],
        builtAtNanos: Int64 = 0
    ) -> BASLatentSpine {
        BASLatentSpine(
            turnID: turnID,
            inputTokenCount: inputTokenCount,
            inputEmbeddingDigest: inputEmbeddingDigest,
            inputCoverageNotes: inputCoverageNotes,
            candidateSeeds: candidateSeeds,
            concernSeeds: concernSeeds,
            builtAtNanos: builtAtNanos)
    }

    /// Convenience:build a spine from planner candidates
    /// alone (no encoder output)。 Used in test paths + early
    /// integration before the host wires the encoder。 Each
    /// candidate gets a placeholder seed with token-count
    /// estimated from action-summary length + a deterministic
    /// digest based on the candidate ID。
    public static func buildFromCandidates(
        turnID: String,
        candidates: [BASPlannerCandidate],
        builtAtNanos: Int64 = 0
    ) -> BASLatentSpine {
        let seeds = candidates.map { cand in
            BASCandidateSeed(
                candidateID: cand.candidateID,
                // Rough token-count estimate — caller replaces
                // when encoder runs
                tokenCount:
                    estimateTokenCount(cand.actionSummary),
                embeddingDigest:
                    placeholderDigest(cand.candidateID),
                encoderConfidence: 0.0,  // placeholder
                coverageNotes: ["placeholder"])
        }
        return BASLatentSpine(
            turnID: turnID,
            candidateSeeds: seeds,
            builtAtNanos: builtAtNanos)
    }

    /// Token count estimator (length / 4 — rough heuristic
    /// matching typical English subword tokenizers)。
    public static func estimateTokenCount(
        _ text: String
    ) -> Int {
        max(1, text.count / 4)
    }

    /// Deterministic placeholder digest — first 16 hex chars
    /// of a stable hash of the input。 NOT a cryptographic hash
    /// — just a stable string for the digest field until the
    /// real encoder runs。
    public static func placeholderDigest(
        _ key: String
    ) -> String {
        var hash: UInt64 = 14695981039346656037  // FNV offset
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211  // FNV prime
        }
        return String(
            format: "%016llx",
            hash & 0xFFFFFFFFFFFFFFFF)
    }
}

// MARK: - Reuse statistics (for ch 980 hot/cold decisions)

/// Per-agent reuse statistic — how much of an agent's per-turn
/// work was served from the spine cache vs cold-computed。
/// Caller (coordinator) accumulates these across the turn
/// for the audit ledger and hot/cold tier reassignment in
/// ch 980+。
public struct BASLatentSpineReuseStat:
    Sendable, Equatable, Hashable, Codable
{
    public let agentRole: BASAgentRole
    public let candidateHits: Int
    public let candidateMisses: Int
    public let concernHits: Int
    public let concernMisses: Int

    public init(
        agentRole: BASAgentRole,
        candidateHits: Int = 0,
        candidateMisses: Int = 0,
        concernHits: Int = 0,
        concernMisses: Int = 0
    ) {
        self.agentRole = agentRole
        self.candidateHits = max(0, candidateHits)
        self.candidateMisses = max(0, candidateMisses)
        self.concernHits = max(0, concernHits)
        self.concernMisses = max(0, concernMisses)
    }

    /// Cache-hit ratio (0.0-1.0)。 Returns 0.0 when no lookups
    /// happened (avoid divide by zero)。 Used by ch 980 hot/
    /// cold tier — high-hit agents should stay hot;low-hit
    /// agents are candidates for cold-start。
    public var hitRatio: Double {
        let total = candidateHits + candidateMisses
            + concernHits + concernMisses
        if total == 0 { return 0.0 }
        let hits = candidateHits + concernHits
        return Double(hits) / Double(total)
    }
}
