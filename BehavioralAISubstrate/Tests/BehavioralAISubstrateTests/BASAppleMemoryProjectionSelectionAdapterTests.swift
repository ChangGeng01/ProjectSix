import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Memory Projection Selection Adapter")
struct BASAppleMemoryProjectionSelectionAdapterTests {
    @Model
    final class SelectionGovernedFixture: BASAppleGovernedMemoryEntity {
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
            basSourceRaw = BASMemorySource.archive.rawValue
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

        static func basMake(from fields: BASGovernedMemoryStoredFields) -> SelectionGovernedFixture {
            SelectionGovernedFixture(id: fields.id, priority: fields.priority, lastConfirmedAt: fields.lastConfirmedAt)
        }

        var basSource: BASMemorySource {
            get { BASMemorySource(rawValue: basSourceRaw) ?? .archive }
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
    final class SelectionCandidateFixture: BASAppleCandidateMemoryEntity {
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
            basSourceRaw = BASMemorySource.archive.rawValue
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

        static func basMake(from fields: BASCandidateMemoryStoredFields) -> SelectionCandidateFixture {
            SelectionCandidateFixture(
                id: fields.id,
                priority: fields.priority,
                lastObservedAt: fields.lastObservedAt,
                status: fields.status,
                governanceDecision: fields.lastGovernanceDecision
            )
        }

        var basSource: BASMemorySource {
            get { BASMemorySource(rawValue: basSourceRaw) ?? .archive }
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

    @Model
    final class SelectionCheckEventFixture: BASAppleCheckEventMemoryEntity {
        @Attribute(.unique) var modelID: UUID
        var createdAt: Date
        var id: String

        init(id: String, createdAt: Date) {
            modelID = UUID()
            self.id = id
            self.createdAt = createdAt
        }

        var basCheckEventMemoryInput: BASCheckEventMemoryInput {
            BASCheckEventMemoryInput(
                id: id,
                scenarioID: "buy",
                scenarioTitle: "Impulse buy",
                actionID: "wait90s",
                actionTitle: "Wait 90 Seconds",
                note: id,
                createdAt: createdAt
            )
        }
    }

    @Model
    final class SelectionComparativeFixture: BASAppleComparativeMemoryEntity {
        @Attribute(.unique) var id: UUID
        var updatedAt: Date
        var prompt: String
        var longTerm: String

        init(prompt: String, updatedAt: Date) {
            id = UUID()
            self.prompt = prompt
            longTerm = ""
            self.updatedAt = updatedAt
        }

        var basComparativeMemoryInput: BASComparativeMemoryInput {
            BASComparativeMemoryInput(
                prompt: prompt,
                longTerm: longTerm,
                updatedAt: updatedAt
            )
        }
    }

    @Model
    final class SelectionReflectiveFixture: BASAppleReflectiveMemoryEntity {
        @Attribute(.unique) var id: UUID
        var updatedAt: Date
        var prompt: String
        var longTerm: String

        init(prompt: String, updatedAt: Date) {
            id = UUID()
            self.prompt = prompt
            longTerm = ""
            self.updatedAt = updatedAt
        }

        var basReflectiveMemoryInput: BASReflectiveMemoryInput {
            BASReflectiveMemoryInput(
                prompt: prompt,
                longTerm: longTerm,
                updatedAt: updatedAt
            )
        }
    }

    @Test("governance snapshot counts candidate status and governance categories")
    func governanceSnapshotCountsStatuses() throws {
        let context = try makeContext()
        context.insert(SelectionGovernedFixture(id: "record-1", priority: 0.8, lastConfirmedAt: .now))
        context.insert(SelectionGovernedFixture(id: "record-2", priority: 0.6, lastConfirmedAt: .now.addingTimeInterval(-10)))
        context.insert(SelectionCandidateFixture(id: "pending-a", priority: 0.9, lastObservedAt: .now, status: .pending, governanceDecision: .deferred))
        context.insert(SelectionCandidateFixture(id: "pending-b", priority: 0.7, lastObservedAt: .now.addingTimeInterval(-10), status: .pending, governanceDecision: .admit))
        context.insert(SelectionCandidateFixture(id: "promoted-a", priority: 0.5, lastObservedAt: .now.addingTimeInterval(-20), status: .promoted, governanceDecision: .admit))
        try context.save()

        let snapshot = BASAppleMemoryProjectionSelectionAdapter.governanceSnapshot(
            in: context,
            recordType: SelectionGovernedFixture.self,
            candidateType: SelectionCandidateFixture.self
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
        context.insert(SelectionGovernedFixture(id: "record-c", priority: 0.5, lastConfirmedAt: now))
        context.insert(SelectionGovernedFixture(id: "record-a", priority: 0.9, lastConfirmedAt: now.addingTimeInterval(-20)))
        context.insert(SelectionGovernedFixture(id: "record-b", priority: 0.9, lastConfirmedAt: now.addingTimeInterval(-10)))
        context.insert(SelectionCandidateFixture(id: "candidate-b", priority: 0.8, lastObservedAt: now.addingTimeInterval(-10), status: .pending, governanceDecision: .deferred))
        context.insert(SelectionCandidateFixture(id: "candidate-a", priority: 0.8, lastObservedAt: now, status: .pending, governanceDecision: .admit))
        context.insert(SelectionCandidateFixture(id: "candidate-z", priority: 0.95, lastObservedAt: now, status: .promoted, governanceDecision: .admit))
        try context.save()

        let records = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
            in: context,
            recordType: SelectionGovernedFixture.self,
            limit: 2
        )
        let candidates = BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
            in: context,
            candidateType: SelectionCandidateFixture.self
        )

        #expect(records.map(\.basID) == ["record-b", "record-a"])
        #expect(candidates.map(\.basID) == ["candidate-a", "candidate-b"])
    }

    @Test("generic temporal fetch keeps newest-first canonical ordering across host-defined sources")
    func eventAndWorkspaceFetchAdaptersPreserveOrdering() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let context = try makeContext()
        context.insert(SelectionCheckEventFixture(id: "check-b", createdAt: now.addingTimeInterval(-10)))
        context.insert(SelectionCheckEventFixture(id: "check-a", createdAt: now))
        context.insert(SelectionComparativeFixture(prompt: "comparative-b", updatedAt: now.addingTimeInterval(-10)))
        context.insert(SelectionComparativeFixture(prompt: "comparative-a", updatedAt: now))
        context.insert(SelectionReflectiveFixture(prompt: "reflective-b", updatedAt: now.addingTimeInterval(-10)))
        context.insert(SelectionReflectiveFixture(prompt: "reflective-a", updatedAt: now))
        try context.save()

        let checks = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionCheckEvents(
            in: context,
            eventType: SelectionCheckEventFixture.self
        )
        let comparativeRecords = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionComparativeRecords(
            in: context,
            comparativeType: SelectionComparativeFixture.self
        )
        let reflectiveRecords = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionReflectiveRecords(
            in: context,
            reflectiveType: SelectionReflectiveFixture.self
        )
        let genericChecks = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionTemporalEntries(
            in: context,
            entryType: SelectionCheckEventFixture.self,
            timestamp: { $0.basCheckEventMemoryInput.createdAt },
            stableID: { $0.basCheckEventMemoryInput.id }
        )
        let genericBalances = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionTemporalEntries(
            in: context,
            entryType: SelectionComparativeFixture.self,
            timestamp: { $0.basComparativeMemoryInput.updatedAt }
        )
        let genericMirrors = BASAppleMemoryProjectionSelectionAdapter.fetchProjectionTemporalEntries(
            in: context,
            entryType: SelectionReflectiveFixture.self,
            timestamp: { $0.basReflectiveMemoryInput.updatedAt }
        )

        #expect(checks.map(\.id) == ["check-a", "check-b"])
        #expect(comparativeRecords.map(\.prompt) == ["comparative-a", "comparative-b"])
        #expect(reflectiveRecords.map(\.prompt) == ["reflective-a", "reflective-b"])
        #expect(genericChecks.map(\.id) == ["check-a", "check-b"])
        #expect(genericBalances.map(\.prompt) == ["comparative-a", "comparative-b"])
        #expect(genericMirrors.map(\.prompt) == ["reflective-a", "reflective-b"])
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            SelectionGovernedFixture.self,
            SelectionCandidateFixture.self,
            SelectionCheckEventFixture.self,
            SelectionComparativeFixture.self,
            SelectionReflectiveFixture.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
