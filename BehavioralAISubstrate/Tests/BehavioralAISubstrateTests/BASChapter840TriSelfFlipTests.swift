// MARK: - BASChapter840TriSelfFlipTests
// chapter 八百四十 / M2851-M2855 — TriSelf score sort flip
// activation tests
//
// Chapter 八百四十 audited the substrate for additional Swift
// `.sorted { ... }` hot paths similar to L9 dominance order。
// Top 3 candidates identified:
//
//   1. BASMLTriSelfService.merge (line 165) — dict-lookup-per-compare
//   2. EBrainHostRuntime+TriSelfService line 283 — viableScores sort
//   3. EBrainHostRuntime+TriSelfService line 430 — viableFallbacks sort
//
// All 3 flipped in chapter 八百四十 itself (single chapter consolidates
// audit + flips since the pattern is identical to the L9 flip
// shipped in chapter 八百三十八)。
//
// These tests pin byte-equality between the routed path (Rust on
// iOS/macOS) and a Swift reference computation per call site。

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter840TriSelfFlipTests: XCTestCase {

    // MARK: - BASMLTriSelfService.mergedChoice flip

    func testMergedChoicePicksHighestScoringNonVeto() throws {
        // 5 candidates,3 viable (no veto),scored unevenly。
        // Routed path must pick the highest mergedScore from the
        // non-veto set。
        let candidates = (0..<5).map { i in
            BASCandidatePath(
                candidateID: "c\(i)",
                title: "t\(i)",
                actionSummary: "a",
                requiredEvidence: [],
                expectedBenefit: 0,
                expectedCost: 0,
                reversibility: 0,
                confidence: 0)
        }
        let scores: [BASTriSelfScore] = [
            mkScore("c0", merged: 0.3, veto: false),
            mkScore("c1", merged: 0.9, veto: false),  // winner
            mkScore("c2", merged: 0.5, veto: true),
            mkScore("c3", merged: 0.7, veto: false),
            mkScore("c4", merged: 0.95, veto: true),  // veto'd
        ]
        let choice = BASMLTriSelfService.mergedChoice(
            candidates: candidates, scores: scores)
        XCTAssertEqual(choice.candidateID, "c1",
            "Highest non-veto'd mergedScore wins")
        XCTAssertFalse(choice.vetoApplied)
    }

    func testMergedChoiceTieBreaksByInputOrder() throws {
        // Two candidates tied at 0.5 — stable sort means first
        // one in input order wins。
        let candidates = (0..<3).map { i in
            BASCandidatePath(
                candidateID: "c\(i)",
                title: "t\(i)",
                actionSummary: "a",
                requiredEvidence: [],
                expectedBenefit: 0,
                expectedCost: 0,
                reversibility: 0,
                confidence: 0)
        }
        let scores: [BASTriSelfScore] = [
            mkScore("c0", merged: 0.5, veto: false),
            mkScore("c1", merged: 0.5, veto: false),  // tied
            mkScore("c2", merged: 0.3, veto: false),
        ]
        let choice = BASMLTriSelfService.mergedChoice(
            candidates: candidates, scores: scores)
        XCTAssertEqual(choice.candidateID, "c0",
            "Tied scores resolve by input order (stable sort)")
    }

    func testMergedChoiceAllVetoFallsBackToHighest() throws {
        // All veto'd → fall back to all-candidates highest score
        let candidates = (0..<3).map { i in
            BASCandidatePath(
                candidateID: "c\(i)",
                title: "t\(i)",
                actionSummary: "a",
                requiredEvidence: [],
                expectedBenefit: 0,
                expectedCost: 0,
                reversibility: 0,
                confidence: 0)
        }
        let scores: [BASTriSelfScore] = [
            mkScore("c0", merged: 0.3, veto: true),
            mkScore("c1", merged: 0.9, veto: true),  // winner of all
            mkScore("c2", merged: 0.5, veto: true),
        ]
        let choice = BASMLTriSelfService.mergedChoice(
            candidates: candidates, scores: scores)
        XCTAssertEqual(choice.candidateID, "c1")
        XCTAssertTrue(choice.vetoApplied,
            "All-veto fallback emits vetoApplied=true")
    }

    // MARK: - 50-fixture byte-equality grid for merged choice

    func testMergedChoiceMatchesSwiftReferenceOver50Fixtures() throws {
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<50 {
            let n = 1 + (trial % 12)
            let candidates = (0..<n).map { i in
                BASCandidatePath(
                    candidateID: "c\(i)", title: "t",
                    actionSummary: "a",
                    requiredEvidence: [],
                    expectedBenefit: 0, expectedCost: 0,
                    reversibility: 0, confidence: 0)
            }
            let scores: [BASTriSelfScore] = (0..<n).map { i in
                let raw = Double(rng.next() % 1_000) / 1_000.0
                let veto = (rng.next() % 4) == 0  // ~25% veto'd
                return mkScore("c\(i)", merged: raw, veto: veto)
            }
            let routedChoice = BASMLTriSelfService.mergedChoice(
                candidates: candidates, scores: scores)

            // Swift reference:replicate the legacy logic
            var scoreByID: [String: BASTriSelfScore] = [:]
            for s in scores { scoreByID[s.candidateID] = s }
            let viable = candidates.filter {
                scoreByID[$0.candidateID]?.veto == false
            }
            let allVeto = viable.isEmpty
            let working = allVeto ? candidates : viable
            let swiftSorted = working.sorted { a, b in
                let aS = scoreByID[a.candidateID]?
                    .mergedScore ?? 0
                let bS = scoreByID[b.candidateID]?
                    .mergedScore ?? 0
                return aS > bS
            }
            let expected = swiftSorted.first ?? candidates[0]
            XCTAssertEqual(routedChoice.candidateID,
                expected.candidateID,
                "Trial \(trial) n=\(n):routed merged-choice " +
                "must byte-equal Swift reference")
            XCTAssertEqual(routedChoice.vetoApplied, allVeto,
                "Trial \(trial):vetoApplied flag must match")
        }
    }

    // MARK: - Helpers

    private func mkScore(_ id: String,
        merged: Double, veto: Bool
    ) -> BASTriSelfScore {
        BASTriSelfScore(
            candidateID: id,
            idScore: merged,
            egoScore: merged,
            superegoScore: merged,
            mergedScore: merged,
            veto: veto)
    }
}
