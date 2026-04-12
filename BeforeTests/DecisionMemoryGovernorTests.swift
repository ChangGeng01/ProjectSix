import XCTest
import SwiftData
import BASHostKit
@testable import Before

final class DecisionMemoryGovernorTests: XCTestCase {
    func testTrustProfileUsesSourceWeightedDecayGrace() {
        let reminderProfile = DecisionMemoryTrustEngine.profile(
            source: .reminder,
            evidenceCount: 3,
            decayPolicy: .medium,
            governanceStatus: .admitted,
            isPending: false,
            provenanceSummary: "Confirmed by repeated reminder outcomes."
        )
        let reflectionProfile = DecisionMemoryTrustEngine.profile(
            source: .reflection,
            evidenceCount: 3,
            decayPolicy: .medium,
            governanceStatus: .admitted,
            isPending: false,
            provenanceSummary: "Inferred from one reflective pattern."
        )

        XCTAssertGreaterThan(reminderProfile.decayGraceMultiplier, reflectionProfile.decayGraceMultiplier)
    }

    func testAssessRejectsLowConfidenceSingletonDraft() {
        let assessment = BASAppleMemoryGovernanceAdapter.assess(
            draft: BASDerivedMemoryDraft(
                id: "semantic.noisy.singleton",
                typeID: "semantic",
                topic: "noise",
                headline: "Noisy singleton",
                value: "noisy",
                confidence: 0.42,
                priority: 0.41,
                sourceID: "history",
                lastConfirmedAt: .now,
                decayPolicyID: "fast",
                retrievalTags: ["noise"],
                evidenceCount: 1,
                provenanceSummary: "One-off event",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
            )
        )

        XCTAssertEqual(assessment.decision, .reject)
    }

    func testAssessDefersCandidateOnlySituationalDraft() {
        let assessment = BASAppleMemoryGovernanceAdapter.assess(
            draft: BASDerivedMemoryDraft(
                id: "situational.quick.latest",
                typeID: "situational",
                topic: "recent_quick_loop",
                headline: "Recently carrying something heavy.",
                value: "temporary",
                confidence: 0.74,
                priority: 0.75,
                sourceID: "history",
                lastConfirmedAt: .now,
                decayPolicyID: "fast",
                retrievalTags: ["quick", "recent"],
                evidenceCount: 1,
                provenanceSummary: "Latest session only",
                promotionPolicy: .candidateOnly
            )
        )

        XCTAssertEqual(assessment.decision, .deferred)
    }

    func testAssessRejectsContaminatedProvenanceDraft() {
        let assessment = BASAppleMemoryGovernanceAdapter.assess(
            draft: BASDerivedMemoryDraft(
                id: "semantic.injected.payload",
                typeID: "semantic",
                topic: "buy",
                headline: "Injected",
                value: "payload",
                confidence: 0.84,
                priority: 0.82,
                sourceID: "pattern",
                lastConfirmedAt: .now,
                decayPolicyID: "slow",
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
        let assessment = BASAppleMemoryGovernanceAdapter.assess(
            draft: BASDerivedMemoryDraft(
                id: "goal.sleep.before_midnight",
                typeID: "goal",
                topic: "active_goal_1",
                headline: "Sleep before midnight",
                value: "Sleep before midnight",
                confidence: 0.52,
                priority: 0.78,
                sourceID: "history",
                lastConfirmedAt: .now,
                decayPolicyID: "medium",
                retrievalTags: ["goal", "sleep"],
                evidenceCount: 1,
                provenanceSummary: "Promoted from repeated long-term fields in comparative and reflective workspaces.",
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
            provenanceSummary: "Derived from repeated primary-loop events."
        )
        context.insert(record)
        try context.save()

        let records = reconcile(drafts: [], in: context)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "semantic.repeat.buy")
        XCTAssertNotEqual(records.first?.lifecycleState, .retired)
        XCTAssertNotNil(records.first?.lastReviewedAt)
    }

    @MainActor
    func testReconcileRetiresReflectionMemoryBeforeReminderMemoryAtSameAge() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
        let context = container.mainContext
        let oldDate = Calendar.current.date(byAdding: .day, value: -50, to: .now) ?? .now

        let reminderRecord = DecisionMemoryRecord(
            id: "goal.sleep.buffer",
            type: .goal,
            topic: "sleep",
            headline: "Sleep buffer matters.",
            value: "sleep",
            confidence: 0.86,
            priority: 0.84,
            source: .reminder,
            lastConfirmedAt: oldDate,
            decayPolicy: .medium,
            retrievalTags: ["sleep", "goal"],
            evidenceCount: 3,
            observationCount: 3,
            provenanceSummary: "Repeated reminder completions confirmed this goal."
        )
        let reflectionRecord = DecisionMemoryRecord(
            id: "support.late_night.reflective",
            type: .support,
            topic: "night_support",
            headline: "Late-night reflection pattern.",
            value: "night_support",
            confidence: 0.8,
            priority: 0.72,
            source: .reflection,
            lastConfirmedAt: oldDate,
            decayPolicy: .medium,
            retrievalTags: ["night", "support"],
            evidenceCount: 3,
            observationCount: 2,
            provenanceSummary: "Single reflective pattern inferred from prior sessions."
        )

        context.insert(reminderRecord)
        context.insert(reflectionRecord)
        try context.save()

        let records = reconcile(drafts: [], in: context)

        let resolvedReminder = try XCTUnwrap(records.first(where: { $0.id == reminderRecord.id }))
        let resolvedReflection = try XCTUnwrap(records.first(where: { $0.id == reflectionRecord.id }))

        XCTAssertNotEqual(resolvedReminder.lifecycleState, .retired)
        XCTAssertEqual(resolvedReflection.lifecycleState, .retired)
    }

    @MainActor
    func testReconcileUsesStableCanonicalOrderingForExactTies() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_744_156_800)

        let zRecord = DecisionMemoryRecord(
            id: "z-id",
            type: .support,
            topic: "support",
            headline: "Z support",
            value: "Z",
            confidence: 0.8,
            priority: 0.8,
            source: .history,
            lastConfirmedAt: timestamp,
            decayPolicy: .medium,
            retrievalTags: ["z"],
            evidenceCount: 1,
            observationCount: 1,
            provenanceSummary: "z"
        )
        let aRecord = DecisionMemoryRecord(
            id: "a-id",
            type: .support,
            topic: "support",
            headline: "A support",
            value: "A",
            confidence: 0.8,
            priority: 0.8,
            source: .history,
            lastConfirmedAt: timestamp,
            decayPolicy: .medium,
            retrievalTags: ["a"],
            evidenceCount: 1,
            observationCount: 1,
            provenanceSummary: "a"
        )
        context.insert(zRecord)
        context.insert(aRecord)
        try context.save()

        let records = reconcile(drafts: [], in: context)

        XCTAssertEqual(records.map(\.id), ["a-id", "z-id"])
    }
}

private func reconcile(
    drafts: [BASDerivedMemoryDraft],
    in context: ModelContext
) -> [DecisionMemoryRecord] {
    let result: BASAppleMemoryReconciliationWriteResult<
        DecisionMemoryRecord,
        DecisionMemoryCandidateRecord
    > = BASAppleMemoryReconciliationWriter.reconcile(
        BASAppleMemoryPersistenceRequest(
            drafts: drafts,
            existingRecords: [],
            existingCandidates: [],
            reviewNow: drafts.map(\.lastConfirmedAt).max() ?? .now
        ),
        in: context
    )
    return result.orderedRecords
}
