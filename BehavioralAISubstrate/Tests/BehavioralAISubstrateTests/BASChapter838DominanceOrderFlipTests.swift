// MARK: - BASChapter838DominanceOrderFlipTests
// chapter 八百三十八 / M2841-M2845 — L9 dominance order flip
// activation byte-equality test
//
// Verifies the chapter 八百三十八 flip at the two L9
// `buildCandidateFrontier` call sites:
//
//   1. BASHostKit/EBrainRuntimeCoordinator+Candidates.swift (line 25)
//   2. BASOrchestration/EBrainNeuralMaterializationCore.swift (line 287)
//
// Both sites now compute scores into a [Float] array,route to
// `BASAutoRouteRanker.dreamLoopDominanceOrder(scores:)` for the
// sort,and fall back to the Swift `.sorted` body if the Rust
// FFI returns nil。
//
// Byte-equality invariant: the routed dominance-order output
// MUST produce the same `[String]` candidate ID list as the
// Swift-only reference computation。 If this test fails,the
// flip introduced an ordering discrepancy and must be reverted。

import XCTest
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASChapter838DominanceOrderFlipTests: XCTestCase {

    // MARK: - 8-candidate fixture grid

    func testFlipPreservesOrderOnAscendingScores() throws {
        let candidates = makeCandidates(
            benefits: [0.1, 0.2, 0.3, 0.4, 0.5,
                       0.6, 0.7, 0.8],
            reversibilities: [0.5, 0.5, 0.5, 0.5, 0.5,
                              0.5, 0.5, 0.5],
            confidences: [0.5, 0.5, 0.5, 0.5, 0.5,
                          0.5, 0.5, 0.5],
            costs: [0.0, 0.0, 0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0])
        runByteEqualityCheck(candidates: candidates,
            fixtureName: "ascending-benefits")
    }

    func testFlipPreservesOrderOnDescendingScores() throws {
        let candidates = makeCandidates(
            benefits: [0.8, 0.7, 0.6, 0.5, 0.4,
                       0.3, 0.2, 0.1],
            reversibilities: [0.5, 0.5, 0.5, 0.5, 0.5,
                              0.5, 0.5, 0.5],
            confidences: [0.5, 0.5, 0.5, 0.5, 0.5,
                          0.5, 0.5, 0.5],
            costs: [0.0, 0.0, 0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0])
        runByteEqualityCheck(candidates: candidates,
            fixtureName: "descending-benefits")
    }

    func testFlipPreservesOrderOnMixedScores() throws {
        let candidates = makeCandidates(
            benefits: [0.5, 0.9, 0.3, 0.7, 0.1,
                       0.8, 0.2, 0.6],
            reversibilities: [0.4, 0.6, 0.8, 0.5, 0.3,
                              0.7, 0.2, 0.9],
            confidences: [0.3, 0.7, 0.5, 0.4, 0.8,
                          0.2, 0.6, 0.1],
            costs: [0.1, 0.2, 0.3, 0.05, 0.4,
                    0.15, 0.25, 0.0])
        runByteEqualityCheck(candidates: candidates,
            fixtureName: "mixed-scores")
    }

    func testFlipPreservesOrderOnTiedScores() throws {
        // All 8 candidates produce the same dominance score —
        // ties must resolve by input order (stable sort)。
        let candidates = makeCandidates(
            benefits: [0.5, 0.5, 0.5, 0.5, 0.5,
                       0.5, 0.5, 0.5],
            reversibilities: [0.5, 0.5, 0.5, 0.5, 0.5,
                              0.5, 0.5, 0.5],
            confidences: [0.5, 0.5, 0.5, 0.5, 0.5,
                          0.5, 0.5, 0.5],
            costs: [0.2, 0.2, 0.2, 0.2, 0.2,
                    0.2, 0.2, 0.2])
        runByteEqualityCheck(candidates: candidates,
            fixtureName: "all-tied")
    }

    func testFlipPreservesOrderOnSingleCandidate() throws {
        let candidates = makeCandidates(
            benefits: [0.7], reversibilities: [0.5],
            confidences: [0.3], costs: [0.1])
        runByteEqualityCheck(candidates: candidates,
            fixtureName: "single-candidate")
    }

    // MARK: - Helpers

    private func makeCandidates(
        benefits: [Double],
        reversibilities: [Double],
        confidences: [Double],
        costs: [Double]
    ) -> [BASCandidatePath] {
        let n = benefits.count
        return (0..<n).map { i in
            BASCandidatePath(
                candidateID: "cand-\(i)",
                title: "Candidate \(i)",
                actionSummary: "action",
                requiredEvidence: [],
                expectedBenefit: benefits[i],
                expectedCost: costs[i],
                reversibility: reversibilities[i],
                confidence: confidences[i])
        }
    }

    /// Build a frontier two ways:via the (already-flipped) public
    /// `buildCandidateFrontier` AND via a pure Swift reference
    /// computation that re-implements the legacy sort。 The two
    /// outputs MUST match。
    private func runByteEqualityCheck(
        candidates: [BASCandidatePath],
        fixtureName: String
    ) {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp-fixture-\(fixtureName)",
            candidates: candidates,
            forecasts: [],
            critiques: [],
            stabilityScore: 0.5)
        // Path A — routed (Rust on iOS/macOS, Swift fallback elsewhere)
        let routed = BASNeuralMaterializationCompiler
            .buildCandidateFrontier(from: thoughtFrame)
        XCTAssertNotNil(routed,
            "Fixture \(fixtureName):frontier must build")

        // Path B — pure Swift reference (mirror of the legacy sort)
        let swiftReference: [String] = candidates
            .sorted { lhs, rhs in
                let sl =
                    (lhs.expectedBenefit * 0.45)
                    + (lhs.reversibility * 0.30)
                    + (lhs.confidence * 0.20)
                    - (lhs.expectedCost * 0.25)
                let sr =
                    (rhs.expectedBenefit * 0.45)
                    + (rhs.reversibility * 0.30)
                    + (rhs.confidence * 0.20)
                    - (rhs.expectedCost * 0.25)
                return sl > sr
            }
            .map(\.candidateID)

        XCTAssertEqual(routed?.dominanceOrder ?? [],
            swiftReference,
            "Fixture \(fixtureName):routed dominance order " +
            "must byte-equal Swift reference")
    }
}
