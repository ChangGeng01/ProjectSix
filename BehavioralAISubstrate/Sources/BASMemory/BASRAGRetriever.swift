// MARK: - BASRAGRetriever — chapter 三百六三 / M850
//
// Phase P1 G4 part 3: typed RAG retrieval facade that composes
// `BASEmbeddingProvider` + `BASVectorIndex` + `BASVectorReranker`
// + caller-supplied atom lookup into a single async function。
// Closes the "L8 = semantic memory" claim from M840 Cognitive
// OS roadmap §3.4。
//
// ## Why this exists
//
// M847 shipped the four primitives in isolation:
//   - BASEmbeddingProvider (text → BASEmbedding)
//   - BASVectorIndex (insert / topK)
//   - BASVectorReranker (rerank candidates)
//   - BASIdentityVectorReranker (identity stub)
//
// M849 shipped SQLite-backed cross-session persistence
// (BASSQLiteVectorIndexStorage)。
//
// M850 (this file) composes them into the canonical 3-stage
// retrieval pipeline:
//
//   queryText
//     ↓ embeddingProvider.embed
//   queryEmbedding
//     ↓ vectorIndex.topK
//   topKResults (atomID + score)
//     ↓ reranker.rerank
//   reranked
//     ↓ atomLookup
//   atoms + scores → BASRAGResult
//
// Hosts that don't use this composer can still consume the
// individual primitives directly。This facade is the canonical
// composition for the most common case。
//
// ## Why facade not invasive wire-up
//
// M840 §3.4 wire-up was originally proposed in
// `EBrainHostRuntime+MemoryService.retrieve()`。On closer
// review,that wire-up requires:
//   - Adding 3 optional dependencies to
//     `BASHostRuntimeEBrainMemoryService` struct (provider /
//     index / reranker)
//   - Re-shaping retrieve() to be async (currently sync) which
//     cascades through the substrate flow
//
// This facade provides the same end-user functionality without
// invasively modifying the substrate retrieve() flow。Hosts
// compose:
//
//     let bundle = memoryService.retrieve(...)
//     let rag = await BASRAGRetriever.retrieve(
//         queryText: prompt,
//         embeddingProvider: provider,
//         vectorIndex: index,
//         atomLookup: { id in atomStore.atom(forID: id) })
//     // Caller decides how to merge bundle.atoms + rag.atoms
//
// Future M851+ may inline this into `retrieve()` once the
// async-hop concern is addressed (chapter 三百四七 M834-style
// careful Sendable analysis)。
//
// ## Doctrine pins held
//
//   - All BASEmbeddingProvider / BASVectorIndex /
//     BASVectorReranker pins apply
//   - 单提交口 (L11/L14) 不变 — RAG retrieval feeds memory
//     bundle,never bypasses gate
//   - chapter 二百一一 single-source-of-truth — ONE composition
//     facade for the canonical 3-stage pipeline
//   - chapter 一百八十五 anti-magic-number — default top-k +
//     reason code prefixes named typed constants
//   - ADR-014 OPT-IN → PROD — facade is purely additive,
//     hosts that don't call it use existing tier-prefix
//     retrieval

import Foundation
import BASRuntimeCore

// MARK: - BASRAGResult

/// Typed result of a RAG retrieval pipeline run。
public struct BASRAGResult: Sendable, Equatable {
    /// Successfully-fetched atoms,ordered by reranker score
    /// descending。Same order as the reranker output。
    public let atoms: [BASMemoryAtom]

    /// Per-atom score (after reranking)。Keyed by atomID。
    public let scores: [String: Float]

    /// Atom IDs that the vector index returned but `atomLookup`
    /// could not find。These are typically stale entries (atom
    /// was deleted from the L8 store but the vector index hasn't
    /// been swept yet)。Caller logs these for diagnostic emission。
    public let staleAtomIDs: [String]

    /// Reason codes for audit emission (mirrors chapter 二百一一
    /// reason-code grep doctrine)。Caller appends to retrieval
    /// tags / audit ledger。
    public let reasonCodes: [String]

    public init(
        atoms: [BASMemoryAtom],
        scores: [String: Float],
        staleAtomIDs: [String],
        reasonCodes: [String]
    ) {
        self.atoms = atoms
        self.scores = scores
        self.staleAtomIDs = staleAtomIDs
        self.reasonCodes = reasonCodes
    }
}

// MARK: - BASRAGRetriever namespace

/// Pure-function RAG retrieval composer。Stateless;all
/// dependencies passed at call time。
public enum BASRAGRetriever {

    /// Default top-k for the vector index stage (chapter 一百
    /// 八十五 anti-magic-number — pinned named constant)。
    /// Caller can override via the `k` parameter。
    public static let defaultTopK: Int = 10

    /// Reason-code prefix for audit emission。Mirrors existing
    /// `mesh-coreml:` and `constitution:` reason-code prefix
    /// idiom in this codebase。
    public static let reasonCodePrefix: String = "rag"

    /// Run the canonical 3-stage RAG retrieval pipeline。
    ///
    /// Stages:
    ///   1. Embed `queryText` via `embeddingProvider`
    ///   2. Top-k vector similarity via `vectorIndex`
    ///     (with optional `excludingDomains` filter for chapter
    ///     三百五六 G3 L3 composition)
    ///   3. Rerank via `reranker` (default: identity)
    ///   4. Resolve atom IDs to `BASMemoryAtom` via `atomLookup`
    ///
    /// - Parameters:
    ///   - queryText: text to embed for semantic similarity
    ///   - embeddingProvider: typed conformer (NLEmbedding /
    ///     stub / future MiniLM)
    ///   - vectorIndex: in-memory cosine top-k actor
    ///   - reranker: typed conformer (default identity);future
    ///     ChengluMemory v0 retrieval_rerank head wires here
    ///   - atomLookup: caller-supplied closure mapping atomID
    ///     → BASMemoryAtom?。Returning nil means "stale entry,
    ///     skip" (added to staleAtomIDs for diagnostic emission)
    ///   - k: max candidates to retrieve (default 10)
    ///   - excludingDomains: domains to filter at vector index
    ///     stage (chapter 三百五六 G3 L3 composition)
    ///   - candidateContextBuilder: optional closure that
    ///     produces the per-candidate context string the
    ///     reranker consumes。Default: nil (reranker context is
    ///     empty;identity reranker doesn't use it anyway,
    ///     learned rerankers should provide this)
    /// - Returns: typed BASRAGResult with atoms + scores +
    ///   staleAtomIDs + reasonCodes
    public static func retrieve(
        queryText: String,
        embeddingProvider: any BASEmbeddingProvider,
        vectorIndex: BASVectorIndex,
        reranker: any BASVectorReranker
            = BASIdentityVectorReranker(),
        atomLookup: @Sendable (String) async -> BASMemoryAtom?,
        k: Int = BASRAGRetriever.defaultTopK,
        excludingDomains: [String] = [],
        candidateContextBuilder:
            (@Sendable (String) async -> String)? = nil
    ) async -> BASRAGResult {
        var reasonCodes: [String] = [
            "\(reasonCodePrefix):provider:" +
                "\(embeddingProvider.providerVersion)",
            "\(reasonCodePrefix):reranker:" +
                "\(reranker.rerankerVersion)",
            "\(reasonCodePrefix):k:\(k)"
        ]
        if !excludingDomains.isEmpty {
            reasonCodes.append(
                "\(reasonCodePrefix):excluded-domains:" +
                "\(excludingDomains.count)")
        }
        // Empty query → empty result (defensive)
        let trimmed = queryText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reasonCodes.append(
                "\(reasonCodePrefix):empty-query")
            return BASRAGResult(
                atoms: [],
                scores: [:],
                staleAtomIDs: [],
                reasonCodes: reasonCodes)
        }
        // Stage 1: embed query
        let queryEmbedding = await embeddingProvider
            .embed(trimmed)
        let normalizedQuery = queryEmbedding.normalized
        // Stage 2: top-k vector similarity
        let candidates = await vectorIndex.topK(
            query: normalizedQuery,
            k: k,
            excludingDomains: excludingDomains)
        if candidates.isEmpty {
            reasonCodes.append(
                "\(reasonCodePrefix):no-candidates")
            return BASRAGResult(
                atoms: [],
                scores: [:],
                staleAtomIDs: [],
                reasonCodes: reasonCodes)
        }
        // Stage 3: reranker (with optional per-candidate context)
        var context: [String: String] = [:]
        if let contextBuilder = candidateContextBuilder {
            for candidate in candidates {
                context[candidate.atomID] = await
                    contextBuilder(candidate.atomID)
            }
        }
        let reranked = await reranker.rerank(
            query: normalizedQuery,
            candidates: candidates,
            candidateContext: context)
        // Stage 4: resolve atom IDs to BASMemoryAtom
        var atoms: [BASMemoryAtom] = []
        var scoreMap: [String: Float] = [:]
        var stale: [String] = []
        for candidate in reranked {
            if let atom = await atomLookup(candidate.atomID) {
                atoms.append(atom)
                scoreMap[candidate.atomID] = candidate.score
            } else {
                stale.append(candidate.atomID)
            }
        }
        reasonCodes.append(
            "\(reasonCodePrefix):resolved:\(atoms.count)")
        if !stale.isEmpty {
            reasonCodes.append(
                "\(reasonCodePrefix):stale:\(stale.count)")
        }
        return BASRAGResult(
            atoms: atoms,
            scores: scoreMap,
            staleAtomIDs: stale,
            reasonCodes: reasonCodes)
    }
}
