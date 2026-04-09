import XCTest
@testable import Before

final class DecisionMemoryGovernorTests: XCTestCase {
    func testAssessRejectsLowConfidenceSingletonDraft() {
        let assessment = DecisionMemoryGovernor.assess(
            draft: DecisionMemoryDraft(
                id: "semantic.noisy.singleton",
                type: .semantic,
                topic: "noise",
                headline: "Noisy singleton",
                value: "noisy",
                confidence: 0.42,
                priority: 0.41,
                source: .history,
                lastConfirmedAt: .now,
                decayPolicy: .fast,
                retrievalTags: ["noise"],
                evidenceCount: 1,
                provenanceSummary: "One-off event",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
            )
        )

        XCTAssertEqual(assessment.decision, .reject)
    }

    func testAssessDefersCandidateOnlySituationalDraft() {
        let assessment = DecisionMemoryGovernor.assess(
            draft: DecisionMemoryDraft(
                id: "situational.quick.latest",
                type: .situational,
                topic: "recent_quick_loop",
                headline: "Recently carrying something heavy.",
                value: "temporary",
                confidence: 0.74,
                priority: 0.75,
                source: .history,
                lastConfirmedAt: .now,
                decayPolicy: .fast,
                retrievalTags: ["quick", "recent"],
                evidenceCount: 1,
                provenanceSummary: "Latest session only",
                promotionPolicy: .candidateOnly
            )
        )

        XCTAssertEqual(assessment.decision, .deferred)
    }
}
