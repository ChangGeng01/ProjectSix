// MARK: - BASVectorIndex — chapter 三百六十 / M847
//
// Phase P1 G4 第二刀: in-memory cosine-similarity vector index。
// Closes the "vector index" piece of G4 from M840 Cognitive OS
// roadmap。
//
// ## Why in-memory only (per M840 §3.4 explicit choice)
//
// > External vector DB (Pinecone/Weaviate): rejected. iPhone-scale
// > corpus fits in SQLite blob + memory.
//
// For a personal cognitive OS:
//   - 10K memory atoms × 384 dims × 4 bytes (Float32) = 15 MB
//   - Linear scan top-k: 10K × 384 mults = 4M ops < 5ms on M1
//
// No external service,no async I/O on retrieval path,no extra
// dependency。SQLite-backed persistence ships in a future chapter
// (vector blob column on memory_atoms,loaded into memory at
// session start)。
//
// ## What this ships
//
//   - `BASVectorIndexEntry` typed row (atomID + embedding +
//     metadata for filtering)
//   - `BASVectorIndex` actor (Sendable async insert + top-k)
//   - Cosine similarity over normalized vectors (precomputed at
//     insert time for fast top-k scan)
//   - Optional metadata filter at top-k time (for chapter 三百五六
//     restrictedMemoryDomains[] composition)
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — index is pure transformation,
//     no permit/verdict mutation
//   - 红线 7 hint-only — similarity is INPUT to retrieval scoring
//   - chapter 二百一一 single-source-of-truth — ONE vector index
//     primitive
//   - chapter 一百八十五 anti-magic-number — default top-k +
//     dimension-mismatch behavior pinned
//   - ADR-014 OPT-IN → PROD — empty index returns empty results,
//     no error (caller falls through to existing tier-ordered
//     retrieval)

import Foundation
import BASRuntimeCore

// MARK: - Index entry

/// Typed row in the vector index。Pairs an atom ID with its
/// embedding + free-form metadata for retrieval-time filtering。
public struct BASVectorIndexEntry:
    Codable, Sendable, Equatable
{
    /// Atom ID (matches `BASGovernedMemory.id.uuidString`)。
    public let atomID: String

    /// Pre-normalized embedding (caller responsibility — call
    /// `.normalized` before insert to avoid re-normalization on
    /// every top-k scan)。
    public let normalizedEmbedding: BASEmbedding

    /// Free-form domain tag for restrictedMemoryDomains[]
    /// composition (chapter 三百五六 G3 L3)。Caller sets this
    /// from `BASGovernedMemory.sourceType` or similar。
    public let domain: String

    /// Free-form payload metadata for caller-defined filtering
    /// (e.g. tier / governance status / sensitivity tag)。
    public let metadata: [String: String]

    public init(
        atomID: String,
        normalizedEmbedding: BASEmbedding,
        domain: String = "",
        metadata: [String: String] = [:]
    ) {
        self.atomID = atomID
        self.normalizedEmbedding = normalizedEmbedding
        self.domain = domain
        self.metadata = metadata
    }
}

// MARK: - Top-k result

/// Typed result of a top-k similarity query。
public struct BASVectorTopKResult:
    Codable, Sendable, Equatable
{
    /// Candidate atom ID。
    public let atomID: String

    /// Cosine similarity score in `[-1, 1]` (assuming both
    /// vectors were normalized at insert time)。Higher = more
    /// similar。
    public let score: Float

    public init(atomID: String, score: Float) {
        self.atomID = atomID
        self.score = score
    }
}

// MARK: - Vector index actor

/// Actor-isolated in-memory cosine-similarity vector index。
/// Inserts pre-normalized embeddings;top-k scans are linear
/// (sufficient for iPhone-scale corpora < 10K atoms per M840
/// §3.4 doctrine)。
///
/// **Dimension binding**: the first insert sets the index's
/// expected dimension。Subsequent inserts with different
/// dimension throw `BASVectorIndexError.dimensionMismatch`。
///
/// **Thread safety**: all mutating operations + reads are actor-
/// isolated。Hosts can hold a reference + concurrently query。
public actor BASVectorIndex {

    /// chapter 七百十八 第一刀 — opt-in feature flag controlling
    /// whether the per-pair `cosine(_:_:)` helper routes through
    /// `BASAutoRouteRanker.cosineSimilarity` (Rust SIMD ≥ dim 64,
    /// Rust scalar < dim 64 per chapter 七百四 measurement)。
    ///
    /// Default `false` until chapter 七百十八 第二刀 perf
    /// measurement confirms speedup at typical RAG corpus sizes
    /// (1K-10K entries × dim 128-768)。 Hosts can opt in at any
    /// time before constructing the index。
    public nonisolated(unsafe) static var useRoutedCosine:
        Bool = false

    /// chapter 七百十八 第三刀 — second opt-in flag for the
    /// BATCHED topK fast-path:builds a contiguous corpus
    /// array once + single `bas_ranker_batched_cosine_simd`
    /// FFI hop。 Amortizes FFI overhead across all entries。
    /// Default off until perf measurement confirms。
    public nonisolated(unsafe) static var useBatchedTopK:
        Bool = false

    // MARK: - Errors

    public enum BASVectorIndexError: Error,
        Equatable, Sendable
    {
        /// Caller inserted an embedding with a dimension that
        /// doesn't match the index's bound dimension。
        case dimensionMismatch(
            expected: Int, got: Int)
        /// Caller inserted a duplicate atomID。Index is keyed by
        /// atomID;use `replace(...)` to update。
        case duplicateAtomID(String)
    }

    // MARK: - State

    private var entries: [String: BASVectorIndexEntry] = [:]
    private var orderedIDs: [String] = []
    private var boundDimension: Int? = nil

    public init() {}

    // MARK: - Insert / replace / remove

    /// Insert a new entry。Throws on dimension mismatch or
    /// duplicate atomID。
    public func insert(
        _ entry: BASVectorIndexEntry
    ) throws {
        if let bound = boundDimension {
            guard entry.normalizedEmbedding.dimension == bound
            else {
                throw BASVectorIndexError.dimensionMismatch(
                    expected: bound,
                    got: entry.normalizedEmbedding.dimension)
            }
        } else {
            boundDimension = entry.normalizedEmbedding.dimension
        }
        guard entries[entry.atomID] == nil else {
            throw BASVectorIndexError.duplicateAtomID(
                entry.atomID)
        }
        entries[entry.atomID] = entry
        orderedIDs.append(entry.atomID)
    }

    /// Replace existing entry by atomID,or insert if absent。
    /// Same dimension-bind contract as insert。
    public func upsert(
        _ entry: BASVectorIndexEntry
    ) throws {
        if let bound = boundDimension {
            guard entry.normalizedEmbedding.dimension == bound
            else {
                throw BASVectorIndexError.dimensionMismatch(
                    expected: bound,
                    got: entry.normalizedEmbedding.dimension)
            }
        } else {
            boundDimension = entry.normalizedEmbedding.dimension
        }
        if entries[entry.atomID] == nil {
            orderedIDs.append(entry.atomID)
        }
        entries[entry.atomID] = entry
    }

    /// Remove entry by atomID。Returns true if removed,false if
    /// absent。
    @discardableResult
    public func remove(atomID: String) -> Bool {
        guard entries[atomID] != nil else { return false }
        entries.removeValue(forKey: atomID)
        orderedIDs.removeAll { $0 == atomID }
        return true
    }

    // MARK: - Top-k query

    /// Cosine similarity top-k。Pass a pre-normalized query
    /// embedding (caller calls `.normalized` first)。
    ///
    /// - Parameters:
    ///   - query: pre-normalized query embedding
    ///   - k: max results to return (clamped to entries.count)
    ///   - excludingDomains: drop entries whose `domain` matches
    ///     any of these (case-insensitive substring) — for
    ///     chapter 三百五六 restrictedMemoryDomains composition
    /// - Returns: top-k results sorted by score descending。
    ///   Empty array if index is empty or k <= 0。
    public func topK(
        query: BASEmbedding,
        k: Int,
        excludingDomains: [String] = []
    ) -> [BASVectorTopKResult] {
        guard k > 0, !entries.isEmpty else { return [] }
        // Defensive: query dimension must match bound dimension
        if let bound = boundDimension,
           query.dimension != bound
        {
            return []
        }
        // chapter 七百十八 第三刀 — batched fast-path when
        // useBatchedTopK is ON。 Single FFI hop for the entire
        // corpus,amortizing per-pair overhead。
        if Self.useBatchedTopK {
            return topKBatched(
                query: query.vector,
                k: k,
                excludingDomains: excludingDomains)
        }
        // Score every entry (linear scan — fine for < 10K)
        var scored: [BASVectorTopKResult] = []
        scored.reserveCapacity(entries.count)
        for id in orderedIDs {
            guard let entry = entries[id] else { continue }
            // Apply domain filter (chapter 三百五六 composition)
            if !excludingDomains.isEmpty,
               domainExcluded(
                    entry.domain,
                    against: excludingDomains)
            {
                continue
            }
            let score = Self.cosine(
                lhs: query.vector,
                rhs: entry.normalizedEmbedding.vector)
            scored.append(BASVectorTopKResult(
                atomID: id, score: score))
        }
        // Sort descending + truncate
        scored.sort { $0.score > $1.score }
        if scored.count > k {
            return Array(scored.prefix(k))
        }
        return scored
    }

    // MARK: - Convenience

    public var entryCount: Int {
        entries.count
    }

    public var dimension: Int? {
        boundDimension
    }

    public func contains(atomID: String) -> Bool {
        entries[atomID] != nil
    }

    // MARK: - Private helpers

    /// Cosine similarity between two **already-normalized**
    /// vectors。If callers passed normalized inputs (the contract
    /// for this index),this reduces to the dot product。If
    /// either was not normalized,the result still falls in
    /// `[-magnitude, +magnitude]` but the magnitude isn't bounded
    /// at 1。Caller's contract pin: normalize at insert + query
    /// time。
    fileprivate static func cosine(
        lhs: [Float], rhs: [Float]
    ) -> Float {
        // Mismatched dim → 0 (defensive — top-k caller already
        // gates on bound dimension,this is belt-and-suspenders)
        guard lhs.count == rhs.count else { return 0 }
        // chapter 七百十八 第一刀 — opt-in route through Rust。
        // Per chapter 七百四 measurement Rust SIMD wins at
        // dim ≥ 64,Rust scalar wins at smaller dims。 Default
        // OFF until 七百十八 第二刀 perf confirms。
        //
        // LEGACY PATH (kept,unchanged):
        //     var dot: Float = 0
        //     for i in 0..<lhs.count { dot += lhs[i] * rhs[i] }
        //     return dot
        if useRoutedCosine {
            // For pre-normalized vectors `cosineSimilarity`
            // (which divides by ‖q‖·‖r‖ ≈ 1·1 = 1) returns
            // mathematically the same value as the bare dot
            // product within fp32 rounding。
            return BASAutoRouteRanker
                .cosineSimilarity(lhs, rhs).value
        }
        var dot: Float = 0
        for i in 0..<lhs.count {
            dot += lhs[i] * rhs[i]
        }
        return dot
    }

    /// chapter 七百十八 第三刀 — batched top-K fast-path。
    /// Builds a contiguous corpus array ONCE from the index's
    /// `entries` map,then dispatches a single
    /// `bas_ranker_batched_cosine_simd` FFI call。 Amortizes
    /// the FFI hop across all entries (vs per-pair where we
    /// pay N FFI calls)。
    ///
    /// Output scores are paired with `orderedIDs` to recover
    /// the (atomID, score) tuples。 Domain filtering is
    /// applied AFTER scoring (cost is just N comparisons,
    /// so post-filter is simpler than pre-filter)。
    fileprivate func topKBatched(
        query: [Float], k: Int,
        excludingDomains: [String]
    ) -> [BASVectorTopKResult] {
        let dim = query.count
        // Flatten orderedIDs into contiguous (entries[id]) row
        // matrix。 Filter out any IDs whose entry is missing
        // (defensive — never happens in practice)。
        var corpusIDs: [String] = []
        var corpus: [Float] = []
        corpusIDs.reserveCapacity(orderedIDs.count)
        corpus.reserveCapacity(orderedIDs.count * dim)
        for id in orderedIDs {
            guard let e = entries[id] else { continue }
            let v = e.normalizedEmbedding.vector
            guard v.count == dim else { continue }
            corpusIDs.append(id)
            corpus.append(contentsOf: v)
        }
        guard !corpus.isEmpty else { return [] }
        let r = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: query, corpus: corpus, dim: dim)
        // Pair scores with IDs, filter excluded domains,
        // sort descending,truncate to k
        var scored: [BASVectorTopKResult] = []
        scored.reserveCapacity(corpusIDs.count)
        for (i, id) in corpusIDs.enumerated() {
            if !excludingDomains.isEmpty,
               let e = entries[id],
               domainExcluded(
                    e.domain, against: excludingDomains)
            {
                continue
            }
            scored.append(BASVectorTopKResult(
                atomID: id, score: r.value[i]))
        }
        scored.sort { $0.score > $1.score }
        if scored.count > k {
            return Array(scored.prefix(k))
        }
        return scored
    }

    fileprivate func domainExcluded(
        _ domain: String,
        against patterns: [String]
    ) -> Bool {
        guard !domain.isEmpty else { return false }
        let lowered = domain.lowercased()
        for pattern in patterns {
            let trimmed = pattern.trimmingCharacters(
                in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if lowered.contains(trimmed.lowercased()) {
                return true
            }
        }
        return false
    }
}
