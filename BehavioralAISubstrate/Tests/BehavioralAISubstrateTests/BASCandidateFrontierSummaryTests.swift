import XCTest
@testable import BASOrchestration

final class BASCandidateFrontierSummaryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func obs(
        _ kind: BASCandidateSignalKind,
        candidateID: String,
        salience: Double = 0.5
    ) -> BASCandidateObservation {
        BASCandidateObservation(
            kind: kind,
            candidateID: candidateID,
            salience: salience,
            confidence: 1.0,
            content: "test",
            observedAt: now)
    }

    private func bundle(
        _ obsList: [BASCandidateObservation]
    ) -> BASCandidateObservationBundle {
        BASCandidateObservationBundle(
            turnID: "t-1",
            sessionID: "s-1",
            observations: obsList,
            emittedAt: now)
    }

    func testEmptyBundleSummarizesEmpty() {
        let summary = bundle([]).summarize()
        XCTAssertEqual(summary.candidateCount, 0)
        XCTAssertNil(summary.dominantCandidateID)
        XCTAssertEqual(summary.statusCode, "empty")
        XCTAssertFalse(summary.emittedDiversitySignal)
    }

    func testDiversityOnlyBundleStatus() {
        let summary = bundle([
            obs(.diversitySignal, candidateID: "c1")
        ]).summarize()
        XCTAssertEqual(summary.statusCode, "diversity-only")
        XCTAssertTrue(summary.emittedDiversitySignal)
        XCTAssertNil(summary.dominantCandidateID)
    }

    func testDominantClearStatus() {
        let summary = bundle([
            obs(.candidate, candidateID: "c1"),
            obs(.candidate, candidateID: "c2"),
            obs(.dominanceSignal,
                candidateID: "c1",
                salience: 0.9),
            obs(.dominanceSignal,
                candidateID: "c2",
                salience: 0.6),
            obs(.diversitySignal, candidateID: "c1"),
        ]).summarize()
        XCTAssertEqual(summary.candidateCount, 2)
        XCTAssertEqual(summary.dominantCandidateID, "c1")
        XCTAssertEqual(summary.statusCode, "dominant-clear")
    }

    func testGuardianHeldStatusOverridesDominantClear() {
        // Even with a clear winner, presence of guardianBranch
        // should flag the bundle as guardian-held.
        let summary = bundle([
            obs(.candidate, candidateID: "c1"),
            obs(.dominanceSignal,
                candidateID: "c1",
                salience: 0.9),
            obs(.guardianBranch,
                candidateID: "c1",
                salience: 0.5),
        ]).summarize()
        XCTAssertEqual(summary.statusCode, "guardian-held")
        XCTAssertEqual(summary.guardianBranchCount, 1)
    }

    func testReversibleAndDelayedCounts() {
        let summary = bundle([
            obs(.candidate, candidateID: "c1"),
            obs(.candidate, candidateID: "c2"),
            obs(.reversibilitySignal, candidateID: "c1"),
            obs(.reversibilitySignal, candidateID: "c2"),
            obs(.delayRecommendation, candidateID: "c1"),
        ]).summarize()
        XCTAssertEqual(summary.reversibleCandidateCount, 2)
        XCTAssertEqual(summary.delayedCandidateCount, 1)
    }

    func testReversibleCountIsDistinctCandidates() {
        // Multiple reversibility signals on same candidate
        // count once.
        let summary = bundle([
            obs(.reversibilitySignal, candidateID: "c1"),
            obs(.reversibilitySignal, candidateID: "c1"),
            obs(.reversibilitySignal, candidateID: "c1"),
        ]).summarize()
        XCTAssertEqual(summary.reversibleCandidateCount, 1)
    }
}
