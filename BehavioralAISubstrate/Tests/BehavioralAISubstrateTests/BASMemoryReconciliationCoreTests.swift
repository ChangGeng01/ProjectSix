import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemory Reconciliation Core")
struct BASMemoryReconciliationCoreTests {
    @Test("reconciler promotes immediate goal draft into candidate and governed record plans")
    func reconcilerPromotesImmediateGoalDraft() {
        let request = BASMemoryReconciliationRequest(
            drafts: [
                BASMemoryReconciliationDraftInput(
                    draft: BASMemoryGovernanceDraftInput(
                        id: "goal.sleep.before_midnight",
                        typeID: "goal",
                        topic: "sleep",
                        headline: "Sleep before midnight",
                        value: "Sleep before midnight",
                        confidence: 0.52,
                        priority: 0.78,
                        source: .history,
                        lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
                        decayPolicy: .medium,
                        retrievalTags: ["goal", "sleep"],
                        evidenceCount: 1,
                        provenanceSummary: "Promoted from repeated long-term fields in balance and mirror workspaces.",
                        promotionPolicy: .immediate,
                        tierID: "warm"
                    ),
                    fingerprint: "goal.sleep.before_midnight::v1"
                )
            ],
            existingRecords: [],
            existingCandidates: [],
            reviewNow: Date(timeIntervalSince1970: 1_744_156_800)
        )

        let plan = BASMemoryReconciler.plan(request)
        let candidatePlan = try! #require(plan.candidatePlans.first(where: { $0.id == "goal.sleep.before_midnight" }))
        let recordPlan = try! #require(plan.recordPlans.first(where: { $0.id == "goal.sleep.before_midnight" }))
        let candidate = try! #require(candidatePlan.snapshot)
        let record = try! #require(recordPlan.snapshot)

        #expect(candidatePlan.operation == .add)
        #expect(candidate.status == .promoted)
        #expect(candidate.lastWriteOperation == .add)
        #expect(candidate.lastGovernanceDecision == .admit)
        #expect(recordPlan.operation == .add)
        #expect(record.lifecycleState == .active)
        #expect(record.observationCount == 1)
    }

    @Test("reconciler retires reflection memory before reminder memory at the same age")
    func reconcilerRetiresReflectionMemoryBeforeReminderMemory() {
        let reviewNow = Date(timeIntervalSince1970: 1_744_156_800)
        let oldDate = Date(timeIntervalSince1970: 1_739_836_800)
        let request = BASMemoryReconciliationRequest(
            drafts: [],
            existingRecords: [
                BASExistingGovernedMemorySnapshot(
                    id: "goal.sleep.buffer",
                    typeID: "goal",
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
                    provenanceSummary: "Repeated reminder completions confirmed this goal.",
                    lifecycleState: .active,
                    lastReviewedAt: oldDate,
                    tierID: "warm"
                ),
                BASExistingGovernedMemorySnapshot(
                    id: "support.late_night.reflective",
                    typeID: "support",
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
                    provenanceSummary: "Single reflective pattern inferred from prior sessions.",
                    lifecycleState: .active,
                    lastReviewedAt: oldDate,
                    tierID: "warm"
                ),
            ],
            existingCandidates: [],
            reviewNow: reviewNow
        )

        let plan = BASMemoryReconciler.plan(request)
        let reminderPlan = try! #require(plan.recordPlans.first(where: { $0.id == "goal.sleep.buffer" }))
        let reflectionPlan = try! #require(plan.recordPlans.first(where: { $0.id == "support.late_night.reflective" }))

        #expect(reminderPlan.snapshot?.lifecycleState != .retired)
        #expect(reflectionPlan.snapshot?.lifecycleState == .retired)
    }

    @Test("reconciler is stable for unchanged promoted support memory")
    func reconcilerIsStableForUnchangedPromotedSupportMemory() {
        let reviewNow = Date(timeIntervalSince1970: 1_744_156_800)
        let draft = BASMemoryReconciliationDraftInput(
            draft: BASMemoryGovernanceDraftInput(
                id: "support.action.decideTomorrow",
                typeID: "support",
                topic: "action_support",
                headline: "Putting it into Tomorrow Box often breaks the loop.",
                value: "Decide Tomorrow",
                confidence: 0.72,
                priority: 0.79,
                source: .history,
                lastConfirmedAt: reviewNow,
                decayPolicy: .medium,
                retrievalTags: ["support", "tomorrow", "delay", "loop_break", "quick", "decideTomorrow"],
                evidenceCount: 2,
                provenanceSummary: "Derived from repeated successful quick-check final actions.",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2),
                tierID: "warm"
            ),
            fingerprint: "support.action.decideTomorrow::stable"
        )

        let firstPlan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: [draft],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: reviewNow
            )
        )
        let firstCandidate = try! #require(firstPlan.candidatePlans.first?.snapshot)
        let firstRecord = try! #require(firstPlan.recordPlans.first?.snapshot)

        let secondPlan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: [draft],
                existingRecords: [firstRecord],
                existingCandidates: [firstCandidate],
                reviewNow: reviewNow
            )
        )

        let secondCandidatePlan = try! #require(
            secondPlan.candidatePlans.first(where: { $0.id == "support.action.decideTomorrow" })
        )
        let secondRecordPlan = try! #require(
            secondPlan.recordPlans.first(where: { $0.id == "support.action.decideTomorrow" })
        )

        #expect(secondCandidatePlan.snapshot?.confirmationCount == 1)
        #expect(secondCandidatePlan.snapshot?.lastWriteOperation == .noop)
        #expect(secondRecordPlan.operation == .noop)
    }

    @Test("reconciler canonicalizes retrieval tags before deciding unchanged memory is an update")
    func reconcilerCanonicalizesRetrievalTags() {
        let reviewNow = Date(timeIntervalSince1970: 1_744_156_800)
        let existingRecord = BASExistingGovernedMemorySnapshot(
            id: "support.action.decideTomorrow",
            typeID: "support",
            topic: "action_support",
            headline: "Putting it into Tomorrow Box often breaks the loop.",
            value: "Decide Tomorrow",
            confidence: 0.72,
            priority: 0.79,
            source: .history,
            lastConfirmedAt: reviewNow,
            decayPolicy: .medium,
            retrievalTags: ["decidetomorrow", "delay", "loop_break", "quick", "support", "tomorrow"],
            evidenceCount: 3,
            observationCount: 1,
            provenanceSummary: "Derived from repeated successful quick-check final actions.",
            lifecycleState: .active,
            lastReviewedAt: reviewNow,
            tierID: "warm"
        )
        let existingCandidate = BASExistingCandidateMemorySnapshot(
            id: "support.action.decideTomorrow",
            typeID: "support",
            topic: "action_support",
            headline: "Putting it into Tomorrow Box often breaks the loop.",
            value: "Decide Tomorrow",
            confidence: 0.72,
            priority: 0.79,
            source: .history,
            firstObservedAt: reviewNow,
            lastObservedAt: reviewNow,
            decayPolicy: .medium,
            retrievalTags: ["decidetomorrow", "delay", "loop_break", "quick", "support", "tomorrow"],
            evidenceCount: 3,
            confirmationCount: 1,
            lastObservationFingerprint: "support.action.decideTomorrow::stable",
            status: .promoted,
            provenanceSummary: "Derived from repeated successful quick-check final actions.",
            lastWriteOperation: .add,
            lastGovernanceDecision: .admit,
            governanceReason: "Structured evidence is strong enough to participate in governed memory.",
            tierID: "warm"
        )
        let draft = BASMemoryReconciliationDraftInput(
            draft: BASMemoryGovernanceDraftInput(
                id: "support.action.decideTomorrow",
                typeID: "support",
                topic: "action_support",
                headline: "Putting it into Tomorrow Box often breaks the loop.",
                value: "Decide Tomorrow",
                confidence: 0.72,
                priority: 0.79,
                source: .history,
                lastConfirmedAt: reviewNow,
                decayPolicy: .medium,
                retrievalTags: ["support", "tomorrow", "delay", "loop_break", "quick", "decideTomorrow"],
                evidenceCount: 3,
                provenanceSummary: "Derived from repeated successful quick-check final actions.",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2),
                tierID: "warm"
            ),
            fingerprint: "support.action.decideTomorrow::stable"
        )

        let plan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: [draft],
                existingRecords: [existingRecord],
                existingCandidates: [existingCandidate],
                reviewNow: reviewNow
            )
        )

        #expect(plan.candidatePlans.first?.snapshot?.lastWriteOperation == .noop)
        #expect(plan.recordPlans.first?.operation == .noop)
    }
}
