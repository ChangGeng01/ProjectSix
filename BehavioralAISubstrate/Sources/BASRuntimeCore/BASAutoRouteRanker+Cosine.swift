// MARK: - BASAutoRouteRanker+Cosine
// God-object extraction (audit ch1040, WS1): the Cosine domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - Batched cosine routing (chapter 七百十五 第四刀)
    //
    // Per matrix「Metal:embedding similarity」 — but per
    // chapter 七百十五 第三刀 tournament: Rust SIMD wins at all
    // measured sizes on Apple M-series。 Routing decision
    // (Rust vs Metal) is pure-policy here;the dispatch is
    // synchronous Rust at all sizes below
    // `batchedCosineMetalMinRows`。 Metal dispatch requires an
    // async dispatcher,exposed via a separate brain helper
    // that takes the dispatcher as a parameter。

    /// Pure-policy helper returning the routing CHOICE for a
    /// given (corpus_rows × dim) shape。
    public static func batchedCosineChoice(
        corpusRows: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        if corpusRows >= thresholds.batchedCosineMetalMinRows
        {
            return .metalBatchedCosine
        }
        return .rustBatchedCosine
    }

    /// Synchronous Rust-SIMD batched cosine。 Returns
    /// (scores[n_rows], choice)。 Always routes to Rust here;
    /// callers wanting the Metal fallback must use the brain
    /// helper that takes a dispatcher (chapter 七百十五 第四刀
    /// `BASCognitiveBrain.batchedCosineAuto`)。
    ///
    /// chapter 八百七十二 / M3026 — adaptive parallel routing:
    /// when corpus has ≥ `thresholds.batchedCosineRayonMinRows`
    /// rows,routes to the rayon-parallel C ABI for ~core-count
    /// speedup at large-batch FFI amortization。 Below threshold
    /// the sequential SIMD path wins (FFI overhead < rayon
    /// scheduling overhead at small batches)。
    ///
    /// chapter 八百八十 / M3085 — wired the chapter 879 threshold
    /// field `batchedCosineRayonChunkRows` through to the Rust
    /// rayon worker chunk size via the new
    /// `bas_ranker_batched_cosine_simd_rayon_chunked` C ABI。
    /// Default 64 → byte-identical to the chapter 872 result;
    /// host calibration can now legitimately tune chunk size per
    /// device (was a chapter 八百七十六.6 TODO promoted here)。
    public static func batchedCosineSimilarity(
        query: [Float],
        corpus: [Float],
        dim: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        precondition(dim > 0,
            "dim must be positive")
        precondition(query.count == dim,
            "query length must equal dim")
        precondition(corpus.count % dim == 0,
            "corpus length must be multiple of dim")
        let nRows = corpus.count / dim
        guard nRows > 0 else {
            return BASAutoRouteResult(
                value: [], choice: .rustBatchedCosine)
        }
        var scores = [Float](repeating: 0, count: nRows)
        #if os(iOS) || os(macOS)
        let useRayon = nRows >=
            thresholds.batchedCosineRayonMinRows
        let chunkRows = thresholds
            .batchedCosineRayonChunkRows
        let rc = query.withUnsafeBufferPointer { qp in
            corpus.withUnsafeBufferPointer { cp in
                scores
                    .withUnsafeMutableBufferPointer { op in
                    if useRayon {
                        bas_ranker_batched_cosine_simd_rayon_chunked(
                            qp.baseAddress, query.count,
                            cp.baseAddress, corpus.count,
                            dim,
                            chunkRows,
                            op.baseAddress)
                    } else {
                        bas_ranker_batched_cosine_simd(
                            qp.baseAddress, query.count,
                            cp.baseAddress, corpus.count,
                            dim,
                            op.baseAddress)
                    }
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: scores,
                choice: useRayon
                    ? .rustBatchedCosineRayon
                    : .rustBatchedCosine)
        }
        #endif
        // Pure-Swift fallback (no FFI hop)
        return BASAutoRouteResult(
            value: swiftBatchedCosineFallback(
                query: query, corpus: corpus, dim: dim),
            choice: .swiftNaive)
    }

    private static func swiftBatchedCosineFallback(
        query: [Float], corpus: [Float], dim: Int
    ) -> [Float] {
        let nRows = corpus.count / dim
        var out = [Float](repeating: 0, count: nRows)
        var normQ: Float = 0
        for d in 0..<dim { normQ += query[d] * query[d] }
        let invNormQ: Float = normQ > 0
            ? 1.0 / normQ.squareRoot() : 0
        for r in 0..<nRows {
            var dot: Float = 0
            var normR: Float = 0
            let base = r * dim
            for d in 0..<dim {
                let rd = corpus[base + d]
                dot += query[d] * rd
                normR += rd * rd
            }
            if normR <= 0 {
                out[r] = 0
            } else {
                let invNormR: Float =
                    1.0 / normR.squareRoot()
                out[r] = dot * invNormQ * invNormR
            }
        }
        return out
    }

    // MARK: - int8 cosine retrieval (chapter 七百二十七 第二刀 / M2307)

    /// Cosine between two int8-quantized vectors。 Returns nil on
    /// FFI failure or length mismatch。
    public static func cosineInt8(
        a: [Int8], scaleA: Float,
        b: [Int8], scaleB: Float
    ) -> Float? {
        #if os(iOS) || os(macOS)
        guard a.count == b.count else { return nil }
        var out: Float = 0
        let rc = a.withUnsafeBufferPointer { ap in
            return b.withUnsafeBufferPointer { bp in
                return bas_ranker_cosine_int8(
                    ap.baseAddress, ap.count, scaleA,
                    bp.baseAddress, bp.count, scaleB,
                    &out)
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// Batched cosine across many int8-quantized corpus rows。
    /// `corpus` is n_rows × dim contiguous;`corpusScales` has
    /// one f32 per row。 Returns one cosine per row,or nil on
    /// shape error / FFI failure。
    public static func batchedCosineInt8(
        query: [Int8], scaleQuery: Float,
        corpus: [Int8], corpusScales: [Float],
        dim: Int
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        guard dim > 0,
              query.count == dim,
              corpus.count % dim == 0
        else { return nil }
        let nRows = corpus.count / dim
        guard corpusScales.count == nRows else { return nil }
        var scores = [Float](repeating: 0, count: nRows)
        let rc = query.withUnsafeBufferPointer { qp in
            return corpus.withUnsafeBufferPointer { cp in
                return corpusScales
                    .withUnsafeBufferPointer { sp in
                        return scores
                        .withUnsafeMutableBufferPointer { op in
                            return bas_ranker_batched_cosine_int8(
                                qp.baseAddress, qp.count, scaleQuery,
                                cp.baseAddress, cp.count,
                                sp.baseAddress, sp.count,
                                dim,
                                op.baseAddress, op.count)
                        }
                }
            }
        }
        if rc != 0 { return nil }
        return scores
        #else
        return nil
        #endif
    }

    // MARK: - int8 quantization (chapter 七百二十六 第二刀 / M2302)
    //
    // Net-new capability: substrate gains symmetric int8 quantize
    // / dequantize / matmul primitives。 Foundation for chapters
    // 七百二十七 (int8 vector storage) + 七百二十八 (int8 KV cache)。

    /// Result of quantization: int8 buffer + scale。
    public struct BASQuantizeInt8Result: Sendable, Equatable {
        public let quantized: [Int8]
        public let scale: Float
        public init(quantized: [Int8], scale: Float) {
            self.quantized = quantized
            self.scale = scale
        }
    }

    /// Symmetric int8 quantize。 Returns (int8 buffer + scale)
    /// or nil on FFI failure。
    public static func quantizeInt8(
        _ x: [Float]
    ) -> BASQuantizeInt8Result? {
        #if os(iOS) || os(macOS)
        if x.isEmpty {
            return BASQuantizeInt8Result(
                quantized: [], scale: 0)
        }
        var quantized = [Int8](repeating: 0, count: x.count)
        var scale: Float = 0
        let rc = x.withUnsafeBufferPointer { xp in
            return quantized.withUnsafeMutableBufferPointer { qp in
                return bas_ranker_quantize_int8(
                    xp.baseAddress, xp.count,
                    qp.baseAddress, qp.count,
                    &scale)
            }
        }
        if rc != 0 { return nil }
        return BASQuantizeInt8Result(
            quantized: quantized, scale: scale)
        #else
        return nil
        #endif
    }

    /// Dequantize int8 + scale back to Float32。 Returns nil on
    /// FFI failure。
    public static func dequantizeInt8(
        _ q: [Int8], scale: Float
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        if q.isEmpty { return [] }
        var out = [Float](repeating: 0, count: q.count)
        let rc = q.withUnsafeBufferPointer { qp in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_ranker_dequantize_int8(
                    qp.baseAddress, qp.count, scale,
                    op.baseAddress, op.count)
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// int8 × int8 matmul → Float32。 A (m×k) × B (k×n) = C (m×n),
    /// all row-major。 Returns nil on shape mismatch or FFI failure。
    public static func matmulInt8(
        a: [Int8], scaleA: Float,
        b: [Int8], scaleB: Float,
        m: Int, k: Int, n: Int
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        guard a.count == m * k,
              b.count == k * n
        else { return nil }
        var c = [Float](repeating: 0, count: m * n)
        let rc = a.withUnsafeBufferPointer { ap in
            return b.withUnsafeBufferPointer { bp in
                return c.withUnsafeMutableBufferPointer { cp in
                    return bas_ranker_matmul_int8(
                        ap.baseAddress, ap.count, scaleA,
                        bp.baseAddress, bp.count, scaleB,
                        m, k, n,
                        cp.baseAddress, cp.count)
                }
            }
        }
        if rc != 0 { return nil }
        return c
        #else
        return nil
        #endif
    }

    // MARK: - Aggregations (chapter 七百二十五 第二刀 / M2297)
    //
    // Routes through the chapter 七百二十五 第一刀 Rust
    // `aggregations::usage_count_for_atom`。 Reuses the chapter
    // 七百二十三 records wire format。

    /// Rust-routed `usageCount(forAtomID:)`。 Returns nil only on
    /// FFI failure (extremely unlikely from typed Swift input)。
    public static func usageCountForAtom(
        records: [BASImportanceRecord],
        atomID: String
    ) -> Int? {
        #if os(iOS) || os(macOS)
        let recordsBuf = encodeRecordsBuffer(records)
        let atomIDBytes = Array(atomID.utf8)
        return recordsBuf.withUnsafeBufferPointer { rp in
            return atomIDBytes.withUnsafeBufferPointer { ap in
                let rc = bas_ranker_usage_count_for_atom(
                    rp.baseAddress, recordsBuf.count,
                    ap.baseAddress, atomIDBytes.count)
                return rc >= 0 ? Int(rc) : nil
            }
        }
        #else
        return nil
        #endif
    }
}
