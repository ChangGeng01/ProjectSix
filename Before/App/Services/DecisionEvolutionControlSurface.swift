import Foundation

struct DecisionEvolutionCheckpointSlots: Equatable, Sendable {
    let activeCheckpoint: DecisionReviewCheckpointSnapshot?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let reviewCheckpoint: DecisionReviewCheckpointSnapshot?
    let pendingReviewQueue: [DecisionReviewCheckpointSnapshot]
}

struct DecisionEvolutionControlSurfaceSummarySectionPresentation: Identifiable, Equatable, Sendable {
    let role: DecisionEvolutionCheckpointRole
    let title: String
    let presentation: DecisionEvolutionCheckpointPresentation
    let summaryBadges: [DecisionEvolutionSummaryBadgePresentation]

    var id: String {
        "\(role)-\(presentation.checkpointID)"
    }
}

struct DecisionEvolutionControlSurface: Equatable, Sendable {
    let activeCheckpoint: DecisionReviewCheckpointSnapshot?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
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
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource? = nil,
        reviewCheckpoint: DecisionReviewCheckpointSnapshot?,
        pendingReviewQueue: [DecisionReviewCheckpointSnapshot],
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?,
        restorableCheckpointIDs: Set<String> = []
    ) {
        self.activeCheckpoint = activeCheckpoint
        self.activeCheckpointSource = activeCheckpointSource
            ?? (activeCheckpoint == nil ? .none : .pinnedHint)
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

    var activeKillSwitches: [String] {
        activeCheckpoint?.activeKillSwitches ?? []
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

    var summarySectionPresentations: [DecisionEvolutionControlSurfaceSummarySectionPresentation] {
        var sections: [DecisionEvolutionControlSurfaceSummarySectionPresentation] = []

        if let activePresentation {
            sections.append(
                DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionPresentation(
                    role: .active,
                    presentation: activePresentation,
                    activeSource: activeCheckpointSource
                )
            )
        }

        if let reviewPresentation = spotlightReviewPresentation {
            sections.append(
                DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionPresentation(
                    role: .reviewHead,
                    presentation: reviewPresentation
                )
            )
        }

        return sections
    }

    var projectedAutomaticCheckpointIDAfterApprovingPendingQueue: String? {
        let candidates = ([activeCheckpoint].compactMap { $0 } + pendingReviewQueue)
        guard !candidates.isEmpty else { return nil }

        return candidates.max { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.checkpointID < rhs.checkpointID
        }?.checkpointID
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
    var activeKillSwitches: [String] {
        eBrain?.activeKillSwitches ?? []
    }

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

extension DecisionEvolutionControlSurface {
    static func resolveCheckpointSlots(
        activeCheckpointHint: DecisionReviewCheckpointSnapshot?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource? = nil,
        latestAutomaticLineage: DecisionEvolutionLineageSnapshot? = nil,
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot]
    ) -> DecisionEvolutionCheckpointSlots {
        let pendingReviewQueue = pendingReviewCheckpoints.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.checkpointID > rhs.checkpointID
        }

        let activeCheckpoint = activeCheckpointHint
            ?? latestAutomaticLineage.map(DecisionReviewCheckpointSnapshot.init(lineage:))
        let resolvedActiveCheckpointSource: DecisionEvolutionActiveCheckpointSource = activeCheckpointSource ?? {
            if activeCheckpointHint != nil {
                return .pinnedHint
            }

            if latestAutomaticLineage != nil {
                return .automaticFallback
            }

            return .none
        }()

        return DecisionEvolutionCheckpointSlots(
            activeCheckpoint: activeCheckpoint,
            activeCheckpointSource: resolvedActiveCheckpointSource,
            reviewCheckpoint: pendingReviewQueue.first,
            pendingReviewQueue: pendingReviewQueue
        )
    }
}

extension DecisionEvolutionControlSurface {
    func coverageFacts(
        latestPersistedLineage: DecisionEvolutionLineageSnapshot?,
        recoveredCheckpointOverride: DecisionReviewCheckpointSnapshot? = nil
    ) -> DecisionEvolutionCoverageFacts {
        let recoveredCheckpoint = recoveredCheckpointOverride ?? activeCheckpoint

        return DecisionEvolutionCoverageFacts(
            recoveredCheckpoint: recoveredCheckpoint,
            latestPersistedLineage: latestPersistedLineage,
            recoveredEBrainAvailable: recoveredCheckpoint != nil || latestPersistedLineage != nil,
            recoveredAuditFindingCount: recoveredCheckpoint?.auditFindings.count
                ?? latestPersistedLineage?.eBrain.guardrailFindings.count
                ?? 0,
            recoveredTicketCount: recoveredCheckpoint?.updateTicketSummaries.count
                ?? latestPersistedLineage?.eBrain.updateTicketSummaries.count
                ?? 0
        )
    }
}
