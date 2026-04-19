import Foundation

enum DecisionEvolutionReleasePathPresentationSupport {
    static let blockedActiveKillSwitchHeadline = DecisionEvolutionKillSwitchPresentationSupport.blockedReleaseHeadline
    static let watchingRecommendedKillSwitchesHeadline = DecisionEvolutionKillSwitchPresentationSupport.recommendedReleaseHeadline
    static let blockedRuntimeGuardrailsHeadline = DecisionEvolutionReleaseStagePresentationSupport.blockedRuntimeGuardrailsHeadline
    static let watchingFirstActiveCheckpointHeadline = DecisionEvolutionRestorabilityPresentationSupport.waitingForFirstActiveCheckpointHeadline
    static let blockedUntilRestorableHeadline = DecisionEvolutionRestorabilityPresentationSupport.blockedUntilRestorableHeadline
    static let watchingPendingReviewHeadline = DecisionEvolutionPendingReviewPresentationSupport.releaseHeadline
    static let watchingAuditFindingsHeadline = DecisionEvolutionReleaseStagePresentationSupport.watchingAuditFindingsHeadline
    static let watchingRollbackReadinessHeadline = DecisionEvolutionRestorabilityPresentationSupport.watchingRollbackReadinessHeadline
    static let readyForGuardedPilotHeadline = DecisionEvolutionReleaseStagePresentationSupport.readyForGuardedPilotHeadline

    static let activeKillSwitchReason = DecisionEvolutionKillSwitchPresentationSupport.blockedReleaseReason
    static let noActiveCheckpointReason = DecisionEvolutionRestorabilityPresentationSupport.noActiveCheckpointReason
    static let activeCheckpointNotRestorableReason = DecisionEvolutionRestorabilityPresentationSupport.blockedReason
    static let rollbackNotReadyReason = DecisionEvolutionReleaseStagePresentationSupport.rollbackNotReadyReason

    static func activeCheckpointRestorableReason(
        checkpointID: String?
    ) -> String {
        DecisionEvolutionRestorabilityPresentationSupport.activeCheckpointRestorableReason(
            checkpointID: checkpointID
        )
    }
}

enum DecisionEvolutionReleaseSummaryPresentationSupport {
    static let activeSourcePrefix = "Active source"

    static func operatorHeadline(
        for presentationMode: DecisionEvolutionReleaseSummaryPresentationMode
    ) -> String? {
        switch presentationMode {
        case .mutationHub:
            DecisionEvolutionMutationHubPresentationSupport.headline
        case .surface, .compact:
            nil
        }
    }

    static func operatorDetail(
        for presentationMode: DecisionEvolutionReleaseSummaryPresentationMode
    ) -> String? {
        switch presentationMode {
        case .mutationHub:
            DecisionEvolutionMutationHubPresentationSupport.releaseSummaryDetail
        case .surface, .compact:
            nil
        }
    }

    static func stateTone(
        _ state: DecisionSystemReleaseState
    ) -> DecisionEvolutionSummaryBadgeTone {
        switch state {
        case .ready:
            .moss
        case .watch:
            .ember
        case .blocked:
            .red
        }
    }

    static func badgePresentations(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [DecisionEvolutionSummaryBadgePresentation] {
        [
            DecisionEvolutionSummaryBadgePresentation(
                title: releaseSummary.state.title.uppercased(),
                tone: stateTone(releaseSummary.state)
            ),
            DecisionEvolutionSurfaceBadgePresentationSupport.pendingReviewBadge(
                count: releaseSummary.pendingReviewCount
            ),
            DecisionEvolutionSurfaceBadgePresentationSupport.rollbackReadyBadge(
                count: releaseSummary.rollbackReadyCount
            )
        ]
    }

    static func build(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        presentationMode: DecisionEvolutionReleaseSummaryPresentationMode
    ) -> DecisionEvolutionReleaseSummaryPresentation {
        DecisionEvolutionReleaseSummaryPresentation(
            state: releaseSummary.state,
            stateTone: stateTone(releaseSummary.state),
            badgePresentations: badgePresentations(releaseSummary: releaseSummary),
            pendingReviewCount: releaseSummary.pendingReviewCount,
            rollbackReadyCount: releaseSummary.rollbackReadyCount,
            headline: releaseSummary.headline,
            primaryReason: releaseSummary.reasons.first,
            activeCheckpointHeadline: controlSurface.activePresentation.map {
                checkpointHeadline(
                    roleTitle: DecisionEvolutionRuntimePresentationSupport.activeRoleTitle,
                    presentation: $0
                )
            },
            reviewCheckpointHeadline: controlSurface.spotlightReviewPresentation.map {
                checkpointHeadline(
                    roleTitle: DecisionEvolutionRuntimePresentationSupport.reviewHeadRoleTitle,
                    presentation: $0
                )
            },
            activeSourceText: activeSourceText(releaseSummary: releaseSummary),
            activeKillSwitchesText: DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: releaseSummary.activeKillSwitches
            ),
            recommendedKillSwitchesText: DecisionEvolutionKillSwitchPresentationSupport.recommendedLine(
                killSwitches: releaseSummary.recommendedKillSwitches
            ),
            operatorHeadline: operatorHeadline(for: presentationMode),
            operatorDetail: operatorDetail(for: presentationMode)
        )
    }

    static func checkpointHeadline(
        roleTitle: String,
        presentation: DecisionEvolutionCheckpointPresentation
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "\(roleTitle): \(presentation.checkpointID)",
            presentation.approvalStateTitle,
            presentation.summaryText,
        ])
    }

    static func activeSourceText(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> String? {
        guard releaseSummary.activeCheckpointID != nil,
              releaseSummary.activeCheckpointSource != .none else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: activeSourcePrefix,
            values: [releaseSummary.activeCheckpointSource.title]
        )
    }
}

struct DecisionEvolutionReleaseSummaryActionPresentation {
    let allowsLocalMutationActions: Bool
    let showsAnyActionRow: Bool
    let quickActionsTitle: String?
    let rollbackTitle: String
    let approveQueueTitle: String
    let clearReviewLineageTitle: String
    let rollbackIntent: DecisionEvolutionMutationIntent?
    let approveQueueIntent: DecisionEvolutionMutationIntent?
    let clearReviewLineageIntent: DecisionEvolutionMutationIntent?
}

enum DecisionEvolutionReleaseSummaryActionSupport {
    static func build(
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    ) -> DecisionEvolutionReleaseSummaryActionPresentation {
        let allowsLocalMutationActions = surfaceContract.allowsMutations
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: controlSurface,
                releaseSummary: nil,
                activeKillSwitches: controlSurface.activeKillSwitches,
                recommendedKillSwitches: controlSurface.queueKillSwitches,
                canRestoreActiveCheckpoint: controlSurface.activePresentation?.applyReady == true,
                canRollbackActiveCheckpoint: controlSurface.canRollbackActiveCheckpoint,
                allowsLocalMutationActions: allowsLocalMutationActions
            )
        )
        let actionPlan = policy.surfaceActionPlan(
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter
        )
        let actionBundle = DecisionEvolutionWorkspaceMutationActionBundle.build(
            controlSurface: controlSurface
        )

        return DecisionEvolutionReleaseSummaryActionPresentation(
            allowsLocalMutationActions: actionPlan.allowsLocalMutationActions,
            showsAnyActionRow: actionPlan.showsAnyActionRow,
            quickActionsTitle: actionPlan.quickActionsTitle,
            rollbackTitle: DecisionEvolutionMutationActionLexiconSupport.rollbackActiveTitle,
            approveQueueTitle: DecisionEvolutionMutationHubPresentationSupport.approveQueueTitle,
            clearReviewLineageTitle: DecisionEvolutionMutationActionLexiconSupport.clearReviewLineageTitle,
            rollbackIntent: actionBundle.rollbackActiveIntent,
            approveQueueIntent: actionBundle.approveQueueIntent,
            clearReviewLineageIntent: actionBundle.clearReviewLineageIntent
        )
    }
}

enum DecisionEvolutionReleaseSummaryBuilder {
    static func build(
        evolutionControlSurface: DecisionEvolutionControlSurface,
        eBrainSummary: DecisionSystemEBrainSummary?,
        dominantBlockers: [String],
        activeKillSwitches: [String],
        recommendedKillSwitchesHint: [String]
    ) -> DecisionSystemReleaseControlSummary {
        let blockerSignals = eBrainSummary?.source == .persistedCheckpoint ? [] : dominantBlockers
        let reviewAuditFindings = orderedUnique(
            evolutionControlSurface.reviewAuditFindings
            + runtimeHorizonAuditFindings(from: eBrainSummary)
        )
        let resolvedActiveKillSwitches = orderedUnique(
            activeKillSwitches
            + runtimeActiveKillSwitches(
                from: eBrainSummary,
                controlSurface: evolutionControlSurface
            )
        )
        let queueKillSwitches = evolutionControlSurface.queueKillSwitches
        let recommendedKillSwitches = orderedUnique(
            recommendedKillSwitchesHint
            + queueKillSwitches
        ).filter { !resolvedActiveKillSwitches.contains($0) }
        let killSwitches = orderedUnique(
            resolvedActiveKillSwitches + recommendedKillSwitches
        )
        let canRestoreActiveCheckpoint = evolutionControlSurface.activePresentation?.applyReady == true
        let canRollbackActiveCheckpoint = evolutionControlSurface.canRollbackActiveCheckpoint
        let policy = DecisionEvolutionPolicyEngine.evaluate(
            DecisionEvolutionPolicyEngine.input(
                controlSurface: evolutionControlSurface,
                releaseSummary: nil,
                activeKillSwitches: resolvedActiveKillSwitches,
                recommendedKillSwitches: recommendedKillSwitches,
                reviewAuditFindings: reviewAuditFindings,
                runtimeBlockerSignals: blockerSignals,
                canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
                canRollbackActiveCheckpoint: canRollbackActiveCheckpoint
            )
        )
        let guidance = policy.releaseGuidance

        return DecisionSystemReleaseControlSummary(
            state: guidance.state,
            headline: guidance.headline,
            reasons: guidance.reasons,
            activeKillSwitches: resolvedActiveKillSwitches,
            recommendedKillSwitches: recommendedKillSwitches,
            killSwitches: killSwitches,
            pendingReviewCount: evolutionControlSurface.pendingReviewCount,
            rollbackReadyCount: evolutionControlSurface.rollbackReadyCount,
            canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: canRollbackActiveCheckpoint,
            activeCheckpointID: evolutionControlSurface.activePresentation?.checkpointID,
            activeCheckpointSource: evolutionControlSurface.activeCheckpointSource,
            reviewCheckpointID: evolutionControlSurface.reviewPresentation?.checkpointID,
            primaryBlocker: policy.primaryBlocker
        )
    }

    private static func runtimeActiveKillSwitches(
        from eBrainSummary: DecisionSystemEBrainSummary?,
        controlSurface: DecisionEvolutionControlSurface
    ) -> [String] {
        if eBrainSummary?.source == .liveRuntime {
            return eBrainSummary?.activeKillSwitches ?? []
        }

        if let activeCheckpointID = controlSurface.activePresentation?.checkpointID,
           eBrainSummary?.checkpointID == activeCheckpointID {
            return eBrainSummary?.activeKillSwitches ?? []
        }

        return controlSurface.activeCheckpoint?.activeKillSwitches ?? []
    }

    private static func runtimeHorizonAuditFindings(
        from eBrainSummary: DecisionSystemEBrainSummary?
    ) -> [String] {
        guard eBrainSummary?.source == .liveRuntime else {
            return []
        }

        return orderedUnique(
            [
                eBrainSummary?.riskFactorsLine,
                eBrainSummary?.reasonCodesLine,
                eBrainSummary?.sovereignVerdictLine,
                eBrainSummary?.sovereignAuthorityLine,
                eBrainSummary?.sovereignAuditLine
            ].compactMap { value in
                guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmedValue.isEmpty else {
                    return nil
                }
                return trimmedValue
            }
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}
