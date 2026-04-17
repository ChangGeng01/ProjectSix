import Foundation

enum DecisionEvolutionRuntimePresentationSupport {
    static let activeRoleTitle = DecisionEvolutionCheckpointLexiconSupport.activeRuntimeRoleTitle
    static let reviewHeadRoleTitle = DecisionEvolutionCheckpointLexiconSupport.reviewHeadRoleTitle
    static let applyReadyTitle = "Apply ready"
    static let applyUnavailableTitle = "Apply unavailable"

    static func roleTitle(isActive: Bool) -> String {
        DecisionEvolutionCheckpointLexiconSupport.runtimeRoleTitle(
            isActive: isActive
        )
    }

    static func applyTitle(applyReady: Bool) -> String {
        applyReady ? applyReadyTitle : applyUnavailableTitle
    }

    static func spotlightDetail(
        checkpointID: String,
        isActive: Bool,
        approvalStateTitle: String,
        applyReady: Bool,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    ) -> String {
        let roleTitle = roleTitle(isActive: isActive)
        let activeSourceDetail = if isActive, activeCheckpointSource != .none {
            " • \(activeCheckpointSource.title)"
        } else {
            ""
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "\(roleTitle) \(checkpointID)\(activeSourceDetail)",
            approvalStateTitle,
            applyTitle(applyReady: applyReady)
        ])
    }

    static func reviewHeadWithoutActiveCheckpointLine(
        checkpointID: String
    ) -> String {
        "\(DecisionEvolutionCheckpointLexiconSupport.reviewHeadRoleTitle) \(checkpointID) is visible in the shared control surface, but no active checkpoint is attached to the main release path yet."
    }
}

enum DecisionEvolutionHistoryFilterPresentationSupport {
    static let allTitle = "All"
    static let reviewTitle = "Review"
    static let rollbackReadyTitle = "Rollback"
    static let blockedTitle = "Blocked"
    static let lineageBackedTitle = "Lineage"

    static func title(
        for filter: DecisionEvolutionHistoryFilter
    ) -> String {
        switch filter {
        case .all:
            allTitle
        case .review:
            reviewTitle
        case .rollbackReady:
            rollbackReadyTitle
        case .blocked:
            blockedTitle
        case .lineageBacked:
            lineageBackedTitle
        }
    }
}

struct DecisionEvolutionWorkspaceFacts: Equatable, Sendable {
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let canRestoreActiveCheckpoint: Bool
    let canRollbackActiveCheckpoint: Bool
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let killSwitches: [String]

    var hasPendingReview: Bool {
        pendingReviewCount > 0
    }

    var hasRecommendedKillSwitches: Bool {
        !recommendedKillSwitches.isEmpty
    }

    var hasActiveKillSwitches: Bool {
        !activeKillSwitches.isEmpty
    }
}

struct DecisionEvolutionRuntimeSpotlight: Equatable, Sendable {
    let roleTitle: String
    let detailText: String
}

struct DecisionEvolutionRuntimeStatusPresentation: Equatable, Sendable {
    let headline: String?
    let detail: String?
    let usesAttentionAccent: Bool
}

enum DecisionEvolutionHistoryFilter: String, CaseIterable, Identifiable, Equatable, Sendable {
    case all
    case review
    case rollbackReady
    case blocked
    case lineageBacked

    var id: String { rawValue }

    var title: String {
        DecisionEvolutionHistoryFilterPresentationSupport.title(for: self)
    }

    func matches(
        _ checkpoint: DecisionEvolutionCheckpointPresentation,
        inReviewQueue: Bool
    ) -> Bool {
        switch self {
        case .all:
            true
        case .review:
            inReviewQueue || checkpoint.approvalState == .reviewSuggested
        case .rollbackReady:
            checkpoint.rollbackReady
        case .blocked:
            !checkpoint.killSwitches.isEmpty || !checkpoint.auditFindings.isEmpty
        case .lineageBacked:
            checkpoint.hasLineage
        }
    }
}

struct DecisionEvolutionRecoveryPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor?
    let availabilityText: String
    let emptyMessage: String
}

struct DecisionEvolutionWorkspaceSnapshot: Equatable, Sendable {
    let controlSurface: DecisionEvolutionControlSurface
    let releaseSummary: DecisionSystemReleaseControlSummary?
    let spotlightSet: DecisionEvolutionSpotlightSet

    static func build(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionWorkspaceSnapshot {
        DecisionEvolutionWorkspaceSnapshot(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            spotlightSet: DecisionEvolutionSpotlightSet.build(
                controlSurface: controlSurface,
                historyPresentations: historyPresentations
            )
        )
    }

    var activePresentation: DecisionEvolutionCheckpointPresentation? {
        spotlightSet.activePresentation
    }

    var reviewPresentation: DecisionEvolutionCheckpointPresentation? {
        spotlightSet.reviewPresentation
    }

    var remainingReviewQueue: [DecisionEvolutionCheckpointPresentation] {
        spotlightSet.remainingReviewQueue
    }

    var historyPresentations: [DecisionEvolutionCheckpointPresentation] {
        spotlightSet.historyPresentations
    }

    func filteredEvolutionQueue(
        using filter: DecisionEvolutionHistoryFilter
    ) -> [DecisionEvolutionCheckpointPresentation] {
        remainingReviewQueue.filter {
            filter.matches($0, inReviewQueue: true)
        }
    }

    func filteredEvolutionHistory(
        using filter: DecisionEvolutionHistoryFilter
    ) -> [DecisionEvolutionCheckpointPresentation] {
        historyPresentations.filter {
            filter.matches($0, inReviewQueue: false)
        }
    }

    var spotlightedPendingReviewCount: Int {
        reviewPresentation == nil ? 0 : 1
    }

    var queuedPendingReviewCount: Int {
        remainingReviewQueue.count
    }

    var totalPendingReviewCount: Int {
        controlSurface.pendingReviewCount
    }

    var facts: DecisionEvolutionWorkspaceFacts {
        DecisionEvolutionWorkspaceFacts(
            pendingReviewCount: releaseSummary?.pendingReviewCount ?? controlSurface.pendingReviewCount,
            rollbackReadyCount: releaseSummary?.rollbackReadyCount ?? controlSurface.rollbackReadyCount,
            canRestoreActiveCheckpoint: releaseSummary?.canRestoreActiveCheckpoint ?? (controlSurface.activePresentation?.applyReady == true),
            canRollbackActiveCheckpoint: releaseSummary?.canRollbackActiveCheckpoint ?? controlSurface.canRollbackActiveCheckpoint,
            activeKillSwitches: releaseSummary?.activeKillSwitches ?? controlSurface.activeCheckpoint?.activeKillSwitches ?? [],
            recommendedKillSwitches: releaseSummary?.recommendedKillSwitches ?? controlSurface.queueKillSwitches,
            killSwitches: releaseSummary?.killSwitches ?? Self.orderedUnique(
                (releaseSummary?.activeKillSwitches ?? controlSurface.activeCheckpoint?.activeKillSwitches ?? [])
                + (releaseSummary?.recommendedKillSwitches ?? controlSurface.queueKillSwitches)
            )
        )
    }

    var effectivePendingReviewCount: Int {
        facts.pendingReviewCount
    }

    var effectiveRollbackReadyCount: Int {
        facts.rollbackReadyCount
    }

    var effectiveCanRestoreActiveCheckpoint: Bool {
        facts.canRestoreActiveCheckpoint
    }

    var effectiveCanRollbackActiveCheckpoint: Bool {
        facts.canRollbackActiveCheckpoint
    }

    var effectiveActiveKillSwitches: [String] {
        facts.activeKillSwitches
    }

    var effectiveRecommendedKillSwitches: [String] {
        facts.recommendedKillSwitches
    }

    var effectiveKillSwitches: [String] {
        facts.killSwitches
    }

    func recoveryPresentation(hasCurrentBrainState: Bool) -> DecisionEvolutionRecoveryPresentation {
        let hasRecoveredLineage = activePresentation?.hasLineage == true
            || reviewPresentation?.hasLineage == true

        return DecisionEvolutionRecoveryPresentation(
            sourceDescriptor: hasRecoveredLineage ? .checkpointRecoveryWorkspace : nil,
            availabilityText: DecisionEvolutionCheckpointRecoverySupport.availabilityText(
                hasCurrentBrainState: hasCurrentBrainState,
                hasAnyCheckpoint: controlSurface.hasAnyCheckpoint
            ),
            emptyMessage: DecisionEvolutionCheckpointRecoverySupport.emptyMessage(
                hasCurrentBrainState: hasCurrentBrainState,
                hasAnyCheckpoint: controlSurface.hasAnyCheckpoint
            )
        )
    }

    func runtimeSpotlight(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> DecisionEvolutionRuntimeSpotlight? {
        let spotlightPresentation = activePresentation ?? reviewPresentation
        guard let spotlightPresentation else { return nil }

        let isActive = activePresentation?.checkpointID == spotlightPresentation.checkpointID
        let roleTitle = DecisionEvolutionRuntimePresentationSupport.roleTitle(
            isActive: isActive
        )

        return DecisionEvolutionRuntimeSpotlight(
            roleTitle: roleTitle,
            detailText: DecisionEvolutionRuntimePresentationSupport.spotlightDetail(
                checkpointID: spotlightPresentation.checkpointID,
                isActive: isActive,
                approvalStateTitle: spotlightPresentation.approvalStateTitle,
                applyReady: spotlightPresentation.applyReady,
                activeCheckpointSource: releaseSummary.activeCheckpointSource
            )
        )
    }

    func runtimeStatusPresentation(
        attentionSignal: DecisionEvolutionAttentionSignal
    ) -> DecisionEvolutionRuntimeStatusPresentation? {
        if let releaseSummary,
           let spotlight = runtimeSpotlight(releaseSummary: releaseSummary) {
            return DecisionEvolutionRuntimeStatusPresentation(
                headline: nil,
                detail: spotlight.detailText,
                usesAttentionAccent: false
            )
        }

        guard attentionSignal.requiresAttention else { return nil }
        return DecisionEvolutionRuntimeStatusPresentation(
            headline: attentionSignal.headline,
            detail: attentionSignal.detail,
            usesAttentionAccent: true
        )
    }

    var reviewHeadWithoutActiveCheckpointLine: String? {
        guard activePresentation == nil,
              let reviewPresentation else { return nil }
        return DecisionEvolutionRuntimePresentationSupport.reviewHeadWithoutActiveCheckpointLine(
            checkpointID: reviewPresentation.checkpointID
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}
