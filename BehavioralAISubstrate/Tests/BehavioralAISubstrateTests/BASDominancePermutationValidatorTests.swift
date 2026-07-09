import XCTest
@testable import BASOrchestration

/// audit orchestration MED-2 — the neural materialization core's dominance-order mapping used a
/// `precondition` that ABORTED the whole process on an out-of-bounds Rust index (a caller could
/// feed a crash), and it never checked for DUPLICATE indices (a repeated index silently
/// dropped/duplicated a candidateID). It now validates the full permutation and fail-safes to the
/// Swift sort. This pins the validator (the prior "close" 13a7e5b66 fixed only a sibling call site).
final class BASDominancePermutationValidatorTests: XCTestCase {

    private func valid(_ idx: [Int32], _ n: Int) -> Bool {
        BASNeuralMaterializationCompiler.isValidDominancePermutation(idx, count: n)
    }

    func testAcceptsAValidPermutation() {
        XCTAssertTrue(valid([2, 0, 1], 3))
        XCTAssertTrue(valid([0], 1))
        XCTAssertTrue(valid([], 0))
    }

    func testRejectsOutOfBoundsIndex() {
        XCTAssertFalse(valid([3, 0, 1], 3), "index 3 is out of bounds for n=3 (would crash the subscript)")
        XCTAssertFalse(valid([-1, 0, 1], 3), "a negative index is invalid")
    }

    func testRejectsDuplicateIndex() {
        XCTAssertFalse(valid([0, 0, 1], 3), "a repeated index drops/duplicates a candidate")
        XCTAssertFalse(valid([1, 1, 1], 3))
    }

    func testRejectsWrongLength() {
        XCTAssertFalse(valid([0, 1], 3), "too few indices is not a complete permutation")
        XCTAssertFalse(valid([0, 1, 2, 0], 3), "too many indices")
    }
}
