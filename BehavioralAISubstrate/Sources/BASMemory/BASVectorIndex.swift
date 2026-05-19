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

    /// chapter 七百十八 第一刀 — feature flag controlling
    /// whether the per-pair `cosine(_:_:)` helper routes through
    /// `BASAutoRouteRanker.cosineSimilarity` (Rust SIMD ≥ dim 64,
    /// Rust scalar < dim 64 per chapter 七百四 measurement)。
    ///
    /// **DEFAULT FLIPPED ON at chapter 七百十八 第四刀** (M2264)
    /// per chapter 七百十八 第二刀 perf measurement:Rust wins
    /// 8.69× — 43.09× across (100/1K/5K entries × 128/384/768
    /// dim) grid。 The LARGEST per-target production speedup
    /// measured in this branch arc。
    ///
    /// Byte-equality verified by BASChapter718VectorIndexByteEqualityTests
    /// (top-K ordering identical across all three paths within
    /// fp32 tolerance)。
    ///
    /// Hosts that need the legacy Swift scalar path (e.g。 for
    /// replay-byte-pinned compat against an existing audit
    /// archive with fp32 score-byte pinning) can flip to `false`
    /// at startup。
    public nonisolated(unsafe) static var useRoutedCosine:
        Bool = true

    /// chapter 七百十八 第三刀 — second opt-in flag for the
    /// BATCHED topK fast-path:builds a contiguous corpus
    /// array once + single `bas_ranker_batched_cosine_simd`
    /// FFI hop。 Amortizes FFI overhead across all entries。
    ///
    /// Default STAYS off per chapter 七百十八 第二刀:per-pair
    /// Rust wins by 2.5-7% over batched at our measured sizes
    /// (the O(N*dim) memcpy to build the contiguous corpus
    /// cancels the FFI-amortization gain)。 Hosts with very
    /// large stable corpora (≥ 10K entries × ≥ 768 dim) MAY
    /// benefit from flipping this on,since the memcpy
    /// amortizes across multiple queries against the same
    /// corpus。
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

    /// chapter 七百二十七 第二刀 — feature flag controlling
    /// whether `topKInt8(query:)` is permitted。 Default OFF —
    /// hosts opt in by:
    ///   1. flipping the flag,
    ///   2. inserting BASInt8VectorIndexEntry rows (via
    ///      `insertInt8` / `upsertInt8`),
    ///   3. calling `topKInt8(query:)` instead of `topK`。
    ///
    /// The Float32 path (legacy entries + `topK`) keeps working
    /// concurrently — int8 entries live in a separate parallel
    /// dictionary。 Mixing isn't supported within a single query;
    /// callers pick the path per query。
    ///
    /// Quality gate:cosine-drift ≤ 0.01 across 100 random
    /// queries × 1000-row corpus (chapter 七百二十七 第三刀
    /// `BASChapter727Int8VectorDriftGateTests`)。 NOT byte-equal
    /// with Float32 — first chapter in the arc to ship a
    /// quality-drift-gated production path。
    public nonisolated(unsafe) static var
        useInt8VectorStorage: Bool = false

    // MARK: - State

    private var entries: [String: BASVectorIndexEntry] = [:]
    private var orderedIDs: [String] = []
    private var boundDimension: Int? = nil

    /// chapter 七百二十七 第二刀 — int8-quantized entry storage,
    /// parallel to the Float32 `entries` map。 Hosts use
    /// `insertInt8` / `topKInt8` to opt into this path。
    private var int8Entries:
        [String: BASInt8VectorIndexEntry] = [:]
    private var int8OrderedIDs: [String] = []

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

    // MARK: - int8 insert / upsert / remove (chapter 七百二十七 第二刀)

    /// Insert an int8-quantized entry。 Dimension-bind contract
    /// mirrors the Float32 path:first insert sets the bound,
    /// subsequent inserts with different dim throw。
    public func insertInt8(
        _ entry: BASInt8VectorIndexEntry
    ) throws {
        if let bound = boundDimension {
            guard entry.dimension == bound else {
                throw BASVectorIndexError.dimensionMismatch(
                    expected: bound,
                    got: entry.dimension)
            }
        } else {
            boundDimension = entry.dimension
        }
        guard int8Entries[entry.atomID] == nil else {
            throw BASVectorIndexError.duplicateAtomID(
                entry.atomID)
        }
        int8Entries[entry.atomID] = entry
        int8OrderedIDs.append(entry.atomID)
    }

    @discardableResult
    public func removeInt8(atomID: String) -> Bool {
        guard int8Entries[atomID] != nil else { return false }
        int8Entries.removeValue(forKey: atomID)
        int8OrderedIDs.removeAll { $0 == atomID }
        return true
    }

    public var int8EntryCount: Int {
        int8Entries.count
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
               Self.domainExcluded(
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

    /// chapter 七百二十七 第二刀 — int8-quantized top-k。
    /// Quantizes the Float32 query once,then runs a single
    /// batched-int8-cosine FFI call over the int8 corpus。
    /// Caller must pre-normalize the query (same contract as
    /// `topK`)。 Returns empty if `useInt8VectorStorage == false`
    /// or no int8 entries are loaded。
    ///
    /// Cosine-drift gate (chapter 七百二十七 第三刀):
    ///   max |cos_int8 - cos_f32| ≤ 0.01 across 100 random
    ///   queries × 1000-row 384-dim corpus
    public func topKInt8(
        query: BASEmbedding,
        k: Int,
        excludingDomains: [String] = []
    ) -> [BASVectorTopKResult] {
        guard k > 0, !int8Entries.isEmpty else { return [] }
        if let bound = boundDimension,
           query.dimension != bound
        { return [] }
        guard Self.useInt8VectorStorage else { return [] }

        let dim = query.dimension

        // Quantize the query once
        guard let qq = BASAutoRouteRanker.quantizeInt8(
            query.vector)
        else { return [] }

        // Build contiguous corpus + per-row scales,recording
        // which atomIDs they correspond to (so domain filter
        // applies before scoring)。
        var candidateIDs: [String] = []
        var corpusFlat: [Int8] = []
        var rowScales: [Float] = []
        candidateIDs.reserveCapacity(int8Entries.count)
        corpusFlat.reserveCapacity(
            int8Entries.count * dim)
        rowScales.reserveCapacity(int8Entries.count)
        for id in int8OrderedIDs {
            guard let entry = int8Entries[id]
            else { continue }
            if !excludingDomains.isEmpty,
               Self.domainExcluded(
                    entry.domain,
                    against: excludingDomains)
            { continue }
            candidateIDs.append(id)
            corpusFlat.append(
                contentsOf: entry.quantizedEmbedding
                    .toInt8Array())
            rowScales.append(
                entry.quantizedEmbedding.scale)
        }
        if candidateIDs.isEmpty { return [] }

        // Single batched FFI hop
        guard let scores = BASAutoRouteRanker
            .batchedCosineInt8(
                query: qq.quantized,
                scaleQuery: qq.scale,
                corpus: corpusFlat,
                corpusScales: rowScales,
                dim: dim)
        else { return [] }

        // Pair (id, score) + sort descending,truncate to k
        var paired: [BASVectorTopKResult] =
            zip(candidateIDs, scores).map {
                BASVectorTopKResult(
                    atomID: $0.0, score: $0.1)
            }
        paired.sort { $0.score > $1.score }
        if paired.count > k {
            return Array(paired.prefix(k))
        }
        return paired
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
               Self.domainExcluded(
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

    fileprivate static func domainExcluded(
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
