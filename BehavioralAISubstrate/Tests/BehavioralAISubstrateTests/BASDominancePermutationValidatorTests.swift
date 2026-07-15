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

    // MARK: - audit orchestration LOW-4: the fallback sort breaks score ties deterministically

    private func candidate(_ id: String) -> BASCandidatePath {
        // Identical benefit/cost/reversibility/confidence ⇒ identical dominance score.
        BASCandidatePath(
            candidateID: id, title: "t", actionSummary: "a",
            expectedBenefit: 0.5, expectedCost: 0.1, reversibility: 0.5, confidence: 0.5)
    }

    func testEqualScoreCandidatesSortDeterministicallyByID() {
        // Two equal-score candidates presented in DESCENDING id order.
        let order = BASNeuralMaterializationCompiler.dominanceFallbackOrder(
            [candidate("z-cand"), candidate("a-cand")])
        XCTAssertEqual(order, ["a-cand", "z-cand"],
            "equal dominance scores must tiebreak on candidateID ASC — a bare `>` left input order")
        // Symmetry: the reverse input yields the SAME deterministic order.
        let order2 = BASNeuralMaterializationCompiler.dominanceFallbackOrder(
            [candidate("a-cand"), candidate("z-cand")])
        XCTAssertEqual(order, order2, "the fallback order is input-order-independent for equal scores")
    }
}
