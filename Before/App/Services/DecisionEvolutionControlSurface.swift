import Foundation

struct DecisionEvolutionControlSurface: Equatable, Sendable {
    let activeCheckpoint: DecisionReviewCheckpointSnapshot?
    let reviewCheckpoint: DecisionReviewCheckpointSnapshot?
    let pendingReviewQueue: [DecisionReviewCheckpointSnapshot]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    let reviewAuditFindings: [String]
    let reviewKillSwitches: [String]
    let queueAuditFindings: [String]
    let queueKillSwitches: [String]

    init(
        activeCheckpoint: DecisionReviewCheckpointSnapshot?,
        reviewCheckpoint: DecisionReviewCheckpointSnapshot?,
        pendingReviewQueue: [DecisionReviewCheckpointSnapshot],
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?
    ) {
        self.activeCheckpoint = activeCheckpoint
        self.reviewCheckpoint = reviewCheckpoint ?? pendingReviewQueue.first
        self.pendingReviewQueue = pendingReviewQueue
        self.pendingReviewCount = pendingReviewQueue.count
        self.rollbackReadyCount = pendingReviewQueue.filter(\.rollbackReady).count
        self.latestPersistedLineage = latestPersistedLineage
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
        activeCheckpoint?.presentation
    }

    var reviewPresentation: DecisionEvolutionCheckpointPresentation? {
        reviewCheckpoint?.presentation
    }

    var distinctReviewPresentation: DecisionEvolutionCheckpointPresentation? {
        guard let reviewPresentation else { return nil }
        guard reviewPresentation.checkpointID != activePresentation?.checkpointID else { return nil }
        return reviewPresentation
    }

    var activeRollbackCheckpointID: String? {
        activeCheckpoint?.previousCheckpointID
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
