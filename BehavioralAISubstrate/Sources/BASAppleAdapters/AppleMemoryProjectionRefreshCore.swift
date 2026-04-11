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

    public var balanceRecordLimit: Int {
        get { comparativeRecordLimit }
        set { comparativeRecordLimit = newValue }
    }

    public var mirrorRecordLimit: Int {
        get { reflectiveRecordLimit }
        set { reflectiveRecordLimit = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case recordLimit
        case candidateLimit
        case checkEventLimit
        case comparativeRecordLimit
        case reflectiveRecordLimit
        case balanceRecordLimit
        case mirrorRecordLimit
    }

    public init(
        recordLimit: Int = 72,
        candidateLimit: Int = 32,
        checkEventLimit: Int = 96,
        comparativeRecordLimit: Int = 36,
        reflectiveRecordLimit: Int = 36,
        balanceRecordLimit: Int? = nil,
        mirrorRecordLimit: Int? = nil
    ) {
        self.recordLimit = recordLimit
        self.candidateLimit = candidateLimit
        self.checkEventLimit = checkEventLimit
        self.comparativeRecordLimit = balanceRecordLimit ?? comparativeRecordLimit
        self.reflectiveRecordLimit = mirrorRecordLimit ?? reflectiveRecordLimit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordLimit = try container.decodeIfPresent(Int.self, forKey: .recordLimit) ?? 72
        candidateLimit = try container.decodeIfPresent(Int.self, forKey: .candidateLimit) ?? 32
        checkEventLimit = try container.decodeIfPresent(Int.self, forKey: .checkEventLimit) ?? 96
        comparativeRecordLimit = try container.decodeIfPresent(Int.self, forKey: .comparativeRecordLimit) ??
            container.decodeIfPresent(Int.self, forKey: .balanceRecordLimit) ??
            36
        reflectiveRecordLimit = try container.decodeIfPresent(Int.self, forKey: .reflectiveRecordLimit) ??
            container.decodeIfPresent(Int.self, forKey: .mirrorRecordLimit) ??
            36
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
    public var recordCount: Int
    public var candidateCount: Int
    public var allCandidatesPending: Bool

    public init(
        recordCount: Int,
        candidateCount: Int,
        allCandidatesPending: Bool
    ) {
        self.recordCount = recordCount
        self.candidateCount = candidateCount
        self.allCandidatesPending = allCandidatesPending
    }
}

public struct BASAppleMemoryProjectionRefreshResult: Codable, Equatable, Sendable {
    public var baseProjection: BASBrainProjection
    public var governanceSnapshot: BASAppleProjectionGovernanceSnapshot
    public var diagnostics: BASAppleMemoryProjectionDiagnostics
    public var refreshedAt: Date

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

public enum BASAppleMemoryProjectionRefreshAdapter {
    public static func refreshProjection<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot,
        refreshGovernanceSnapshot: (ModelContext) -> BASAppleProjectionGovernanceSnapshot,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        fetchRecords: (ModelContext, Int) -> [Governed],
        fetchCandidates: (ModelContext, Int) -> [Candidate],
        fetchCheckEvents: (ModelContext, Int) -> [Event],
        fetchComparativeRecords: (ModelContext, Int) -> [Comparative],
        fetchReflectiveRecords: (ModelContext, Int) -> [Reflective],
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ comparativeRecords: [Comparative],
            _ reflectiveRecords: [Reflective]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        var resolvedGovernanceSnapshot = governanceSnapshot
        let records = fetchRecords(context, limits.recordLimit)
        let candidates = fetchCandidates(context, limits.candidateLimit)
        let resolvedRecords: [Governed]
        let resolvedCandidates: [Candidate]

        if resolvedGovernanceSnapshot.totalRecordCount == 0 &&
            resolvedGovernanceSnapshot.totalCandidateCount == 0 {
            let refreshed: BASAppleMemoryReconciliationWriteResult<Governed, Candidate> =
                BASAppleMemoryGovernanceAdapter.refreshStoredMemories(
                    in: context,
                    now: now,
                    reminderType: reminderType,
                    checkEventType: checkEventType,
                    comparativeRecordType: comparativeRecordType,
                    reflectiveRecordType: reflectiveRecordType,
                    behavior: behavior,
                    memoryTrustBehavior: memoryTrustBehavior,
                    onSaveError: onSaveError
                )
            resolvedRecords = Array(refreshed.orderedRecords.prefix(limits.recordLimit))
            resolvedGovernanceSnapshot = refreshGovernanceSnapshot(context)
            resolvedCandidates = fetchCandidates(context, limits.candidateLimit)
        } else {
            resolvedRecords = records
            resolvedCandidates = candidates
        }

        let checkEvents = fetchCheckEvents(context, limits.checkEventLimit)
        let comparativeRecords = fetchComparativeRecords(context, limits.comparativeRecordLimit)
        let reflectiveRecords = fetchReflectiveRecords(context, limits.reflectiveRecordLimit)

        rebuildEmbeddings(
            resolvedRecords,
            resolvedCandidates,
            checkEvents,
            comparativeRecords,
            reflectiveRecords
        )

        let projection = BASAppleMemoryProjectionAdapter.compileProjection(
            records: resolvedRecords,
            candidates: resolvedCandidates,
            events: checkEvents,
            governanceSnapshot: resolvedGovernanceSnapshot,
            memoryTrustBehavior: memoryTrustBehavior
        )

        return BASAppleMemoryProjectionRefreshResult(
            baseProjection: projection,
            governanceSnapshot: resolvedGovernanceSnapshot,
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: resolvedRecords.count,
                candidateCount: resolvedCandidates.count,
                allCandidatesPending: resolvedCandidates.allSatisfy {
                    $0.basSnapshot.status == .pending
                }
            ),
            refreshedAt: now
        )
    }

    public static func refreshProjection<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        governanceSnapshot: BASAppleProjectionGovernanceSnapshot,
        refreshGovernanceSnapshot: (ModelContext) -> BASAppleProjectionGovernanceSnapshot,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        balanceRecordType: Balance.Type,
        mirrorRecordType: Mirror.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        fetchRecords: (ModelContext, Int) -> [Governed],
        fetchCandidates: (ModelContext, Int) -> [Candidate],
        fetchCheckEvents: (ModelContext, Int) -> [Event],
        fetchBalanceRecords: (ModelContext, Int) -> [Balance],
        fetchMirrorRecords: (ModelContext, Int) -> [Mirror],
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ balanceRecords: [Balance],
            _ mirrorRecords: [Mirror]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        refreshProjection(
            in: context,
            now: now,
            governanceSnapshot: governanceSnapshot,
            refreshGovernanceSnapshot: refreshGovernanceSnapshot,
            limits: limits,
            reminderType: reminderType,
            checkEventType: checkEventType,
            comparativeRecordType: balanceRecordType,
            reflectiveRecordType: mirrorRecordType,
            behavior: behavior,
            fetchRecords: fetchRecords,
            fetchCandidates: fetchCandidates,
            fetchCheckEvents: fetchCheckEvents,
            fetchComparativeRecords: fetchBalanceRecords,
            fetchReflectiveRecords: fetchMirrorRecords,
            rebuildEmbeddings: rebuildEmbeddings,
            onSaveError: onSaveError
        )
    }
}

public enum BASAppleMemoryProjectionRuntime {
    public static func refresh<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ comparativeRecords: [Comparative],
            _ reflectiveRecords: [Reflective]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        refresh(
            in: context,
            now: now,
            limits: limits,
            recordType: recordType,
            candidateType: candidateType,
            reminderType: reminderType,
            checkEventType: checkEventType,
            comparativeRecordType: comparativeRecordType,
            reflectiveRecordType: reflectiveRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            fetchRecords: {
                BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
                    in: $0,
                    recordType: recordType,
                    limit: $1
                )
            },
            fetchCandidates: {
                BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
                    in: $0,
                    candidateType: candidateType,
                    limit: $1
                )
            },
            fetchCheckEvents: {
                BASAppleMemoryProjectionSelectionAdapter.fetchProjectionTemporalEntries(
                    in: $0,
                    entryType: checkEventType,
                    limit: $1,
                    timestamp: { $0.basCheckEventMemoryInput.createdAt },
                    stableID: { $0.basCheckEventMemoryInput.id }
                )
            },
            fetchComparativeRecords: {
                BASAppleMemoryProjectionSelectionAdapter.fetchProjectionComparativeRecords(
                    in: $0,
                    comparativeType: comparativeRecordType,
                    limit: $1
                )
            },
            fetchReflectiveRecords: {
                BASAppleMemoryProjectionSelectionAdapter.fetchProjectionReflectiveRecords(
                    in: $0,
                    reflectiveType: reflectiveRecordType,
                    limit: $1
                )
            },
            rebuildEmbeddings: rebuildEmbeddings,
            onSaveError: onSaveError
        )
    }

    public static func refresh<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Comparative: BASAppleComparativeMemoryEntity,
        Reflective: BASAppleReflectiveMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        comparativeRecordType: Comparative.Type,
        reflectiveRecordType: Reflective.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        fetchRecords: (ModelContext, Int) -> [Governed],
        fetchCandidates: (ModelContext, Int) -> [Candidate],
        fetchCheckEvents: (ModelContext, Int) -> [Event],
        fetchComparativeRecords: (ModelContext, Int) -> [Comparative],
        fetchReflectiveRecords: (ModelContext, Int) -> [Reflective],
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ comparativeRecords: [Comparative],
            _ reflectiveRecords: [Reflective]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        let governanceSnapshot = BASAppleMemoryProjectionSelectionAdapter.governanceSnapshot(
            in: context,
            recordType: recordType,
            candidateType: candidateType
        )
        return BASAppleMemoryProjectionRefreshAdapter.refreshProjection(
            in: context,
            now: now,
            governanceSnapshot: governanceSnapshot,
            refreshGovernanceSnapshot: {
                BASAppleMemoryProjectionSelectionAdapter.governanceSnapshot(
                    in: $0,
                    recordType: recordType,
                    candidateType: candidateType
                )
            },
            limits: limits,
            reminderType: reminderType,
            checkEventType: checkEventType,
            comparativeRecordType: comparativeRecordType,
            reflectiveRecordType: reflectiveRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            fetchRecords: fetchRecords,
            fetchCandidates: fetchCandidates,
            fetchCheckEvents: fetchCheckEvents,
            fetchComparativeRecords: fetchComparativeRecords,
            fetchReflectiveRecords: fetchReflectiveRecords,
            rebuildEmbeddings: rebuildEmbeddings,
            onSaveError: onSaveError
        )
    }

    public static func refresh<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        balanceRecordType: Balance.Type,
        mirrorRecordType: Mirror.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ balanceRecords: [Balance],
            _ mirrorRecords: [Mirror]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        refresh(
            in: context,
            now: now,
            limits: limits,
            recordType: recordType,
            candidateType: candidateType,
            reminderType: reminderType,
            checkEventType: checkEventType,
            comparativeRecordType: balanceRecordType,
            reflectiveRecordType: mirrorRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            rebuildEmbeddings: rebuildEmbeddings,
            onSaveError: onSaveError
        )
    }

    public static func refresh<
        Governed: BASAppleGovernedMemoryEntity,
        Candidate: BASAppleCandidateMemoryEntity,
        Reminder: BASAppleReminderMemoryEntity,
        Event: BASAppleCheckEventMemoryEntity & BASAppleProjectionEventSource,
        Balance: BASAppleBalanceMemoryEntity,
        Mirror: BASAppleMirrorMemoryEntity
    >(
        in context: ModelContext,
        now: Date,
        limits: BASAppleMemoryProjectionRefreshLimits = .default,
        recordType: Governed.Type,
        candidateType: Candidate.Type,
        reminderType: Reminder.Type,
        checkEventType: Event.Type,
        balanceRecordType: Balance.Type,
        mirrorRecordType: Mirror.Type,
        behavior: BASMemoryDerivationBehavior = .generic,
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic,
        fetchRecords: (ModelContext, Int) -> [Governed],
        fetchCandidates: (ModelContext, Int) -> [Candidate],
        fetchCheckEvents: (ModelContext, Int) -> [Event],
        fetchBalanceRecords: (ModelContext, Int) -> [Balance],
        fetchMirrorRecords: (ModelContext, Int) -> [Mirror],
        rebuildEmbeddings: (
            _ records: [Governed],
            _ candidates: [Candidate],
            _ checkEvents: [Event],
            _ balanceRecords: [Balance],
            _ mirrorRecords: [Mirror]
        ) -> Void,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleMemoryProjectionRefreshResult {
        refresh(
            in: context,
            now: now,
            limits: limits,
            recordType: recordType,
            candidateType: candidateType,
            reminderType: reminderType,
            checkEventType: checkEventType,
            comparativeRecordType: balanceRecordType,
            reflectiveRecordType: mirrorRecordType,
            behavior: behavior,
            memoryTrustBehavior: memoryTrustBehavior,
            fetchRecords: fetchRecords,
            fetchCandidates: fetchCandidates,
            fetchCheckEvents: fetchCheckEvents,
            fetchComparativeRecords: fetchBalanceRecords,
            fetchReflectiveRecords: fetchMirrorRecords,
            rebuildEmbeddings: rebuildEmbeddings,
            onSaveError: onSaveError
        )
    }
}
