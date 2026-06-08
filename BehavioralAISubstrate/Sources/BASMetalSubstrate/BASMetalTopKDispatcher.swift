// ADR-039 Phase 2 — L8 retrieval ranking on Metal: batched cosine (GPU) + top-K selection.
//
// The HEAVY compute (query × corpus cosine, O(N·D)) runs on the GPU via the existing
// `BASMetalBatchedCosineSimilarityDispatcher`; the cheap top-K SELECTION (O(N) partial pick) runs on the
// CPU. The result is `BASApproxValue`-quarantined: the SCORES are GPU-derived (non-bit-reproducible), so
// the ranking is approximate (ADR-036 already sanctioned L8 cosineTopK as non-byte-equal). Per the
// determinism boundary (ADR-039), this is allowed because it is RETRIEVAL RANKING — the atom store /
// identity stay CPU/Rust; only `atomID` (a deterministic key) crosses into the spine, never the score.
//
// On a Metal fault the GPU dispatch THROWS — the L8 seam (BASL8RoutedMemoryService) is responsible for
// the Rust/CPU fallback (Phase 2 seam wiring). This dispatcher does the Metal path only.

import Foundation

/// One ranked retrieval hit: a corpus row index + its cosine score. Deterministic-comparable.
public struct BASCosineTopKHit: Sendable, Equatable, Codable {
    public let rowIndex: Int
    public let score: Float
    public init(rowIndex: Int, score: Float) {
        self.rowIndex = rowIndex
        self.score = score
    }
}

public actor BASMetalTopKDispatcher {

    private let cosine: BASMetalBatchedCosineSimilarityDispatcher

    public init(loader: BASMetalKernelLibraryLoader) {
        self.cosine = BASMetalBatchedCosineSimilarityDispatcher(loader: loader)
    }

    public var hasMemoizedPipeline: Bool {
        get async { await cosine.hasMemoizedPipeline }
    }

    /// Metal batched-cosine scores + deterministic CPU top-K. Returns the top-`k` hits by descending
    /// score (tie-break: ascending rowIndex). `BASApproxValue(.metal)` — GPU-tainted scores. Throws on a
    /// Metal fault (the caller falls back).
    public func dispatch(
        query: [Float],
        corpus: [Float],
        dim: Int,
        k: Int
    ) async throws -> BASApproxValue<[BASCosineTopKHit]> {
        let scores = try await cosine.dispatch(query: query, corpus: corpus, dim: dim)
        let top = Self.selectTopK(scores: scores, k: k)
        return BASApproxValue(
            top, provenance: .metal(kernel: "batched_cosine_similarity+topk", device: "gpu"))
    }

    /// Deterministic top-K over precomputed scores: sort by (−score, +rowIndex), take `k`. CPU; pure.
    /// (The SELECTION is deterministic; the SCORES are the Metal taint, hence the wrapper at the seam.)
    public static func selectTopK(scores: [Float], k: Int) -> [BASCosineTopKHit] {
        let hits = scores.enumerated().map { BASCosineTopKHit(rowIndex: $0.offset, score: $0.element) }
        let sorted = hits.sorted { a, b in
            a.score != b.score ? a.score > b.score : a.rowIndex < b.rowIndex
        }
        return Array(sorted.prefix(max(0, k)))
    }

    /// Pure-CPU cosine + top-K reference (for parity tests + the seam's fallback). Same selection rule.
    public static func cpuReference(
        query: [Float],
        corpus: [Float],
        dim: Int,
        k: Int
    ) -> [BASCosineTopKHit] {
        guard dim > 0, !query.isEmpty, corpus.count % dim == 0 else { return [] }
        let nRows = corpus.count / dim
        var qNorm: Float = 0
        for v in query { qNorm += v * v }
        qNorm = qNorm.squareRoot()
        var scores = [Float](repeating: 0, count: nRows)
        for r in 0..<nRows {
            var dot: Float = 0, rNorm: Float = 0
            let base = r * dim
            for d in 0..<dim {
                let rv = corpus[base + d]
                dot += query[d] * rv
                rNorm += rv * rv
            }
            rNorm = rNorm.squareRoot()
            scores[r] = (qNorm > 0 && rNorm > 0) ? dot / (qNorm * rNorm) : 0
        }
        return selectTopK(scores: scores, k: k)
    }
}
