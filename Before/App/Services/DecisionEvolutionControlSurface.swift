import Foundation

struct DecisionEvolutionControlSurface: Equatable, Sendable {
    let activeCheckpoint: DecisionReviewCheckpointSnapshot?
    let reviewCheckpoint: DecisionReviewCheckpointSnapshot?
    let pendingReviewQueue: [DecisionReviewCheckpointSnapshot]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    let restorableCheckpointIDs: Set<String>
    let reviewAuditFindings: [String]
    let reviewKillSwitches: [String]
    let queueAuditFindings: [String]
    let queueKillSwitches: [String]

    init(
        activeCheckpoint: DecisionReviewCheckpointSnapshot?,
        reviewCheckpoint: DecisionReviewCheckpointSnapshot?,
        pendingReviewQueue: [DecisionReviewCheckpointSnapshot],
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?,
        restorableCheckpointIDs: Set<String> = []
    ) {
        self.activeCheckpoint = activeCheckpoint
        self.reviewCheckpoint = reviewCheckpoint ?? pendingReviewQueue.first
        self.pendingReviewQueue = pendingReviewQueue
        self.pendingReviewCount = pendingReviewQueue.count
        self.rollbackReadyCount = pendingReviewQueue.filter {
            Self.resolvedRollbackReady(for: $0, restorableCheckpointIDs: restorableCheckpointIDs)
        }.count
        self.latestPersistedLineage = latestPersistedLineage
        self.restorableCheckpointIDs = restorableCheckpointIDs
        self.reviewAuditFindings = self.reviewCheckpoint?.auditFindings ?? []
        self.reviewKillSwitches = self.reviewCheckpoint?.killSwitches ?? []
        self.queueAuditFindings = Self.orderedUnique(
            pendingReviewQueue.flatMap(\.auditFindings)
        )
        self.queueKillSwitches = Self.orderedUnique(
            pendingReviewQueue.flatMap(\.killSwitches)
        )
    }

    var hasAnyCheckpoint: Bool {
        activeCheckpoint != nil || reviewCheckpoint != nil
    }

    var activePresentation: DecisionEvolutionCheckpointPresentation? {
        activeCheckpoint?.presentation(
            rollbackReadyOverride: resolvedRollbackReady(for: activeCheckpoint)
        )
    }

    var reviewPresentation: DecisionEvolutionCheckpointPresentation? {
        reviewCheckpoint?.presentation(
            rollbackReadyOverride: resolvedRollbackReady(for: reviewCheckpoint)
        )
    }

    var pendingReviewPresentations: [DecisionEvolutionCheckpointPresentation] {
        pendingReviewQueue.map { checkpoint in
            checkpoint.presentation(
                rollbackReadyOverride: resolvedRollbackReady(for: checkpoint)
            )
        }
    }

    var pendingReviewLineagePresentations: [DecisionEvolutionCheckpointPresentation] {
        pendingReviewPresentations.filter(\.hasLineage)
    }

    func resolvedPresentation(
        for checkpoint: DecisionEvolutionCheckpoint
    ) -> DecisionEvolutionCheckpointPresentation {
        let snapshot = DecisionReviewCheckpointSnapshot(checkpoint: checkpoint)
        return snapshot.presentation(
            rollbackReadyOverride: resolvedRollbackReady(for: snapshot)
        )
    }

    func resolvedPresentations(
        for checkpoints: [DecisionEvolutionCheckpoint]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        checkpoints.map { resolvedPresentation(for: $0) }
    }

    var distinctReviewPresentation: DecisionEvolutionCheckpointPresentation? {
        guard let reviewPresentation else { return nil }
        guard reviewPresentation.checkpointID != activePresentation?.checkpointID else { return nil }
        return reviewPresentation
    }

    func checkpointIsRestorable(_ checkpointID: String?) -> Bool {
        guard let checkpointID else { return false }
        return restorableCheckpointIDs.contains(checkpointID)
    }

    func resolvedRollbackReady(
        for checkpoint: DecisionReviewCheckpointSnapshot?
    ) -> Bool {
        Self.resolvedRollbackReady(
            for: checkpoint,
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }

    var activeRollbackCheckpointID: String? {
        guard let rollbackID = activeCheckpoint?.previousCheckpointID else {
            return nil
        }
        return checkpointIsRestorable(rollbackID) ? rollbackID : nil
    }

    var canRollbackActiveCheckpoint: Bool {
        activeRollbackCheckpointID != nil
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func resolvedRollbackReady(
        for checkpoint: DecisionReviewCheckpointSnapshot?,
        restorableCheckpointIDs: Set<String>
    ) -> Bool {
        guard let checkpoint, checkpoint.rollbackReady else { return false }
        guard let previousCheckpointID = checkpoint.previousCheckpointID else { return false }
        return restorableCheckpointIDs.contains(previousCheckpointID)
    }
}

extension DecisionReviewCheckpointSnapshot {
    var riskLevel: String? {
        eBrain?.riskLevel
    }

    var resolvedRiskLevel: String? {
        eBrain?.riskLevel ?? fallbackRiskLevel
    }

    var permitMode: String? {
        eBrain?.permitMode
    }

    var resolvedPermitMode: String? {
        eBrain?.permitMode ?? fallbackPermitMode
    }

    var hostGatePercent: Int? {
        eBrain?.hostGatePercent
    }

    var sessionID: String? {
        eBrain?.sessionID
    }

    var recordedAt: Date? {
        eBrain?.recordedAt
    }

    var thoughtFoldChecksum: String? {
        eBrain?.thoughtFoldChecksum
    }

    var updateTicketSummaries: [String] {
        eBrain?.updateTicketSummaries ?? []
    }

    var auditFindings: [String] {
        eBrain?.guardrailFindings ?? []
    }

    var killSwitches: [String] {
        eBrain?.killSwitches ?? []
    }
}
