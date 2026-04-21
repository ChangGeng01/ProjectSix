import Foundation

enum DecisionEvolutionNarrativeFormattingSupport {
    static let separator = " • "

    static func joined(
        _ values: [String]
    ) -> String {
        values.joined(separator: separator)
    }

    static func labeledLine(
        prefix: String,
        values: [String]
    ) -> String? {
        prefixedLine(
            prefix: prefix,
            values: values,
            separatorAfterPrefix: ": "
        )
    }

    static func prefixedLine(
        prefix: String,
        values: [String],
        separatorAfterPrefix: String = " "
    ) -> String? {
        guard !values.isEmpty else { return nil }
        return "\(prefix)\(separatorAfterPrefix)\(joined(values))"
    }

    static func checkpointCountLine(
        _ count: Int,
        suffix: String
    ) -> String {
        "\(count) checkpoint(s) \(suffix)"
    }

    static func sovereignAuthorityValues(
        tokenScopes: [String],
        warrantScopes: [String],
        warrantPolicyIDs: [String],
        warrantTTLIDs: [String],
        warrantWitnessCount: Int,
        lockScopeID: String?,
        quarantineZoneIDs: [String],
        tokenScopeLimit: Int? = nil,
        warrantScopeLimit: Int? = nil,
        warrantPolicyLimit: Int? = nil,
        warrantTTLLimit: Int? = nil,
        quarantineZoneLimit: Int? = nil
    ) -> [String] {
        let summarizedTokenScopes = summarize(tokenScopes, limit: tokenScopeLimit)
        let summarizedWarrantScopes = summarize(warrantScopes, limit: warrantScopeLimit)
        let summarizedWarrantPolicies = summarize(warrantPolicyIDs, limit: warrantPolicyLimit)
        let summarizedWarrantTTLs = summarize(warrantTTLIDs, limit: warrantTTLLimit)
        let summarizedQuarantineZones = summarize(quarantineZoneIDs, limit: quarantineZoneLimit)

        return [
            summarizedTokenScopes.isEmpty ? nil : "tokens \(summarizedTokenScopes.joined(separator: ", "))",
            summarizedWarrantScopes.isEmpty ? nil : "warrants \(summarizedWarrantScopes.joined(separator: ", "))",
            summarizedWarrantPolicies.isEmpty ? nil : "policy \(summarizedWarrantPolicies.joined(separator: ", "))",
            summarizedWarrantTTLs.isEmpty ? nil : "ttl \(summarizedWarrantTTLs.joined(separator: ", "))",
            warrantWitnessCount > 0 ? "witnesses \(warrantWitnessCount)" : nil,
            lockScopeID.map { "lock \($0)" },
            summarizedQuarantineZones.isEmpty ? nil : "quarantine \(summarizedQuarantineZones.joined(separator: ", "))"
        ]
        .compactMap { $0 }
    }

    static func sovereignAuthorityLine(
        tokenScopes: [String],
        warrantScopes: [String],
        warrantPolicyIDs: [String],
        warrantTTLIDs: [String],
        warrantWitnessCount: Int,
        lockScopeID: String?,
        quarantineZoneIDs: [String],
        prefix: String = "Sovereign authority"
    ) -> String? {
        prefixedLine(
            prefix: prefix,
            separatorAfterPrefix: separator,
            values: sovereignAuthorityValues(
                tokenScopes: tokenScopes,
                warrantScopes: warrantScopes,
                warrantPolicyIDs: warrantPolicyIDs,
                warrantTTLIDs: warrantTTLIDs,
                warrantWitnessCount: warrantWitnessCount,
                lockScopeID: lockScopeID,
                quarantineZoneIDs: quarantineZoneIDs
            )
        )
    }

    private static func summarize(
        _ values: [String],
        limit: Int?
    ) -> [String] {
        guard let limit, limit >= 0 else {
            return values
        }
        return Array(values.prefix(limit))
    }
}

enum DecisionEvolutionControlSurfaceLexiconSupport {
    static let controlCenterNavigationTitle = "Evolution Control"
    static let controlCenterTitle = "Evolution control center"
    static let killSwitchControlPlaneTitle = "Kill-switch control plane"
    static let mutationCentralizedHeadline = "Mutations are centralized in \(controlCenterNavigationTitle)"
}

enum DecisionEvolutionSurfaceTitleLexiconSupport {
    static let homeTitle = "Home runtime"
    static let historyTitle = "History workbench"
    static let portraitTitle = "Portrait overview"
    static let settingsTitle = "Settings monitor"

    static func title(
        for surfaceKind: DecisionEvolutionSurfaceKind
    ) -> String {
        switch surfaceKind {
        case .home:
            homeTitle
        case .history:
            historyTitle
        case .portrait:
            portraitTitle
        case .settings:
            settingsTitle
        case .controlCenter:
            DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle
        }
    }
}

enum DecisionEvolutionMutationRoutingPresentationSupport {
    static let readFirstOperatorDetail = "This surface stays aligned as a read-first status view. Open the control center to mutate checkpoints without splitting review facts across multiple shells."
    static let mutationHubPilotDetail = "Work the review queue, restore the active checkpoint, and clear stale lineage from the dedicated mutation hub."

    static func routedPilotDetail(
        controlCenterTitle: String = DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle
    ) -> String {
        "See release blockers and queue state here, then jump into \(controlCenterTitle) for checkpoint mutations."
    }
}

enum DecisionEvolutionSurfaceBadgePresentationSupport {
    static func pendingReviewBadge(
        count: Int
    ) -> DecisionEvolutionSummaryBadgePresentation {
        DecisionEvolutionSummaryBadgePresentation(
            title: "\(count) PENDING",
            tone: count > 0 ? .orange : .secondary
        )
    }

    static func rollbackReadyBadge(
        count: Int
    ) -> DecisionEvolutionSummaryBadgePresentation {
        DecisionEvolutionSummaryBadgePresentation(
            title: DecisionEvolutionCheckpointLexiconSupport.rollbackReadyCountBadgeTitle(count),
            tone: count > 0 ? .moss : .secondary
        )
    }

    static func lineageBackedBadge(
        count: Int
    ) -> DecisionEvolutionSummaryBadgePresentation? {
        guard count > 0 else { return nil }
        return DecisionEvolutionSummaryBadgePresentation(
            title: "\(count) LINEAGE-BACKED",
            tone: .ember
        )
    }
}

enum DecisionEvolutionLineagePresentationSupport {
    static func pendingReviewLineageNotice(
        pendingReviewLineageCount: Int,
        hasReleaseSummary: Bool
    ) -> String? {
        guard hasReleaseSummary, pendingReviewLineageCount > 0 else { return nil }
        return "\(pendingReviewLineageCount) pending checkpoints still carry recovered lineage."
    }

    static func retainedPendingReviewFactsLine(
        lineageBackedCount: Int
    ) -> String? {
        guard lineageBackedCount > 0 else { return nil }
        return "\(lineageBackedCount) lineage-backed review checkpoint(s) keep their recovered facts."
    }

    static func retainedSelectedFactsAfterApprovalLine(
        lineageBackedCount: Int
    ) -> String? {
        guard lineageBackedCount > 0 else { return nil }
        return "\(lineageBackedCount) selected checkpoint(s) keep their recovered lineage facts after approval."
    }
}

enum DecisionEvolutionMutationHubPresentationSupport {
    static let headline = "Mutation hub"
    static let operatorDetail = "Apply, approve, rollback, and lineage-clearing actions stay available in this dedicated control surface."
    static let releaseSummaryDetail = "Release readiness is summarized once here. Apply, approve, rollback, and lineage-clearing actions live in the mutation workspace below."
    static let quickActionsTitle = "Quick actions"
    static let restoreActivePathTitle = "Restore active path"
    static let rollbackActivePathTitle = "Rollback active path"
    static let approveQueueTitle = "Approve queue"
    static let clearQueueLineageTitle = "Clear queue lineage"
}

enum DecisionEvolutionBatchMutationLexiconSupport {
    static let headerTitle = "Batch mutation workspace"
    static let headerDetail = "Select checkpoints from the control surface, then run guarded batch actions without drilling into every card."
    static let selectAllTitle = "Select all"
    static let reviewQueueTitle = "Review queue"
    static let lineageBackedTitle = "Lineage-backed"
    static let clearSelectionTitle = "Clear"
    static let applySelectedTitle = "Apply selected"
    static let emptySelectionLine = "Pick one or more checkpoints to unlock selection-scoped approve / mark-review / clear-lineage mutations here."
    static let emptySelectionSummary = "No checkpoints are selected yet. Pick a slice of the control surface, then run guarded batch mutations from here."
    static let reviewSelectionToken = "review"
    static let automaticSelectionToken = "automatic"
    static let lineageBackedSelectionToken = "lineage-backed"
}

enum DecisionEvolutionCheckpointMutationLexiconSupport {
    static let markCheckpointTitle = "Mark checkpoint"
    static let clearCheckpointLineageTitle = "Clear checkpoint lineage"
}

enum DecisionEvolutionKillSwitchControlLexiconSupport {
    static let mutationHeaderDetail = "Promote runtime kill switches from suggestions into a real host-controlled policy surface."
    static let applyRecommendedTitle = "Apply recommended"
    static let clearActiveTitle = "Clear active switches"
    static let enableTitle = "Enable"
    static let disableTitle = "Disable"
    static let activeStateBadgeTitle = "ACTIVE"
    static let recommendedStateBadgeTitle = "RECOMMENDED"
    static let recommendedPrefix = "Recommended"

    static func readOnlyHeaderDetail(
        controlCenterTitle: String = DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle
    ) -> String {
        "This surface shows the active runtime kill-switch policy. Open \(controlCenterTitle) to mutate it."
    }

    static func recommendedLine(
        ids: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: recommendedPrefix,
            values: ids
        )
    }
}

enum DecisionEvolutionReadFirstNarrativeSupport {
    static let settingsTitle = "Read-first evolution control"
    static let settingsDetail = "Settings mirrors the shared evolution workspace, but routes any mutation work to the control center."

    static func settingsPresentation(
        refreshTitle: String = DecisionEvolutionSurfaceStatusPresentationSupport.refreshTitle
    ) -> DecisionEvolutionReadFirstSurfacePresentation {
        DecisionEvolutionReadFirstSurfacePresentation(
            title: settingsTitle,
            detail: settingsDetail,
            refreshTitle: refreshTitle
        )
    }
}

enum DecisionEvolutionHistoryTrailLexiconSupport {
    static let sectionSubtitle = "Checkpoint lineage, risk permits, review state, rollback readiness, and queue operations now stay visible in one full workspace."
    static let workspaceTitle = "Evolution trail"
    static let filterTitle = "Evolution filter"
    static let queueSectionTitle = "Pending review queue"
    static let queueSectionDetail = "Every remaining review-suggested checkpoint stays operable here, not just the queue head."
    static let historySectionTitle = "Checkpoint history"
    static let historySectionDetail = "The full recovered trail stays browseable here even after the active/review spotlight changes."

    static func inventoryLine(
        checkpointCount: Int,
        pendingReviewCount: Int,
        rollbackReadyCount: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "\(checkpointCount) checkpoints",
            "\(pendingReviewCount) pending review",
            "\(rollbackReadyCount) rollback-ready"
        ])
    }

    static func queueSection() -> DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentation(
            title: queueSectionTitle,
            detail: queueSectionDetail,
            emptyMessage: nil
        )
    }

    static func historySection() -> DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentation(
            title: historySectionTitle,
            detail: historySectionDetail,
            emptyMessage: nil
        )
    }
}

enum DecisionEvolutionHomeQueueLexiconSupport {
    static let title = "Evolution review queue"
    static let detail = "Home keeps the review head in spotlight, while the remaining queue stays visible here and mutations stay centralized in Evolution Control."

    static func queuedBadgeTitle(
        count: Int
    ) -> String {
        "\(count) queued"
    }

    static func countsLine(
        totalPendingReviewCount: Int,
        spotlightedPendingReviewCount: Int,
        queuedPendingReviewCount: Int
    ) -> String? {
        guard spotlightedPendingReviewCount > 0 else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Total pending \(totalPendingReviewCount)",
            "review head \(spotlightedPendingReviewCount)",
            "queue tail \(queuedPendingReviewCount)"
        ])
    }
}

enum DecisionEvolutionSurfaceKind: String, CaseIterable, Equatable, Sendable {
    case home
    case history
    case portrait
    case settings
    case controlCenter
}

struct DecisionEvolutionSurfaceContract: Equatable, Sendable {
    let kind: DecisionEvolutionSurfaceKind
    let interactionMode: DecisionEvolutionControlInteractionMode
    let releaseSummaryMode: DecisionEvolutionReleaseSummaryPresentationMode
    let showsEmbeddedReleaseSummaryInPilotPanel: Bool
    let showsCheckpointActionBarInSummary: Bool
    let routesMutationsToControlCenter: Bool

    var allowsMutations: Bool {
        !routesMutationsToControlCenter
    }

    var showsControlCenterShortcut: Bool {
        routesMutationsToControlCenter
    }

    var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        switch kind {
        case .home, .settings:
            navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        case .history:
            navigationSurfaceOptions(showPortraitShortcut: true)
        case .portrait:
            navigationSurfaceOptions(showHistoryShortcut: true)
        case .controlCenter:
            navigationSurfaceOptions()
        }
    }

    static let home = DecisionEvolutionSurfaceContract(
        kind: .home,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let history = DecisionEvolutionSurfaceContract(
        kind: .history,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let portrait = DecisionEvolutionSurfaceContract(
        kind: .portrait,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .surface,
        showsEmbeddedReleaseSummaryInPilotPanel: true,
        showsCheckpointActionBarInSummary: true,
        routesMutationsToControlCenter: true
    )

    static let settings = DecisionEvolutionSurfaceContract(
        kind: .settings,
        interactionMode: .observeAndRoute,
        releaseSummaryMode: .compact,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false,
        routesMutationsToControlCenter: true
    )

    static let controlCenter = DecisionEvolutionSurfaceContract(
        kind: .controlCenter,
        interactionMode: .mutationHub,
        releaseSummaryMode: .mutationHub,
        showsEmbeddedReleaseSummaryInPilotPanel: false,
        showsCheckpointActionBarInSummary: false,
        routesMutationsToControlCenter: false
    )

    static func contract(for kind: DecisionEvolutionSurfaceKind) -> DecisionEvolutionSurfaceContract {
        switch kind {
        case .home:
            .home
        case .history:
            .history
        case .portrait:
            .portrait
        case .settings:
            .settings
        case .controlCenter:
            .controlCenter
        }
    }

    func summarySurfaceOptions(
        showCheckpointActionBar overrideShowCheckpointActionBar: Bool? = nil,
        showControlCenterShortcut overrideShowControlCenterShortcut: Bool? = nil,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false
    ) -> DecisionEvolutionSummarySurfaceOptions {
        let navigationOptions = navigationSurfaceOptions(
            showControlCenterShortcut: overrideShowControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
        return DecisionEvolutionSummarySurfaceOptions(
            showCheckpointActionBar: overrideShowCheckpointActionBar ?? showsCheckpointActionBarInSummary,
            showControlCenterShortcut: navigationOptions.showControlCenterShortcut,
            showHistoryShortcut: navigationOptions.showHistoryShortcut,
            showPortraitShortcut: navigationOptions.showPortraitShortcut
        )
    }

    func summarySurfaceOptions(
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        showCheckpointActionBar overrideShowCheckpointActionBar: Bool? = nil
    ) -> DecisionEvolutionSummarySurfaceOptions {
        DecisionEvolutionSummarySurfaceOptions(
            showCheckpointActionBar: overrideShowCheckpointActionBar ?? showsCheckpointActionBarInSummary,
            showControlCenterShortcut: navigationOptions.showControlCenterShortcut,
            showHistoryShortcut: navigationOptions.showHistoryShortcut,
            showPortraitShortcut: navigationOptions.showPortraitShortcut
        )
    }

    func navigationSurfaceOptions(
        showControlCenterShortcut overrideShowControlCenterShortcut: Bool? = nil,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false
    ) -> DecisionEvolutionNavigationSurfaceOptions {
        DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: overrideShowControlCenterShortcut ?? showsControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
    }
}

struct DecisionEvolutionNavigationSurfaceOptions: Equatable, Sendable {
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool

    var showsAnyShortcut: Bool {
        showControlCenterShortcut || showHistoryShortcut || showPortraitShortcut
    }

    var preferredDestination: DecisionEvolutionNavigationDestination? {
        if showControlCenterShortcut {
            return .controlCenter
        }

        if showHistoryShortcut {
            return .history
        }

        if showPortraitShortcut {
            return .portrait
        }

        return nil
    }
}

enum DecisionEvolutionNavigationDestination: String, Equatable, Sendable {
    case controlCenter
    case history
    case portrait

    func actionTitle(routesMutationsToControlCenter: Bool) -> String {
        switch self {
        case .controlCenter:
            return routesMutationsToControlCenter ? "Open control center" : "Control center"
        case .history:
            return "Open History"
        case .portrait:
            return "Open Portrait"
        }
    }
}

struct DecisionEvolutionSummarySurfaceOptions: Equatable, Sendable {
    let showCheckpointActionBar: Bool
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool

    var navigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: showControlCenterShortcut,
            showHistoryShortcut: showHistoryShortcut,
            showPortraitShortcut: showPortraitShortcut
        )
    }
}

enum DecisionEvolutionOperatorFooterStyleRole: Equatable, Sendable {
    case primary
    case secondary
    case tertiary
}

struct DecisionEvolutionOperatorFooterPresentation: Equatable, Sendable {
    let headline: String
    let detail: String
    let interactionMode: DecisionEvolutionControlInteractionMode
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let routesMutationsToControlCenter: Bool
    let showsDetail: Bool
    let controlCenterStyle: DecisionEvolutionOperatorFooterStyleRole
    let adjacentShortcutStyle: DecisionEvolutionOperatorFooterStyleRole

    var navigationRowPresentation: DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentation(
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: routesMutationsToControlCenter,
            controlCenterTitle: DecisionEvolutionNavigationDestination.controlCenter.actionTitle(
                routesMutationsToControlCenter: routesMutationsToControlCenter
            ),
            controlCenterStyle: controlCenterStyle,
            adjacentShortcutStyle: adjacentShortcutStyle,
            historyTitle: DecisionEvolutionNavigationRowPresentationSupport.historyTitle,
            portraitTitle: DecisionEvolutionNavigationRowPresentationSupport.portraitTitle
        )
    }
}

struct DecisionEvolutionNavigationRowPresentation: Equatable, Sendable {
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let routesMutationsToControlCenter: Bool
    let controlCenterTitle: String?
    let controlCenterStyle: DecisionEvolutionOperatorFooterStyleRole
    let adjacentShortcutStyle: DecisionEvolutionOperatorFooterStyleRole
    let historyTitle: String
    let portraitTitle: String
}

struct DecisionEvolutionBatchMutationPresentation: Equatable, Sendable {
    let headerTitle: String
    let headerDetail: String
    let selectAllTitle: String
    let reviewQueueTitle: String
    let automaticTitle: String
    let lineageBackedTitle: String
    let clearSelectionTitle: String
    let targetsPrefix: String
    let applySelectedTitle: String
    let approveSelectedTitle: String
    let markSelectedTitle: String
    let clearSelectedLineageTitle: String
    let emptySelectionLine: String?
    let readOnlyHeadline: String?
    let readOnlyDetail: String?
}

struct DecisionEvolutionBatchMutationSelectionPresentation: Equatable, Sendable {
    let summaryLine: String
    let usesAccentTone: Bool
    let targetsLine: String?
}

enum DecisionEvolutionCheckpointSecondaryActionKind: Equatable, Sendable {
    case approve
    case markForReview
}

struct DecisionEvolutionCheckpointActionPresentation: Equatable, Sendable {
    let showsMutationActions: Bool
    let showsApplyAction: Bool
    let secondaryActionKind: DecisionEvolutionCheckpointSecondaryActionKind?
    let showsClearLineageAction: Bool
    let footerPresentation: DecisionEvolutionOperatorFooterPresentation?
    let navigationPresentation: DecisionEvolutionNavigationRowPresentation?

    let applyTitle: String
    let approveTitle: String
    let markTitle: String
    let clearLineageTitle: String
}

struct DecisionEvolutionKillSwitchPanelPresentation: Equatable, Sendable {
    let headerTitle: String
    let headerDetail: String
    let activeBadgeTitle: String
    let recommendedBadgeTitle: String
    let recommendedLine: String?
    let showsMutationActions: Bool
    let footerPresentation: DecisionEvolutionOperatorFooterPresentation?
    let applyRecommendedTitle: String
    let clearActiveTitle: String
    let enableTitle: String
    let disableTitle: String
    let activeStateBadgeTitle: String
    let recommendedStateBadgeTitle: String
}

struct DecisionEvolutionSectionPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let emptyMessage: String?
}

struct DecisionEvolutionControlCenterHeaderPresentation: Equatable, Sendable {
    let navigationTitle: String
    let title: String
    let detail: String
    let refreshTitle: String
    let dismissTitle: String
}

struct DecisionEvolutionHistoryTrailPresentation: Equatable, Sendable {
    let sectionTitle: String
    let sectionSubtitle: String
    let workspaceTitle: String
    let refreshTitle: String
    let queueSection: DecisionEvolutionSectionPresentation
    let historySection: DecisionEvolutionSectionPresentation
    let filterTitle: String

    func inventoryLine(
        checkpointCount: Int,
        pendingReviewCount: Int,
        rollbackReadyCount: Int
    ) -> String {
        DecisionEvolutionHistoryTrailLexiconSupport.inventoryLine(
            checkpointCount: checkpointCount,
            pendingReviewCount: pendingReviewCount,
            rollbackReadyCount: rollbackReadyCount
        )
    }
}

struct DecisionEvolutionHomeQueuePresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let queuedBadgeTitle: String
    let countsLine: String?
}

struct DecisionEvolutionReadFirstSurfacePresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let refreshTitle: String
}

enum DecisionEvolutionSurfaceStatusPresentationSupport {
    static let doneTitle = "Done"
    static let refreshTitle = "Refresh"
    static let refreshingTitle = "Refreshing…"

    static func summaryEmptyMessage(
        for surfaceKind: DecisionEvolutionSurfaceKind
    ) -> String? {
        switch surfaceKind {
        case .history:
            "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this summary will show its risk, permit, tickets, audit, and rollback readiness."
        case .settings:
            "No persisted checkpoint lineage is attached yet. Once review traffic appears, Settings will mirror the shared evolution workspace here."
        case .controlCenter:
            "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this control center will show active risk, permit, rollback and review facts."
        case .home, .portrait:
            nil
        }
    }

    static func settingsReadFirstPresentation() -> DecisionEvolutionReadFirstSurfacePresentation {
        DecisionEvolutionReadFirstNarrativeSupport.settingsPresentation(
            refreshTitle: refreshTitle
        )
    }
}

enum DecisionEvolutionHistoryTrailPresentationSupport {
    static func build() -> DecisionEvolutionHistoryTrailPresentation {
        DecisionEvolutionHistoryTrailPresentation(
            sectionTitle: DecisionEvolutionControlSurfaceLexiconSupport.controlCenterTitle,
            sectionSubtitle: DecisionEvolutionHistoryTrailLexiconSupport.sectionSubtitle,
            workspaceTitle: DecisionEvolutionHistoryTrailLexiconSupport.workspaceTitle,
            refreshTitle: DecisionEvolutionSurfaceStatusPresentationSupport.refreshTitle,
            queueSection: DecisionEvolutionHistoryTrailLexiconSupport.queueSection(),
            historySection: DecisionEvolutionHistoryTrailLexiconSupport.historySection(),
            filterTitle: DecisionEvolutionHistoryTrailLexiconSupport.filterTitle
        )
    }
}

enum DecisionEvolutionHomeQueuePresentationSupport {
    static func build(
        totalPendingReviewCount: Int,
        spotlightedPendingReviewCount: Int,
        queuedPendingReviewCount: Int
    ) -> DecisionEvolutionHomeQueuePresentation {
        DecisionEvolutionHomeQueuePresentation(
            title: DecisionEvolutionHomeQueueLexiconSupport.title,
            detail: DecisionEvolutionHomeQueueLexiconSupport.detail,
            queuedBadgeTitle: DecisionEvolutionHomeQueueLexiconSupport.queuedBadgeTitle(
                count: queuedPendingReviewCount
            ),
            countsLine: DecisionEvolutionHomeQueueLexiconSupport.countsLine(
                totalPendingReviewCount: totalPendingReviewCount,
                spotlightedPendingReviewCount: spotlightedPendingReviewCount,
                queuedPendingReviewCount: queuedPendingReviewCount
            )
        )
    }
}

enum DecisionEvolutionCheckpointRole: Equatable, Sendable {
    case active
    case reviewHead
}

struct DecisionEvolutionCheckpointRolePresentation: Equatable, Sendable {
    let title: String
}

enum DecisionEvolutionControlCenterSectionKind: Equatable, Sendable {
    case releaseReadiness
    case killSwitchControlPlane
    case operatorMutationHub
    case checkpointSpotlight
    case activeCheckpointWorkspace
    case reviewHeadWorkspace
    case pendingReviewQueue
    case recoveredCheckpointHistory
}

enum DecisionEvolutionControlCenterNarrativeSupport {
    static let headerDetail = "Operate the full L13 review path from one place: active checkpoint, review head, pending queue, release readiness, rollback, and persisted lineage."
    static let releaseReadinessTitle = "Release readiness"
    static let releaseReadinessDetail = "One summary strip for rollout state, blockers, rollback readiness, and kill-switch posture."
    static let releaseReadinessEmptyMessage = "Release readiness will appear here once a flight-deck summary is available."
    static let operatorMutationHubTitle = "Operator mutation hub"
    static let operatorMutationHubDetail = "Queue-wide pilot controls and selection-scoped checkpoint mutations now live in one guarded workspace."
    static let checkpointSpotlightTitle = "Checkpoint spotlight"
    static let checkpointSpotlightDetail = "Keep the current active checkpoint and review head visible even as the queue evolves."
    static let activeCheckpointWorkspaceTitle = "Active checkpoint workspace"
    static let activeCheckpointWorkspaceDetail = "Mutate the live active path without losing sight of restored lineage and rollback readiness."
    static let reviewHeadWorkspaceTitle = "Review head workspace"
    static let reviewHeadWorkspaceDetail = "Work the queue head directly without collapsing the rest of the pending review backlog."
    static let pendingReviewQueueTitle = "Pending review queue"
    static let pendingReviewQueueDetail = "The remaining review-suggested checkpoints stay operable here instead of being hidden behind the queue head."
    static let recoveredCheckpointHistoryTitle = "Recovered checkpoint history"
    static let recoveredCheckpointHistoryDetail = "Recovered lineage history remains browseable here even after the active and review spotlight changes."

    static func section(
        _ kind: DecisionEvolutionControlCenterSectionKind
    ) -> DecisionEvolutionSectionPresentation {
        switch kind {
        case .releaseReadiness:
            DecisionEvolutionSectionPresentation(
                title: releaseReadinessTitle,
                detail: releaseReadinessDetail,
                emptyMessage: releaseReadinessEmptyMessage
            )
        case .killSwitchControlPlane:
            DecisionEvolutionSectionPresentation(
                title: DecisionEvolutionControlSurfaceLexiconSupport.killSwitchControlPlaneTitle,
                detail: DecisionEvolutionKillSwitchControlLexiconSupport.mutationHeaderDetail,
                emptyMessage: nil
            )
        case .operatorMutationHub:
            DecisionEvolutionSectionPresentation(
                title: operatorMutationHubTitle,
                detail: operatorMutationHubDetail,
                emptyMessage: nil
            )
        case .checkpointSpotlight:
            DecisionEvolutionSectionPresentation(
                title: checkpointSpotlightTitle,
                detail: checkpointSpotlightDetail,
                emptyMessage: DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(
                    for: .controlCenter
                )
            )
        case .activeCheckpointWorkspace:
            DecisionEvolutionSectionPresentation(
                title: activeCheckpointWorkspaceTitle,
                detail: activeCheckpointWorkspaceDetail,
                emptyMessage: nil
            )
        case .reviewHeadWorkspace:
            DecisionEvolutionSectionPresentation(
                title: reviewHeadWorkspaceTitle,
                detail: reviewHeadWorkspaceDetail,
                emptyMessage: nil
            )
        case .pendingReviewQueue:
            DecisionEvolutionSectionPresentation(
                title: pendingReviewQueueTitle,
                detail: pendingReviewQueueDetail,
                emptyMessage: nil
            )
        case .recoveredCheckpointHistory:
            DecisionEvolutionSectionPresentation(
                title: recoveredCheckpointHistoryTitle,
                detail: recoveredCheckpointHistoryDetail,
                emptyMessage: nil
            )
        }
    }
}

enum DecisionEvolutionOperatorFooterPresentationSupport {
    static func releaseSummary(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionOperatorFooterPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            showsDetail: false,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .secondary
        )
    }

    static func pilotControl(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionOperatorFooterPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            showsDetail: true,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .tertiary
        )
    }

    static func checkpointAction(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionOperatorFooterPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            showsDetail: true,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .secondary
        )
    }

    static func killSwitchPanel(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionOperatorFooterPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            showsDetail: false,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .secondary
        )
    }

    private static func build(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        showsDetail: Bool,
        controlCenterStyle: DecisionEvolutionOperatorFooterStyleRole,
        adjacentShortcutStyle: DecisionEvolutionOperatorFooterStyleRole
    ) -> DecisionEvolutionOperatorFooterPresentation {
        DecisionEvolutionOperatorFooterPresentation(
            headline: surfaceContract.interactionMode.operatorHeadline,
            detail: surfaceContract.interactionMode.operatorDetail,
            interactionMode: surfaceContract.interactionMode,
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
            showsDetail: showsDetail,
            controlCenterStyle: controlCenterStyle,
            adjacentShortcutStyle: adjacentShortcutStyle
        )
    }
}

enum DecisionEvolutionNavigationRowPresentationSupport {
    static let historyTitle = DecisionEvolutionNavigationDestination.history.actionTitle(
        routesMutationsToControlCenter: true
    )
    static let portraitTitle = DecisionEvolutionNavigationDestination.portrait.actionTitle(
        routesMutationsToControlCenter: true
    )

    static func readFirstSurface(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionNavigationRowPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .secondary
        )
    }

    static func settingsReadFirst(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionNavigationRowPresentation {
        readFirstSurface(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions
        )
    }

    static func pilotMutationHub(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionNavigationRowPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            controlCenterStyle: .tertiary,
            adjacentShortcutStyle: .tertiary
        )
    }

    static func checkpointMutationHub(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionNavigationRowPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            controlCenterStyle: .secondary,
            adjacentShortcutStyle: .secondary
        )
    }

    static func controlCenterCompanion(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionNavigationRowPresentation {
        build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            controlCenterStyle: .secondary,
            adjacentShortcutStyle: .secondary
        )
    }

    private static func build(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        controlCenterStyle: DecisionEvolutionOperatorFooterStyleRole,
        adjacentShortcutStyle: DecisionEvolutionOperatorFooterStyleRole
    ) -> DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentation(
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
            controlCenterTitle: nil,
            controlCenterStyle: controlCenterStyle,
            adjacentShortcutStyle: adjacentShortcutStyle,
            historyTitle: historyTitle,
            portraitTitle: portraitTitle
        )
    }
}

enum DecisionEvolutionBatchMutationPresentationSupport {
    static func build(
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionBatchMutationPresentation {
        DecisionEvolutionBatchMutationPresentation(
            headerTitle: DecisionEvolutionBatchMutationLexiconSupport.headerTitle,
            headerDetail: DecisionEvolutionBatchMutationLexiconSupport.headerDetail,
            selectAllTitle: DecisionEvolutionBatchMutationLexiconSupport.selectAllTitle,
            reviewQueueTitle: DecisionEvolutionBatchMutationLexiconSupport.reviewQueueTitle,
            automaticTitle: DecisionEvolutionCheckpointLexiconSupport.automaticApprovalTitle,
            lineageBackedTitle: DecisionEvolutionBatchMutationLexiconSupport.lineageBackedTitle,
            clearSelectionTitle: DecisionEvolutionBatchMutationLexiconSupport.clearSelectionTitle,
            targetsPrefix: DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix,
            applySelectedTitle: DecisionEvolutionBatchMutationLexiconSupport.applySelectedTitle,
            approveSelectedTitle: DecisionEvolutionMutationActionLexiconSupport.approveSelectedTitle,
            markSelectedTitle: DecisionEvolutionMutationActionLexiconSupport.markSelectedTitle,
            clearSelectedLineageTitle: DecisionEvolutionMutationActionLexiconSupport.clearSelectedLineageTitle,
            emptySelectionLine: surfaceContract.allowsMutations
                ? DecisionEvolutionBatchMutationLexiconSupport.emptySelectionLine
                : nil,
            readOnlyHeadline: surfaceContract.allowsMutations
                ? nil
                : surfaceContract.interactionMode.operatorHeadline,
            readOnlyDetail: surfaceContract.allowsMutations
                ? nil
                : surfaceContract.interactionMode.operatorDetail
        )
    }
}

enum DecisionEvolutionBatchMutationSelectionPresentationSupport {
    static let emptySelectionSummary = DecisionEvolutionBatchMutationLexiconSupport.emptySelectionSummary

    static func build(
        selection: DecisionEvolutionBatchMutationSelection,
        targetsPrefix: String
    ) -> DecisionEvolutionBatchMutationSelectionPresentation {
        let summaryLine: String
        if selection.selectedPresentations.isEmpty {
            summaryLine = emptySelectionSummary
        } else {
            var parts = ["\(selection.selectedPresentations.count) selected"]
            if !selection.selectedReviewPresentations.isEmpty {
                parts.append("\(selection.selectedReviewPresentations.count) \(DecisionEvolutionBatchMutationLexiconSupport.reviewSelectionToken)")
            }
            if !selection.selectedAutomaticPresentations.isEmpty {
                parts.append("\(selection.selectedAutomaticPresentations.count) \(DecisionEvolutionBatchMutationLexiconSupport.automaticSelectionToken)")
            }
            if !selection.selectedLineagePresentations.isEmpty {
                parts.append("\(selection.selectedLineagePresentations.count) \(DecisionEvolutionBatchMutationLexiconSupport.lineageBackedSelectionToken)")
            }
            summaryLine = DecisionEvolutionNarrativeFormattingSupport.joined(parts)
        }

        let targetsLine = selection.selectedPresentations.isEmpty
            ? nil
            : DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: targetsPrefix,
                values: selection.selectedPresentations.map(\.checkpointID)
            )

        return DecisionEvolutionBatchMutationSelectionPresentation(
            summaryLine: summaryLine,
            usesAccentTone: selection.hasSelection,
            targetsLine: targetsLine
        )
    }
}

enum DecisionEvolutionCheckpointActionPresentationSupport {
    static func build(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        applyReady: Bool,
        approvalState: DecisionEvolutionApprovalState?,
        hasLineage: Bool
    ) -> DecisionEvolutionCheckpointActionPresentation {
        let actionAvailability = DecisionEvolutionPolicyEngine.checkpointActionAvailability(
            allowsLocalMutationActions: surfaceContract.allowsMutations,
            applyReady: applyReady,
            approvalState: approvalState,
            hasLineage: hasLineage
        )
        return DecisionEvolutionCheckpointActionPresentation(
            showsMutationActions: actionAvailability.showsMutationActions,
            showsApplyAction: actionAvailability.canApply,
            secondaryActionKind: actionAvailability.secondaryActionKind,
            showsClearLineageAction: actionAvailability.canClearLineage,
            footerPresentation: actionAvailability.showsMutationActions
                ? nil
                : DecisionEvolutionOperatorFooterPresentationSupport.checkpointAction(
                    surfaceContract: surfaceContract,
                    navigationOptions: navigationOptions
                ),
            navigationPresentation: actionAvailability.showsMutationActions && navigationOptions.showsAnyShortcut
                ? DecisionEvolutionNavigationRowPresentationSupport.checkpointMutationHub(
                    surfaceContract: surfaceContract,
                    navigationOptions: navigationOptions
                )
                : nil,
            applyTitle: DecisionEvolutionMutationActionLexiconSupport.applyCheckpointTitle,
            approveTitle: DecisionEvolutionMutationActionLexiconSupport.approveCheckpointTitle,
            markTitle: DecisionEvolutionCheckpointMutationLexiconSupport.markCheckpointTitle,
            clearLineageTitle: DecisionEvolutionCheckpointMutationLexiconSupport.clearCheckpointLineageTitle
        )
    }
}

enum DecisionEvolutionKillSwitchPanelPresentationSupport {
    static func build(
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions,
        activeKillSwitchCount: Int,
        recommendedKillSwitchIDs: [String],
        unresolvedRecommendedCount: Int
    ) -> DecisionEvolutionKillSwitchPanelPresentation {
        let allowsMutations = surfaceContract.allowsMutations
        return DecisionEvolutionKillSwitchPanelPresentation(
            headerTitle: DecisionEvolutionControlSurfaceLexiconSupport.killSwitchControlPlaneTitle,
            headerDetail: allowsMutations
                ? DecisionEvolutionKillSwitchControlLexiconSupport.mutationHeaderDetail
                : DecisionEvolutionKillSwitchControlLexiconSupport.readOnlyHeaderDetail(),
            activeBadgeTitle: "\(activeKillSwitchCount) ACTIVE",
            recommendedBadgeTitle: "\(unresolvedRecommendedCount) RECOMMENDED",
            recommendedLine: DecisionEvolutionKillSwitchControlLexiconSupport.recommendedLine(
                ids: recommendedKillSwitchIDs
            ),
            showsMutationActions: allowsMutations,
            footerPresentation: allowsMutations || !navigationOptions.showsAnyShortcut
                ? nil
                : DecisionEvolutionOperatorFooterPresentationSupport.killSwitchPanel(
                    surfaceContract: surfaceContract,
                    navigationOptions: navigationOptions
                ),
            applyRecommendedTitle: DecisionEvolutionKillSwitchControlLexiconSupport.applyRecommendedTitle,
            clearActiveTitle: DecisionEvolutionKillSwitchControlLexiconSupport.clearActiveTitle,
            enableTitle: DecisionEvolutionKillSwitchControlLexiconSupport.enableTitle,
            disableTitle: DecisionEvolutionKillSwitchControlLexiconSupport.disableTitle,
            activeStateBadgeTitle: DecisionEvolutionKillSwitchControlLexiconSupport.activeStateBadgeTitle,
            recommendedStateBadgeTitle: DecisionEvolutionKillSwitchControlLexiconSupport.recommendedStateBadgeTitle
        )
    }
}

enum DecisionEvolutionSectionPresentationSupport {
    static func controlCenterHeader() -> DecisionEvolutionControlCenterHeaderPresentation {
        DecisionEvolutionControlCenterHeaderPresentation(
            navigationTitle: DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle,
            title: DecisionEvolutionControlSurfaceLexiconSupport.controlCenterTitle,
            detail: DecisionEvolutionControlCenterNarrativeSupport.headerDetail,
            refreshTitle: DecisionEvolutionSurfaceStatusPresentationSupport.refreshTitle,
            dismissTitle: DecisionEvolutionSurfaceStatusPresentationSupport.doneTitle
        )
    }

    static func checkpointRole(
        _ role: DecisionEvolutionCheckpointRole
    ) -> DecisionEvolutionCheckpointRolePresentation {
        DecisionEvolutionCheckpointRolePresentation(
            title: DecisionEvolutionCheckpointLexiconSupport.checkpointRoleTitle(role)
        )
    }

    static func controlCenter(
        _ kind: DecisionEvolutionControlCenterSectionKind
    ) -> DecisionEvolutionSectionPresentation {
        DecisionEvolutionControlCenterNarrativeSupport.section(kind)
    }
}

enum DecisionEvolutionControlSurfaceSummaryPresentationSupport {
    static func sectionTitle(
        for role: DecisionEvolutionCheckpointRole
    ) -> String {
        DecisionEvolutionCheckpointLexiconSupport.checkpointRoleTitle(role)
    }

    static func sectionPresentation(
        role: DecisionEvolutionCheckpointRole,
        presentation: DecisionEvolutionCheckpointPresentation,
        activeSource: DecisionEvolutionActiveCheckpointSource = .none
    ) -> DecisionEvolutionControlSurfaceSummarySectionPresentation {
        DecisionEvolutionControlSurfaceSummarySectionPresentation(
            role: role,
            title: sectionTitle(for: role),
            presentation: presentation,
            summaryBadges: role == .active
                ? presentation.summaryBadgePresentations(activeSource: activeSource)
                : presentation.summaryBadgePresentations()
        )
    }
}

extension DecisionEvolutionOperatorFooterStyleRole {
    var buttonStyle: BeforeActionButton.Style {
        switch self {
        case .primary:
            .primary
        case .secondary:
            .secondary
        case .tertiary:
            .tertiary
        }
    }
}
