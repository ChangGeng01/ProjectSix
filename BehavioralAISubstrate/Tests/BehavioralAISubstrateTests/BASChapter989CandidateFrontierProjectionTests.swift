// MARK: - BASChapter989CandidateFrontierProjectionTests
// chapter 九百八十九 / M3650 — Cross-Module Integration Arc ch7
//
// Closes ch 982.5 META-REVIEW cross-module Gap 5:
// fabric `.candidateFrontier` deltas (per-candidate) disjoint
// from host's aggregate `BASCandidateFrontier` summary。 Now
// the projection adapter makes them consumable side-by-side。
//
// Tests pin:
//   1. candidateIDs in input order (preserves enumeration)
//   2. dominanceOrder confidence-descending with lex tie-break
//   3. reversiblePaths >= 0.7 band classification
//   4. guardPaths high-reversibility (safe-retreat) band classification
//   5. frontierWidth = candidate count
//   6. diversityScore [0,1] bounded
//   7. Empty + single-candidate edge cases
//   8. Determinism across input order permutations

import XCTest
@testable import BASOrchestration
@testable import BASMemory

final class BASChapter989CandidateFrontierProjectionTests:
    XCTestCase
{

    // MARK: - candidateIDs ordering

    func testCandidateIDs_PreservesInputOrder() {
        let candidates = [
            makeCand(id: "alpha", confidence: 0.5),
            makeCand(id: "beta", confidence: 0.9),
            makeCand(id: "gamma", confidence: 0.3),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.candidateIDs,
            ["alpha", "beta", "gamma"],
            "ch 989 Gap 5: candidateIDs MUST preserve input order " +
            "(host's original enumeration)")
    }

    // MARK: - dominanceOrder

    func testDominanceOrder_ConfidenceDescending() {
        let candidates = [
            makeCand(id: "low", confidence: 0.2),
            makeCand(id: "high", confidence: 0.9),
            makeCand(id: "mid", confidence: 0.5),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.dominanceOrder,
            ["high", "mid", "low"],
            "ch 989 Gap 5: dominanceOrder MUST be confidence-" +
            "descending")
    }

    func testDominanceOrder_TieBrokenByLexCandidateID() {
        let candidates = [
            makeCand(id: "zebra", confidence: 0.5),
            makeCand(id: "alpha", confidence: 0.5),
            makeCand(id: "mango", confidence: 0.5),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.dominanceOrder,
            ["alpha", "mango", "zebra"],
            "ch 989 Gap 5: ties broken by candidateID lex " +
            "ascending — Root Law 7 可回放 determinism")
    }

    // MARK: - Reversibility band classification

    func testReversiblePaths_HighReversibilityBand() {
        let candidates = [
            makeCand(id: "high", reversibility: 0.9),
            makeCand(id: "mid", reversibility: 0.5),
            makeCand(id: "low", reversibility: 0.1),
            makeCand(id: "boundary", reversibility: 0.7),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(Set(frontier.reversiblePaths),
            Set(["high", "boundary"]),
            "ch 989 Gap 5: reversibility >= 0.7 → reversiblePaths")
    }

    func testGuardPaths_AreHighReversibilitySafeRetreat() {
        // audit orchestration HIGH-1: guardPaths are PROTECTIVE SAFE-RETREAT fallbacks (HIGH
        // reversibility), per BASGuardBranch ("a minimal REVERSIBLE guard branch") — NOT the danger
        // band. This test previously pinned the INVERTED semantic (reversibility < 0.3), the exact
        // opposite of the neural producer, feeding L9 planning the wrong guard set.
        let candidates = [
            makeCand(id: "safe", reversibility: 0.9),
            makeCand(id: "midhigh", reversibility: 0.4),
            makeCand(id: "danger", reversibility: 0.1),
            makeCand(id: "boundary", reversibility: 0.7),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(Set(frontier.guardPaths),
            Set(["safe", "boundary"]),
            "reversibility >= 0.7 (safe-retreat band) → guardPaths")
        XCTAssertFalse(frontier.guardPaths.contains("danger"),
            "a low-reversibility (danger) candidate is NEVER a guard path — that was the inversion")
    }

    func testGuardBandsAreSharedSingleSourceOfTruth() {
        // The canonical band both producers now use.
        XCTAssertTrue(BASReversibilityBands.isGuardPath(reversibility: 0.7))
        XCTAssertTrue(BASReversibilityBands.isGuardPath(reversibility: 0.9))
        XCTAssertFalse(BASReversibilityBands.isGuardPath(reversibility: 0.69))
        XCTAssertFalse(BASReversibilityBands.isGuardPath(reversibility: 0.1),
            "the danger band is NOT a guard path")
    }

    // MARK: - frontierWidth

    func testFrontierWidth_EqualsCount() {
        let candidates = [
            makeCand(id: "a"),
            makeCand(id: "b"),
            makeCand(id: "c"),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.frontierWidth, 3)
    }

    // MARK: - Diversity score

    func testDiversity_AllSameConfidence_HighDiversity() {
        // All identical → variance 0 → diversity 1.0
        let candidates = [
            makeCand(id: "a", confidence: 0.5),
            makeCand(id: "b", confidence: 0.5),
            makeCand(id: "c", confidence: 0.5),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.diversityScore, 1.0,
            accuracy: 0.001,
            "ch 989 Gap 5: zero variance → diversity = 1.0")
    }

    func testDiversity_BoundedToZeroOne() {
        // Maximum spread → low diversity
        let candidates = [
            makeCand(id: "a", confidence: 0.0),
            makeCand(id: "b", confidence: 1.0),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertGreaterThanOrEqual(frontier.diversityScore, 0.0)
        XCTAssertLessThanOrEqual(frontier.diversityScore, 1.0)
    }

    // MARK: - Edge cases

    func testEmpty_ProducesEmptyFrontier() {
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: [])
        XCTAssertTrue(frontier.candidateIDs.isEmpty)
        XCTAssertEqual(frontier.frontierWidth, 0)
        XCTAssertEqual(frontier.diversityScore, 1.0,
            "ch 989 Gap 5: empty frontier convention: " +
            "diversity = 1.0 (no variance possible)")
    }

    func testSingleCandidate_DiversityIsOne() {
        let candidates = [makeCand(id: "only", confidence: 0.7)]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertEqual(frontier.candidateIDs, ["only"])
        XCTAssertEqual(frontier.dominanceOrder, ["only"])
        XCTAssertEqual(frontier.diversityScore, 1.0,
            accuracy: 0.001,
            "ch 989 Gap 5: single-candidate diversity is 1.0 " +
            "by convention (no spread to measure)")
    }

    // MARK: - Determinism

    func testDeterminism_AcrossInputOrderPermutations() {
        let c1 = [
            makeCand(id: "a", confidence: 0.5),
            makeCand(id: "b", confidence: 0.7),
            makeCand(id: "c", confidence: 0.3),
        ]
        let c2 = [
            makeCand(id: "c", confidence: 0.3),
            makeCand(id: "a", confidence: 0.5),
            makeCand(id: "b", confidence: 0.7),
        ]
        let f1 = BASAgentFabricAdapters
            .candidateFrontierProjection(from: c1)
        let f2 = BASAgentFabricAdapters
            .candidateFrontierProjection(from: c2)
        // candidateIDs differ (input order), but dominanceOrder
        // does not
        XCTAssertEqual(f1.dominanceOrder, f2.dominanceOrder,
            "ch 989 Gap 5: dominanceOrder MUST be order-invariant " +
            "across input permutations (deterministic)")
        XCTAssertEqual(f1.diversityScore, f2.diversityScore,
            accuracy: 0.001,
            "ch 989 Gap 5: diversityScore MUST be order-invariant")
    }

    // MARK: - Helpers

    private func makeCand(
        id: String,
        confidence: Double = 0.5,
        reversibility: Double = 0.5
    ) -> BASPlannerCandidate {
        BASPlannerCandidate(
            candidateID: id,
            title: "test",
            actionSummary: "a",
            confidence: confidence,
            reversibility: reversibility)
    }
}
