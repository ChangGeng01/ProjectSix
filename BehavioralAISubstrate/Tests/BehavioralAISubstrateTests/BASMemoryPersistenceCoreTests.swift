import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemory Persistence Core")
struct BASMemoryPersistenceCoreTests {
    @Test("governed persistence fields canonicalize retrieval tags")
    func governedFieldsCanonicalizeRetrievalTags() {
        let fields = BASMemoryPersistenceApplier.governedFields(
            from: BASExistingGovernedMemorySnapshot(
                id: "support.action.decideTomorrow",
                typeID: "support",
                topic: "action_support",
                headline: "Putting it into Tomorrow Box often breaks the loop.",
                value: "Decide Tomorrow",
                confidence: 0.72,
                priority: 0.79,
                source: .history,
                lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
                decayPolicy: .medium,
                retrievalTags: ["Tomorrow", "support", "delay", "support", "decidetomorrow"],
                evidenceCount: 3,
                observationCount: 1,
                provenanceSummary: "Derived from repeated successful quick-check final actions.",
                lifecycleState: .active,
                lastReviewedAt: Date(timeIntervalSince1970: 1_744_156_800),
                tierID: "warm"
            )
        )

        #expect(fields.retrievalTags == ["decidetomorrow", "delay", "support", "tomorrow"])
    }

    @Test("candidate persistence fields canonicalize retrieval tags")
    func candidateFieldsCanonicalizeRetrievalTags() {
        let fields = BASMemoryPersistenceApplier.candidateFields(
            from: BASExistingCandidateMemorySnapshot(
                id: "goal.sleep.before_midnight",
                typeID: "goal",
                topic: "sleep",
                headline: "Sleep before midnight",
                value: "Sleep before midnight",
                confidence: 0.52,
                priority: 0.78,
                source: .history,
                firstObservedAt: Date(timeIntervalSince1970: 1_744_150_000),
                lastObservedAt: Date(timeIntervalSince1970: 1_744_156_800),
                decayPolicy: .medium,
                retrievalTags: ["Goal", "sleep", "goal"],
                evidenceCount: 1,
                confirmationCount: 0,
                lastObservationFingerprint: "goal.sleep.before_midnight::v1",
                status: .pending,
                provenanceSummary: "Promoted from repeated long-term fields in balance and mirror workspaces.",
                lastWriteOperation: .add,
                lastGovernanceDecision: .deferred,
                governanceReason: "Needs repeated confirmations before it becomes governed memory.",
                tierID: "warm"
            )
        )

        #expect(fields.retrievalTags == ["goal", "sleep"])
    }

    @Test("canonical governed order is stable on exact ties")
    func canonicalGovernedOrderIsStableOnExactTies() {
        let timestamp = Date(timeIntervalSince1970: 1_744_156_800)
        let ids = BASMemoryPersistenceApplier.canonicalGovernedOrder(
            for: [
                BASExistingGovernedMemorySnapshot(
                    id: "z-id",
                    typeID: "support",
                    topic: "support",
                    headline: "Z",
                    value: "Z",
                    confidence: 0.8,
                    priority: 0.8,
                    source: .history,
                    lastConfirmedAt: timestamp,
                    decayPolicy: .medium,
                    retrievalTags: ["z"],
                    evidenceCount: 1,
                    observationCount: 1,
                    provenanceSummary: "z",
                    lifecycleState: .active,
                    lastReviewedAt: timestamp,
                    tierID: "warm"
                ),
                BASExistingGovernedMemorySnapshot(
                    id: "a-id",
                    typeID: "support",
                    topic: "support",
                    headline: "A",
                    value: "A",
                    confidence: 0.8,
                    priority: 0.8,
                    source: .history,
                    lastConfirmedAt: timestamp,
                    decayPolicy: .medium,
                    retrievalTags: ["a"],
                    evidenceCount: 1,
                    observationCount: 1,
                    provenanceSummary: "a",
                    lifecycleState: .active,
                    lastReviewedAt: timestamp,
                    tierID: "warm"
                )
            ]
        )

        #expect(ids == ["a-id", "z-id"])
    }
}
