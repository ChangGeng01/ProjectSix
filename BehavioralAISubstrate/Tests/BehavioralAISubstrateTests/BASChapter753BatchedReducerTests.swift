// MARK: - BASChapter753BatchedReducerTests
// chapter 七百五十三 第二刀 / M2434
//
// MATURATION ARC L8 second hot path — batched admission-tiebreak
// reducer。 Per chapter 七百十八 batched-cosine pattern,a single
// FFI call processes N decisions to amortize FFI overhead。
// Designed to cross the 1.5× threshold that the chapter 七百五十一
// 第二刀 per-call port missed (1.08× marginal)。

import XCTest
@testable import BASRuntimeCore

final class BASChapter753BatchedReducerTests: XCTestCase {

    // MARK: - ABI version bumped to 2

    func testABIVersionIsTwo() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.atomReducerABIVersion(), 2,
            "chapter 七百五十三 第二刀 bumped ABI 1 → 2 for " +
            "the batched API")
        #endif
    }

    // MARK: - Byte-equality:batched ≡ per-call ≡ Swift reference

    private func swiftReference(
        existing: Double,
        new: Double,
        tiebreakKeepsExisting: Bool
    ) -> Bool {
        if existing > new { return false }
        if existing < new { return true }
        return !tiebreakKeepsExisting
    }

    /// 256-pair deterministic byte-equality test:batched output
    /// MUST equal per-call output for every pair。
    func testBatchedByteEqualsPerCallAcross256Pairs() {
        var state: UInt64 = 0xDEAD_BEEF_F00D_CAFE
        func nextDouble() -> Double {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z =  z ^ (z >> 31)
            return Double(z >> 11) / Double(UInt64(1) << 53)
        }

        let n = 256
        var existing = [Double](repeating: 0, count: n)
        var new = [Double](repeating: 0, count: n)
        for i in 0..<n {
            existing[i] = nextDouble()
            new[i] = nextDouble()
        }

        // Per-call (chapter 七百五十一 第二刀 path) — the
        // baseline expected behavior
        let perCall: [Bool] = (0..<n).map { i in
            BASAutoRouteRanker
                .atomReducerShouldReplaceAdmitted(
                    existingConfidence: existing[i],
                    newConfidence: new[i],
                    tiebreakKeepsExisting: true)
        }

        // Batched (chapter 七百五十三 第二刀 NEW path)
        guard let batched =
            BASAutoRouteRanker
                .atomReducerBatchedShouldReplaceAdmitted(
                    existing: existing,
                    new: new,
                    tiebreakKeepsExisting: true)
        else {
            XCTFail("batched returned nil")
            return
        }

        XCTAssertEqual(perCall.count, batched.count)
        for i in 0..<n {
            XCTAssertEqual(
                batched[i], perCall[i],
                "drift at i=\(i): existing=\(existing[i]) " +
                "new=\(new[i])")
        }

        // Also pin against pure-Swift reference
        for i in 0..<n {
            let expected = swiftReference(
                existing: existing[i],
                new: new[i],
                tiebreakKeepsExisting: true)
            XCTAssertEqual(batched[i], expected)
        }
    }

    // MARK: - Edge cases

    func testEmptyArraysReturnEmpty() {
        let result = BASAutoRouteRanker
            .atomReducerBatchedShouldReplaceAdmitted(
                existing: [],
                new: [],
                tiebreakKeepsExisting: true)
        XCTAssertEqual(result, [])
    }

    func testMismatchedLengthsReturnsNil() {
        let result = BASAutoRouteRanker
            .atomReducerBatchedShouldReplaceAdmitted(
                existing: [0.5, 0.6],
                new: [0.5],
                tiebreakKeepsExisting: true)
        XCTAssertNil(result)
    }

    func testTiebreakFlagPropagatesInBatch() {
        // All ties — flag controls every decision
        let existing = [0.5, 0.7, 0.9]
        let new      = [0.5, 0.7, 0.9]
        let keepExisting = BASAutoRouteRanker
            .atomReducerBatchedShouldReplaceAdmitted(
                existing: existing,
                new: new,
                tiebreakKeepsExisting: true)
        let replaceTie = BASAutoRouteRanker
            .atomReducerBatchedShouldReplaceAdmitted(
                existing: existing,
                new: new,
                tiebreakKeepsExisting: false)
        XCTAssertEqual(keepExisting, [false, false, false])
        XCTAssertEqual(replaceTie, [true, true, true])
    }

    // MARK: - 5-axis perf grid (4 cells: N=16/256/1024/4096)

    func testPerfGridAcross4Cells() {
        #if os(iOS) || os(macOS)
        let cells = [16, 256, 1024, 4096]
        let iterations = 1_000

        var state: UInt64 = 0xFADE_F00D_CAFE_BEEF
        func nextDouble() -> Double {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z =  z ^ (z >> 31)
            return Double(z >> 11) / Double(UInt64(1) << 53)
        }

        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百五十三 第二刀 — L8 BATCHED REDUCER 5-axis perf")
        print("=================================================================")
        print(
            "  Per-cell:\(iterations) iters batched vs per-call")
        print("")
        print(
            "  N    | Per-call (ms)| Batched (ms) | Speedup")
        print(
            "  -----|--------------|--------------|----------")

        for n in cells {
            var existing = [Double](repeating: 0, count: n)
            var new = [Double](repeating: 0, count: n)
            for i in 0..<n {
                existing[i] = nextDouble()
                new[i] = nextDouble()
            }

            // Warmup
            for _ in 0..<10 {
                for i in 0..<n {
                    _ = BASAutoRouteRanker
                        .atomReducerShouldReplaceAdmitted(
                            existingConfidence: existing[i],
                            newConfidence: new[i],
                            tiebreakKeepsExisting: true)
                }
                _ = BASAutoRouteRanker
                    .atomReducerBatchedShouldReplaceAdmitted(
                        existing: existing,
                        new: new,
                        tiebreakKeepsExisting: true)
            }

            // Per-call (chapter 七百五十一 第二刀 path)
            let perCallStart = Date()
            var perCallSink = 0
            for _ in 0..<iterations {
                for i in 0..<n {
                    if BASAutoRouteRanker
                        .atomReducerShouldReplaceAdmitted(
                            existingConfidence: existing[i],
                            newConfidence: new[i],
                            tiebreakKeepsExisting: true)
                    {
                        perCallSink &+= 1
                    }
                }
            }
            let perCallMs = Date()
                .timeIntervalSince(perCallStart) * 1000.0

            // Batched (chapter 七百五十三 第二刀 NEW)
            let batchedStart = Date()
            var batchedSink = 0
            for _ in 0..<iterations {
                if let out = BASAutoRouteRanker
                    .atomReducerBatchedShouldReplaceAdmitted(
                        existing: existing,
                        new: new,
                        tiebreakKeepsExisting: true)
                {
                    for v in out where v {
                        batchedSink &+= 1
                    }
                }
            }
            let batchedMs = Date()
                .timeIntervalSince(batchedStart) * 1000.0

            // Sanity:both paths agree on count
            XCTAssertEqual(perCallSink, batchedSink,
                "per-call and batched MUST agree on " +
                "replace-count at N=\(n)")

            let speedup = perCallMs / batchedMs
            print(String(
                format: "  %-4d | %12.3f | %12.3f | %.2fx",
                n, perCallMs, batchedMs, speedup))
        }
        print("")
        print(
            "  Decision rule:if batched ≥ 1.5× per-call at ≥1 cell,")
        print(
            "                 flip batched as default for that N。")
        print(
            "                 Else opt-in via BASAutoRouteRanker.")
        print("")
        #endif
    }
}
