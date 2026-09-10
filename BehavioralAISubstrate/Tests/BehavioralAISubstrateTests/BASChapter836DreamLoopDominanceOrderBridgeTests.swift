// MARK: - BASChapter836DreamLoopDominanceOrderBridgeTests
// chapter 八百三十六 / M2831-M2835 — L9 dominance order Swift
// bridge over the Rust `bas_dream_loop_dominance_order` primitive
// scaffolded in chapter 八百三十五。
//
// Pins five invariants of the Swift bridge:
//
//   1. Descending sort by score (highest first)。
//   2. Stable on ties — equal scores preserve input order。
//   3. Empty input returns empty array (no FFI fault)。
//   4. Single-element input returns [0]。
//   5. NaN scores sort to the end (treated as -inf)。
//
// Bridge contract (chapter 八百三十五):
//
//   BASAutoRouteRanker.dreamLoopDominanceOrder(scores:) -> [Int32]?
//
// The Swift wrapper allocates its own output buffer of capacity
// `scores.count`, so the FFI cannot reject on insufficient capacity。
// `nil` is reserved for true FFI fault (currently unreachable
// from the wrapper since we own both the input slice and the
// output buffer)。
//
// Determinism boundary: the Rust kernel uses stable sort on
// (-score, index) so ties resolve by input order, matching Swift's
// `.sorted { ... }` behavior on equal-key pairs。

import XCTest
@testable import BASRuntimeCore

final class BASChapter836DreamLoopDominanceOrderBridgeTests: XCTestCase {

    // MARK: - Descending order

    func testDominanceOrderDescendingByScore() {
        let scores: [Float] = [0.1, 0.9, 0.3, 0.7, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertNotNil(result, "Bridge should not return nil on " +
            "well-formed input")
        // Highest score 0.9 (index 1), then 0.7 (3), 0.5 (4),
        // 0.3 (2), 0.1 (0)
        XCTAssertEqual(result, [1, 3, 4, 2, 0],
            "Expected indices sorted descending by score")
    }

    // MARK: - Stable on ties

    func testDominanceOrderStableOnTies() {
        // All three scores 0.5 — stable sort preserves input order
        let scores: [Float] = [0.5, 0.5, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertEqual(result, [0, 1, 2],
            "Ties resolve by input order (stable sort)")
    }

    func testDominanceOrderPartialTie() {
        // Mixed:two ties at 0.9,one at 0.5
        let scores: [Float] = [0.5, 0.9, 0.9, 0.5]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        // 0.9-tied first (indices 1 then 2), then 0.5-tied
        // (indices 0 then 3)
        XCTAssertEqual(result, [1, 2, 0, 3],
            "Mixed ties resolve by input order within each tie")
    }

    // MARK: - Empty / single element

    func testDominanceOrderEmptyReturnsEmpty() {
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: [])
        XCTAssertEqual(result, [],
            "Empty scores produces empty index list (no FFI fault)")
    }

    func testDominanceOrderSingleElementReturnsZero() {
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: [0.42])
        XCTAssertEqual(result, [0],
            "Single-element input returns [0]")
    }

    // MARK: - NaN handling

    func testDominanceOrderNaNSortsToEnd() {
        // NaN is treated as -inf:sorts to the end
        let scores: [Float] = [0.5, .nan, 0.9, 0.1]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertNotNil(result)
        // First three positions:0.9 (2), 0.5 (0), 0.1 (3)
        // Last position:NaN (1)
        XCTAssertEqual(result?.prefix(3).map { $0 } ?? [],
            [2, 0, 3], "Non-NaN scores sorted descending in prefix")
        XCTAssertEqual(result?.last, 1, "NaN sorts to the end")
    }

    // MARK: - Already-sorted input is identity

    func testDominanceOrderAlreadySortedDescendingStays() {
        let scores: [Float] = [0.9, 0.7, 0.5, 0.3, 0.1]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertEqual(result, [0, 1, 2, 3, 4],
            "Already-sorted descending stays in place")
    }

    // MARK: - Ascending input reverses

    func testDominanceOrderAscendingInputReverses() {
        let scores: [Float] = [0.1, 0.3, 0.5, 0.7, 0.9]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertEqual(result, [4, 3, 2, 1, 0],
            "Ascending input reverses to descending order")
    }

    // MARK: - 100-fixture byte-equality vs Swift reference

    func testDominanceOrderMatchesSwiftReferenceOver100Fixtures() {
        // Mirror of Swift `EBrainRuntimeCoordinator+Candidates.swift`
        // .sorted { lhs, rhs in scores[lhs] > scores[rhs] } pattern。
        // For each fixture,both the Rust bridge and a Swift
        // reference produce the same ordering。
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<100 {
            let n = 1 + (trial % 32)
            var scores: [Float] = []
            scores.reserveCapacity(n)
            for _ in 0..<n {
                let raw = Double(rng.next() % 1_000)
                    / 1_000.0
                scores.append(Float(raw))
            }
            // Rust bridge result
            let rustResult = BASAutoRouteRanker
                .dreamLoopDominanceOrder(scores: scores) ?? []
            // Swift reference (stable sort on (-score, index))
            let swiftResult: [Int32] =
                Array(0..<Int32(n)).sorted {
                    a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            XCTAssertEqual(rustResult, swiftResult,
                "Trial \(trial):Rust bridge ≡ Swift reference " +
                "for n=\(n)")
        }
    }
}
