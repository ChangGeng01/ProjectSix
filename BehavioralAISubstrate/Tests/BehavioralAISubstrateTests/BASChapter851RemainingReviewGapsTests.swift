// MARK: - BASChapter851RemainingReviewGapsTests
// chapter 八百五十一 / M2906-M2910 — Close remaining gaps from
// the chapter 八百四十五 parallel agent review
//
// Three gaps that were DOCUMENTED but not CLOSED in chapter
// 八百四十七 全面 修复 (the user there acknowledged "partial"
// closure for some review items)。 This chapter ships the
// actual fixes per 「尽力 开发」 directive。
//
//   1. CRITICAL-1 (Agent B):Fallback path untested on Apple
//      platforms。 The Swift fallback body runs only when the
//      FFI returns nil,which currently never happens under
//      production call-site invariants。 If a future FFI
//      regression breaks the Rust path,the Swift fallback
//      activates without any test coverage — silent
//      degradation。 Fixed via debug-only test seam
//      `_setForceFallbackForTesting`。
//
//   2. HIGH-3 (Agent B):No concurrent-call safety test。
//      The bridge has nonisolated(unsafe) counters and FFI
//      buffers;multiple turns dispatched concurrently must
//      not corrupt each other's results。 Fixed via 1000-call
//      DispatchQueue.concurrentPerform test。
//
//   3. MEDIUM-4 (Agent B):100K+ scale perf test。 The
//      chapter 八百三十七 perf grid topped at n=10K。 A 100K
//      test would catch any sub-quadratic regression in
//      either path。 Fixed via dedicated 100K test。

import XCTest
@testable import BASRuntimeCore
@_spi(BASTestSeam) import BASRuntimeCore

final class BASChapter851RemainingReviewGapsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BASAutoRouteRanker.resetDominanceOrderTelemetry()
    }

    override func tearDown() {
        // Ensure the forced-fallback flag is OFF after every test
        // so subsequent tests in other classes see the normal path。
        #if DEBUG
        BASAutoRouteRanker._setForceFallbackForTesting(false)
        BASAutoRouteRanker._setInjectRawIndicesForTesting(nil)
        #endif
        super.tearDown()
    }

    // MARK: - audit orchestration MED-2: corrupt FFI return fails SAFE, not process-abort

    /// The pure validator rejects every non-permutation. Reversal (drop any guard clause) reds.
    func testValidatedPermutationRejectsNonPermutations() {
        typealias R = BASAutoRouteRanker
        XCTAssertEqual(R.validatedPermutation([2, 0, 1], count: 3), [2, 0, 1],
            "a genuine permutation passes through unchanged")
        XCTAssertEqual(R.validatedPermutation([], count: 0), [], "empty is a valid 0-permutation")
        XCTAssertNil(R.validatedPermutation([0, 1], count: 3), "short return (length drift) rejected")
        XCTAssertNil(R.validatedPermutation([0, 1, 2, 3], count: 3), "over-long return rejected")
        XCTAssertNil(R.validatedPermutation([0, 3, 1], count: 3), "out-of-range index (3 >= 3) rejected")
        XCTAssertNil(R.validatedPermutation([-1, 0, 1], count: 3), "negative index rejected")
        XCTAssertNil(R.validatedPermutation([0, 0, 1], count: 3), "duplicate index rejected")
    }

    /// A corrupt kernel return (injected) makes the wrapper return nil → each call site's Swift
    /// `.sorted` fallback, NOT a process-aborting precondition. Reversal (wrapper returns the raw
    /// array without validatedPermutation) reds this: the bad array leaks out instead of nil.
    func testWrapperFallsBackSafelyOnCorruptKernelReturn() {
        #if DEBUG
        // n = 3, but the "kernel" returns an out-of-bounds index and a duplicate.
        BASAutoRouteRanker._setInjectRawIndicesForTesting([0, 5, 0])
        let result = BASAutoRouteRanker.dreamLoopDominanceOrderDouble(scores: [0.1, 0.9, 0.5])
        XCTAssertNil(result,
            "a corrupt kernel return must yield nil (→ Swift fallback), never an OOB index array "
            + "that a call-site precondition would abort the process on")
        let snap = BASAutoRouteRanker.dominanceOrderTelemetrySnapshot()
        XCTAssertEqual(snap.f64FallbackCount, 1, "the safe-fallback path increments the counter")

        // A VALID injected permutation still passes through (the validator is not over-eager).
        BASAutoRouteRanker.resetDominanceOrderTelemetry()
        BASAutoRouteRanker._setInjectRawIndicesForTesting([2, 0, 1])
        XCTAssertEqual(BASAutoRouteRanker.dreamLoopDominanceOrderDouble(scores: [0.1, 0.9, 0.5]),
            [2, 0, 1], "a valid injected permutation is returned unchanged")
        #endif
    }

    // MARK: - 1. CRITICAL-1: Fallback path coverage on Apple

    func testForcedFallbackReturnsNilAndIncrementsCounter() {
        #if DEBUG
        BASAutoRouteRanker._setForceFallbackForTesting(true)
        let scores: [Double] = [0.1, 0.9, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores)
        XCTAssertNil(result,
            "Forced fallback must return nil from the routed " +
            "path so callers route to their Swift fallback")
        let snap = BASAutoRouteRanker
            .dominanceOrderTelemetrySnapshot()
        XCTAssertEqual(snap.f64CallCount, 1)
        XCTAssertEqual(snap.f64FallbackCount, 1,
            "Fallback counter must increment on forced fallback")
        #endif
    }

    func testForcedFallbackAlsoCoversF32Path() {
        #if DEBUG
        BASAutoRouteRanker._setForceFallbackForTesting(true)
        let scores: [Float] = [0.1, 0.9, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertNil(result)
        let snap = BASAutoRouteRanker
            .dominanceOrderTelemetrySnapshot()
        XCTAssertEqual(snap.f32FallbackCount, 1)
        #endif
    }

    func testProductionCallSiteUsesSwiftFallbackWhenForced() {
        #if DEBUG
        // Simulate a call-site pattern (mirrors all 7 production
        // flip sites):attempt routed,fall through to Swift
        // .sorted。 Verify the Swift fallback produces the correct
        // result under forced fallback。
        BASAutoRouteRanker._setForceFallbackForTesting(true)
        let scores: [Double] = [0.3, 0.9, 0.1, 0.7]
        let result: [Int32]
        if let indices = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores) {
            // Should NOT take this branch under forced fallback
            XCTFail("Expected routed path to return nil")
            result = indices
        } else {
            // This is the production fallback shape — Swift
            // `.sorted` over the same scores
            result = Array(0..<Int32(scores.count))
                .sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
        }
        // Expected descending order by score:
        //   0.9 (idx 1), 0.7 (idx 3), 0.3 (idx 0), 0.1 (idx 2)
        XCTAssertEqual(result, [1, 3, 0, 2],
            "Swift fallback under forced-nil must produce the " +
            "same descending-by-score order as the routed path")
        #endif
    }

    // MARK: - 2. HIGH-3: Concurrent-call safety

    func testConcurrentDispatchProducesCorrectResults() {
        // Run 1000 dispatches in parallel,each with a distinct
        // input,verify each result matches its Swift reference。
        // Detects:shared buffer corruption,counter races
        // (latent until contention),unsafe global state。
        let n = 64
        let iterations = 1000

        let queue = DispatchQueue(
            label: "chapter-851-concurrent",
            attributes: .concurrent)
        let group = DispatchGroup()
        // Reference-typed, lock-guarded counter so the concurrent dispatch closures capture an immutable
        // `let` (Swift-6 Sendable-capture safe) rather than a mutable local var. Behavior is identical.
        final class FailureCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func increment() { lock.lock(); value += 1; lock.unlock() }
            var snapshot: Int { lock.lock(); defer { lock.unlock() }; return value }
        }
        let failed = FailureCounter()

        for trial in 0..<iterations {
            group.enter()
            queue.async {
                // Build a per-trial deterministic input so each
                // call has a unique expected answer (catches any
                // shared-buffer corruption that would mix results)
                var scores: [Double] = []
                scores.reserveCapacity(n)
                for i in 0..<n {
                    let raw = Double((trial * 7 + i * 13) % 1000)
                        / 1000.0
                    scores.append(raw)
                }
                let routed = BASAutoRouteRanker
                    .dreamLoopDominanceOrderDouble(scores: scores)
                    ?? []
                let reference: [Int32] = Array(0..<Int32(n))
                    .sorted { a, b in
                        let sa = scores[Int(a)]
                        let sb = scores[Int(b)]
                        if sa == sb { return a < b }
                        return sa > sb
                    }
                if routed != reference {
                    failed.increment()
                }
                group.leave()
            }
        }
        group.wait()

        XCTAssertEqual(failed.snapshot, 0,
            "All \(iterations) concurrent dispatches must " +
            "produce correct results。 Any failure indicates " +
            "shared state corruption or race condition in the " +
            "bridge or kernel。")

        // Verify counter reached expected count (atomic adds
        // under contention should NOT lose updates with the
        // wrapping increment pattern,but verify it anyway)
        let snap = BASAutoRouteRanker
            .dominanceOrderTelemetrySnapshot()
        XCTAssertEqual(snap.f64CallCount, iterations,
            "Counter must reach exactly \(iterations) under " +
            "concurrent dispatch — no atomic adds lost")
    }

    // MARK: - 3. MEDIUM-4: 100K+ scale perf

    func testDominanceOrderPerf100KCandidates() {
        // Chapter 八百三十七 topped at n=10K。 Extending to 100K
        // catches any sub-quadratic regression in either path
        // and validates the FFI overhead remains negligible
        // even at much larger N。
        let n = 100_000
        var rng = SystemRandomNumberGenerator()
        let scores: [Double] = (0..<n).map { _ in
            Double(rng.next() % 1_000_000) / 1_000_000.0
        }
        let iters = 5

        let routedNs = measureNanos {
            for _ in 0..<iters {
                _ = BASAutoRouteRanker
                    .dreamLoopDominanceOrderDouble(scores: scores)
            }
        }
        let swiftNs = measureNanos {
            for _ in 0..<iters {
                _ = Array(0..<Int32(n)).sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            }
        }
        let ratio = Double(routedNs) / Double(swiftNs)
        print(String(format:
            "== chapter 851 100K perf: " +
            "Swift %.3f ms,  Rust %.3f ms,  ratio %.3f×",
            Double(swiftNs) / 1_000_000.0,
            Double(routedNs) / 1_000_000.0,
            ratio))
        XCTAssertGreaterThan(swiftNs, 0)
        XCTAssertGreaterThan(routedNs, 0)
        // Sanity:Rust should remain faster at this scale
        // (chapter 八百三十七 showed 100× at 10K — at 100K we'd
        // expect a similar or better ratio since Swift closure
        // overhead grows with N)。 If ratio > 1.0,something
        // regressed。 Allow plenty of headroom (4×) since CI
        // hardware varies。
        XCTAssertLessThan(ratio, 4.0,
            "At n=100K,routed should still be faster than " +
            "Swift baseline (chapter 八百三十七 showed 100× at " +
            "10K)。 Ratio > 4× would indicate a regression。")
    }

    // MARK: - Helpers

    private func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }
}
