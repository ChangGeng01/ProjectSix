import XCTest
@testable import BASHostKit

/// audit orchestration MED-2 — the Rust dominance-order FFI must fail SAFE.
///
/// The old code applied the Rust indices with an inline `precondition(i < count)`
/// that ABORTED the process on an out-of-bounds index (FFI drift / corruption)
/// and never checked duplicates. Now a corrupt/drifted result is rejected and
/// the caller falls back to the trusted Swift score-sort — no crash, no silent
/// duplicate/drop.
final class BASMLMemoryDominanceFallbackTests: XCTestCase {

    func testValidPermutationAccepted() {
        XCTAssertTrue(BASMLMemoryService.isValidDominancePermutation([2, 0, 1], count: 3))
        XCTAssertTrue(BASMLMemoryService.isValidDominancePermutation([], count: 0))
    }

    func testInvalidPermutationsRejected() {
        XCTAssertFalse(BASMLMemoryService.isValidDominancePermutation([0, 3, 1], count: 3), "out of bounds")
        XCTAssertFalse(BASMLMemoryService.isValidDominancePermutation([0, 0, 1], count: 3), "duplicate")
        XCTAssertFalse(BASMLMemoryService.isValidDominancePermutation([0, 1], count: 3), "wrong count")
        XCTAssertFalse(BASMLMemoryService.isValidDominancePermutation([-1, 0, 1], count: 3), "negative")
    }

    private let items: [(score: Double, stored: String)] =
        [(0.1, "a"), (0.9, "b"), (0.5, "c")]   // score-sort desc ⇒ b, c, a

    func testValidRustOrderAppliedVerbatim() {
        let out = BASMLMemoryService.orderedByDominance(items, rustIndices: [1, 2, 0])
        XCTAssertEqual(out.map { $0.stored }, ["b", "c", "a"], "a valid Rust order is applied as-is")
    }

    func testCorruptRustIndicesFallBackToSortNoCrash() {
        // out-of-bounds — must NOT crash; falls back to score-sort desc
        XCTAssertEqual(
            BASMLMemoryService.orderedByDominance(items, rustIndices: [0, 5, 1]).map { $0.stored },
            ["b", "c", "a"], "out-of-bounds index ⇒ Swift sort fallback (no process abort)")
        // duplicate — silent-drop hazard; falls back
        XCTAssertEqual(
            BASMLMemoryService.orderedByDominance(items, rustIndices: [0, 0, 1]).map { $0.stored },
            ["b", "c", "a"], "duplicate index ⇒ fallback")
        // Rust returned nil — falls back
        XCTAssertEqual(
            BASMLMemoryService.orderedByDominance(items, rustIndices: nil).map { $0.stored },
            ["b", "c", "a"], "nil ⇒ fallback")
    }
}
