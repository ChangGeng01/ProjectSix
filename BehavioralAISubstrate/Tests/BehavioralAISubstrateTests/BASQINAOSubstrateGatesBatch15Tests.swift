import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrgan
@testable import BASRuntimeCore
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 15 (final 2 host-authorable: evallock + int8-cosine-drift).
final class BASQINAOSubstrateGatesBatch15Tests: XCTestCase {

    // [QINAO-REMOVED 2026-06-24 audit] mlx_evallock_concurrent_correctness was HOLLOW — it built a
    // stdlib NSRecursiveLock IN the test (the real MLX evalLock is vendor/package-private + device-gated),
    // so it tested no BAS production code. Removed; #17 is documented as a vendor/device-gated metric
    // (like #19 CoreAI, #99 CI) in QINAO_SUBSTRATE_GATE_MAP.md — not a host-authorable substrate gate.
    func test_qinao_int8_vector_cosine_drift() {
        // QINAO #33 HIGH — int8 cosine-drift bound.
        // Subject: the int8 vector quantize + cosine path
        //   BASAutoRouteRanker.quantizeInt8(_:) -> BASQuantizeInt8Result?
        //   BASAutoRouteRanker.cosineInt8(a:scaleA:b:scaleB:) -> Float?
        // both static on the `public enum BASAutoRouteRanker` (BASRuntimeCore).
        // Documented bound (BASInt8VectorIndexEntry header + chapter 727
        // quality gate): max |cos_int8 - cos_f32| <= 0.01 over a
        // representative grid of L2-normalized 384-dim vectors.
        //
        // The cosineInt8/quantizeInt8 path is #if os(iOS) || os(macOS)
        // gated because it routes to the in-repo Rust ranker binary
        // (bas_ranker_quantize_int8 / bas_ranker_cosine_int8). That host
        // (macOS) path IS the real source of truth — not a device fake —
        // so we assert the invariant directly against it, mirroring the
        // existing BASChapter727Int8VectorDriftGateTests construction
        // verbatim (SplitMix64 unit-vector generator + f32 dot cosine).
        #if os(iOS) || os(macOS)
        // --- helpers (defined inside the method) ---
        func unitVector(seed: UInt64, dim: Int) -> [Float] {
            var s = seed
            var v = [Float](repeating: 0, count: dim)
            for i in 0..<dim {
                s &+= 0x9E37_79B9_7F4A_7C15
                var z = s
                z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                z = z ^ (z >> 31)
                let u = (Float(z & 0xFFFF_FFFF)
                        / Float(UInt32.max)) * 2 - 1
                v[i] = u
            }
            var sumSquares: Float = 0
            for x in v { sumSquares += x * x }
            let mag = sqrt(sumSquares)
            if mag > 0 {
                for i in 0..<dim { v[i] /= mag }
            }
            return v
        }
        func f32Cosine(_ a: [Float], _ b: [Float]) -> Float {
            var dot: Float = 0
            for i in 0..<a.count { dot += a[i] * b[i] }
            return dot
        }

        let dim = 384
        let queryCount = 64
        let corpusCount = 512
        let bound: Float = 0.01

        var queries: [[Float]] = []
        queries.reserveCapacity(queryCount)
        for qi in 0..<queryCount {
            queries.append(unitVector(seed: UInt64(qi * 7919), dim: dim))
        }
        var corpus: [[Float]] = []
        corpus.reserveCapacity(corpusCount)
        for ci in 0..<corpusCount {
            corpus.append(unitVector(seed: UInt64(ci * 7867 + 31), dim: dim))
        }

        // Quantize entire corpus once.
        var corpusInt8: [[Int8]] = []
        var corpusScales: [Float] = []
        corpusInt8.reserveCapacity(corpusCount)
        for v in corpus {
            guard let r = BASAutoRouteRanker.quantizeInt8(v) else {
                XCTFail("quantizeInt8 returned nil for a valid corpus row")
                return
            }
            corpusInt8.append(r.quantized)
            corpusScales.append(r.scale)
        }

        // --- exhaustive-ish drift sweep ---
        var maxDrift: Float = 0
        var firstQI8: Float = 0   // capture for determinism re-check
        var capturedQ = false
        for qi in 0..<queryCount {
            let q = queries[qi]
            guard let qq = BASAutoRouteRanker.quantizeInt8(q) else {
                XCTFail("quantizeInt8 returned nil for a valid query")
                return
            }
            for ci in 0..<corpusCount {
                let cF32 = f32Cosine(q, corpus[ci])
                guard let cI8 = BASAutoRouteRanker.cosineInt8(
                    a: qq.quantized, scaleA: qq.scale,
                    b: corpusInt8[ci], scaleB: corpusScales[ci]) else {
                    XCTFail("cosineInt8 returned nil for valid int8 vectors")
                    return
                }
                if qi == 0 && ci == 0 {
                    firstQI8 = cI8
                    capturedQ = true
                }
                let drift = abs(cF32 - cI8)
                if drift > maxDrift { maxDrift = drift }
            }
        }
        XCTAssertTrue(capturedQ, "drift sweep produced no comparisons")

        // Raised bar #1 — the documented drift bound holds exhaustively.
        let comparisons = queryCount * corpusCount
        XCTAssertLessThanOrEqual(
            maxDrift, bound,
            "max int8 cosine drift \(maxDrift) over \(comparisons) "
            + "comparisons exceeds documented bound \(bound)")

        // Raised bar #2 — determinism: re-quantize + recompute the
        // (q0, c0) pair and require byte-identical Float output.
        guard let qq0 = BASAutoRouteRanker.quantizeInt8(queries[0]) else {
            XCTFail("re-quantize of query[0] returned nil"); return
        }
        guard let cI8Again = BASAutoRouteRanker.cosineInt8(
            a: qq0.quantized, scaleA: qq0.scale,
            b: corpusInt8[0], scaleB: corpusScales[0]) else {
            XCTFail("re-compute cosineInt8 returned nil"); return
        }
        XCTAssertEqual(
            cI8Again, firstQI8,
            "int8 cosine is non-deterministic across recomputation")

        // Raised bar #3 — mutate + assert: perturbing one query
        // coordinate must change the int8 cosine (path is live, not a
        // constant). A self-cosine must be ~1 and stay within bound of
        // the f32 self-cosine (1.0).
        var perturbed = queries[0]
        perturbed[0] = -perturbed[0]
        perturbed[1] = -perturbed[1]
        guard let qp = BASAutoRouteRanker.quantizeInt8(perturbed) else {
            XCTFail("quantizeInt8 of perturbed vector returned nil"); return
        }
        guard let cPerturbed = BASAutoRouteRanker.cosineInt8(
            a: qp.quantized, scaleA: qp.scale,
            b: corpusInt8[0], scaleB: corpusScales[0]) else {
            XCTFail("cosineInt8 of perturbed vector returned nil"); return
        }
        XCTAssertNotEqual(
            cPerturbed, firstQI8,
            "perturbing the query left the int8 cosine unchanged")

        // self-cosine: int8(q0) vs int8(q0) must be within bound of 1.0
        guard let cSelf = BASAutoRouteRanker.cosineInt8(
            a: qq0.quantized, scaleA: qq0.scale,
            b: qq0.quantized, scaleB: qq0.scale) else {
            XCTFail("self cosineInt8 returned nil"); return
        }
        XCTAssertLessThanOrEqual(
            abs(Float(1.0) - cSelf), bound,
            "int8 self-cosine \(cSelf) drifts from 1.0 beyond \(bound)")

        print("QINAO-GATE int8_vector_cosine_drift: PASS "
            + "maxDrift=\(maxDrift) <= \(bound) over \(comparisons) "
            + "comparisons (\(queryCount)q x \(corpusCount)r x \(dim)d), "
            + "deterministic + mutation-sensitive, selfCos=\(cSelf)")
        #else
        throw XCTSkip("int8 quantize/cosine path is host-gated "
            + "(#if os(iOS) || os(macOS)); Rust ranker binary unavailable")
        #endif
    }
}
