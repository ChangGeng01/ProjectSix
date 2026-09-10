// MARK: - BASVectorReranker — chapter 三百六十 / M847
//
// Phase P1 G4 第三刀: typed reranker protocol + identity stub
// conformer。Closes the "reranker" piece of G4 from M840
// Cognitive OS roadmap。
//
// ## Why this exists
//
// Per chapter 三百三六 (M823) `BASChengluMemoryAspirationalAdapter`,
// the future ChengluMemory_v0 model will produce 5 outputs:
//   - embedding (consumed by BASEmbeddingProvider — chapter 三百六十)
//   - memory_type
//   - memory_decay
//   - **retrieval_rerank** ← consumed here
//   - conflict_score
//
// G4 ships the typed reranker contract NOW so the retrieval
// pipeline (embedding → vector index → reranker) is fully
// typed end-to-end。The actual ChengluMemory model wires in
// later via a future `BASChengluRetrievalReranker` conformer
// (P2 work)。
//
// **For M847**: ship the identity stub so the pipeline composes
// without a trained model。Identity reranker preserves the
// vector-similarity score order — caller still gets a typed
// `[BASVectorTopKResult]` reranker output that's safe to
// substitute later。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — reranker is pure transformation
//   - 红线 7 hint-only — reranker score is INPUT to retrieval
//     ordering,not a decision
//   - chapter 二百一一 single-source-of-truth — ONE reranker
//     protocol,N conformers (identity + future learned)
//   - chapter 三百三六 BASChengluMemoryAspirationalAdapter
//     forward-compat — `retrievalRerankKey` output maps cleanly
//     to a future learned conformer that consumes `BASMemory
//     Atom.summary` + the query embedding to produce a refined
//     score
//   - ADR-014 OPT-IN → PROD — identity stub is the default,
//     hosts opt in by passing a learned conformer

import Foundation

// MARK: - Reranker protocol

/// Async Sendable protocol for reordering vector top-k candidates。
///
/// Implementations may:
///   - Identity (this file's stub) — preserve vector-similarity
///     order
///   - Learned (P2 future) — re-score using a richer signal
///     (full atom content + query context + recency)
///   - Composite — blend multiple scoring signals
///
/// **Determinism**: same `(query, candidates, candidateContext)`
/// triple MUST produce the same reranked output。Required for
/// replay (G1 BASEventReplayRunner) + audit reproducibility。
public protocol BASVectorReranker: Sendable {
    /// Stable reranker identifier。Surfaced in audit codes
    /// (eg. `reranker:identity-v1`)。
    var rerankerVersion: String { get }

    /// Rerank candidates given a query embedding + optional
    /// per-candidate context strings。
    ///
    /// - Parameters:
    ///   - query: the query embedding (may not be needed by
    ///     identity stub but required by future learned
    ///     conformers)
    ///   - candidates: top-k results from vector index (already
    ///     sorted by raw cosine score)
    ///   - candidateContext: optional `[atomID: contextText]`
    ///     map — caller provides atom content / metadata for
    ///     learned rerankers to consume。Identity stub ignores。
    /// - Returns: reranked candidates,sorted by reranker's
    ///   refined score descending。Same atomIDs as input;only
    ///   order + score may change。
    func rerank(
        query: BASEmbedding,
        candidates: [BASVectorTopKResult],
        candidateContext: [String: String]
    ) async -> [BASVectorTopKResult]
}

// MARK: - Identity stub conformer

/// Trivial reranker that preserves the input order unchanged。
/// Used as the default / opt-in entrypoint until a learned
/// conformer (e.g. ChengluMemory v0 retrieval_rerank head)
/// is trained。
///
/// **Behavior**: `rerank(...)` returns its input unchanged (same
/// scores,same order)。
///
/// **Why ship this**: pipeline consumers always have a typed
/// reranker step — substituting a learned conformer later is a
/// 1-line code change in the host wiring,not a structural
/// refactor。
public struct BASIdentityVectorReranker: BASVectorReranker {
    public let rerankerVersion: String

    /// Default reranker version tag (chapter 八十七 raw value
    /// stability — audit walkers grep this)。
    public static let defaultVersion: String = "identity-v1"

    public init(
        rerankerVersion: String =
            BASIdentityVectorReranker.defaultVersion
    ) {
        self.rerankerVersion = rerankerVersion
    }

    public func rerank(
        query: BASEmbedding,
        candidates: [BASVectorTopKResult],
        candidateContext: [String: String]
    ) async -> [BASVectorTopKResult] {
        // Pure pass-through — preserve input order + scores
        candidates
    }
}
