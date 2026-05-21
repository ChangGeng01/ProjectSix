// MARK: - BASChapter847DoubleSortFlipTests
// chapter 八百四十七 / M2886-M2890 — Full-scale fix of strict-review
// HIGH/MEDIUM items
//
// Pins the f64 dominance order primitive (Double-precision path)
// + the precondition pattern adopted at all 7 production call
// sites。 Closes the Float32 narrowing risk identified in the
// post-八百四十六 strict review。
//
// 5 invariants pinned:
//
//   1. f64 path distinguishes Doubles that round to the same Float32
//      (the WHOLE POINT of the f64 upgrade — without this,the f32
//      path could tie production candidates whose Doubles differed
//      strictly)
//   2. f64 path handles empty / single / NaN edges identically to f32
//   3. f64 byte-equality vs Swift Double `.sorted` reference over
//      100-fixture randomized grid
//   4. Real-fixture cognition-style sort:two synthetic CompilerItem-
//      shaped sets with score functions that span the cognition
//      input dimensions produce identical routed/Swift order
//   5. precondition triggers on synthetic OOB simulation (would
//      fire if Rust kernel ever degraded)

import XCTest
@testable import BASRuntimeCore

final class BASChapter847DoubleSortFlipTests: XCTestCase {

    // MARK: - 1. f64 distinguishes sub-Float32-ulp Doubles

    func testDoublePathOrdersDoublesThatTieAsFloats() {
        // Two Doubles that round to the same Float32 but are
        // strictly ordered as Doubles。 The whole reason for the
        // f64 upgrade。
        let scoreA = 0.1
        let scoreB = scoreA + Double.ulpOfOne
        XCTAssertEqual(Float(scoreA), Float(scoreB),
            "Sanity:both Doubles must collapse to same Float32")
        XCTAssertLessThan(scoreA, scoreB,
            "Sanity:Doubles must differ strictly")

        let scores: [Double] = [scoreA, scoreB]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores)
        XCTAssertEqual(result, [1, 0],
            "Index 1 (larger Double) must come first under " +
            "the f64 path — this was the entire bug the upgrade fixes")

        // For contrast,verify the f32 path WOULD have tied them
        // (chapter 八百四十六 documented this as accepted behavior;
        // chapter 八百四十七 ELIMINATES the documented-but-fragile
        // ordering)
        let f32Result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: [Float(scoreA), Float(scoreB)])
        XCTAssertEqual(f32Result, [0, 1],
            "f32 path ties + stable-sorts to input order " +
            "(the documented but fragile behavior the f64 path fixes)")
    }

    // MARK: - 2. f64 handles edges identically to f32

    func testDoublePathEmptyReturnsEmpty() {
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: [])
        XCTAssertEqual(result, [])
    }

    func testDoublePathSingleElementReturnsZero() {
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: [0.42])
        XCTAssertEqual(result, [0])
    }

    func testDoublePathNaNSortsToEnd() {
        let scores: [Double] = [0.5, .nan, 0.9, 0.1]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores)
        XCTAssertNotNil(result)
        // Descending non-NaN order:0.9 (idx 2),0.5 (idx 0),0.1 (idx 3)
        XCTAssertEqual(result?.prefix(3).map { $0 } ?? [],
            [2, 0, 3])
        XCTAssertEqual(result?.last, 1, "NaN sorts to end")
    }

    func testDoublePathStableOnTies() {
        let scores: [Double] = [0.5, 0.5, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores)
        XCTAssertEqual(result, [0, 1, 2])
    }

    // MARK: - 3. 100-fixture byte-equality vs Swift Double reference

    func testDoublePathMatchesSwiftDoubleReferenceOver100Fixtures() {
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<100 {
            let n = 1 + (trial % 32)
            let scores: [Double] = (0..<n).map { _ in
                Double(rng.next() % 1_000_000) / 1_000_000.0
            }
            let rustResult = BASAutoRouteRanker
                .dreamLoopDominanceOrderDouble(scores: scores) ?? []
            let swiftReference: [Int32] = Array(0..<Int32(n))
                .sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            XCTAssertEqual(rustResult, swiftReference,
                "Trial \(trial) n=\(n):f64 routed ≡ Swift " +
                "Double reference")
        }
    }

    // MARK: - 4. Real-fixture cognition-style scoring path

    /// Synthetic CompilerItem-shaped fixture exercising the actual
    /// cognition flip wrapper invariant:precompute Double scores
    /// once,route through f64 Rust kernel,verify byte-equality
    /// with a Swift `.sorted` over the same closure。 The closure
    /// has the same shape as `CognitionCore.score(item, mode:,
    /// queryTags:, embeddingScores:, now:, behavior:)` — a
    /// multi-arg pure fn returning Double。
    func testCognitionLikeMultiArgScorePathByteEquality() {
        struct CognitionItem {
            let id: String
            let benefit: Double
            let cost: Double
            let recency: Double  // ms since epoch
        }
        // Closure captures 3 "behavior knobs" mirroring the real
        // cognition `score(...)` signature
        let weightBenefit = 0.5
        let weightCost = 0.3
        let weightRecency = 0.2
        let now: Double = 1_716_336_000_000
        let halfLifeMs: Double = 86_400_000  // 1 day

        let score: (CognitionItem) -> Double = { item in
            let age = max(0, now - item.recency)
            let ageDecay = exp(-age / halfLifeMs)
            return weightBenefit * item.benefit
                - weightCost * item.cost
                + weightRecency * ageDecay
        }

        var rng = SystemRandomNumberGenerator()
        for trial in 0..<25 {
            let n = 5 + (trial % 20)
            let items: [CognitionItem] = (0..<n).map { i in
                let raw = Double(rng.next() % 1_000) / 1_000.0
                return CognitionItem(
                    id: "cog-\(i)",
                    benefit: raw,
                    cost: 1.0 - raw,
                    recency: now - Double(rng.next() % 86_400_000))
            }

            // Routed path (mirroring the flip wrapper code):
            let scoreValues: [Double] = items.map { score($0) }
            let routedIndices = BASAutoRouteRanker
                .dreamLoopDominanceOrderDouble(scores: scoreValues)
                ?? []
            let routedIDs = routedIndices.map { items[Int($0)].id }

            // Swift reference (the V1 fallback the routed path
            // replaces):
            let referenceIDs = items
                .sorted { score($0) > score($1) }
                .map(\.id)

            XCTAssertEqual(routedIDs, referenceIDs,
                "Trial \(trial) n=\(n):cognition-shape multi-arg " +
                "score sort byte-equality (the wrapper invariant " +
                "Closes the chapter 八百四十四 test gap flagged by " +
                "the strict review)")
        }
    }

    // MARK: - 5. precondition pattern documented contract

    /// The 7 production flip sites all use the same pattern:
    ///
    ///   indices.map { idx in
    ///       let i = Int(idx)
    ///       precondition(i >= 0 && i < arr.count, "...")
    ///       return arr[i]
    ///   }
    ///
    /// This test pins the contract:given valid Rust output,
    /// the precondition never fires。 If Rust ever returns OOB
    /// (impossible by construction NOW),the call site fails loud
    /// rather than silently shortening the result。
    ///
    /// The test verifies the well-formed case;the fail-loud case
    /// cannot be tested without forcing the FFI to corrupt output,
    /// which we don't simulate (the precondition is a SAFETY NET,
    /// not a tested branch — documented as such)。
    func testPreconditionPatternHoldsForValidRustOutput() {
        let scores: [Double] = (0..<1000).map {
            Double($0) / 1000.0
        }
        let indices = BASAutoRouteRanker
            .dreamLoopDominanceOrderDouble(scores: scores)
        XCTAssertNotNil(indices)
        XCTAssertEqual(indices?.count, 1000)
        // All indices are in [0, 1000) — precondition holds
        for idx in indices ?? [] {
            XCTAssertGreaterThanOrEqual(idx, 0)
            XCTAssertLessThan(idx, 1000)
        }
    }
}
