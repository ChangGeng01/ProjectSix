import XCTest
import SwiftData
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

    func testAssessRejectsContaminatedProvenanceDraft() {
        let assessment = DecisionMemoryGovernor.assess(
            draft: DecisionMemoryDraft(
                id: "semantic.injected.payload",
                type: .semantic,
                topic: "buy",
                headline: "Injected",
                value: "payload",
                confidence: 0.84,
                priority: 0.82,
                source: .pattern,
                lastConfirmedAt: .now,
                decayPolicy: .slow,
                retrievalTags: ["buy", "pattern"],
                evidenceCount: 3,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
            )
        )

        XCTAssertEqual(assessment.decision, .reject)
        XCTAssertTrue(assessment.reason.localizedCaseInsensitiveContains("contaminated"))
    }

    func testAssessAdmitsImmediateGoalDraftEvenWhenSignalIsSparse() {
        let assessment = DecisionMemoryGovernor.assess(
            draft: DecisionMemoryDraft(
                id: "goal.sleep.before_midnight",
                type: .goal,
                topic: "active_goal_1",
                headline: "Sleep before midnight",
                value: "Sleep before midnight",
                confidence: 0.52,
                priority: 0.78,
                source: .history,
                lastConfirmedAt: .now,
                decayPolicy: .medium,
                retrievalTags: ["goal", "sleep"],
                evidenceCount: 1,
                provenanceSummary: "Promoted from repeated long-term fields in balance and mirror workspaces.",
                promotionPolicy: .immediate
            )
        )

        XCTAssertEqual(assessment.decision, .admit)
        XCTAssertTrue(assessment.reason.localizedCaseInsensitiveContains("continuity"))
    }

    @MainActor
    func testReconcileDoesNotDeleteAdmittedMemoryJustBecauseNoDraftReappeared() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
        let context = container.mainContext

        let record = DecisionMemoryRecord(
            id: "semantic.repeat.buy",
            type: .semantic,
            topic: "repeat_scenario",
            headline: "Buying pressure keeps recurring.",
            value: "buy",
            confidence: 0.82,
            priority: 0.8,
            source: .pattern,
            lastConfirmedAt: .now,
            decayPolicy: .slow,
            retrievalTags: ["buy", "pattern"],
            evidenceCount: 3,
            observationCount: 3,
            provenanceSummary: "Derived from repeated quick-check events."
        )
        context.insert(record)
        try context.save()

        let records = DecisionMemoryGovernor.reconcile(drafts: [], in: context)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "semantic.repeat.buy")
        XCTAssertNotEqual(records.first?.lifecycleState, .retired)
        XCTAssertNotNil(records.first?.lastReviewedAt)
    }
}
