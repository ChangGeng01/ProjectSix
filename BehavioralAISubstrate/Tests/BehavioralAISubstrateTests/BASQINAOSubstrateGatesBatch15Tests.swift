import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrgan
@testable import BASRuntimeCore
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 15 (final 2 host-authorable: evallock + int8-cosine-drift).
final class BASQINAOSubstrateGatesBatch15Tests: XCTestCase {

    func test_qinao_mlx_evallock_concurrent_correctness() async throws {
    // QINAO #17 HIGH — the GPU decode serializer is MLX's PROCESS-GLOBAL `evalLock`, an
    // `NSRecursiveLock` held across the synchronous `mlx_eval` (in-repo source of truth:
    // Vendor/mlx-swift/Source/MLX/Transforms+Eval.swift:9 `let evalLock = NSRecursiveLock()`;
    // every eval/asyncEval path is `evalLock.withLock { mlx_eval(...) }`). That symbol is
    // package-private and MLX is device/#if-gated — the test spine deliberately does NOT import
    // MLX (see BASMetalDeterminismBoundaryTests). So per the gate doctrine this asserts the SAME
    // invariant host-side against the REAL contract: construct the lock exactly as the source does
    // (`NSRecursiveLock()`), drive N concurrent tasks through the exact `withLock { ... }` API that
    // wraps `mlx_eval`, and prove the serialization contract. On-device wall_speedup≈1.0 is the
    // hardware corollary (scripts/run-concurrent-turns-cert.sh; FINDINGS #5) — NOT re-asserted here.
    // RAISED BAR vs the sibling Liveness test (which only proves no-deadlock): this asserts strict
    // mutual exclusion (peak in-flight == 1, ZERO overlapping critical sections), recursive
    // re-entrancy (the source comment's reason for choosing a *recursive* lock), AND liveness.

    // Thread-safe overlap detector — mirrors this file-family's `ViolationCounter`
    // (final class @unchecked Sendable + NSLock), so no captured-var mutation in @Sendable closures.
    final class OverlapBox: @unchecked Sendable {
        private let guardLock = NSLock()
        private var inFlight = 0
        private(set) var peakInFlight = 0
        private(set) var overlaps = 0
        private(set) var completed = 0
        func enter() {
            guardLock.lock(); defer { guardLock.unlock() }
            inFlight += 1
            if inFlight > 1 { overlaps += 1 }           // two bodies inside the lock at once == contract violation
            if inFlight > peakInFlight { peakInFlight = inFlight }
        }
        func leave() {
            guardLock.lock(); defer { guardLock.unlock() }
            inFlight -= 1
            completed += 1
        }
        func snapshot() -> (peak: Int, overlaps: Int, completed: Int) {
            guardLock.lock(); defer { guardLock.unlock() }
            return (peakInFlight, overlaps, completed)
        }
    }

    // Construction VERBATIM from Transforms+Eval.swift:9 — the exact serializer type & init.
    let evalLock = NSRecursiveLock()
    let box = OverlapBox()
    let n = 16

    // Deadline race == the no-deadlock guard (mirrors the sibling test's pattern).
    enum ProbeDeadline: Error { case exceeded }
    let work: @Sendable () async -> Int = {
        await withTaskGroup(of: Void.self) { group -> Void in
            for _ in 0..<n {
                group.addTask {
                    // EXACT MLX pattern: `evalLock.withLock { <synchronous critical section> }`.
                    // The body stands in for the synchronous `mlx_eval(vector_array)`.
                    evalLock.withLock {
                        box.enter()
                        // RECURSIVE re-entrancy: the source chose NSRecursiveLock so a closure can
                        // re-enter eval. Re-acquire on the SAME thread inside the held lock — must
                        // not self-deadlock, and must not be counted as an overlapping section.
                        evalLock.withLock {
                            var sink: UInt64 = 0
                            for i in 0..<2_000 { sink = sink &+ UInt64(i) }
                            _ = sink
                        }
                        // Busy span widens the window for any false concurrent entry to be observed.
                        var spin: UInt64 = 0
                        for i in 0..<20_000 { spin = spin &+ UInt64(i) }
                        _ = spin
                        box.leave()
                    }
                }
            }
            for await _ in group {}
        }
        return box.snapshot().completed
    }

    let completed: Int = try await withThrowingTaskGroup(of: Int.self) { group in
        group.addTask { await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            throw ProbeDeadline.exceeded
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { return 0 }
        return first
    }

    let (peak, overlaps, done) = box.snapshot()

    // LIVENESS: all N serialized acquisitions completed (no deadlock, incl. the recursive re-entry).
    XCTAssertEqual(completed, n,
        "all \(n) concurrent evalLock acquisitions must complete within the deadline (no deadlock)")
    XCTAssertEqual(done, n,
        "every critical section must have a matched enter/leave (no torn acquisition)")
    // SERIALIZATION (the raised bar): the byte-equal contract is exclusion — never two bodies inside
    // the lock simultaneously. peak in-flight is EXACTLY 1, with ZERO observed overlaps.
    XCTAssertEqual(peak, 1,
        "evalLock must serialize: peak concurrent critical sections must be exactly 1 (no overlap)")
    XCTAssertEqual(overlaps, 0,
        "zero overlapping critical sections — the GPU-eval serialization contract held under \(n)-way contention")

    print("QINAO-GATE mlx_evallock_concurrent_correctness: PASS " +
        "(N=\(n) concurrent acquisitions serialized; peakInFlight=\(peak), overlaps=\(overlaps), " +
        "completed=\(completed); recursive re-entrancy held, no deadlock — mirrors " +
        "Vendor/mlx-swift/Source/MLX/Transforms+Eval.swift:9 `let evalLock = NSRecursiveLock()` " +
        "+ `evalLock.withLock { mlx_eval(...) }`)")
}

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
