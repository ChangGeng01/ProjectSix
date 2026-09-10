import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory

@Suite("BASApple Memory Projection Refresh Adapter")
struct BASAppleMemoryProjectionRefreshAdapterTests {
    @Model
    final class RefreshGovernedFixture: BASAppleGovernedMemoryEntity {
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

        init(
            basID: String,
            basTypeID: String,
            basTopic: String,
            basHeadline: String,
            basValue: String,
            basConfidence: Double,
            basPriority: Double,
            basSource: BASMemorySource,
            basLastConfirmedAt: Date,
            basDecayPolicy: BASMemoryDecayPolicy,
            basRetrievalTags: [String],
            basEvidenceCount: Int,
            basObservationCount: Int,
            basProvenanceSummary: String,
            basLifecycleState: BASMemoryLifecycleState,
            basLastReviewedAt: Date,
            basTierID: String
        ) {
            self.basID = basID
            self.basTypeID = basTypeID
            self.basTopic = basTopic
            self.basHeadline = basHeadline
            self.basValue = basValue
            self.basConfidence = basConfidence
            self.basPriority = basPriority
            self.basSourceRaw = basSource.rawValue
            self.basLastConfirmedAt = basLastConfirmedAt
            self.basDecayPolicyRaw = basDecayPolicy.rawValue
            self.basRetrievalTags = basRetrievalTags
            self.basEvidenceCount = basEvidenceCount
            self.basObservationCount = basObservationCount
            self.basProvenanceSummary = basProvenanceSummary
            self.basLifecycleStateRaw = basLifecycleState.rawValue
            self.basLastReviewedAt = basLastReviewedAt
            self.basTierID = basTierID
        }

        static func basMake(from fields: BASGovernedMemoryStoredFields) -> RefreshGovernedFixture {
            RefreshGovernedFixture(
                basID: fields.id,
                basTypeID: fields.typeID,
                basTopic: fields.topic,
                basHeadline: fields.headline,
                basValue: fields.value,
                basConfidence: fields.confidence,
                basPriority: fields.priority,
                basSource: fields.source,
                basLastConfirmedAt: fields.lastConfirmedAt,
                basDecayPolicy: fields.decayPolicy,
                basRetrievalTags: fields.retrievalTags,
                basEvidenceCount: fields.evidenceCount,
                basObservationCount: fields.observationCount,
                basProvenanceSummary: fields.provenanceSummary,
                basLifecycleState: fields.lifecycleState,
                basLastReviewedAt: fields.lastReviewedAt,
                basTierID: fields.tierID
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
    final class RefreshCandidateFixture: BASAppleCandidateMemoryEntity {
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
            basID: String,
            basTypeID: String,
            basTopic: String,
            basHeadline: String,
            basValue: String,
            basConfidence: Double,
            basPriority: Double,
            basSource: BASMemorySource,
            basFirstObservedAt: Date,
            basLastObservedAt: Date,
            basDecayPolicy: BASMemoryDecayPolicy,
            basRetrievalTags: [String],
            basEvidenceCount: Int,
            basConfirmationCount: Int,
            basLastObservationFingerprint: String,
            basStatus: BASMemoryCandidateStatus,
            basProvenanceSummary: String,
            basLastWriteOperation: BASMemoryWriteOperation,
            basLastGovernanceDecision: BASMemoryGovernanceDecision,
            basGovernanceReason: String,
            basTierID: String
        ) {
            self.basID = basID
            self.basTypeID = basTypeID
            self.basTopic = basTopic
            self.basHeadline = basHeadline
            self.basValue = basValue
            self.basConfidence = basConfidence
            self.basPriority = basPriority
            self.basSourceRaw = basSource.rawValue
            self.basFirstObservedAt = basFirstObservedAt
            self.basLastObservedAt = basLastObservedAt
            self.basDecayPolicyRaw = basDecayPolicy.rawValue
            self.basRetrievalTags = basRetrievalTags
            self.basEvidenceCount = basEvidenceCount
            self.basConfirmationCount = basConfirmationCount
            self.basLastObservationFingerprint = basLastObservationFingerprint
            self.basStatusRaw = basStatus.rawValue
            self.basProvenanceSummary = basProvenanceSummary
            self.basLastWriteOperationRaw = basLastWriteOperation.rawValue
            self.basLastGovernanceDecisionRaw = basLastGovernanceDecision.rawValue
            self.basGovernanceReason = basGovernanceReason
            self.basTierID = basTierID
        }

        static func basMake(from fields: BASCandidateMemoryStoredFields) -> RefreshCandidateFixture {
            RefreshCandidateFixture(
                basID: fields.id,
                basTypeID: fields.typeID,
                basTopic: fields.topic,
                basHeadline: fields.headline,
                basValue: fields.value,
                basConfidence: fields.confidence,
                basPriority: fields.priority,
                basSource: fields.source,
                basFirstObservedAt: fields.firstObservedAt,
                basLastObservedAt: fields.lastObservedAt,
                basDecayPolicy: fields.decayPolicy,
                basRetrievalTags: fields.retrievalTags,
                basEvidenceCount: fields.evidenceCount,
                basConfirmationCount: fields.confirmationCount,
                basLastObservationFingerprint: fields.lastObservationFingerprint,
                basStatus: fields.status,
                basProvenanceSummary: fields.provenanceSummary,
                basLastWriteOperation: fields.lastWriteOperation,
                basLastGovernanceDecision: fields.lastGovernanceDecision,
                basGovernanceReason: fields.governanceReason,
                basTierID: fields.tierID
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
    final class RefreshCueFixture: BASAppleCueMemoryEntity {
        @Attribute(.unique) var id: UUID
        var content: String
        var lastUsedAt: Date

        init(content: String, lastUsedAt: Date) {
            self.id = UUID()
            self.content = content
            self.lastUsedAt = lastUsedAt
        }

        var basCueMemoryInput: BASCueMemoryInput {
            BASCueMemoryInput(content: content, lastUsedAt: lastUsedAt)
        }
    }

    @Model
    final class RefreshCheckEventFixture: BASAppleCheckEventMemoryEntity, BASAppleProjectionEventSource {
        @Attribute(.unique) var id: String
        var scenarioID: String
        var scenarioTitle: String
        var actionID: String
        var actionTitle: String
        var note: String
        var createdAt: Date

        init(
            id: String,
            scenarioID: String,
            scenarioTitle: String,
            actionID: String,
            actionTitle: String,
            note: String,
            createdAt: Date
        ) {
            self.id = id
            self.scenarioID = scenarioID
            self.scenarioTitle = scenarioTitle
            self.actionID = actionID
            self.actionTitle = actionTitle
            self.note = note
            self.createdAt = createdAt
        }

        var basCheckEventMemoryInput: BASCheckEventMemoryInput {
            BASCheckEventMemoryInput(
                id: id,
                scenarioID: scenarioID,
                scenarioTitle: scenarioTitle,
                actionID: actionID,
                actionTitle: actionTitle,
                note: note,
                createdAt: createdAt
            )
        }

        var basProjectionEventInput: BASProjectionEventInput {
            BASProjectionEventInput(
                id: id,
                note: note,
                fallbackContent: scenarioTitle,
                createdAt: createdAt,
                scenarioID: scenarioID,
                actionID: actionID,
                reflectionOutcomeID: nil,
                entrySourceID: "app"
            )
        }
    }

    @Model
    final class RefreshComparativeFixture: BASAppleComparativeMemoryEntity {
        @Attribute(.unique) var id: UUID
        var prompt: String
        var longTerm: String
        var updatedAt: Date

        init(prompt: String, longTerm: String, updatedAt: Date) {
            self.id = UUID()
            self.prompt = prompt
            self.longTerm = longTerm
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
    final class RefreshReflectiveFixture: BASAppleReflectiveMemoryEntity {
        @Attribute(.unique) var id: UUID
        var prompt: String
        var longTerm: String
        var updatedAt: Date

        init(prompt: String, longTerm: String, updatedAt: Date) {
            self.id = UUID()
            self.prompt = prompt
            self.longTerm = longTerm
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

    @Test("refresh projection hydrates stored memories when governance is empty")
    func refreshProjectionHydratesStoredMemoriesWhenGovernanceIsEmpty() throws {
        let now = Date(timeIntervalSince1970: 1_744_200_000)
        let container = try makeContainer()
        let context = ModelContext(container)
        seedHistory(into: context, now: now)
        try context.save()

        var rebuildCall: (Int, Int, Int, Int, Int)?
        let refreshed = try BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            recordType: RefreshGovernedFixture.self,
            candidateType: RefreshCandidateFixture.self,
            cueType: RefreshCueFixture.self,
            checkEventType: RefreshCheckEventFixture.self,
            comparativeRecordType: RefreshComparativeFixture.self,
            reflectiveRecordType: RefreshReflectiveFixture.self,
            rebuildEmbeddings: { records, candidates, checkEvents, comparativeRecords, reflectiveRecords in
                rebuildCall = (
                    records.count,
                    candidates.count,
                    checkEvents.count,
                    comparativeRecords.count,
                    reflectiveRecords.count
                )
            }
        )

        #expect(refreshed.governanceSnapshot.totalRecordCount > 0)
        #expect(refreshed.diagnostics.recordCount > 0)
        #expect(refreshed.baseProjection.records.count == refreshed.diagnostics.recordCount)
        #expect(refreshed.baseProjection.recentEvents.count == 1)
        #expect(rebuildCall?.0 == refreshed.diagnostics.recordCount)
        #expect(rebuildCall?.2 == 1)
    }

    @Test("refresh projection reuses existing governed projection when governance is already populated")
    func refreshProjectionReusesExistingGovernedProjectionWhenPopulated() throws {
        let now = Date(timeIntervalSince1970: 1_744_200_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(
            RefreshGovernedFixture(
                basID: "profile.concise",
                basTypeID: "profile",
                basTopic: "communication",
                basHeadline: "Keep it short.",
                basValue: "Short, direct language lands better.",
                basConfidence: 0.9,
                basPriority: 0.9,
                basSource: .pattern,
                basLastConfirmedAt: now,
                basDecayPolicy: .slow,
                basRetrievalTags: ["profile"],
                basEvidenceCount: 2,
                basObservationCount: 2,
                basProvenanceSummary: "Existing governed memory.",
                basLifecycleState: .active,
                basLastReviewedAt: now,
                basTierID: "warm"
            )
        )
        seedHistory(into: context, now: now)
        try context.save()

        let refreshed = try BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            recordType: RefreshGovernedFixture.self,
            candidateType: RefreshCandidateFixture.self,
            cueType: RefreshCueFixture.self,
            checkEventType: RefreshCheckEventFixture.self,
            comparativeRecordType: RefreshComparativeFixture.self,
            reflectiveRecordType: RefreshReflectiveFixture.self,
            rebuildEmbeddings: { _, _, _, _, _ in }
        )

        let storedRecords = try context.fetch(FetchDescriptor<RefreshGovernedFixture>())
        #expect(storedRecords.count == 1)
        #expect(refreshed.diagnostics.recordCount == 1)
        #expect(refreshed.baseProjection.records.count == 1)
        #expect(refreshed.baseProjection.records.first?.content == "Keep it short.")
    }

    @Test("reconciliation does not return success when a real read-only store rejects its save")
    func reconciliationDoesNotReturnSuccessWhenReadOnlyStoreRejectsSave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-memory-read-only-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Failed to remove read-only governed-memory fixture directory: \(error)")
            }
        }

        let storeURL = directory.appendingPathComponent("memory.store")
        let schema = Schema([RefreshGovernedFixture.self, RefreshCandidateFixture.self])
        let seed = RefreshGovernedFixture(
            basID: "seed",
            basTypeID: "profile",
            basTopic: "seed",
            basHeadline: "Seed",
            basValue: "Committed seed",
            basConfidence: 0.8,
            basPriority: 0.8,
            basSource: .archive,
            basLastConfirmedAt: Date(timeIntervalSince1970: 1_744_200_000),
            basDecayPolicy: .slow,
            basRetrievalTags: ["seed"],
            basEvidenceCount: 2,
            basObservationCount: 2,
            basProvenanceSummary: "Committed before reopening read-only.",
            basLifecycleState: .active,
            basLastReviewedAt: Date(timeIntervalSince1970: 1_744_200_000),
            basTierID: "warm"
        )

        do {
            let writable = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [writable])
            let context = ModelContext(container)
            context.insert(seed)
            try context.save()
        }

        let reviewNow = Date(timeIntervalSince1970: 1_744_286_400)
        var result: BASAppleMemoryReconciliationWriteResult?
        var saveError: Error?
        do {
            let readOnly = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [readOnly])
            let caller = ModelContext(container)
            do {
                result = try BASAppleMemoryReconciliationWriter.reconcile(
                    BASAppleMemoryPersistenceRequest(
                        drafts: [
                            BASDerivedMemoryDraft(
                                id: "must-not-persist",
                                typeID: "goal",
                                topic: "strict-write",
                                headline: "Must not return success",
                                value: "A rejected save is not a successful reconciliation.",
                                confidence: 0.9,
                                priority: 0.9,
                                sourceID: BASMemorySource.archive.rawValue,
                                lastConfirmedAt: reviewNow,
                                decayPolicyID: BASMemoryDecayPolicy.medium.rawValue,
                                retrievalTags: ["strict-write"],
                                evidenceCount: 2,
                                provenanceSummary: "Real read-only SwiftData save failure fixture.",
                                promotionPolicy: .immediate
                            )
                        ],
                        existingRecords: [],
                        existingCandidates: [],
                        reviewNow: reviewNow
                    ),
                    recordType: RefreshGovernedFixture.self,
                    candidateType: RefreshCandidateFixture.self,
                    in: caller
                )
            } catch {
                saveError = error
            }
        }

        #expect(saveError != nil)
        #expect(result == nil)

        let writable = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let reopened = try ModelContainer(for: schema, configurations: [writable])
        let storedRecords = try ModelContext(reopened).fetch(FetchDescriptor<RefreshGovernedFixture>())
        #expect(storedRecords.map(\.basID) == ["seed"])
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: RefreshGovernedFixture.self,
            RefreshCandidateFixture.self,
            RefreshCueFixture.self,
            RefreshCheckEventFixture.self,
            RefreshComparativeFixture.self,
            RefreshReflectiveFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func seedHistory(into context: ModelContext, now: Date) {
        context.insert(
            RefreshCueFixture(
                content: "Sleep on it.",
                lastUsedAt: now.addingTimeInterval(-3_600)
            )
        )
        context.insert(
            RefreshCheckEventFixture(
                id: "event-1",
                scenarioID: "buy",
                scenarioTitle: "Buy",
                actionID: "decide_tomorrow",
                actionTitle: "Decide Tomorrow",
                note: "I should wait until morning before buying it.",
                createdAt: now.addingTimeInterval(-900)
            )
        )
        context.insert(
            RefreshComparativeFixture(
                prompt: "Should I buy this tonight?",
                longTerm: "Tomorrow usually feels clearer.",
                updatedAt: now.addingTimeInterval(-600)
            )
        )
        context.insert(
            RefreshReflectiveFixture(
                prompt: "Why does this feel urgent now?",
                longTerm: "Nighttime urgency usually passes.",
                updatedAt: now.addingTimeInterval(-300)
            )
        )
    }

    private func governanceSnapshot(in context: ModelContext) -> BASAppleProjectionGovernanceSnapshot {
        let records = (try? context.fetch(FetchDescriptor<RefreshGovernedFixture>())) ?? []
        let candidates = (try? context.fetch(FetchDescriptor<RefreshCandidateFixture>())) ?? []
        return BASAppleProjectionGovernanceSnapshot(
            totalRecordCount: records.count,
            totalCandidateCount: candidates.count,
            pendingCandidateCount: candidates.filter { $0.basStatus == .pending }.count,
            promotedCandidateCount: candidates.filter { $0.basStatus == .promoted }.count,
            deferredCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .deferred }.count,
            admittedCandidateCount: candidates.filter { $0.basLastGovernanceDecision == .admit }.count
        )
    }

    private func fetchRecords(
        in context: ModelContext,
        limit: Int
    ) -> [RefreshGovernedFixture] {
        var descriptor = FetchDescriptor<RefreshGovernedFixture>(
            sortBy: [
                SortDescriptor(\.basPriority, order: .reverse),
                SortDescriptor(\.basLastConfirmedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCandidates(
        in context: ModelContext,
        limit: Int
    ) -> [RefreshCandidateFixture] {
        var descriptor = FetchDescriptor<RefreshCandidateFixture>(
            sortBy: [
                SortDescriptor(\.basPriority, order: .reverse),
                SortDescriptor(\.basLastObservedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCheckEvents(
        in context: ModelContext,
        limit: Int
    ) -> [RefreshCheckEventFixture] {
        var descriptor = FetchDescriptor<RefreshCheckEventFixture>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchComparativeRecords(
        in context: ModelContext,
        limit: Int
    ) -> [RefreshComparativeFixture] {
        var descriptor = FetchDescriptor<RefreshComparativeFixture>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchReflectiveRecords(
        in context: ModelContext,
        limit: Int
    ) -> [RefreshReflectiveFixture] {
        var descriptor = FetchDescriptor<RefreshReflectiveFixture>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
