import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Memory Projection Selection Adapter")
struct BASAppleMemoryProjectionSelectionAdapterTests {
    @Model
    final class GovernedFixture: BASAppleGovernedMemoryEntity {
        @Attribute(.unique) var basID: String
        var basTypeID: String
        var basTopic: String
        var basHeadline: String
        var basValue: String
        var basConfidence: Double
        var basPriority: Double
        var basSourceRaw: String
        var basLastConfirmedAt: Date
        var basDecayPolicyRaw: String
        var basRetrievalTags: [String]
        var basEvidenceCount: Int
        var basObservationCount: Int
        var basProvenanceSummary: String
        var basLifecycleStateRaw: String
        var basLastReviewedAt: Date
        var basTierID: String

        init(id: String, priority: Double, lastConfirmedAt: Date) {
            basID = id
            basTypeID = "semantic"
            basTopic = id
            basHeadline = id
            basValue = id
            basConfidence = 0.9
            basPriority = priority
            basSourceRaw = BASMemorySource.history.rawValue
            basLastConfirmedAt = lastConfirmedAt
            basDecayPolicyRaw = BASMemoryDecayPolicy.medium.rawValue
            basRetrievalTags = [id]
            basEvidenceCount = 1
            basObservationCount = 1
            basProvenanceSummary = id
            basLifecycleStateRaw = BASMemoryLifecycleState.active.rawValue
            basLastReviewedAt = lastConfirmedAt
            basTierID = "warm"
        }

        static func basMake(from fields: BASGovernedMemoryStoredFields) -> GovernedFixture {
            GovernedFixture(id: fields.id, priority: fields.priority, lastConfirmedAt: fields.lastConfirmedAt)
        }

        var basSource: BASMemorySource {
            get { BASMemorySource(rawValue: basSourceRaw) ?? .history }
            set { basSourceRaw = newValue.rawValue }
        }

        var basDecayPolicy: BASMemoryDecayPolicy {
            get { BASMemoryDecayPolicy(rawValue: basDecayPolicyRaw) ?? .medium }
            set { basDecayPolicyRaw = newValue.rawValue }
        }

        var basLifecycleState: BASMemoryLifecycleState {
            get { BASMemoryLifecycleState(rawValue: basLifecycleStateRaw) ?? .active }
            set { basLifecycleStateRaw = newValue.rawValue }
        }

        var basSnapshot: BASExistingGovernedMemorySnapshot {
            BASExistingGovernedMemorySnapshot(
                id: basID,
                typeID: basTypeID,
                topic: basTopic,
                headline: basHeadline,
                value: basValue,
                confidence: basConfidence,
                priority: basPriority,
                source: basSource,
                lastConfirmedAt: basLastConfirmedAt,
                decayPolicy: basDecayPolicy,
                retrievalTags: basRetrievalTags,
                evidenceCount: basEvidenceCount,
                observationCount: basObservationCount,
                provenanceSummary: basProvenanceSummary,
                lifecycleState: basLifecycleState,
                lastReviewedAt: basLastReviewedAt,
                tierID: basTierID
            )
        }
    }

    @Model
    final class CandidateFixture: BASAppleCandidateMemoryEntity {
        @Attribute(.unique) var basID: String
        var basTypeID: String
        var basTopic: String
        var basHeadline: String
        var basValue: String
        var basConfidence: Double
        var basPriority: Double
        var basSourceRaw: String
        var basFirstObservedAt: Date
        var basLastObservedAt: Date
        var basDecayPolicyRaw: String
        var basRetrievalTags: [String]
        var basEvidenceCount: Int
        var basConfirmationCount: Int
        var basLastObservationFingerprint: String
        var basStatusRaw: String
        var basProvenanceSummary: String
        var basLastWriteOperationRaw: String
        var basLastGovernanceDecisionRaw: String
        var basGovernanceReason: String
        var basTierID: String

        init(
            id: String,
            priority: Double,
            lastObservedAt: Date,
            status: BASMemoryCandidateStatus,
            governanceDecision: BASMemoryGovernanceDecision
        ) {
            basID = id
            basTypeID = "semantic"
            basTopic = id
            basHeadline = id
            basValue = id
            basConfidence = 0.7
            basPriority = priority
            basSourceRaw = BASMemorySource.history.rawValue
            basFirstObservedAt = lastObservedAt.addingTimeInterval(-60)
            basLastObservedAt = lastObservedAt
            basDecayPolicyRaw = BASMemoryDecayPolicy.medium.rawValue
            basRetrievalTags = [id]
            basEvidenceCount = 1
            basConfirmationCount = 0
            basLastObservationFingerprint = id
            basStatusRaw = status.rawValue
            basProvenanceSummary = id
            basLastWriteOperationRaw = BASMemoryWriteOperation.add.rawValue
            basLastGovernanceDecisionRaw = governanceDecision.rawValue
            basGovernanceReason = governanceDecision.rawValue
            basTierID = "warm"
        }

        static func basMake(from fields: BASCandidateMemoryStoredFields) -> CandidateFixture {
            CandidateFixture(
                id: fields.id,
                priority: fields.priority,
                lastObservedAt: fields.lastObservedAt,
                status: fields.status,
                governanceDecision: fields.lastGovernanceDecision
            )
        }

        var basSource: BASMemorySource {
            get { BASMemorySource(rawValue: basSourceRaw) ?? .history }
            set { basSourceRaw = newValue.rawValue }
        }

        var basDecayPolicy: BASMemoryDecayPolicy {
            get { BASMemoryDecayPolicy(rawValue: basDecayPolicyRaw) ?? .medium }
            set { basDecayPolicyRaw = newValue.rawValue }
        }

        var basStatus: BASMemoryCandidateStatus {
            get { BASMemoryCandidateStatus(rawValue: basStatusRaw) ?? .pending }
            set { basStatusRaw = newValue.rawValue }
        }

        var basLastWriteOperation: BASMemoryWriteOperation {
            get { BASMemoryWriteOperation(rawValue: basLastWriteOperationRaw) ?? .noop }
            set { basLastWriteOperationRaw = newValue.rawValue }
        }

        var basLastGovernanceDecision: BASMemoryGovernanceDecision {
            get { BASMemoryGovernanceDecision(rawValue: basLastGovernanceDecisionRaw) ?? .deferred }
            set { basLastGovernanceDecisionRaw = newValue.rawValue }
        }

        var basSnapshot: BASExistingCandidateMemorySnapshot {
            BASExistingCandidateMemorySnapshot(
                id: basID,
                typeID: basTypeID,
                topic: basTopic,
                headline: basHeadline,
                value: basValue,
                confidence: basConfidence,
                priority: basPriority,
                source: basSource,
                firstObservedAt: basFirstObservedAt,
                lastObservedAt: basLastObservedAt,
                decayPolicy: basDecayPolicy,
                retrievalTags: basRetrievalTags,
                evidenceCount: basEvidenceCount,
                confirmationCount: basConfirmationCount,
                lastObservationFingerprint: basLastObservationFingerprint,
                status: basStatus,
                provenanceSummary: basProvenanceSummary,
                lastWriteOperation: basLastWriteOperation,
                lastGovernanceDecision: basLastGovernanceDecision,
                governanceReason: basGovernanceReason,
                tierID: basTierID
            )
        }
    }

    @Test("governance snapshot counts candidate status and governance categories")
    func governanceSnapshotCountsStatuses() throws {
        let context = try makeContext()
        context.insert(GovernedFixture(id: "record-1", priority: 0.8, lastConfirmedAt: .now))
        context.insert(GovernedFixture(id: "record-2", priority: 0.6, lastConfirmedAt: .now.addingTimeInterval(-10)))
        context.insert(CandidateFixture(id: "pending-a", priority: 0.9, lastObservedAt: .now, status: .pending, governanceDecision: .deferred))
        context.insert(CandidateFixture(id: "pending-b", priority: 0.7, lastObservedAt: .now.addingTimeInterval(-10), status: .pending, governanceDecision: .admit))
        context.insert(CandidateFixture(id: "promoted-a", priority: 0.5, lastObservedAt: .now.addingTimeInterval(-20), status: .promoted, governanceDecision: .admit))
        try context.save()

        let snapshot = BASAppleMemoryProjectionSelectionAdapter.governanceSnapshot(
            in: context,
            recordType: GovernedFixture.self,
            candidateType: CandidateFixture.self
        )

        #expect(snapshot.totalRecordCount == 2)
        #expect(snapshot.totalCandidateCount == 3)
        #expect(snapshot.pendingCandidateCount == 2)
        #expect(snapshot.promotedCandidateCount == 1)
        #expect(snapshot.deferredCandidateCount == 1)
        #expect(snapshot.admittedCandidateCount == 2)
    }

    @Test("projection fetch adapters keep canonical record ordering and pending-only candidate ordering")
    func fetchAdaptersPreserveCanonicalProjectionOrdering() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let context = try makeContext()
        context.insert(GovernedFixture(id: "record-c", priority: 0.5, lastConfirmedAt: now))
        context.insert(GovernedFixture(id: "record-a", priority: 0.9, lastConfirmedAt: now.addingTimeInterval(-20)))
        context.insert(GovernedFixture(id: "record-b", priority: 0.9, lastConfirmedAt: now.addingTimeInterval(-10)))
        context.insert(CandidateFixture(id: "candidate-b", priority: 0.8, lastObservedAt: now.addingTimeInterval(-10), status: .pending, governanceDecision: .deferred))
        context.insert(CandidateFixture(id: "candidate-a", priority: 0.8, lastObservedAt: now, status: .pending, governanceDecision: .admit))
        context.insert(CandidateFixture(id: "candidate-z", priority: 0.95, lastObservedAt: now, status: .promoted, governanceDecision: .admit))
        try context.save()

        let records = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
            in: context,
            recordType: GovernedFixture.self,
            limit: 2
        )
        let candidates = BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
            in: context,
            candidateType: CandidateFixture.self
        )

        #expect(records.map(\.basID) == ["record-b", "record-a"])
        #expect(candidates.map(\.basID) == ["candidate-a", "candidate-b"])
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            GovernedFixture.self,
            CandidateFixture.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
