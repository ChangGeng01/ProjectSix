// MARK: - BASVectorStorageSelector
// chapter 七百三十六 第一/二/三刀 / M2351-M2353
//
// Vector counterpart to the chapter 七百三十五 KV tier selector。
// Picks the cheapest `BASVectorStorageTier` meeting both:
//   (a) the host's memory budget AND
//   (b) the host's recall priority。
//
// Bridges three substrate areas under one decision API:
//   - Area 1 (Rust ranker):   Float32 batched cosine + int8 cosine
//   - Area 2 (SQL persistence): vector index can be in-memory or
//                              SQL-backed (host's choice,orthogonal)
//   - Area 4 (PQ approx NN):   chapter 七百二十九 BASPQIndex
//
// Pure-Swift utility — no FFI,no Rust dependency。 Host passes
// in the corpus size + budget + priority signals;substrate maps
// to a tier choice。

import Foundation

/// Typed vector storage tier identifier。 Mirrors the chapter
/// 七百三十五 BASKVCachePrecisionTier pattern but for the
/// vector-retrieval layer (chapter 七百十八 / 七百二十七 / 七百二十九)。
public enum BASVectorStorageTier:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Float32 baseline — chapter 七百十八 batched cosine flat-
    /// scan。 Exact distance,1× memory。 Best for small corpora
    /// (≤ 10K rows on iOS) and quality-pinned workloads。
    case float32 = "float32"

    /// int8 quantized storage — chapter 七百二十七
    /// BASInt8VectorIndexEntry。 4× memory shrink,99% recall@10,
    /// cosine-drift ≤ 0.0012。 Best for corpora that need to fit
    /// in tight RAM with minimal quality loss。
    case int8 = "int8"

    /// PQ approximate NN — chapter 七百二十九 BASPQIndex。 53×
    /// memory shrink,recall depends on corpus clustering (3% on
    /// uniform random,70-90% on production embeddings per
    /// literature)。 Best for very large corpora (≥ 100K rows)
    /// where Float32 doesn't fit。
    case pq = "pq"

    /// Theoretical memory shrink ratio for this tier vs Float32
    /// (asymptotic at large dim)。
    public var asymptoticShrinkRatio: Double {
        switch self {
        case .float32: return 1.0
        case .int8:    return 4.0
        case .pq:      return 53.0
        }
    }

    /// Recommended MINIMUM corpus size threshold for picking this
    /// tier。 Tiers below their threshold lose to Float32 because
    /// the per-tier overhead (codebooks for PQ,scales for int8)
    /// dilutes the memory savings。 Tiers at or above their
    /// threshold start winning。
    public var recommendedMinCorpusSize: Int {
        switch self {
        case .float32: return 0       // always usable
        case .int8:    return 1_000   // below 1K rows,FFI
                                     // overhead dominates
        case .pq:      return 100_000 // below 100K rows,flat-
                                     // scan wins per the chapter
                                     // 七百二十九 honest landing
        }
    }

    /// Recall@10 envelope for this tier (literature-pinned on
    /// production-shaped embeddings)。 Float32 = 1.0,int8 ≈ 0.99,
    /// PQ ≈ 0.85 (with chapter 七百三十一 K-means++ refinement)。
    public var typicalRecallAt10: Double {
        switch self {
        case .float32: return 1.0
        case .int8:    return 0.99
        case .pq:      return 0.85
        }
    }
}

/// Host-declared recall priority。 Hint to the selector about
/// what tradeoff the host prefers when memory is constrained。
public enum BASVectorRecallPriority:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Audit-pinned corpora — never approximate。 Use Float32
    /// flat-scan regardless of memory pressure。
    case exact = "exact"

    /// Recall-priority hosts — prefer Float32 / int8 over PQ
    /// when both fit。
    case recallFirst = "recall-first"

    /// Memory-priority hosts — accept lower recall in exchange
    /// for the biggest memory shrink (PQ at large N)。
    case memoryFirst = "memory-first"
}

/// Per-row byte estimate at each tier。
public struct BASVectorStorageEstimate:
    Codable, Equatable, Hashable, Sendable
{
    public let float32BytesPerRow: Int
    public let int8BytesPerRow: Int
    public let pqBytesPerRow: Int
    /// PQ has a fixed CODEBOOK overhead independent of corpus
    /// size。 At chapter 七百二十九 defaults (K=16,M=8,
    /// sub_dim=dim/8 floats):8 × 16 × (dim/8) × 4 bytes。
    public let pqCodebookBytes: Int

    public init(
        float32BytesPerRow: Int,
        int8BytesPerRow: Int,
        pqBytesPerRow: Int,
        pqCodebookBytes: Int
    ) {
        self.float32BytesPerRow = float32BytesPerRow
        self.int8BytesPerRow = int8BytesPerRow
        self.pqBytesPerRow = pqBytesPerRow
        self.pqCodebookBytes = pqCodebookBytes
    }

    /// Total bytes at `tier` for `corpusSize` rows。 PQ includes
    /// the constant codebook overhead;the other tiers don't。
    public func totalBytes(
        corpusSize: Int,
        tier: BASVectorStorageTier
    ) -> Int {
        switch tier {
        case .float32:
            return corpusSize * float32BytesPerRow
        case .int8:
            return corpusSize * int8BytesPerRow
        case .pq:
            return corpusSize * pqBytesPerRow
                + pqCodebookBytes
        }
    }
}

/// Builds a `BASVectorStorageEstimate` from vector shape。
public enum BASVectorStorageEstimator {

    /// Default PQ subquantizer count (M=8 per chapter 七百二十九)。
    public static let defaultPqM: Int = 8
    /// Default PQ codes per subquantizer (K=16 per chapter 七百二十九)。
    public static let defaultPqK: Int = 16

    /// Estimate per-row + codebook bytes across the 3 tiers for
    /// a vector index storing `dim`-dimensional Float32 vectors。
    public static func estimate(
        dim: Int,
        pqM: Int = defaultPqM,
        pqK: Int = defaultPqK
    ) -> BASVectorStorageEstimate {
        // Float32:dim × 4 bytes per row
        let f32 = dim * 4
        // int8:dim bytes + 4-byte scale + 8-byte len/version
        // overhead per row (matches chapter 七百二十七 measurement
        // showing ~3.86× shrink at large corpus → asymptotically
        // dim+12)
        let int8Bytes = dim + 12
        // PQ:M bytes per row (one code per subquantizer);PQ
        // codebook = M × K × sub_dim × 4 bytes
        let pqRow = pqM
        let subDim = dim / max(pqM, 1)
        let codebook = pqM * pqK * subDim * 4
        return BASVectorStorageEstimate(
            float32BytesPerRow: f32,
            int8BytesPerRow: int8Bytes,
            pqBytesPerRow: pqRow,
            pqCodebookBytes: codebook)
    }
}

/// Host-facing vector storage tier selector。 Picks the best
/// `BASVectorStorageTier` for a corpus shape given the host's
/// memory budget + recall priority。
public enum BASVectorStorageSelector {

    /// Pick the right tier。 Returns the tier choice + the bytes
    /// the chosen tier consumes + diagnostics。
    ///
    /// Decision logic:
    ///   - `.exact`        → always .float32 (regardless of budget
    ///                       or size)
    ///   - `.recallFirst`  → Float32 if fits → int8 if fits → PQ
    ///                       only if corpus ≥ recommendedMinCorpusSize
    ///                       AND neither prior tier fits
    ///   - `.memoryFirst`  → PQ if corpus ≥ recommendedMinCorpusSize
    ///                       AND PQ savings > 1 MB; else int8 if
    ///                       corpus ≥ int8 threshold AND int8 savings
    ///                       > 1 MB; else Float32
    public static func select(
        estimate: BASVectorStorageEstimate,
        corpusSize: Int,
        memoryBudgetBytes: Int,
        recallPriority: BASVectorRecallPriority
    ) -> Selection {
        let f32Total = estimate.totalBytes(
            corpusSize: corpusSize, tier: .float32)
        let i8Total = estimate.totalBytes(
            corpusSize: corpusSize, tier: .int8)
        let pqTotal = estimate.totalBytes(
            corpusSize: corpusSize, tier: .pq)

        switch recallPriority {

        case .exact:
            return Selection(
                tier: .float32,
                bytesUsed: f32Total,
                fitsInBudget: f32Total <= memoryBudgetBytes,
                reason: "exact priority — Float32 always")

        case .recallFirst:
            if f32Total <= memoryBudgetBytes {
                return Selection(
                    tier: .float32,
                    bytesUsed: f32Total,
                    fitsInBudget: true,
                    reason: "Float32 fits the budget")
            }
            // int8 only if corpus is big enough that FFI
            // overhead doesn't dominate
            if corpusSize
                >= BASVectorStorageTier.int8
                    .recommendedMinCorpusSize
               && i8Total <= memoryBudgetBytes
            {
                return Selection(
                    tier: .int8,
                    bytesUsed: i8Total,
                    fitsInBudget: true,
                    reason:
                        "Float32 over budget,int8 fits")
            }
            // PQ only if corpus crosses the 100K threshold
            if corpusSize
                >= BASVectorStorageTier.pq
                    .recommendedMinCorpusSize
               && pqTotal <= memoryBudgetBytes
            {
                return Selection(
                    tier: .pq,
                    bytesUsed: pqTotal,
                    fitsInBudget: true,
                    reason:
                        "neither Float32 nor int8 fit,PQ does")
            }
            // Nothing fits — return Float32 with the flag,let
            // host decide whether to reject or OOM-risk
            return Selection(
                tier: .float32,
                bytesUsed: f32Total,
                fitsInBudget: false,
                reason:
                    "no tier fits budget — falling back to Float32")

        case .memoryFirst:
            // Compute savings vs Float32 for each tier
            let int8Savings = f32Total - i8Total
            let pqSavings   = f32Total - pqTotal

            // Try PQ first (biggest savings),but ONLY at
            // corpus ≥ 100K AND savings > 1 MB
            if corpusSize
                >= BASVectorStorageTier.pq
                    .recommendedMinCorpusSize
               && pqSavings >= 1_048_576
            {
                return Selection(
                    tier: .pq,
                    bytesUsed: pqTotal,
                    fitsInBudget:
                        pqTotal <= memoryBudgetBytes,
                    reason:
                        "memory-first + corpus ≥ 100K → PQ")
            }
            // int8 if savings > 1 MB
            if corpusSize
                >= BASVectorStorageTier.int8
                    .recommendedMinCorpusSize
               && int8Savings >= 1_048_576
            {
                return Selection(
                    tier: .int8,
                    bytesUsed: i8Total,
                    fitsInBudget:
                        i8Total <= memoryBudgetBytes,
                    reason:
                        "memory-first → int8 (savings ≥ 1 MB)")
            }
            // Savings too small to justify any compression
            return Selection(
                tier: .float32,
                bytesUsed: f32Total,
                fitsInBudget:
                    f32Total <= memoryBudgetBytes,
                reason:
                    "compression savings < 1 MB,keep Float32")
        }
    }

    public struct Selection:
        Equatable, Hashable, Sendable
    {
        public let tier: BASVectorStorageTier
        public let bytesUsed: Int
        public let fitsInBudget: Bool
        public let reason: String

        public init(
            tier: BASVectorStorageTier,
            bytesUsed: Int,
            fitsInBudget: Bool,
            reason: String
        ) {
            self.tier = tier
            self.bytesUsed = bytesUsed
            self.fitsInBudget = fitsInBudget
            self.reason = reason
        }
    }
}
