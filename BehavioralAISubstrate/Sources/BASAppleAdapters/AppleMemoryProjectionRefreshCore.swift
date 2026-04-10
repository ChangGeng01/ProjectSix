import Foundation
import SwiftData
import BASMemory

public struct BASAppleMemoryProjectionRefreshLimits: Codable, Equatable, Sendable {
    public static let `default` = BASAppleMemoryProjectionRefreshLimits()

    public var recordLimit: Int
    public var candidateLimit: Int
    public var checkEventLimit: Int
    public var balanceRecordLimit: Int
    public var mirrorRecordLimit: Int

    public init(
        recordLimit: Int = 72,
        candidateLimit: Int = 32,
        checkEventLimit: Int = 96,
        balanceRecordLimit: Int = 36,
        mirrorRecordLimit: Int = 36
    ) {
        self.recordLimit = recordLimit
        self.candidateLimit = candidateLimit
        self.checkEventLimit = checkEventLimit
        self.balanceRecordLimit = balanceRecordLimit
        self.mirrorRecordLimit = mirrorRecordLimit
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
                    balanceRecordType: balanceRecordType,
                    mirrorRecordType: mirrorRecordType,
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
        let balanceRecords = fetchBalanceRecords(context, limits.balanceRecordLimit)
        let mirrorRecords = fetchMirrorRecords(context, limits.mirrorRecordLimit)

        rebuildEmbeddings(
            resolvedRecords,
            resolvedCandidates,
            checkEvents,
            balanceRecords,
            mirrorRecords
        )

        let projection = BASAppleMemoryProjectionAdapter.compileProjection(
            records: resolvedRecords,
            candidates: resolvedCandidates,
            events: checkEvents,
            governanceSnapshot: resolvedGovernanceSnapshot
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
}
