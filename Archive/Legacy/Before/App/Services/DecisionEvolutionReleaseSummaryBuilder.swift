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

enum DecisionEvolutionSovereignPosturePresentationSupport {
    static let title = "Sovereign posture"

    static func lines(from reasons: [String]) -> [String] {
        reasons.reduce(into: [String]()) { uniqueLines, reason in
            guard isSovereignPostureLine(reason),
                  !uniqueLines.contains(reason) else { return }
            uniqueLines.append(reason)
        }
    }

    static func primaryReason(from reasons: [String]) -> String? {
        let sovereignPostureLines = lines(from: reasons)
        return reasons.first(where: { !sovereignPostureLines.contains($0) })
            ?? reasons.first
    }

    private static func isSovereignPostureLine(_ reason: String) -> Bool {
        reason.hasPrefix("Sovereign verdict")
            || reason.hasPrefix("Sovereign authority")
            || reason.hasPrefix("Sovereign audit")
            || reason.hasPrefix("Sovereign bridge")
            || reason.hasPrefix("L14 sovereign")
    }
}

enum DecisionEvolutionHorizonDiagnosticsPresentationSupport {
    static let title = "Horizon diagnostics"

    static func lines(from reasons: [String]) -> [String] {
        reasons.reduce(into: [String]()) { uniqueLines, reason in
            guard isHorizonDiagnosticsLine(reason),
                  !uniqueLines.contains(reason) else { return }
            uniqueLines.append(reason)
        }
    }

    private static func isHorizonDiagnosticsLine(_ reason: String) -> Bool {
        reason.hasPrefix("Capability ")
            || reason.hasPrefix("Horizon ")
            || reason.hasPrefix("Temporal ")
            || reason.hasPrefix("Evidence ")
            || reason.hasPrefix("Persistence ")
            || reason.hasPrefix("Court:")
    }
}

enum DecisionEvolutionPresencePresentationSupport {
    static let title = "Presence field"

    static func lines(
        from reasons: [String]
    ) -> [String] {
        lines(
            presenceLine: nil,
            reasons: reasons
        )
    }

    static func lines(
        presenceLine: String?,
        reasons: [String] = []
    ) -> [String] {
        ([presenceLine] + reasons).reduce(into: [String]()) { uniqueLines, candidate in
            guard let normalizedLine = normalizedPresenceLine(candidate),
                  !uniqueLines.contains(normalizedLine) else { return }
            uniqueLines.append(normalizedLine)
        }
    }

    static func isPresenceLine(
        _ line: String
    ) -> Bool {
        normalizedPresenceLine(line) != nil
    }

    private static func normalizedPresenceLine(
        _ line: String?
    ) -> String? {
        guard let trimmedLine = line?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedLine.isEmpty else {
            return nil
        }

        if trimmedLine.hasPrefix("Presence ") || trimmedLine == "Presence" {
            return trimmedLine
        }

        if trimmedLine.hasPrefix("eBrain presence:") {
            let payload = Self.droppingKnownPrefix(
                trimmedLine,
                prefix: "eBrain presence:"
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return payload.isEmpty ? "Presence" : "Presence \(payload)"
        }

        guard trimmedLine.hasPrefix("L6 presence") else {
            return nil
        }

        let payload = Self.droppingKnownPrefix(
            Self.droppingKnownPrefix(
                trimmedLine,
                prefix: "L6 presence • "
            ),
            prefix: "L6 presence"
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "•"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return payload.isEmpty ? "Presence" : "Presence \(payload)"
    }

    private static func droppingKnownPrefix(
        _ value: String,
        prefix: String
    ) -> String {
        guard value.hasPrefix(prefix) else {
            return value
        }

        return String(value.dropFirst(prefix.count))
    }
}

enum DecisionEvolutionPrimaryReasonPresentationSupport {
    static func primaryReason(from reasons: [String]) -> String? {
        let sovereignPostureLines = DecisionEvolutionSovereignPosturePresentationSupport.lines(
            from: reasons
        )
        let horizonDiagnosticsLines = DecisionEvolutionHorizonDiagnosticsPresentationSupport.lines(
            from: reasons
        )
        return reasons.first(where: {
            !sovereignPostureLines.contains($0)
                && !horizonDiagnosticsLines.contains($0)
                && !DecisionEvolutionPresencePresentationSupport.isPresenceLine($0)
        }) ?? reasons.first(where: {
            !horizonDiagnosticsLines.contains($0)
                && !DecisionEvolutionPresencePresentationSupport.isPresenceLine($0)
        }) ?? reasons.first(where: {
            !DecisionEvolutionPresencePresentationSupport.isPresenceLine($0)
        })
    }
}

enum DecisionEvolutionFoldedLungPresentationSupport {
    static let title = "Folded lung"

    static func lines(from reasons: [String]) -> [String] {
        reasons.reduce(into: [String]()) { uniqueLines, reason in
            guard isFoldedLungLine(reason),
                  !uniqueLines.contains(reason) else { return }
            uniqueLines.append(reason)
        }
    }

    private static func isFoldedLungLine(_ reason: String) -> Bool {
        reason.hasPrefix("L3 compression runtime")
            || reason.hasPrefix("Breath ")
            || reason.hasPrefix("Morph graph")
            || reason.hasPrefix("Hot pack")
            || reason.hasPrefix("Precision profile")
            || reason.hasPrefix("Organ packages")
            || reason.hasPrefix("Organ delta")
            || reason.hasPrefix("Breath scheduler")
            || reason.hasPrefix("Thermal exchanger")
            || reason.hasPrefix("Integrity weave")
            || reason.hasPrefix("Resume frame")
            || reason.hasPrefix("Rollback anchor")
    }
}

enum DecisionEvolutionFurnaceContributionPresentationSupport {
    static let title = "Furnace fabric"

    static func lines(from reasons: [String]) -> [String] {
        reasons.reduce(into: [String]()) { uniqueLines, reason in
            guard isFurnaceContributionLine(reason) else { return }

            let presentationLine = presentedContributionLine(reason)
            guard !uniqueLines.contains(presentationLine) else { return }
            uniqueLines.append(presentationLine)
        }
    }

    private static func presentedContributionLine(_ reason: String) -> String {
        DecisionEvolutionEBrainPresentationSupport.windGateMetadataLine(
            rawLine: reason
        ) ?? reason
    }

    private static func isFurnaceContributionLine(_ reason: String) -> Bool {
        reason.hasPrefix("L8 temporal field")
            || reason.hasPrefix("Temporal memory")
            || reason.hasPrefix("L7-L9 cognition")
            || reason.hasPrefix("L9 dream loop")
            || reason.hasPrefix("L10-L12 adjudication")
            || reason.hasPrefix("L11 wind gate")
            || reason.hasPrefix("L13 governance")
            || reason.hasPrefix("L13 version tree")
            || reason.hasPrefix("L13 retraction")
    }
}

enum DecisionEvolutionFurnaceChecklistPresentationSupport {
    static let title = "Furnace review checklist"
    private static let pendingShadowLine = "Review the pending shadow trial before promotion or approval."
    private static let failedShadowLine = "Inspect the failed shadow trial before any further rollout."
    private static let pendingSealLine = "Review the pending evolution seal before promotion or approval."
    private static let deniedSealLine = "Inspect the denied evolution seal before any further rollout."
    private static let versionTreeLine = "Inspect the version tree delta and rollback pointer before wider rollout."
    private static let pendingRetractionLine = "Clear the pending retraction order before wider rollout."
    private static let clearedRetractionLine = "Confirm retraction cleanup before wider rollout."

    static func lines(from reasons: [String]) -> [String] {
        reasons.reduce(into: [String]()) { uniqueLines, reason in
            checklistLines(for: reason).forEach { line in
                guard !uniqueLines.contains(line) else { return }
                uniqueLines.append(line)
            }
        }
    }

    private static func checklistLines(for reason: String) -> [String] {
        var lines: [String] = []

        if reason.hasPrefix("L13 governance") {
            switch governanceState(for: "shadow", in: reason) {
            case "pending":
                lines.append(pendingShadowLine)
            case "failed":
                lines.append(failedShadowLine)
            default:
                break
            }

            switch governanceState(for: "seal", in: reason) {
            case "pending":
                lines.append(pendingSealLine)
            case "denied":
                lines.append(deniedSealLine)
            default:
                break
            }
        }

        if reason.hasPrefix("L13 version tree") {
            lines.append(versionTreeLine)
        }

        if reason.hasPrefix("L13 retraction") {
            switch retractionState(in: reason) {
            case "pending":
                lines.append(pendingRetractionLine)
            case "cleared", "completed":
                lines.append(clearedRetractionLine)
            default:
                break
            }
        }

        return lines
    }

    private static func governanceState(
        for candidateType: String,
        in reason: String
    ) -> String? {
        segment(
            prefixedBy: candidateType,
            in: reason
        ).flatMap(statusToken(from:))
    }

    private static func retractionState(
        in reason: String
    ) -> String? {
        reason
            .components(separatedBy: " • ")
            .dropFirst()
            .first?
            .split(separator: " ")
            .first
            .map(String.init)
    }

    private static func segment(
        prefixedBy prefix: String,
        in reason: String
    ) -> String? {
        reason
            .components(separatedBy: " • ")
            .dropFirst()
            .first(where: { $0.hasPrefix("\(prefix) ") })
    }

    private static func statusToken(
        from segment: String
    ) -> String? {
        segment
            .split(separator: " ")
            .last
            .flatMap { $0.split(separator: "/").first }
            .map(String.init)
    }
}

enum DecisionEvolutionFurnaceNextStepPresentationSupport {
    static let title = "Recommended next step"

    static func detail(
        from checklistLines: [String]
    ) -> String? {
        checklistLines.first
    }
}

struct DecisionEvolutionFurnaceLinesSectionPresentation: Equatable, Sendable {
    let title: String
    let lines: [String]
}

struct DecisionEvolutionFurnaceNextStepSectionPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let action: DecisionEvolutionFurnaceNextStepActionPresentation?
}

struct DecisionEvolutionFurnaceReviewPresentationBundle: Equatable, Sendable {
    let checklistSection: DecisionEvolutionFurnaceLinesSectionPresentation?
    let nextStepSection: DecisionEvolutionFurnaceNextStepSectionPresentation?
    let workbenchPresentation: DecisionEvolutionFurnaceWorkbenchPresentation?

    var checklistLines: [String] {
        checklistSection?.lines ?? []
    }

    var nextStepDetail: String? {
        nextStepSection?.detail
    }

    var nextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation? {
        nextStepSection?.action
    }
}

struct DecisionEvolutionFurnacePresentationBundle: Equatable, Sendable {
    let contributionSection: DecisionEvolutionFurnaceLinesSectionPresentation?
    let review: DecisionEvolutionFurnaceReviewPresentationBundle

    var contributionLines: [String] {
        contributionSection?.lines ?? []
    }
}

struct DecisionEvolutionFurnaceWorkbenchPresentation: Equatable, Sendable {
    let title: String
    let headline: String
    let detail: String
    let availabilityTitle: String
    let availabilityLines: [String]
    let nextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation?
    let focusTarget: DecisionEvolutionMutationHubFocusTarget
    let executionState: DecisionEvolutionFurnaceExecutionStatePresentation
    let runNowAction: DecisionEvolutionFurnaceRunNowActionPresentation?
}

enum DecisionEvolutionFurnaceNextStepActionKind: Equatable, Sendable {
    case navigate(DecisionEvolutionNavigationDestination)
    case focusMutationHub(DecisionEvolutionMutationHubFocusTarget)
}

enum DecisionEvolutionMutationHubFocusTarget: String, Hashable, Equatable, Sendable {
    case quickActions
    case queueLineage
}

struct DecisionEvolutionFurnaceNextStepActionPresentation: Equatable, Sendable {
    let actionTitle: String
    let kind: DecisionEvolutionFurnaceNextStepActionKind
}

struct DecisionEvolutionFurnaceRunNowActionPresentation: Equatable, Sendable {
    let actionTitle: String
    let intent: DecisionEvolutionMutationIntent
}

struct DecisionEvolutionFurnaceExecutionStatePresentation: Equatable, Sendable {
    let title: String
    let headline: String
    let lines: [String]
}

enum DecisionEvolutionFurnaceMutationHubRoutingSupport {
    static func focusTarget(
        for detail: String
    ) -> DecisionEvolutionMutationHubFocusTarget {
        detail.localizedCaseInsensitiveContains("retraction")
            ? .queueLineage
            : .quickActions
    }

    static func actionTitle(
        for focusTarget: DecisionEvolutionMutationHubFocusTarget
    ) -> String {
        switch focusTarget {
        case .quickActions:
            "Inspect quick actions"
        case .queueLineage:
            "Inspect queue lineage"
        }
    }
}

enum DecisionEvolutionFurnaceWorkbenchPresentationSupport {
    static let title = DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchSectionTitle

    static func build(
        detail: String?,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        nextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation? = nil
    ) -> DecisionEvolutionFurnaceWorkbenchPresentation? {
        guard let detail else { return nil }

        let focusTarget = DecisionEvolutionFurnaceMutationHubRoutingSupport.focusTarget(
            for: detail
        )
        let resolvedNextStepAction = nextStepAction ?? DecisionEvolutionFurnaceNextStepActionSupport.build(
            detail: detail,
            surfaceContract: surfaceContract
        )
        let actionBundle = DecisionEvolutionWorkspaceMutationActionBundle.build(
            controlSurface: controlSurface
        )
        let availability: (isBlocked: Bool, lines: [String])

        switch focusTarget {
        case .quickActions:
            availability = (
                actionBundle.restoreActiveIntent == nil
                    && actionBundle.rollbackActiveIntent == nil
                    && actionBundle.approveQueueIntent == nil,
                DecisionEvolutionPilotControlPresentationSupport.quickActionAvailabilityLines(
                    controlSurface: controlSurface,
                    actionBundle: actionBundle
                )
            )
        case .queueLineage:
            let clearLineageAvailable = actionBundle.clearReviewLineageIntent != nil
            availability = (
                !clearLineageAvailable,
                DecisionEvolutionPilotControlPresentationSupport.queueLineageAvailabilityLines(
                    controlSurface: controlSurface,
                    clearLineageAvailable: clearLineageAvailable
                )
            )
        }

        let runNowAction = DecisionEvolutionFurnaceRunNowActionSupport.build(
            detail: detail,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        )
        let executionState = DecisionEvolutionFurnaceExecutionStateSupport.build(
            detail: detail,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract,
            nextStepAction: resolvedNextStepAction,
            runNowAction: runNowAction
        ) ?? DecisionEvolutionFurnaceExecutionStatePresentation(
            title: DecisionEvolutionFurnaceExecutionStateSupport.title,
            headline: "Direct run-now preview is unavailable.",
            lines: []
        )

        return DecisionEvolutionFurnaceWorkbenchPresentation(
            title: title,
            headline: DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchHeadline(
                for: focusTarget
            ),
            detail: detail,
            availabilityTitle: DecisionEvolutionPilotControlPresentationSupport.furnaceWorkbenchAvailabilityTitle(
                isBlocked: availability.isBlocked
            ),
            availabilityLines: availability.lines,
            nextStepAction: resolvedNextStepAction,
            focusTarget: focusTarget,
            executionState: executionState,
            runNowAction: runNowAction
        )
    }
}

enum DecisionEvolutionFurnaceRunNowActionSupport {
    static func build(
        detail: String?,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnaceRunNowActionPresentation? {
        guard surfaceContract.allowsMutations,
              let detail else { return nil }

        let focusTarget = DecisionEvolutionFurnaceMutationHubRoutingSupport.focusTarget(
            for: detail
        )
        let actionBundle = DecisionEvolutionWorkspaceMutationActionBundle.build(
            controlSurface: controlSurface
        )

        switch focusTarget {
        case .quickActions:
            return preferredQuickAction(actionBundle: actionBundle)
        case .queueLineage:
            return actionBundle.clearReviewLineageIntent.map {
                DecisionEvolutionFurnaceRunNowActionPresentation(
                    actionTitle: DecisionEvolutionMutationHubPresentationSupport.clearQueueLineageTitle,
                    intent: $0
                )
            }
        }
    }

    static func preferredQuickAction(
        actionBundle: DecisionEvolutionWorkspaceMutationActionBundle
    ) -> DecisionEvolutionFurnaceRunNowActionPresentation? {
        if let approveQueueIntent = actionBundle.approveQueueIntent {
            return DecisionEvolutionFurnaceRunNowActionPresentation(
                actionTitle: DecisionEvolutionReviewPathPresentationSupport.approveReviewQueueActionTitle,
                intent: approveQueueIntent
            )
        }

        if let rollbackActiveIntent = actionBundle.rollbackActiveIntent {
            return DecisionEvolutionFurnaceRunNowActionPresentation(
                actionTitle: DecisionEvolutionMutationHubPresentationSupport.rollbackActivePathTitle,
                intent: rollbackActiveIntent
            )
        }

        if let restoreActiveIntent = actionBundle.restoreActiveIntent {
            return DecisionEvolutionFurnaceRunNowActionPresentation(
                actionTitle: DecisionEvolutionMutationHubPresentationSupport.restoreActivePathTitle,
                intent: restoreActiveIntent
            )
        }

        return nil
    }
}

enum DecisionEvolutionFurnaceExecutionStateSupport {
    static let title = "Execution state"

    static func build(
        detail: String?,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        nextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation? = nil,
        runNowAction: DecisionEvolutionFurnaceRunNowActionPresentation? = nil
    ) -> DecisionEvolutionFurnaceExecutionStatePresentation? {
        guard let detail else { return nil }

        let resolvedRunNowAction = runNowAction ?? DecisionEvolutionFurnaceRunNowActionSupport.build(
            detail: detail,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        )
        let resolvedNextStepAction = nextStepAction ?? DecisionEvolutionFurnaceNextStepActionSupport.build(
            detail: detail,
            surfaceContract: surfaceContract
        )

        if let resolvedRunNowAction {
            return readyState(resolvedRunNowAction)
        }

        let focusTarget = DecisionEvolutionFurnaceMutationHubRoutingSupport.focusTarget(
            for: detail
        )
        if surfaceContract.allowsMutations {
            return blockedMutationState(
                focusTarget: focusTarget,
                controlSurface: controlSurface
            )
        }

        return readOnlyState(
            nextStepAction: resolvedNextStepAction
        )
    }

    private static func readyState(
        _ runNowAction: DecisionEvolutionFurnaceRunNowActionPresentation
    ) -> DecisionEvolutionFurnaceExecutionStatePresentation {
        let preview = runNowAction.intent.preview
        let previewPresentation = runNowAction.intent.previewPresentation

        var lines = [
            "\(preview.scope.summaryTitle).",
            preview.summary
        ]
        if let targetsLine = previewPresentation.impactTargetsLine(
            preview.targetCheckpointIDs
        ) {
            lines.append(targetsLine)
        }
        if let activeTransitionLine = transitionLine(
            title: previewPresentation.activeTransitionTitle,
            current: preview.currentActiveCheckpointID,
            projected: preview.projectedActiveCheckpointID,
            previewPresentation: previewPresentation
        ) {
            lines.append(activeTransitionLine)
        }
        if let reviewTransitionLine = transitionLine(
            title: previewPresentation.reviewTransitionTitle,
            current: preview.currentReviewCheckpointID,
            projected: preview.projectedReviewCheckpointID,
            previewPresentation: previewPresentation
        ) {
            lines.append(reviewTransitionLine)
        }
        if let warning = preview.warningHighlights.first {
            lines.append("Watch: \(warning)")
        } else if let change = preview.changeHighlights.first {
            lines.append(change)
        }

        return DecisionEvolutionFurnaceExecutionStatePresentation(
            title: title,
            headline: "\(runNowAction.actionTitle) is ready for guarded preview.",
            lines: lines
        )
    }

    private static func transitionLine(
        title: String,
        current: String?,
        projected: String?,
        previewPresentation: DecisionEvolutionMutationPreviewPresentation
    ) -> String? {
        guard current != nil || projected != nil else {
            return nil
        }

        return "\(title): \(previewPresentation.transitionLine(current: current, projected: projected))"
    }

    private static func blockedMutationState(
        focusTarget: DecisionEvolutionMutationHubFocusTarget,
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionFurnaceExecutionStatePresentation {
        let actionBundle = DecisionEvolutionWorkspaceMutationActionBundle.build(
            controlSurface: controlSurface
        )

        let blockerLine: String
        switch focusTarget {
        case .quickActions:
            blockerLine = DecisionEvolutionPilotControlPresentationSupport.preferredQuickActionExecutionBlockerLine(
                controlSurface: controlSurface,
                actionBundle: actionBundle
            )
        case .queueLineage:
            blockerLine = DecisionEvolutionPilotControlPresentationSupport.queueLineageExecutionBlockerLine(
                controlSurface: controlSurface,
                clearLineageAvailable: actionBundle.clearReviewLineageIntent != nil
            )
        }

        return DecisionEvolutionFurnaceExecutionStatePresentation(
            title: title,
            headline: "Direct run-now preview is blocked right now.",
            lines: [
                blockerLine,
                "\(DecisionEvolutionFurnaceMutationHubRoutingSupport.actionTitle(for: focusTarget)) to inspect the holding lane."
            ]
        )
    }

    private static func readOnlyState(
        nextStepAction: DecisionEvolutionFurnaceNextStepActionPresentation?
    ) -> DecisionEvolutionFurnaceExecutionStatePresentation {
        let actionTitle = nextStepAction?.actionTitle ?? "Open control center"

        return DecisionEvolutionFurnaceExecutionStatePresentation(
            title: title,
            headline: "Direct run-now preview stays on the writable surface.",
            lines: [
                "This surface stays read-first for furnace mutations.",
                "\(actionTitle) to inspect the current furnace step before mutating the path."
            ]
        )
    }
}

enum DecisionEvolutionFurnaceNextStepActionSupport {
    static func build(
        detail: String?,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnaceNextStepActionPresentation? {
        guard let detail else { return nil }

        switch surfaceContract.kind {
        case .controlCenter:
            let focusTarget = DecisionEvolutionFurnaceMutationHubRoutingSupport.focusTarget(
                for: detail
            )
            return DecisionEvolutionFurnaceNextStepActionPresentation(
                actionTitle: DecisionEvolutionFurnaceMutationHubRoutingSupport.actionTitle(
                    for: focusTarget
                ),
                kind: .focusMutationHub(focusTarget)
            )
        case .home, .history, .portrait, .settings:
            return DecisionEvolutionFurnaceNextStepActionPresentation(
                actionTitle: DecisionEvolutionNavigationDestination.controlCenter.actionTitle(
                    routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter
                ),
                kind: .navigate(.controlCenter)
            )
        }
    }
}

enum DecisionEvolutionFurnaceReviewPresentationSupport {
    static func build(
        reasons: [String],
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnaceReviewPresentationBundle {
        let checklistLines = DecisionEvolutionFurnaceChecklistPresentationSupport.lines(
            from: reasons
        )
        let checklistSection = checklistLines.isEmpty
            ? nil
            : DecisionEvolutionFurnaceLinesSectionPresentation(
                title: DecisionEvolutionFurnaceChecklistPresentationSupport.title,
                lines: checklistLines
            )
        let nextStepDetail = DecisionEvolutionFurnaceNextStepPresentationSupport.detail(
            from: checklistLines
        )
        let nextStepAction = DecisionEvolutionFurnaceNextStepActionSupport.build(
            detail: nextStepDetail,
            surfaceContract: surfaceContract
        )
        let nextStepSection = nextStepDetail.map {
            DecisionEvolutionFurnaceNextStepSectionPresentation(
                title: DecisionEvolutionFurnaceNextStepPresentationSupport.title,
                detail: $0,
                action: nextStepAction
            )
        }
        let workbenchPresentation = DecisionEvolutionFurnaceWorkbenchPresentationSupport.build(
            detail: nextStepDetail,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract,
            nextStepAction: nextStepAction
        )

        return DecisionEvolutionFurnaceReviewPresentationBundle(
            checklistSection: checklistSection,
            nextStepSection: nextStepSection,
            workbenchPresentation: workbenchPresentation
        )
    }

    static func build(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnaceReviewPresentationBundle {
        build(
            reasons: releaseSummary.reasons,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        )
    }
}

enum DecisionEvolutionFurnacePresentationSupport {
    static func build(
        reasons: [String],
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnacePresentationBundle {
        let contributionLines = DecisionEvolutionFurnaceContributionPresentationSupport.lines(
            from: reasons
        )

        return DecisionEvolutionFurnacePresentationBundle(
            contributionSection: contributionLines.isEmpty
                ? nil
                : DecisionEvolutionFurnaceLinesSectionPresentation(
                    title: DecisionEvolutionFurnaceContributionPresentationSupport.title,
                    lines: contributionLines
                ),
            review: DecisionEvolutionFurnaceReviewPresentationSupport.build(
                reasons: reasons,
                controlSurface: controlSurface,
                surfaceContract: surfaceContract
            )
        )
    }

    static func build(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract
    ) -> DecisionEvolutionFurnacePresentationBundle {
        build(
            reasons: releaseSummary.reasons,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        )
    }
}

enum DecisionEvolutionReleaseSummaryPresentationSupport {
    static let activeSourcePrefix = "Active source"
    static let sovereignPostureTitle = DecisionEvolutionSovereignPosturePresentationSupport.title
    static let horizonDiagnosticsTitle = DecisionEvolutionHorizonDiagnosticsPresentationSupport.title
    static let presenceTitle = DecisionEvolutionPresencePresentationSupport.title
    static let foldedLungTitle = DecisionEvolutionFoldedLungPresentationSupport.title

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
        presentationMode: DecisionEvolutionReleaseSummaryPresentationMode,
        surfaceContract: DecisionEvolutionSurfaceContract = .home
    ) -> DecisionEvolutionReleaseSummaryPresentation {
        let sovereignPostureLines = sovereignPostureLines(releaseSummary: releaseSummary)
        let horizonDiagnosticsLines = horizonDiagnosticsLines(releaseSummary: releaseSummary)
        let presenceLines = presenceLines(releaseSummary: releaseSummary)
        let foldedLungLines = foldedLungLines(releaseSummary: releaseSummary)
        let furnacePresentation = DecisionEvolutionFurnacePresentationSupport.build(
            releaseSummary: releaseSummary,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
        )
        let furnaceContributionSection = furnacePresentation.contributionSection
        let furnaceContributionLines = furnaceContributionSection?.lines ?? []
        let furnaceReview = furnacePresentation.review
        let furnaceChecklistSection = furnaceReview.checklistSection
        let furnaceChecklistLines = furnaceChecklistSection?.lines ?? []
        let furnaceNextStepSection = furnaceReview.nextStepSection
        let furnaceNextStepDetail = furnaceNextStepSection?.detail
        let furnaceNextStepAction = furnaceNextStepSection?.action
        let furnaceWorkbenchPresentation = furnaceReview.workbenchPresentation

        return DecisionEvolutionReleaseSummaryPresentation(
            state: releaseSummary.state,
            stateTone: stateTone(releaseSummary.state),
            badgePresentations: badgePresentations(releaseSummary: releaseSummary),
            pendingReviewCount: releaseSummary.pendingReviewCount,
            rollbackReadyCount: releaseSummary.rollbackReadyCount,
            headline: releaseSummary.headline,
            primaryReason: primaryReason(from: releaseSummary),
            sovereignPostureTitle: sovereignPostureLines.isEmpty ? nil : sovereignPostureTitle,
            sovereignPostureLines: sovereignPostureLines,
            horizonDiagnosticsTitle: horizonDiagnosticsLines.isEmpty ? nil : horizonDiagnosticsTitle,
            horizonDiagnosticsLines: horizonDiagnosticsLines,
            presenceTitle: presenceLines.isEmpty ? nil : presenceTitle,
            presenceLines: presenceLines,
            foldedLungTitle: foldedLungLines.isEmpty ? nil : foldedLungTitle,
            foldedLungLines: foldedLungLines,
            furnaceContributionTitle: furnaceContributionSection?.title,
            furnaceContributionLines: furnaceContributionLines,
            furnaceChecklistTitle: furnaceChecklistSection?.title,
            furnaceChecklistLines: furnaceChecklistLines,
            furnaceNextStepTitle: furnaceNextStepSection?.title,
            furnaceNextStepDetail: furnaceNextStepDetail,
            furnaceNextStepAction: furnaceNextStepAction,
            furnaceWorkbenchPresentation: furnaceWorkbenchPresentation,
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

    static func sovereignPostureLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionSovereignPosturePresentationSupport.lines(
            from: releaseSummary.reasons
        )
    }

    static func furnaceContributionLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionFurnaceContributionPresentationSupport.lines(
            from: releaseSummary.reasons
        )
    }

    static func foldedLungLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionFoldedLungPresentationSupport.lines(
            from: releaseSummary.reasons
        )
    }

    static func horizonDiagnosticsLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionHorizonDiagnosticsPresentationSupport.lines(
            from: releaseSummary.reasons
        )
    }

    static func presenceLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionPresencePresentationSupport.lines(
            presenceLine: releaseSummary.presenceLine,
            reasons: releaseSummary.reasons
        )
    }

    static func furnaceChecklistLines(
        releaseSummary: DecisionSystemReleaseControlSummary
    ) -> [String] {
        DecisionEvolutionFurnaceChecklistPresentationSupport.lines(
            from: releaseSummary.reasons
        )
    }

    private static func primaryReason(
        from releaseSummary: DecisionSystemReleaseControlSummary
    ) -> String? {
        DecisionEvolutionPrimaryReasonPresentationSupport.primaryReason(
            from: releaseSummary.reasons
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
        let reasons = orderedUnique(
            guidance.reasons
                + evolutionControlSurface.queueCourtLines
                + runtimeFoldedLungLines(
                    from: eBrainSummary,
                    controlSurface: evolutionControlSurface
                )
                + runtimeFurnaceContributionLines(
                    from: eBrainSummary,
                    controlSurface: evolutionControlSurface
                )
        )

        return DecisionSystemReleaseControlSummary(
            state: guidance.state,
            headline: guidance.headline,
            reasons: reasons,
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
            presenceLine: runtimePresenceLine(
                from: eBrainSummary,
                controlSurface: evolutionControlSurface
            ),
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

    private static func runtimeFurnaceContributionLines(
        from eBrainSummary: DecisionSystemEBrainSummary?,
        controlSurface: DecisionEvolutionControlSurface
    ) -> [String] {
        guard let eBrainSummary else {
            return []
        }

        if eBrainSummary.source == .liveRuntime {
            return eBrainSummary.furnaceContributionLines
        }

        if let activeCheckpointID = controlSurface.activePresentation?.checkpointID,
           eBrainSummary.checkpointID == activeCheckpointID {
            return eBrainSummary.furnaceContributionLines
        }

        return []
    }

    private static func runtimePresenceLine(
        from eBrainSummary: DecisionSystemEBrainSummary?,
        controlSurface: DecisionEvolutionControlSurface
    ) -> String? {
        guard let eBrainSummary else {
            return nil
        }

        if eBrainSummary.source == .liveRuntime {
            return eBrainSummary.presenceLine
        }

        if let activeCheckpointID = controlSurface.activePresentation?.checkpointID,
           eBrainSummary.checkpointID == activeCheckpointID {
            return eBrainSummary.presenceLine
        }

        return nil
    }

    private static func runtimeFoldedLungLines(
        from eBrainSummary: DecisionSystemEBrainSummary?,
        controlSurface: DecisionEvolutionControlSurface
    ) -> [String] {
        guard let eBrainSummary else {
            return []
        }

        if eBrainSummary.source == .liveRuntime {
            return eBrainSummary.foldedLungLines
        }

        if let activeCheckpointID = controlSurface.activePresentation?.checkpointID,
           eBrainSummary.checkpointID == activeCheckpointID {
            return eBrainSummary.foldedLungLines
        }

        return []
    }

    private static func runtimeHorizonAuditFindings(
        from eBrainSummary: DecisionSystemEBrainSummary?
    ) -> [String] {
        guard eBrainSummary?.source == .liveRuntime else {
            return []
        }

        return orderedUnique(
            [
                eBrainSummary?.executionCapabilityFrame?.detailLine,
                eBrainSummary?.executionCapabilityFrame?.horizonLine,
                eBrainSummary?.executionCapabilityFrame?.temporalLine,
                eBrainSummary?.executionCapabilityFrame?.evidenceLine,
                eBrainSummary?.executionCapabilityFrame?.persistenceLine,
                eBrainSummary?.riskFactorsLine,
                eBrainSummary?.reasonCodesLine,
                eBrainSummary?.courtLine,
                eBrainSummary?.versionTreeLine,
                eBrainSummary?.retractionLine,
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
