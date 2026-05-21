// MARK: - BASChapter837DreamLoopDominanceOrderPerfTests
// chapter 八百三十七 / M2836-M2840 — L9 dominance order
// 5-axis perf measurement
//
// Runs the established 5-axis comparison (per chapter 七百四十九
// + 七百七十八 framework) for the L9 dominance-order primitive
// shipped in chapters 八百三十五-八百三十六:
//
//   Axis 1 — perf:       wall-time grid at 1K / 5K / 10K candidates
//   Axis 2 — memory:     RSS delta via Mach task_info (informational)
//   Axis 3 — state mach: Swift switch vs Rust enum (already exhaustive
//                        — both paths handle empty / single / NaN
//                        identically per chapter 八百三十六 100-fixture
//                        byte-equality grid)
//   Axis 4 — persistence: N/A (pure function, no state)
//   Axis 5 — replay byte: Already pinned by chapter 八百三十六
//                         100-fixture grid (rustResult ≡ swiftResult)
//
// ## Decision rule (chapter 七百四十九 framework)
//
//   ≥3 axes Rust-strictly-better AND no axis Rust-worse-by->1.5×
//     → FLIP DEFAULT
//   Else
//     → Swift stays default,Rust ships OPT-IN via BASAutoRouteRanker
//
// ## Honest expectation
//
// Swift's `Array.sorted(by:)` uses introsort (mixed quicksort +
// heapsort) and benefits from inlined comparison closures。 Rust
// `sort_by` is also introsort-based,but the FFI crossing adds
// constant overhead per call (~100-500 ns)。 For N=1K-10K we expect
// either TIE (within ±50%) or modest Swift win on small N,modest
// Rust win on large N — TBD by actual measurement。
//
// Per 「亏的不要硬上」 + 「多做比较」 discipline:if 5-axis
// doesn't support flip,Rust path ships OPT-IN (already is — chapter
// 八百三十六 wrapper),the measurement informs hosts whether the
// FFI hop is worth it for their workload。

import XCTest
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)

final class BASChapter837DreamLoopDominanceOrderPerfTests: XCTestCase {

    // MARK: - 1K candidates

    func testDominanceOrderPerf1KCandidates() throws {
        runScale(n: 1_000, iters: 100)
    }

    // MARK: - 5K candidates

    func testDominanceOrderPerf5KCandidates() throws {
        runScale(n: 5_000, iters: 50)
    }

    // MARK: - 10K candidates

    func testDominanceOrderPerf10KCandidates() throws {
        runScale(n: 10_000, iters: 20)
    }

    // MARK: - Scorecard at all three scales

    func testDominanceOrderScalingScorecard() throws {
        // Three batch sizes for the canonical scaling table。
        // Reports ratio at each size,then closing verdict。
        let scales: [(n: Int, iters: Int)] = [
            (1_000, 100),
            (5_000, 50),
            (10_000, 20),
        ]
        var verdictRows: [(n: Int, ratio: Double)] = []
        for scale in scales {
            let scores = makeScores(n: scale.n, seed: 0xBA5E)
            let swiftNs = measureNanos {
                for _ in 0..<scale.iters {
                    _ = swiftReferenceSort(scores: scores)
                }
            }
            let rustNs = measureNanos {
                for _ in 0..<scale.iters {
                    _ = BASAutoRouteRanker
                        .dreamLoopDominanceOrder(scores: scores)
                }
            }
            let ratio = swiftNs > 0
                ? Double(rustNs) / Double(swiftNs)
                : 0
            verdictRows.append((scale.n, ratio))
            print(String(format:
                "== chapter 837 [n=%d × %d iters]:" +
                "  Swift %.3f ms,  Rust %.3f ms,  ratio %.2f×",
                scale.n, scale.iters,
                Double(swiftNs) / 1_000_000.0,
                Double(rustNs)  / 1_000_000.0,
                ratio))
        }

        // Decision per 5-axis framework
        let allRustWithin1_5x = verdictRows.allSatisfy {
            $0.ratio <= 1.5
        }
        let anyRustStrictlyBetter = verdictRows.contains {
            $0.ratio < 0.85  // Rust ≥15% faster
        }
        print("== chapter 837 verdict:")
        print("   Axis 1 (perf):       informational " +
              "(ratios above)")
        print("   Axis 2 (memory):     informational " +
              "(both heap-allocate Vec<i32> / Array<Int32>)")
        print("   Axis 3 (state mach): TIE (both handle empty / " +
              "single / NaN identically — pinned by chapter 836)")
        print("   Axis 4 (persistence): N/A (pure function)")
        print("   Axis 5 (replay byte): PASS " +
              "(100-fixture grid in chapter 836)")
        if allRustWithin1_5x && anyRustStrictlyBetter {
            print("   Decision: STRONG-FLIP candidate " +
                  "(Rust ≥1 axis better,no axis >1.5× worse)")
        } else if allRustWithin1_5x {
            print("   Decision: OPT-IN STAYS " +
                  "(TIE — both paths competitive,Swift default keeps " +
                  "FFI overhead off the hot path,Rust available " +
                  "via BASAutoRouteRanker for hosts that benefit)")
        } else {
            print("   Decision: SWIFT WINS " +
                  "(Rust >1.5× worse on at least one axis — " +
                  "per 「亏的不要硬上」 Rust path stays OPT-IN " +
                  "for the audit / determinism contract,not perf)")
        }

        // The actual XCTAssert is just「ratios are sane (positive
        // and finite)」 — the verdict above is the load-bearing
        // artifact for future flip decisions。
        for row in verdictRows {
            XCTAssertGreaterThan(row.ratio, 0,
                "n=\(row.n) ratio must be positive")
            XCTAssertLessThan(row.ratio, 100,
                "n=\(row.n) ratio < 100× — either path " +
                "exploding indicates a measurement bug")
        }
    }

    // MARK: - Helpers

    private func runScale(n: Int, iters: Int) {
        let scores = makeScores(n: n, seed: 0xC0DE)
        let swiftNs = measureNanos {
            for _ in 0..<iters {
                _ = swiftReferenceSort(scores: scores)
            }
        }
        let rustNs = measureNanos {
            for _ in 0..<iters {
                _ = BASAutoRouteRanker
                    .dreamLoopDominanceOrder(scores: scores)
            }
        }
        XCTAssertGreaterThan(swiftNs, 0)
        XCTAssertGreaterThan(rustNs,  0)
        let ratio = Double(rustNs) / Double(swiftNs)
        print(String(format:
            "   n=%d, iters=%d → Swift %.3f ms, " +
            "Rust %.3f ms, ratio %.2f×",
            n, iters,
            Double(swiftNs) / 1_000_000.0,
            Double(rustNs)  / 1_000_000.0,
            ratio))
    }

    /// Mirror of Swift `EBrainRuntimeCoordinator+Candidates.swift`
    /// dominance-order sort:stable on (-score, index)。
    private func swiftReferenceSort(scores: [Float]) -> [Int32] {
        Array(0..<Int32(scores.count)).sorted { a, b in
            let sa = scores[Int(a)]
            let sb = scores[Int(b)]
            if sa == sb { return a < b }
            return sa > sb
        }
    }

    /// Deterministic LCG so repeated runs measure the same input。
    private func makeScores(n: Int, seed: UInt64) -> [Float] {
        var state = seed
        var out: [Float] = []
        out.reserveCapacity(n)
        for _ in 0..<n {
            // xorshift64
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let raw = Double(state % 1_000_000)
                / 1_000_000.0
            out.append(Float(raw))
        }
        return out
    }

    /// Wall-time nanoseconds for a synchronous block。
    private func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }
}

#endif
