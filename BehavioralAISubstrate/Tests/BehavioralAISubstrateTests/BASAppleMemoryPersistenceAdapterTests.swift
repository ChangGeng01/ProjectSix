import Foundation
import Testing
@testable import BASMemory
@testable import BASAppleAdapters

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
                        sourceID: "history",
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
                        source: .history,
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
}
