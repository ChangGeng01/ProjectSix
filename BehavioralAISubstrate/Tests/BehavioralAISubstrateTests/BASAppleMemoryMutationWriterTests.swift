import Foundation
import Testing
@testable import BASMemory
@testable import BASAppleAdapters

@Suite("BASApple Memory Mutation Writer")
struct BASAppleMemoryMutationWriterTests {
    @Test("writer mutates existing governed record with canonical stored fields")
    func writerMutatesExistingGovernedRecord() {
        final class MockGovernedRecord: BASAppleGovernedMemoryMutable {
            let basID: String
            var basTypeID: String
            var basTopic: String
            var basHeadline: String
            var basValue: String
            var basConfidence: Double
            var basPriority: Double
            var basSource: BASMemorySource
            var basLastConfirmedAt: Date
            var basDecayPolicy: BASMemoryDecayPolicy
            var basRetrievalTags: [String]
            var basEvidenceCount: Int
            var basObservationCount: Int
            var basProvenanceSummary: String
            var basLifecycleState: BASMemoryLifecycleState
            var basLastReviewedAt: Date
            var basTierID: String

            init(id: String) {
                basID = id
                basTypeID = "support"
                basTopic = "support"
                basHeadline = "Old"
                basValue = "Old"
                basConfidence = 0.4
                basPriority = 0.4
                basSource = .history
                basLastConfirmedAt = .distantPast
                basDecayPolicy = .fast
                basRetrievalTags = ["old"]
                basEvidenceCount = 1
                basObservationCount = 1
                basProvenanceSummary = "old"
                basLifecycleState = .aging
                basLastReviewedAt = .distantPast
                basTierID = "cold"
            }
        }

        let existing = MockGovernedRecord(id: "support.action.decideTomorrow")
        let updated = BASAppleMemoryMutationWriter.apply(
            BASAppleGovernedMemoryMutation(
                id: existing.basID,
                operation: .update,
                fields: BASGovernedMemoryStoredFields(
                    id: existing.basID,
                    typeID: "support",
                    topic: "action_support",
                    headline: "Putting it into Tomorrow Box often breaks the loop.",
                    value: "Decide Tomorrow",
                    confidence: 0.72,
                    priority: 0.79,
                    source: .history,
                    lastConfirmedAt: Date(timeIntervalSince1970: 1_744_156_800),
                    decayPolicy: .medium,
                    retrievalTags: ["decidetomorrow", "delay", "support", "tomorrow"],
                    evidenceCount: 3,
                    observationCount: 2,
                    provenanceSummary: "Derived from repeated successful quick-check final actions.",
                    lifecycleState: .active,
                    lastReviewedAt: Date(timeIntervalSince1970: 1_744_156_800),
                    tierID: "warm"
                )
            ),
            existing: existing,
            make: { _ in MockGovernedRecord(id: "unused") }
        )

        #expect(updated === existing)
        #expect(existing.basHeadline == "Putting it into Tomorrow Box often breaks the loop.")
        #expect(existing.basRetrievalTags == ["decidetomorrow", "delay", "support", "tomorrow"])
        #expect(existing.basLifecycleState == .active)
        #expect(existing.basTierID == "warm")
    }

    @Test("writer creates and deletes candidate records with canonical stored fields")
    func writerCreatesAndDeletesCandidateRecord() {
        final class MockCandidateRecord: BASAppleCandidateMemoryMutable {
            let basID: String
            var basTypeID: String
            var basTopic: String
            var basHeadline: String
            var basValue: String
            var basConfidence: Double
            var basPriority: Double
            var basSource: BASMemorySource
            var basFirstObservedAt: Date
            var basLastObservedAt: Date
            var basDecayPolicy: BASMemoryDecayPolicy
            var basRetrievalTags: [String]
            var basEvidenceCount: Int
            var basConfirmationCount: Int
            var basLastObservationFingerprint: String
            var basStatus: BASMemoryCandidateStatus
            var basProvenanceSummary: String
            var basLastWriteOperation: BASMemoryWriteOperation
            var basLastGovernanceDecision: BASMemoryGovernanceDecision
            var basGovernanceReason: String
            var basTierID: String

            init(fields: BASCandidateMemoryStoredFields) {
                basID = fields.id
                basTypeID = fields.typeID
                basTopic = fields.topic
                basHeadline = fields.headline
                basValue = fields.value
                basConfidence = fields.confidence
                basPriority = fields.priority
                basSource = fields.source
                basFirstObservedAt = fields.firstObservedAt
                basLastObservedAt = fields.lastObservedAt
                basDecayPolicy = fields.decayPolicy
                basRetrievalTags = fields.retrievalTags
                basEvidenceCount = fields.evidenceCount
                basConfirmationCount = fields.confirmationCount
                basLastObservationFingerprint = fields.lastObservationFingerprint
                basStatus = fields.status
                basProvenanceSummary = fields.provenanceSummary
                basLastWriteOperation = fields.lastWriteOperation
                basLastGovernanceDecision = fields.lastGovernanceDecision
                basGovernanceReason = fields.governanceReason
                basTierID = fields.tierID
            }
        }

        let fields = BASCandidateMemoryStoredFields(
            id: "goal.prepare-before-bed",
            typeID: "goal",
            topic: "night_routine",
            headline: "Preparing tomorrow the night before reduces morning drift.",
            value: "Prep at night",
            confidence: 0.81,
            priority: 0.77,
            source: .reflection,
            firstObservedAt: Date(timeIntervalSince1970: 1_744_000_000),
            lastObservedAt: Date(timeIntervalSince1970: 1_744_156_800),
            decayPolicy: .slow,
            retrievalTags: ["goal", "night", "prep"],
            evidenceCount: 4,
            confirmationCount: 2,
            lastObservationFingerprint: "goal.prepare-before-bed.fp",
            status: .promoted,
            provenanceSummary: "Repeated reflections showed calmer mornings after nightly prep.",
            lastWriteOperation: .update,
            lastGovernanceDecision: .admit,
            governanceReason: "Repeated multi-source confirmation.",
            tierID: "warm"
        )

        let created = BASAppleMemoryMutationWriter.apply(
            BASAppleCandidateMemoryMutation(
                id: fields.id,
                operation: .add,
                fields: fields
            ),
            existing: nil,
            make: MockCandidateRecord.init(fields:)
        )

        #expect(created?.basID == fields.id)
        #expect(created?.basHeadline == fields.headline)
        #expect(created?.basRetrievalTags == ["goal", "night", "prep"])
        #expect(created?.basLastGovernanceDecision == .admit)
        #expect(created?.basTierID == "warm")

        let deleted = BASAppleMemoryMutationWriter.apply(
            BASAppleCandidateMemoryMutation(
                id: fields.id,
                operation: .delete,
                fields: nil
            ),
            existing: created,
            make: MockCandidateRecord.init(fields:)
        )

        #expect(deleted == nil)
    }
}
