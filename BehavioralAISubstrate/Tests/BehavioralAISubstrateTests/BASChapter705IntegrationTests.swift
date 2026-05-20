// MARK: - BASChapter705IntegrationTests
// chapter 七百五 第五刀 / M2200
//
// End-to-end integration tests + performance benchmarks for the
// chapter 七百五 native code knives:
//
//   - Metal FlashAttention (knife 1) — Swift dispatcher
//   - Rust SIMD math (knife 2) — Swift wrappers + perf compare
//   - C++ LSH index (knife 3) — Swift bridge actor
//   - C SPSC ring (knife 4) — Swift wrapper exercise

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

import BASCSystemBridge

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
import BASMPSGraphExecutableCacheCxx
#endif

final class BASChapter705IntegrationTests: XCTestCase {

    // MARK: - C SPSC ring smoke tests

    func testSPSCRingPushPopRoundTrip() throws {
        let ring = try BASSPSCRing<Int64>(capacityHint: 4)
        XCTAssertTrue(ring.push(42))
        XCTAssertTrue(ring.push(43))
        XCTAssertTrue(ring.push(44))
        XCTAssertEqual(ring.pop(), 42)
        XCTAssertEqual(ring.pop(), 43)
        XCTAssertEqual(ring.pop(), 44)
        XCTAssertNil(ring.pop())
    }

    func testSPSCRingFullThenDrain() throws {
        let ring = try BASSPSCRing<Int32>(capacityHint: 4)
        var pushed = 0
        for i in 0..<10 {
            if ring.push(Int32(i)) { pushed += 1 }
            else { break }
        }
        XCTAssertGreaterThanOrEqual(pushed, 1)
        XCTAssertLessThanOrEqual(pushed, 3)
        var drained: [Int32] = []
        while let v = ring.pop() { drained.append(v) }
        XCTAssertEqual(drained.count, pushed)
    }

    func testSPSCRingCapacityIsPowerOfTwo() throws {
        let ring = try BASSPSCRing<Int64>(capacityHint: 100)
        XCTAssertEqual(ring.capacity, 128)
    }

    // MARK: - Rust SIMD vs scalar perf

    func testRustSIMDvsScalarPerf() throws {
        #if os(iOS) || os(macOS)
        let dim = 256
        let a: [Float] = (0..<dim).map {
            Float($0) * 0.01 }
        let b: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        let iters = 50_000

        var sink: Float = 0
        for _ in 0..<10 {
            var s: Float = 0
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    bas_ranker_cosine_similarity(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count, &s)
                }
            }
            sink += s
        }

        let scalarStart =
            DispatchTime.now().uptimeNanoseconds
        var scalarScore: Float = 0
        for _ in 0..<iters {
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    bas_ranker_cosine_similarity(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count,
                        &scalarScore)
                }
            }
        }
        let scalarEnd =
            DispatchTime.now().uptimeNanoseconds
        let scalarMs =
            Double(scalarEnd - scalarStart) / 1_000_000

        let simdStart =
            DispatchTime.now().uptimeNanoseconds
        var simdScore: Float = 0
        for _ in 0..<iters {
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    bas_ranker_cosine_similarity_simd(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count,
                        &simdScore)
                }
            }
        }
        let simdEnd =
            DispatchTime.now().uptimeNanoseconds
        let simdMs =
            Double(simdEnd - simdStart) / 1_000_000

        print(
            "BENCH cosine(dim=\(dim)) \(iters)x — " +
            "Rust scalar=" +
            "\(String(format: "%.2f", scalarMs))ms, " +
            "Rust SIMD=" +
            "\(String(format: "%.2f", simdMs))ms, " +
            "ratio=" +
            "\(String(format: "%.2fx", scalarMs / simdMs))")
        XCTAssertEqual(
            scalarScore, simdScore, accuracy: 1e-4)
        _ = sink
        #endif
    }

    // MARK: - C++ LSH

    func testCxxLSHCreateAndSearch() throws {
        #if os(iOS) || os(macOS)
        let dim: UInt32 = 8
        let handle = bas_lsh_create(dim, 8, 4, 0xCAFE_BABE)
        XCTAssertNotNil(handle)
        defer { bas_lsh_destroy(handle) }

        let vectors: [[Float]] = [
            [1, 0, 0, 0, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0, 0, 0],
            [0.7, 0.7, 0, 0, 0, 0, 0, 0],
            [0.5, 0.5, 0.5, 0.5, 0, 0, 0, 0],
        ]
        for (i, v) in vectors.enumerated() {
            let id = "id-\(i)"
            let rc = id.withCString { idp in
                v.withUnsafeBufferPointer { vp in
                    bas_lsh_add(handle, idp,
                        vp.baseAddress, dim)
                }
            }
            XCTAssertEqual(rc, 0)
        }
        XCTAssertEqual(bas_lsh_count(handle), 5)

        let query: [Float] = [1, 0, 0, 0, 0, 0, 0, 0]
        let outIds = UnsafeMutablePointer<
            UnsafePointer<CChar>?>.allocate(capacity: 3)
        let outScores = UnsafeMutablePointer<Float>
            .allocate(capacity: 3)
        defer {
            outIds.deallocate()
            outScores.deallocate()
        }
        let hits = query.withUnsafeBufferPointer { qp in
            bas_lsh_search(
                handle, qp.baseAddress, dim, 3,
                outIds, outScores)
        }
        XCTAssertGreaterThan(hits, 0)
        XCTAssertEqual(
            String(cString: outIds[0]!), "id-0")
        XCTAssertEqual(outScores[0], 1.0, accuracy: 1e-5)
        #endif
    }

    // MARK: - ABI bundle sanity
    //
    // chapter 七百五十七 第三刀 / M2440 — converted from hardcoded
    // `== 7` to growth-tolerant `>= 9` (current count after BPE +
    // tribunal-court crate additions)。 ABI total bumps when any
    // sibling crate bumps (e.g. atom-store v1 → v2 at chapter
    // 七百五十三 第二刀)。 Forward-compatible floor assertions。

    func testChapter705AbiBundleVersionsMatch() {
        #if os(iOS) || os(macOS)
        let count = bas_substrate_bundle_crate_count()
        let total = bas_substrate_bundle_abi_total()
        XCTAssertGreaterThanOrEqual(count, 9,
            "Bundled crate count must be ≥ 9 (host + 6 七百三 siblings " +
            "+ tokenizer + tribunal-court)")
        XCTAssertGreaterThanOrEqual(total, count,
            "Sum of per-crate ABI versions must be ≥ crate count " +
            "(each crate's ABI starts at 1)")
        XCTAssertEqual(bas_lsh_abi_version(), 1)
        XCTAssertEqual(bas_spsc_ring_abi_version(), 1)
        #endif
    }
}
