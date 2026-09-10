import Foundation
import Testing
@testable import BASMemory

@Suite("BASMemory Persistence Core")
struct BASMemoryPersistenceCoreTests {
    @Test("governed persistence fields canonicalize retrieval tags")
    func governedFieldsCanonicalizeRetrievalTags() {
        let snapshot = BASExistingGovernedMemorySnapshot(
            id: "support.action.decideTomorrow",
            typeID: "support",
            topic: "action_support",
            headline: "Holding the decision often breaks the loop.",
            value: "Decide Tomorrow",
            confidence: 0.72,
            priority: 0.79,
            source: .archive,
            lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
            decayPolicy: .medium,
            retrievalTags: ["Z", "a", "Z"],
            evidenceCount: 3,
            observationCount: 1,
            provenanceSummary: "Derived from repeated successful primary-loop final actions.",
            lifecycleState: .active,
            lastReviewedAt: Date(timeIntervalSince1970: 1_744_156_800),
            tierID: "warm"
        )
        let lossless = BASGovernedMemoryStoredFields(snapshot: snapshot)
        let fields = BASMemoryPersistenceApplier.governedFields(from: snapshot)

        #expect(lossless.retrievalTags == ["Z", "a", "Z"])
        #expect(fields.retrievalTags == ["a", "z"])
    }

    @Test("candidate persistence fields canonicalize retrieval tags")
    func candidateFieldsCanonicalizeRetrievalTags() {
        let snapshot = BASExistingCandidateMemorySnapshot(
            id: "goal.sleep.before_midnight",
            typeID: "goal",
            topic: "sleep",
            headline: "Sleep before midnight",
            value: "Sleep before midnight",
            confidence: 0.52,
            priority: 0.78,
            source: .archive,
            firstObservedAt: Date(timeIntervalSince1970: 1_744_150_000),
            lastObservedAt: Date(timeIntervalSince1970: 1_744_156_800),
            decayPolicy: .medium,
            retrievalTags: ["Z", "a", "Z"],
            evidenceCount: 1,
            confirmationCount: 0,
            lastObservationFingerprint: "goal.sleep.before_midnight::v1",
            status: .pending,
            provenanceSummary: "Promoted from repeated long-term fields in comparative and reflective workspaces.",
            lastWriteOperation: .add,
            lastGovernanceDecision: .deferred,
            governanceReason: "Needs repeated confirmations before it becomes governed memory.",
            tierID: "warm"
        )
        let lossless = BASCandidateMemoryStoredFields(snapshot: snapshot)
        let fields = BASMemoryPersistenceApplier.candidateFields(from: snapshot)

        #expect(lossless.retrievalTags == ["Z", "a", "Z"])
        #expect(fields.retrievalTags == ["a", "z"])
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
                    source: .archive,
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
                    source: .archive,
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
