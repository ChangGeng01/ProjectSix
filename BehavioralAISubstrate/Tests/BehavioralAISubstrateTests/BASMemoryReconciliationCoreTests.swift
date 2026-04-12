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
                        source: .archive,
                        lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
                        decayPolicy: .medium,
                        retrievalTags: ["goal", "sleep"],
                        evidenceCount: 1,
                        provenanceSummary: "Promoted from repeated long-term fields in comparative and reflective workspaces.",
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

    @Test("reconciler retires reflection memory before cue memory at the same age")
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
                    source: .cue,
                    lastConfirmedAt: oldDate,
                    decayPolicy: .medium,
                    retrievalTags: ["sleep", "goal"],
                    evidenceCount: 3,
                    observationCount: 3,
                    provenanceSummary: "Repeated cue completions confirmed this goal.",
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
        let cuePlan = try! #require(plan.recordPlans.first(where: { $0.id == "goal.sleep.buffer" }))
        let reflectionPlan = try! #require(plan.recordPlans.first(where: { $0.id == "support.late_night.reflective" }))

        #expect(cuePlan.snapshot?.lifecycleState != .retired)
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
                headline: "Holding the decision often breaks the loop.",
                value: "Decide Tomorrow",
                confidence: 0.72,
                priority: 0.79,
                source: .archive,
                lastConfirmedAt: reviewNow,
                decayPolicy: .medium,
                retrievalTags: ["support", "tomorrow", "delay", "loop_break", "primary", "decideTomorrow"],
                evidenceCount: 2,
                provenanceSummary: "Derived from repeated successful primary-loop final actions.",
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
            headline: "Holding the decision often breaks the loop.",
            value: "Decide Tomorrow",
            confidence: 0.72,
            priority: 0.79,
            source: .archive,
            lastConfirmedAt: reviewNow,
            decayPolicy: .medium,
            retrievalTags: ["decidetomorrow", "delay", "loop_break", "primary", "support", "tomorrow"],
            evidenceCount: 3,
            observationCount: 1,
            provenanceSummary: "Derived from repeated successful primary-loop final actions.",
            lifecycleState: .active,
            lastReviewedAt: reviewNow,
            tierID: "warm"
        )
        let existingCandidate = BASExistingCandidateMemorySnapshot(
            id: "support.action.decideTomorrow",
            typeID: "support",
            topic: "action_support",
            headline: "Holding the decision often breaks the loop.",
            value: "Decide Tomorrow",
            confidence: 0.72,
            priority: 0.79,
            source: .archive,
            firstObservedAt: reviewNow,
            lastObservedAt: reviewNow,
            decayPolicy: .medium,
            retrievalTags: ["decidetomorrow", "delay", "loop_break", "primary", "support", "tomorrow"],
            evidenceCount: 3,
            confirmationCount: 1,
            lastObservationFingerprint: "support.action.decideTomorrow::stable",
            status: .promoted,
            provenanceSummary: "Derived from repeated successful primary-loop final actions.",
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
                headline: "Holding the decision often breaks the loop.",
                value: "Decide Tomorrow",
                confidence: 0.72,
                priority: 0.79,
                source: .archive,
                lastConfirmedAt: reviewNow,
                decayPolicy: .medium,
                retrievalTags: ["support", "tomorrow", "delay", "loop_break", "primary", "decideTomorrow"],
                evidenceCount: 3,
                provenanceSummary: "Derived from repeated successful primary-loop final actions.",
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

    @Test("reconciler uses host memory trust behavior instead of substrate-only source priors")
    func reconcilerUsesHostMemoryTrustBehavior() {
        let draft = BASMemoryReconciliationDraftInput(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.archive.publish",
                typeID: "semantic",
                topic: "publish_pattern",
                headline: "Publishing cadence matters here.",
                value: "publish cadence",
                confidence: 0.74,
                priority: 0.8,
                source: .archive,
                lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
                decayPolicy: .medium,
                retrievalTags: ["publish", "cadence"],
                evidenceCount: 1,
                provenanceSummary: "Structured host archive confirms this pattern.",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2),
                tierID: "warm"
            ),
            fingerprint: "semantic.archive.publish::v1"
        )

        let genericPlan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: [draft],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: Date(timeIntervalSince1970: 1_744_156_800)
            )
        )
        let hostPlan = BASMemoryReconciler.plan(
            BASMemoryReconciliationRequest(
                drafts: [draft],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: Date(timeIntervalSince1970: 1_744_156_800),
                memoryTrustBehavior: BASMemoryTrustBehavior(
                    baseScoresBySourceID: [
                        BASMemorySource.cue.rawValue: 0.55,
                        BASMemorySource.pattern.rawValue: 0.62,
                        BASMemorySource.reflection.rawValue: 0.7,
                        BASMemorySource.archive.rawValue: 0.92
                    ]
                )
            )
        )

        #expect(genericPlan.candidatePlans.isEmpty)
        #expect(hostPlan.candidatePlans.first?.snapshot?.lastGovernanceDecision == .admit)
        #expect(hostPlan.candidatePlans.first?.snapshot?.status == .pending)
    }
}
