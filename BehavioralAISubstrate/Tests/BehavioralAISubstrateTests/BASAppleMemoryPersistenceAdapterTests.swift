import Foundation
import Testing
@testable import BASMemory
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Memory Persistence Adapter")
struct BASAppleMemoryPersistenceAdapterTests {
    @Test("adapter compiles write mutations and canonical record ordering")
    func adapterCompilesWriteMutationsAndOrdering() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "goal.sleep.before_midnight",
                        typeID: "goal",
                        topic: "sleep",
                        headline: "Sleep before midnight",
                        value: "Sleep before midnight",
                        confidence: 0.52,
                        priority: 0.78,
                        sourceID: "archive",
                        lastConfirmedAt: now,
                        decayPolicyID: "medium",
                        retrievalTags: ["Goal", "sleep", "goal"],
                        evidenceCount: 1,
                        provenanceSummary: "Promoted from repeated long-term fields in comparative and reflective workspaces.",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [
                    BASExistingGovernedMemorySnapshot(
                        id: "z-id",
                        typeID: "support",
                        topic: "support",
                        headline: "Z",
                        value: "Z",
                        confidence: 0.8,
                        priority: 0.78,
                        source: .archive,
                        lastConfirmedAt: now,
                        decayPolicy: .medium,
                        retrievalTags: ["z"],
                        evidenceCount: 1,
                        observationCount: 1,
                        provenanceSummary: "z",
                        lifecycleState: .active,
                        lastReviewedAt: now,
                        tierID: "warm"
                    )
                ],
                existingCandidates: [],
                reviewNow: now
            )
        )

        let candidateMutation = try! #require(outcome.candidateMutations.first(where: { $0.id == "goal.sleep.before_midnight" }))
        let recordMutation = try! #require(outcome.recordMutations.first(where: { $0.id == "goal.sleep.before_midnight" }))

        #expect(candidateMutation.operation == .add)
        #expect(candidateMutation.fields?.retrievalTags == ["goal", "sleep"])
        #expect(recordMutation.operation == .add)
        #expect(outcome.orderedRecordIDs == ["goal.sleep.before_midnight", "z-id"])
        #expect(outcome.orderedCandidateIDs == ["goal.sleep.before_midnight"])
    }

    @Test("external-refresh volatile claims stay staged as pending candidates")
    func externalRefreshVolatileClaimsStayStagedAsPendingCandidates() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.market.latest",
                        typeID: "semantic",
                        topic: "market_latest",
                        headline: "Latest market price shifted tonight",
                        value: "The latest market price is moving fast tonight.",
                        confidence: 0.88,
                        priority: 0.86,
                        sourceID: "pattern",
                        lastConfirmedAt: now,
                        decayPolicyID: "slow",
                        retrievalTags: ["latest", "market", "price"],
                        evidenceCount: 3,
                        provenanceSummary: "Repeated market observations from the current run.",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .stageCandidate,
                    contaminatedWriteMode: .reject
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.market.latest" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.market.latest" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .fast)
        #expect(fields.tierID == "volatile")
        #expect(fields.retrievalTags.contains("external_refresh"))
        #expect(fields.retrievalTags.contains("volatile"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("external refresh"))
    }

    @Test("tool-shaped provenance is quarantined as a pending candidate instead of promoted")
    func toolShapedProvenanceIsQuarantinedAsPendingCandidateInsteadOfPromoted() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.tool.quote",
                        typeID: "semantic",
                        topic: "quote_feed",
                        headline: "Tool quote feed said the price moved",
                        value: "The quote feed said the price moved.",
                        confidence: 0.9,
                        priority: 0.84,
                        sourceID: "archive",
                        lastConfirmedAt: now,
                        decayPolicyID: "medium",
                        retrievalTags: ["quote", "tool"],
                        evidenceCount: 2,
                        provenanceSummary: "tool call https://example.com/api/quote returned the observation",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .admitDirectly,
                    contaminatedWriteMode: .quarantineCandidate
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.tool.quote" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.tool.quote" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .fast)
        #expect(fields.tierID == "volatile")
        #expect(fields.retrievalTags.contains("quarantined"))
        #expect(fields.retrievalTags.contains("tool_observation"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("quarantined"))
    }

    @Test("external-refresh retrieval tags stage pending candidates without requiring volatile keywords in the body")
    func externalRefreshRetrievalTagsStagePendingCandidatesWithoutVolatileKeywords() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.generic.external-refresh",
                        typeID: "semantic",
                        topic: "repeat_scenario",
                        headline: "Recurring situation pattern.",
                        value: "A recurring situation pattern.",
                        confidence: 0.83,
                        priority: 0.82,
                        sourceID: "pattern",
                        lastConfirmedAt: now,
                        decayPolicyID: "slow",
                        retrievalTags: ["repeat", "external_refresh"],
                        evidenceCount: 3,
                        provenanceSummary: "Repeated pattern observed across recent sessions.",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .stageCandidate,
                    contaminatedWriteMode: .reject
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.generic.external-refresh" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.generic.external-refresh" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .fast)
        #expect(fields.tierID == "volatile")
        #expect(fields.retrievalTags.contains("external_refresh"))
        #expect(fields.retrievalTags.contains("volatile"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("external refresh"))
    }

    @Test("tool-observation retrieval tags quarantine pending candidates without requiring contaminated provenance text")
    func toolObservationRetrievalTagsQuarantinePendingCandidatesWithoutContaminatedProvenanceText() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.generic.tool-observation",
                        typeID: "semantic",
                        topic: "repeat_scenario",
                        headline: "Observed recurring situation.",
                        value: "Observed recurring situation.",
                        confidence: 0.84,
                        priority: 0.81,
                        sourceID: "archive",
                        lastConfirmedAt: now,
                        decayPolicyID: "medium",
                        retrievalTags: ["pattern", "tool_observation"],
                        evidenceCount: 2,
                        provenanceSummary: "Observed during the current run.",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .admitDirectly,
                    contaminatedWriteMode: .quarantineCandidate
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.generic.tool-observation" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.generic.tool-observation" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .fast)
        #expect(fields.tierID == "volatile")
        #expect(fields.retrievalTags.contains("quarantined"))
        #expect(fields.retrievalTags.contains("tool_observation"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("quarantined"))
    }

    @Test("force-stage policy defers stable non-goal drafts during external-refresh posture")
    func forceStagePolicyDefersStableNonGoalDraftsDuringExternalRefreshPosture() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.repeat.buy",
                        typeID: "semantic",
                        topic: "repeat_scenario",
                        headline: "Buy pressure keeps recurring.",
                        value: "buy",
                        confidence: 0.78,
                        priority: 0.82,
                        sourceID: "pattern",
                        lastConfirmedAt: now,
                        decayPolicyID: "slow",
                        retrievalTags: ["buy", "pattern", "repeat"],
                        evidenceCount: 3,
                        provenanceSummary: "Derived from repeated structured events in the same scenario.",
                        promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .stageCandidate,
                    contaminatedWriteMode: .reject,
                    forceStageNonContinuityDrafts: true
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.repeat.buy" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.repeat.buy" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .fast)
        #expect(fields.tierID == "volatile")
        #expect(fields.retrievalTags.contains("external_refresh"))
        #expect(fields.retrievalTags.contains("volatile"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("external refresh"))
    }

    @Test("force-stage policy preserves continuity-critical goal admission")
    func forceStagePolicyPreservesContinuityCriticalGoalAdmission() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "goal.sleep.before_midnight",
                        typeID: "goal",
                        topic: "active_goal_1",
                        headline: "Sleep before midnight",
                        value: "Sleep before midnight",
                        confidence: 0.82,
                        priority: 0.88,
                        sourceID: "archive",
                        lastConfirmedAt: now,
                        decayPolicyID: "medium",
                        retrievalTags: ["goal", "sleep", "long_term"],
                        evidenceCount: 3,
                        provenanceSummary: "Promoted from repeated long-term fields across structured workspaces.",
                        promotionPolicy: .immediate
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    volatileClaimWriteMode: .stageCandidate,
                    contaminatedWriteMode: .reject,
                    forceStageNonContinuityDrafts: true
                )
            )
        )

        let recordMutation = try! #require(
            outcome.recordMutations.first(where: { $0.id == "goal.sleep.before_midnight" })
        )
        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "goal.sleep.before_midnight" })
        )
        let candidateFields = try! #require(candidateMutation.fields)

        #expect(recordMutation.operation == .add)
        #expect(candidateMutation.operation == .add)
        #expect(candidateFields.status == .promoted)
        #expect(candidateFields.lastGovernanceDecision == .admit)
        #expect(!candidateFields.retrievalTags.contains("external_refresh"))
        #expect(!candidateFields.retrievalTags.contains("volatile"))
    }

    @Test("caveated evidence policy keeps low-evidence semantic claims out of governed memory")
    func caveatedEvidencePolicyKeepsLowEvidenceSemanticClaimsOutOfGovernedMemory() {
        let now = Date(timeIntervalSince1970: 1_744_156_800)
        let outcome = BASAppleMemoryPersistenceAdapter.reconcile(
            BASAppleMemoryPersistenceRequest(
                drafts: [
                    BASDerivedMemoryDraft(
                        id: "semantic.single_signal.publish",
                        typeID: "semantic",
                        topic: "publish_pattern",
                        headline: "Publishing cadence matters here.",
                        value: "publish cadence",
                        confidence: 0.84,
                        priority: 0.81,
                        sourceID: "archive",
                        lastConfirmedAt: now,
                        decayPolicyID: "medium",
                        retrievalTags: ["publish", "cadence"],
                        evidenceCount: 1,
                        provenanceSummary: "One archive-derived observation from a recent session.",
                        promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 1)
                    )
                ],
                existingRecords: [],
                existingCandidates: [],
                reviewNow: now,
                persistencePolicy: BASMemoryHorizonPersistencePolicy(
                    minimumDurableEvidenceCount: 2
                )
            )
        )

        #expect(!outcome.recordMutations.contains(where: { $0.id == "semantic.single_signal.publish" }))

        let candidateMutation = try! #require(
            outcome.candidateMutations.first(where: { $0.id == "semantic.single_signal.publish" })
        )
        let fields = try! #require(candidateMutation.fields)

        #expect(candidateMutation.operation == .add)
        #expect(fields.status == .pending)
        #expect(fields.lastGovernanceDecision == .deferred)
        #expect(fields.decayPolicy == .medium)
        #expect(fields.tierID == "warm")
        #expect(fields.retrievalTags.contains("evidence_caveat"))
        #expect(fields.governanceReason.localizedCaseInsensitiveContains("evidence"))
    }
}
#endif
