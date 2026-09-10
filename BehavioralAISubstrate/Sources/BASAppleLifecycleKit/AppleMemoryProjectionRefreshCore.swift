import Foundation
import SwiftData
import BASMemory

public struct BASAppleMemoryProjectionRefreshLimits: Codable, Equatable, Sendable {
    public static let `default` = BASAppleMemoryProjectionRefreshLimits()

    public var recordLimit: Int
    public var candidateLimit: Int
    public var checkEventLimit: Int
    public var comparativeRecordLimit: Int
    public var reflectiveRecordLimit: Int

    private enum CodingKeys: String, CodingKey {
        case recordLimit
        case candidateLimit
        case checkEventLimit
        case comparativeRecordLimit
        case reflectiveRecordLimit
    }

    public init(
        recordLimit: Int = 72,
        candidateLimit: Int = 32,
        checkEventLimit: Int = 96,
        comparativeRecordLimit: Int = 36,
        reflectiveRecordLimit: Int = 36
    ) {
        self.recordLimit = recordLimit
        self.candidateLimit = candidateLimit
        self.checkEventLimit = checkEventLimit
        self.comparativeRecordLimit = comparativeRecordLimit
        self.reflectiveRecordLimit = reflectiveRecordLimit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordLimit = try container.decodeIfPresent(Int.self, forKey: .recordLimit) ?? 72
        candidateLimit = try container.decodeIfPresent(Int.self, forKey: .candidateLimit) ?? 32
        checkEventLimit = try container.decodeIfPresent(Int.self, forKey: .checkEventLimit) ?? 96
        comparativeRecordLimit = try container.decodeIfPresent(Int.self, forKey: .comparativeRecordLimit) ?? 36
        reflectiveRecordLimit = try container.decodeIfPresent(Int.self, forKey: .reflectiveRecordLimit) ?? 36
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordLimit, forKey: .recordLimit)
        try container.encode(candidateLimit, forKey: .candidateLimit)
        try container.encode(checkEventLimit, forKey: .checkEventLimit)
        try container.encode(comparativeRecordLimit, forKey: .comparativeRecordLimit)
        try container.encode(reflectiveRecordLimit, forKey: .reflectiveRecordLimit)
    }
}

public struct BASAppleMemoryProjectionDiagnostics: Codable, Equatable, Sendable {
    public let recordCount: Int
    public let candidateCount: Int
    public let allCandidatesPending: Bool

    public init(recordCount: Int, candidateCount: Int, allCandidatesPending: Bool) {
        self.recordCount = recordCount
        self.candidateCount = candidateCount
        self.allCandidatesPending = allCandidatesPending
    }
}

public struct BASAppleMemoryProjectionRefreshResult: Codable, Equatable, Sendable {
    public let baseProjection: BASBrainProjection
    public let governanceSnapshot: BASAppleProjectionGovernanceSnapshot
    public let diagnostics: BASAppleMemoryProjectionDiagnostics
    public let refreshedAt: Date

    public init(
        baseProjection: BASBrainProjection,
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot,
        diagnostics: BASAppleMemoryProjectionDiagnostics,
        refreshedAt: Date
    ) {
        self.baseProjection = baseProjection
        self.governanceSnapshot = governanceSnapshot
        self.diagnostics = diagnostics
        self.refreshedAt = refreshedAt
    }
}

public struct BASAppleMemoryProjectionInputs: Sendable {
    public let records: [BASGovernedMemoryStoredFields]
    public let candidates: [BASCandidateMemoryStoredFields]
    public let checkEvents: [BASCheckEventMemoryInput]
    public let projectionEvents: [BASProjectionEventInput]
    public let comparativeRecords: [BASComparativeMemoryInput]
    public let reflectiveRecords: [BASReflectiveMemoryInput]
    public let governanceSnapshot: BASAppleProjectionGovernanceSnapshot
    public let reconciliation: BASAppleMemoryReconciliationWriteResult?

    public init(
        records: [BASGovernedMemoryStoredFields],
        candidates: [BASCandidateMemoryStoredFields],
        checkEvents: [BASCheckEventMemoryInput],
        projectionEvents: [BASProjectionEventInput],
        comparativeRecords: [BASComparativeMemoryInput],
        reflectiveRecords: [BASReflectiveMemoryInput],
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot,
        reconciliation: BASAppleMemoryReconciliationWriteResult?
    ) {
        self.records = records
        self.candidates = candidates
        self.checkEvents = checkEvents
        self.projectionEvents = projectionEvents
        self.comparativeRecords = comparativeRecords
        self.reflectiveRecords = reflectiveRecords
        self.governanceSnapshot = governanceSnapshot
        self.reconciliation = reconciliation
    }
}

public enum BASAppleMemoryProjectionPersistenceDisposition: Sendable {
    case readOnlyProjection
    case reconciliationEvaluatedNoWrite(BASAppleMemoryReconciliationWriteResult)
    case committedReconciliation(BASAppleMemoryReconciliationWriteResult)
}

public enum BASAppleMemoryProjectionPublicationStage: Sendable {
    case embeddingRebuild
}

public enum BASAppleMemoryProjectionRefreshError: Error {
    case publicationFailed(
        disposition: BASAppleMemoryProjectionPersistenceDisposition,
        stage: BASAppleMemoryProjectionPublicationStage,
        underlying: Error
    )
}

private struct BASAppleProjectionEventValues: Sendable {
    let memory: BASCheckEventMemoryInput
    let projection: BASProjectionEventInput
}

public enum BASAppleMemoryProjectionRefreshAdapter {
    public static func refreshProjection<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted,
        rebuildEmbeddings: (
            _ records: [BASGovernedMemoryStoredFields],
            _ candidates: [BASCandidateMemoryStoredFields],
            _ checkEvents: [BASCheckEventMemoryInput],
            _ comparativeRecords: [BASComparativeMemoryInput],
            _ reflectiveRecords: [BASReflectiveMemoryInput]
        ) throws -> Void
    ) throws -> BASAppleMemoryProjectionRefreshResult {
        try refreshProjection(
            in: context,
            now: now,
            limits: limits,
            recordType: recordType,
            candidateType: candidateType,
            cueType: cueType,
            checkEventType: checkEventType,
            comparativeRecordType: comparativeRecordType,
            reflectiveRecordType: reflectiveRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            persistencePolicy: persistencePolicy,
            using: BASAppleLivePersistenceIO(),
            rebuildEmbeddings: rebuildEmbeddings
        )
    }

    static func refreshProjection<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity,
        IO: BASApplePersistenceIO
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted,
        using io: IO,
        rebuildEmbeddings: (
            _ records: [BASGovernedMemoryStoredFields],
            _ candidates: [BASCandidateMemoryStoredFields],
            _ checkEvents: [BASCheckEventMemoryInput],
            _ comparativeRecords: [BASComparativeMemoryInput],
            _ reflectiveRecords: [BASReflectiveMemoryInput]
        ) throws -> Void
    ) throws -> BASAppleMemoryProjectionRefreshResult {
        let transaction = try BASApplePersistenceTransaction.performReportingSave(
            selectedBy: context,
            using: io
        ) { owned in
            let records = try io.fetch(recordType, in: owned)
            let candidates = try io.fetch(candidateType, in: owned)
            let cues = try io.fetch(cueType, in: owned)
            let checkEvents = try io.fetch(checkEventType, in: owned)
            let comparativeRecords = try io.fetch(comparativeRecordType, in: owned)
            let reflectiveRecords = try io.fetch(reflectiveRecordType, in: owned)

            let reconciliation: BASAppleMemoryReconciliationWriteResult?
            let governedValues: [BASGovernedMemoryStoredFields]
            let candidateValues: [BASCandidateMemoryStoredFields]
            if records.isEmpty && candidates.isEmpty {
                let staged = BASAppleMemoryGovernanceAdapter.stage(
                    in: owned,
                    now: now,
                    records: records,
                    candidates: candidates,
                    cues: cues,
                    checkEvents: checkEvents,
                    comparativeRecords: comparativeRecords,
                    reflectiveRecords: reflectiveRecords,
                    behavior: behavior,
                    memoryTrustBehavior: memoryTrustBehavior,
                    persistencePolicy: persistencePolicy
                )
                reconciliation = staged
                governedValues = staged.orderedRecords
                candidateValues = staged.candidates
            } else {
                reconciliation = nil
                governedValues = records.map {
                    BASGovernedMemoryStoredFields(snapshot: $0.basSnapshot)
                }
                candidateValues = candidates.map {
                    BASCandidateMemoryStoredFields(snapshot: $0.basSnapshot)
                }
            }

            let selectedRecords = Array(
                governedValues.sorted(by: governedOrder).prefix(limits.recordLimit)
            )
            let selectedCandidates = Array(
                candidateValues
                    .filter { $0.status == .pending }
                    .sorted(by: candidateOrder)
                    .prefix(limits.candidateLimit)
            )
            let selectedEventValues = checkEvents
                .map {
                    BASAppleProjectionEventValues(
                        memory: $0.basCheckEventMemoryInput,
                        projection: $0.basProjectionEventInput
                    )
                }
                .sorted(by: eventOrder)
                .prefix(limits.checkEventLimit)
            let selectedComparative = BASAppleMemoryProjectionSelectionAdapter
                .selectProjectionTemporalEntries(
                    comparativeRecords,
                    limit: limits.comparativeRecordLimit,
                    timestamp: { $0.basComparativeMemoryInput.updatedAt }
                )
                .map(\.basComparativeMemoryInput)
            let selectedReflective = BASAppleMemoryProjectionSelectionAdapter
                .selectProjectionTemporalEntries(
                    reflectiveRecords,
                    limit: limits.reflectiveRecordLimit,
                    timestamp: { $0.basReflectiveMemoryInput.updatedAt }
                )
                .map(\.basReflectiveMemoryInput)

            return BASAppleMemoryProjectionInputs(
                records: selectedRecords,
                candidates: selectedCandidates,
                checkEvents: selectedEventValues.map(\.memory),
                projectionEvents: selectedEventValues.map(\.projection),
                comparativeRecords: selectedComparative,
                reflectiveRecords: selectedReflective,
                governanceSnapshot: BASAppleMemoryProjectionSelectionAdapter.governanceSnapshot(
                    records: governedValues,
                    candidates: candidateValues
                ),
                reconciliation: reconciliation
            )
        }

        let disposition: BASAppleMemoryProjectionPersistenceDisposition
        if let reconciliation = transaction.value.reconciliation {
            disposition = transaction.didSave
                ? .committedReconciliation(reconciliation)
                : .reconciliationEvaluatedNoWrite(reconciliation)
        } else {
            disposition = .readOnlyProjection
        }

        let inputs = transaction.value
        do {
            try rebuildEmbeddings(
                inputs.records,
                inputs.candidates,
                inputs.checkEvents,
                inputs.comparativeRecords,
                inputs.reflectiveRecords
            )
        } catch {
            throw BASAppleMemoryProjectionRefreshError.publicationFailed(
                disposition: disposition,
                stage: .embeddingRebuild,
                underlying: error
            )
        }

        let projection = BASAppleMemoryProjectionAdapter.compileProjection(
            records: inputs.records,
            candidates: inputs.candidates,
            events: inputs.projectionEvents,
            governanceSnapshot: inputs.governanceSnapshot,
            memoryTrustBehavior: memoryTrustBehavior
        )
        return BASAppleMemoryProjectionRefreshResult(
            baseProjection: projection,
            governanceSnapshot: inputs.governanceSnapshot,
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: inputs.records.count,
                candidateCount: inputs.candidates.count,
                allCandidatesPending: inputs.candidates.allSatisfy { $0.status == .pending }
            ),
            refreshedAt: now
        )
    }

    private static func governedOrder(
        _ lhs: BASGovernedMemoryStoredFields,
        _ rhs: BASGovernedMemoryStoredFields
    ) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.lastConfirmedAt == rhs.lastConfirmedAt
                ? lhs.id < rhs.id
                : lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func candidateOrder(
        _ lhs: BASCandidateMemoryStoredFields,
        _ rhs: BASCandidateMemoryStoredFields
    ) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.lastObservedAt == rhs.lastObservedAt
                ? lhs.id < rhs.id
                : lhs.lastObservedAt > rhs.lastObservedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func eventOrder(
        _ lhs: BASAppleProjectionEventValues,
        _ rhs: BASAppleProjectionEventValues
    ) -> Bool {
        lhs.memory.createdAt == rhs.memory.createdAt
            ? lhs.memory.id < rhs.memory.id
            : lhs.memory.createdAt > rhs.memory.createdAt
    }
}

public enum BASAppleMemoryProjectionRuntime {
    public static func refresh<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Cue: BASAppleCueMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        cueType: Cue.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted,
        rebuildEmbeddings: (
            _ records: [BASGovernedMemoryStoredFields],
            _ candidates: [BASCandidateMemoryStoredFields],
            _ checkEvents: [BASCheckEventMemoryInput],
            _ comparativeRecords: [BASComparativeMemoryInput],
            _ reflectiveRecords: [BASReflectiveMemoryInput]
        ) throws -> Void
    ) throws -> BASAppleMemoryProjectionRefreshResult {
        try BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            limits: limits,
            recordType: recordType,
            candidateType: candidateType,
            cueType: cueType,
            checkEventType: checkEventType,
            comparativeRecordType: comparativeRecordType,
            reflectiveRecordType: reflectiveRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            persistencePolicy: persistencePolicy,
            rebuildEmbeddings: rebuildEmbeddings
        )
    }
}
