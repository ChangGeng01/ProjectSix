import Foundation

enum DecisionEvolutionMutationKind: String, Equatable, Sendable {
    case applyCheckpoint
    case approveCheckpoint
    case markCheckpointForReview
    case clearCheckpointLineage
    case approveSelectedCheckpoints
    case markSelectedCheckpointsForReview
    case clearSelectedCheckpointLineages
    case restoreActiveCheckpoint
    case rollbackActiveCheckpoint
    case approvePendingCheckpoints
    case clearPendingReviewLineage
}

enum DecisionEvolutionMutationScope: String, Equatable, Sendable {
    case checkpoint
    case activePath
    case reviewQueue
    case selection

    var badgeTitle: String {
        switch self {
        case .checkpoint:
            "CHECKPOINT"
        case .activePath:
            "ACTIVE PATH"
        case .reviewQueue:
            "REVIEW QUEUE"
        case .selection:
            "SELECTION"
        }
    }

    var summaryTitle: String {
        switch self {
        case .checkpoint:
            "Checkpoint mutation"
        case .activePath:
            "Active-path mutation"
        case .reviewQueue:
            "Review-queue mutation"
        case .selection:
            "Selection mutation"
        }
    }
}

struct DecisionEvolutionMutationPreview: Identifiable, Equatable, Sendable {
    let kind: DecisionEvolutionMutationKind
    let scope: DecisionEvolutionMutationScope
    let headline: String
    let summary: String
    let targetCheckpointIDs: [String]
    let currentActiveCheckpointID: String?
    let projectedActiveCheckpointID: String?
    let currentReviewCheckpointID: String?
    let projectedReviewCheckpointID: String?
    let changeHighlights: [String]
    let retainedHighlights: [String]
    let warningHighlights: [String]

    var id: String {
        "\(kind.rawValue):\(targetCheckpointIDs.joined(separator: ","))"
    }
}

struct DecisionEvolutionMutationPreviewPresentation: Equatable, Sendable {
    let toneBadgeTitle: String
    let impactTitle: String
    let impactDetail: String
    let impactTargetsPrefix: String
    let activeTransitionTitle: String
    let reviewTransitionTitle: String
    let transitionArrow: String
    let currentLineTitle: String
    let projectedLineTitle: String
    let missingCheckpointToken: String
    let changeSectionTitle: String
    let retainedSectionTitle: String
    let warningSectionTitle: String
    let cancelTitle: String

    func checkpointToken(_ checkpointID: String?) -> String {
        checkpointID ?? missingCheckpointToken
    }

    func checkpointLine(title: String, checkpointID: String?) -> String {
        "\(title): \(checkpointToken(checkpointID))"
    }

    func currentLine(_ checkpointID: String?) -> String {
        checkpointLine(title: currentLineTitle, checkpointID: checkpointID)
    }

    func projectedLine(_ checkpointID: String?) -> String {
        checkpointLine(title: projectedLineTitle, checkpointID: checkpointID)
    }

    func transitionLine(current: String?, projected: String?) -> String {
        "\(checkpointToken(current)) \(transitionArrow) \(checkpointToken(projected))"
    }

    func impactTargetsLine(_ checkpointIDs: [String]) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: impactTargetsPrefix,
            values: checkpointIDs
        )
    }
}

enum DecisionEvolutionMutationOutcomeTone: Equatable, Sendable {
    case success
    case caution
    case failure
}

enum DecisionEvolutionMutationLabelPresentationSupport {
    static let targetsPrefix = "Targets"
    static let activeTransitionTitle = DecisionEvolutionCheckpointLexiconSupport.activeRuntimeRoleTitle
}

enum DecisionEvolutionMutationOutcomePresentationSupport {
    static let dismissTitle = "Dismiss"
    static let targetsPrefix = DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix

    static func statusTitle(isSuccess: Bool, isDestructive: Bool) -> String {
        if isSuccess {
            return isDestructive ? "Completed with lineage changes" : "Completed"
        }
        return "Action needs attention"
    }

    static func iconName(isSuccess: Bool, isDestructive: Bool) -> String {
        if isSuccess {
            return isDestructive ? "exclamationmark.shield.fill" : "checkmark.seal.fill"
        }
        return "xmark.octagon.fill"
    }

    static func tone(isSuccess: Bool, isDestructive: Bool) -> DecisionEvolutionMutationOutcomeTone {
        if isSuccess {
            return isDestructive ? .caution : .success
        }
        return .failure
    }

    static func targetsLine(
        checkpointIDs: [String],
        targetsPrefix: String = targetsPrefix
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: targetsPrefix,
            values: checkpointIDs
        )
    }
}

struct DecisionEvolutionMutationOutcomePresentation: Equatable, Sendable {
    let statusTitle: String
    let iconName: String
    let dismissTitle: String
    let targetsPrefix: String
    let tone: DecisionEvolutionMutationOutcomeTone

    func targetsLine(_ checkpointIDs: [String]) -> String? {
        DecisionEvolutionMutationOutcomePresentationSupport.targetsLine(
            checkpointIDs: checkpointIDs,
            targetsPrefix: targetsPrefix
        )
    }
}

enum DecisionEvolutionMutationActionLexiconSupport {
    static let applyCheckpointTitle = "Apply checkpoint"
    static let approveCheckpointTitle = "Approve checkpoint"
    static let markReviewTitle = "Mark review"
    static let clearLineageTitle = "Clear lineage"
    static let restoreActiveTitle = "Restore active"
    static let rollbackActiveTitle = "Rollback active"
    static let approvePendingTitle = "Approve pending"
    static let clearReviewLineageTitle = "Clear review lineage"
    static let approveSelectedTitle = "Approve selected"
    static let markSelectedTitle = "Mark selected"
    static let clearSelectedLineageTitle = "Clear selected lineage"
}

struct DecisionEvolutionMutationIntentCopy: Equatable, Sendable {
    let message: String
    let headline: String
    let summary: String
}

enum DecisionEvolutionMutationIntentCopySupport {
    static func applyCheckpoint(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Restore checkpoint \(checkpointID) as the active brain state. This changes the live host state, but it does not auto-approve review status or clear lineage.",
            headline: "Apply \(checkpointID)",
            summary: "Restore this checkpoint as the active brain state while keeping review/audit facts visible."
        )
    }

    static func approveCheckpoint(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Move checkpoint \(checkpointID) out of the review queue and back onto the automatic evolution path.",
            headline: "Approve \(checkpointID)",
            summary: "This keeps the checkpoint record and lineage, but removes its review-suggested status."
        )
    }

    static func markCheckpointForReview(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Move checkpoint \(checkpointID) into the review queue. This does not restore the checkpoint or change the active brain state.",
            headline: "Mark \(checkpointID) for review",
            summary: "Queue this checkpoint for explicit host review without altering the live active state."
        )
    }

    static func clearCheckpointLineage(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Remove recovered lineage from checkpoint \(checkpointID). The checkpoint record stays, but persisted risk, permit, ticket, audit, and kill-switch facts are cleared.",
            headline: "Clear lineage on \(checkpointID)",
            summary: "This keeps the checkpoint record but removes recovered L13 lineage facts."
        )
    }

    static func restoreActiveCheckpoint(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Restore checkpoint \(checkpointID) as the active brain state. This changes the live host state, but it does not auto-approve review status or clear lineage.",
            headline: "Restore active checkpoint",
            summary: "Re-apply the current active checkpoint as the live brain state."
        )
    }

    static func rollbackActiveCheckpoint(
        checkpointID: String
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Restore the previous checkpoint \(checkpointID) and move the active brain state back to that saved version.",
            headline: "Rollback to \(checkpointID)",
            summary: "Restore the previous checkpoint in the active chain."
        )
    }

    static func approvePendingCheckpoints(
        count: Int,
        keepsActiveBrainStateStable: Bool
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Approve \(count) pending review checkpoint\(count == 1 ? "" : "s") and move them back to the automatic evolution path.",
            headline: "Approve \(count) pending checkpoint\(count == 1 ? "" : "s")",
            summary: keepsActiveBrainStateStable
                ? "Empty the review queue without restoring or rewriting the active brain state."
                : "Empty the review queue and let the automatic active slot advance to the most recent approved checkpoint."
        )
    }

    static func clearPendingReviewLineage(
        count: Int
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Remove persisted lineage from \(count) review checkpoint\(count == 1 ? "" : "s"). Review records remain, but recovered risk, permit, ticket, audit, and kill-switch facts will be cleared.",
            headline: "Clear lineage on \(count) pending checkpoint\(count == 1 ? "" : "s")",
            summary: "This preserves the review queue but removes recovered lineage payloads from lineage-backed entries."
        )
    }

    static func approveSelectedCheckpoints(
        count: Int
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Approve \(count) selected review checkpoint\(count == 1 ? "" : "s") and move only that slice back to the automatic evolution path.",
            headline: "Approve \(count) selected checkpoint\(count == 1 ? "" : "s")",
            summary: "Only the selected review checkpoints leave the queue. The untouched review head and queue tail stay visible."
        )
    }

    static func markSelectedCheckpointsForReview(
        count: Int
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Move \(count) selected automatic checkpoint\(count == 1 ? "" : "s") into the explicit review path without restoring them.",
            headline: "Mark \(count) selected checkpoint\(count == 1 ? "" : "s") for review",
            summary: "Only the selected automatic checkpoints move into the review queue."
        )
    }

    static func clearSelectedCheckpointLineages(
        count: Int
    ) -> DecisionEvolutionMutationIntentCopy {
        DecisionEvolutionMutationIntentCopy(
            message: "Remove persisted lineage from \(count) selected checkpoint\(count == 1 ? "" : "s"). The checkpoint records remain in place.",
            headline: "Clear lineage on \(count) selected checkpoint\(count == 1 ? "" : "s")",
            summary: "This keeps the selected checkpoint records but removes their recovered L13 lineage facts."
        )
    }
}

enum DecisionEvolutionMutationPhraseSupport {
    static let reviewQueueWillBeEmptiedLine = "Review queue will be emptied."
    static let approvalMovesToAutomaticLine = "Approval state will move from review-suggested to automatic."

    static func checkpointToken(_ checkpointID: String?) -> String {
        DecisionEvolutionCheckpointLexiconSupport.checkpointToken(checkpointID)
    }

    static func checkpointWillEnterReviewQueueLine(
        checkpointID: String
    ) -> String {
        "Checkpoint \(checkpointID) will enter the review queue."
    }

    static func selectedCheckpointsMoveToAutomaticLine(
        count: Int
    ) -> String {
        "\(count) selected checkpoint(s) will move from review-suggested to automatic."
    }

    static func selectedCheckpointsEnterReviewQueueLine(
        count: Int
    ) -> String {
        "\(count) selected checkpoint(s) will enter the review queue."
    }

    static func pendingCheckpointsMoveToAutomaticLine(
        count: Int
    ) -> String {
        "\(count) checkpoint(s) will move from review-suggested to automatic."
    }

    static func automaticActiveSlotRemainsLine(
        projectedActiveID: String
    ) -> String {
        "Automatic active slot remains \(projectedActiveID)."
    }

    static func automaticActiveSlotMovesToLine(
        projectedActiveID: String
    ) -> String {
        "Automatic active slot will move to \(projectedActiveID)."
    }

    static func automaticActiveSlotTransitionLine(
        currentCheckpointID: String?,
        projectedCheckpointID: String?
    ) -> String {
        "Active automatic slot will move from \(checkpointToken(currentCheckpointID)) to \(checkpointToken(projectedCheckpointID))."
    }

    static func activeCheckpointRemainsLine(
        checkpointID: String?
    ) -> String {
        "Active checkpoint remains \(checkpointToken(checkpointID))."
    }

    static func activeCheckpointTransitionLine(
        currentCheckpointID: String?,
        projectedCheckpointID: String
    ) -> String {
        "Active checkpoint will move from \(checkpointToken(currentCheckpointID)) to \(projectedCheckpointID)."
    }

    static func restoredBrainStateLine(
        checkpointID: String,
        projectedActiveID: String?
    ) -> String {
        "Live brain state will restore from \(checkpointID), but the automatic active slot remains \(checkpointToken(projectedActiveID))."
    }

    static func reviewHeadAlignedLine(
        checkpointID: String
    ) -> String {
        "Review head stays aligned on \(checkpointID) until its approval state changes."
    }

    static func reviewHeadRemainsLine(
        checkpointID: String
    ) -> String {
        "Review head remains \(checkpointID)."
    }

    static func currentReviewHeadRemainsLine(
        checkpointID: String
    ) -> String {
        "Current review head remains \(checkpointID)."
    }

    static func reviewHeadShiftLine(
        checkpointID: String
    ) -> String {
        "Review head will shift to \(checkpointID)."
    }

    static func reviewQueueRetainedAfterApprovalLine(
        count: Int
    ) -> String {
        "Review queue will keep \(count) checkpoint(s) after approval."
    }

    static func suggestedKillSwitchRemovalWarning(
        count: Int
    ) -> String {
        "\(count) suggested kill-switch recommendation(s) will be removed with the lineage payload."
    }
}

struct DecisionEvolutionMutationIntent: Identifiable, Equatable, Sendable {
    let kind: DecisionEvolutionMutationKind
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let preview: DecisionEvolutionMutationPreview

    var id: String { preview.id }

    var previewPresentation: DecisionEvolutionMutationPreviewPresentation {
        DecisionEvolutionMutationPreviewPresentation(
            toneBadgeTitle: isDestructive ? "DESTRUCTIVE" : "GUARDED",
            impactTitle: "Control-surface impact",
            impactDetail: "See the active/review shift before you open the guarded confirmation sheet.",
            impactTargetsPrefix: DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix,
            activeTransitionTitle: DecisionEvolutionMutationLabelPresentationSupport.activeTransitionTitle,
            reviewTransitionTitle: "Review",
            transitionArrow: "→",
            currentLineTitle: "Current",
            projectedLineTitle: "Projected",
            missingCheckpointToken: DecisionEvolutionCheckpointLexiconSupport.missingCheckpointToken,
            changeSectionTitle: "Will change",
            retainedSectionTitle: "Will remain",
            warningSectionTitle: "Watch",
            cancelTitle: "Cancel"
        )
    }
}

struct DecisionEvolutionMutationOutcome: Identifiable, Equatable, Sendable {
    let kind: DecisionEvolutionMutationKind
    let title: String
    let message: String
    let isSuccess: Bool
    let isDestructive: Bool
    let affectedCheckpointIDs: [String]
    let recordedAt: Date

    var id: String {
        "\(kind.rawValue):\(recordedAt.timeIntervalSince1970)"
    }

    var statusTitle: String {
        DecisionEvolutionMutationOutcomePresentationSupport.statusTitle(
            isSuccess: isSuccess,
            isDestructive: isDestructive
        )
    }

    var presentation: DecisionEvolutionMutationOutcomePresentation {
        DecisionEvolutionMutationOutcomePresentation(
            statusTitle: statusTitle,
            iconName: DecisionEvolutionMutationOutcomePresentationSupport.iconName(
                isSuccess: isSuccess,
                isDestructive: isDestructive
            ),
            dismissTitle: DecisionEvolutionMutationOutcomePresentationSupport.dismissTitle,
            targetsPrefix: DecisionEvolutionMutationOutcomePresentationSupport.targetsPrefix,
            tone: DecisionEvolutionMutationOutcomePresentationSupport.tone(
                isSuccess: isSuccess,
                isDestructive: isDestructive
            )
        )
    }

    func affects(checkpointID: String) -> Bool {
        affectedCheckpointIDs.contains(checkpointID)
    }

    func isVisible(in controlSurface: DecisionEvolutionControlSurface) -> Bool {
        guard !affectedCheckpointIDs.isEmpty else { return true }
        let checkpointIDs = Set(controlSurface.allCheckpointPresentations.map(\.checkpointID))
        return !checkpointIDs.intersection(affectedCheckpointIDs).isEmpty
    }
}

extension DecisionEvolutionControlSurface {
    var allCheckpointPresentations: [DecisionEvolutionCheckpointPresentation] {
        var ordered: [DecisionEvolutionCheckpointPresentation] = []
        var seen = Set<String>()

        func append(_ presentation: DecisionEvolutionCheckpointPresentation?) {
            guard let presentation else { return }
            guard seen.insert(presentation.checkpointID).inserted else { return }
            ordered.append(presentation)
        }

        append(activePresentation)
        append(reviewPresentation)
        pendingReviewPresentations.forEach(append)
        return ordered
    }

    func presentation(for checkpointID: String) -> DecisionEvolutionCheckpointPresentation? {
        allCheckpointPresentations.first { $0.checkpointID == checkpointID }
    }
}

enum DecisionEvolutionMutationIntentFactory {
    static func pilotMutationIntents(
        controlSurface: DecisionEvolutionControlSurface
    ) -> [DecisionEvolutionMutationIntent] {
        [
            restoreActiveCheckpoint(controlSurface: controlSurface),
            rollbackActiveCheckpoint(controlSurface: controlSurface),
            approvePendingCheckpoints(controlSurface: controlSurface),
            clearPendingReviewLineage(controlSurface: controlSurface)
        ]
        .compactMap { $0 }
    }

    static func applyCheckpoint(
        checkpointID: String,
        controlSurface: DecisionEvolutionControlSurface,
        presentation override: DecisionEvolutionCheckpointPresentation? = nil
    ) -> DecisionEvolutionMutationIntent? {
        guard let presentation = resolvedPresentation(
            checkpointID: checkpointID,
            controlSurface: controlSurface,
            override: override
        ), presentation.applyReady else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.applyCheckpoint(
            checkpointID: checkpointID
        )

        let currentActiveID = controlSurface.activePresentation?.checkpointID
        let currentReviewID = controlSurface.reviewPresentation?.checkpointID
        let projectedReviewID = currentReviewID == checkpointID ? checkpointID : currentReviewID
        let projectedActiveID = projectedRestoredActiveCheckpointID(
            targetCheckpointID: checkpointID,
            targetPresentation: presentation,
            currentActiveCheckpointID: currentActiveID
        )
        var changes = [
            projectedActiveID == checkpointID
                ? DecisionEvolutionMutationPhraseSupport.activeCheckpointTransitionLine(
                    currentCheckpointID: currentActiveID,
                    projectedCheckpointID: checkpointID
                )
                : DecisionEvolutionMutationPhraseSupport.restoredBrainStateLine(
                    checkpointID: checkpointID,
                    projectedActiveID: projectedActiveID
                )
        ]

        if let currentReviewID {
            if currentReviewID == checkpointID {
                changes.append(
                    DecisionEvolutionMutationPhraseSupport.reviewHeadAlignedLine(
                        checkpointID: checkpointID
                    )
                )
            } else {
                changes.append(
                    DecisionEvolutionMutationPhraseSupport.reviewHeadRemainsLine(
                        checkpointID: currentReviewID
                    )
                )
            }
        }

        return DecisionEvolutionMutationIntent(
            kind: .applyCheckpoint,
            title: DecisionEvolutionMutationActionLexiconSupport.applyCheckpointTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.applyCheckpointTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .applyCheckpoint,
                scope: .checkpoint,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: [checkpointID],
                currentActiveCheckpointID: currentActiveID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: currentReviewID,
                projectedReviewCheckpointID: projectedReviewID,
                changeHighlights: changes,
                retainedHighlights: retainedHighlights(for: presentation)
                    + ["Checkpoint approval stays \(presentation.approvalStateTitle.lowercased())."],
                warningHighlights: applyWarnings(for: presentation)
            )
        )
    }

    static func approveCheckpoint(
        checkpointID: String,
        controlSurface: DecisionEvolutionControlSurface,
        presentation override: DecisionEvolutionCheckpointPresentation? = nil
    ) -> DecisionEvolutionMutationIntent? {
        guard let presentation = resolvedPresentation(
            checkpointID: checkpointID,
            controlSurface: controlSurface,
            override: override
        ), presentation.approvalState == .reviewSuggested else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.approveCheckpoint(
            checkpointID: checkpointID
        )

        let remainingReviewQueue = controlSurface.pendingReviewPresentations
            .filter { $0.checkpointID != checkpointID }
        let projectedReviewID = remainingReviewQueue.first?.checkpointID
        let projectedActiveID = projectedActiveCheckpointIDAfterApproval(
            targetPresentation: presentation,
            currentActivePresentation: controlSurface.activePresentation
        )
        var changes = [
            DecisionEvolutionMutationPhraseSupport.approvalMovesToAutomaticLine
        ]

        if projectedActiveID == checkpointID,
           controlSurface.activePresentation?.checkpointID != checkpointID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.automaticActiveSlotMovesToLine(
                    projectedActiveID: checkpointID
                )
            )
        } else if let projectedActiveID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.automaticActiveSlotRemainsLine(
                    projectedActiveID: projectedActiveID
                )
            )
        }

        if controlSurface.reviewPresentation?.checkpointID == checkpointID {
            if let projectedReviewID {
                changes.append(
                    DecisionEvolutionMutationPhraseSupport.reviewHeadShiftLine(
                        checkpointID: projectedReviewID
                    )
                )
            } else {
                changes.append(
                    DecisionEvolutionMutationPhraseSupport.reviewQueueWillBeEmptiedLine
                )
            }
        }

        return DecisionEvolutionMutationIntent(
            kind: .approveCheckpoint,
            title: DecisionEvolutionMutationActionLexiconSupport.approveCheckpointTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.approveCheckpointTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approveCheckpoint,
                scope: .checkpoint,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: [checkpointID],
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: projectedReviewID,
                changeHighlights: changes,
                retainedHighlights: retainedHighlights(for: presentation),
                warningHighlights: approvalWarnings(for: presentation)
            )
        )
    }

    static func markCheckpointForReview(
        checkpointID: String,
        controlSurface: DecisionEvolutionControlSurface,
        presentation override: DecisionEvolutionCheckpointPresentation? = nil
    ) -> DecisionEvolutionMutationIntent? {
        guard let presentation = resolvedPresentation(
            checkpointID: checkpointID,
            controlSurface: controlSurface,
            override: override
        ), presentation.approvalState != .reviewSuggested else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.markCheckpointForReview(
            checkpointID: checkpointID
        )

        let currentReview = controlSurface.reviewPresentation
        let currentActiveID = controlSurface.activePresentation?.checkpointID
        let projectedReviewID = projectedReviewCheckpointIDAfterMarkReview(
            targetPresentation: presentation,
            currentReviewPresentation: currentReview
        )
        let projectedActiveID = projectedActiveCheckpointIDAfterMarkReview(
            targetCheckpointID: checkpointID,
            currentActiveCheckpointID: currentActiveID
        )

        var changes = [DecisionEvolutionMutationPhraseSupport.checkpointWillEnterReviewQueueLine(
            checkpointID: checkpointID
        )]
        if currentActiveID == checkpointID {
            changes.append("Automatic active slot will hand off to the next available automatic checkpoint, if one exists.")
        } else if let projectedActiveID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.automaticActiveSlotRemainsLine(
                    projectedActiveID: projectedActiveID
                )
            )
        }
        if projectedReviewID == checkpointID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.reviewHeadShiftLine(
                    checkpointID: checkpointID
                )
            )
        } else if let projectedReviewID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.currentReviewHeadRemainsLine(
                    checkpointID: projectedReviewID
                )
            )
        }

        return DecisionEvolutionMutationIntent(
            kind: .markCheckpointForReview,
            title: DecisionEvolutionMutationActionLexiconSupport.markReviewTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.markReviewTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .markCheckpointForReview,
                scope: .checkpoint,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: [checkpointID],
                currentActiveCheckpointID: currentActiveID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: currentReview?.checkpointID,
                projectedReviewCheckpointID: projectedReviewID,
                changeHighlights: changes,
                retainedHighlights: retainedHighlights(for: presentation),
                warningHighlights: ["This action changes review state only; it does not restore the checkpoint."]
            )
        )
    }

    static func clearCheckpointLineage(
        checkpointID: String,
        controlSurface: DecisionEvolutionControlSurface,
        presentation override: DecisionEvolutionCheckpointPresentation? = nil
    ) -> DecisionEvolutionMutationIntent? {
        guard let presentation = resolvedPresentation(
            checkpointID: checkpointID,
            controlSurface: controlSurface,
            override: override
        ), presentation.hasLineage else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.clearCheckpointLineage(
            checkpointID: checkpointID
        )

        return DecisionEvolutionMutationIntent(
            kind: .clearCheckpointLineage,
            title: DecisionEvolutionMutationActionLexiconSupport.clearLineageTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.clearLineageTitle,
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearCheckpointLineage,
                scope: .checkpoint,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: [checkpointID],
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                changeHighlights: [
                    "Recovered lineage facts will be removed from checkpoint \(checkpointID).",
                    "Checkpoint record and approval state remain in place."
                ],
                retainedHighlights: [
                    "Diff summary remains available.",
                    presentation.approvalState == .reviewSuggested
                        ? "Review queue placement remains unchanged."
                        : "Automatic evolution status remains unchanged."
                ],
                warningHighlights: lineageRemovalWarnings(for: presentation)
            )
        )
    }

    static func restoreActiveCheckpoint(
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        guard let activePresentation = controlSurface.activePresentation else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.restoreActiveCheckpoint(
            checkpointID: activePresentation.checkpointID
        )
        return applyCheckpoint(
            checkpointID: activePresentation.checkpointID,
            controlSurface: controlSurface,
            presentation: activePresentation
        ).map { intent in
            DecisionEvolutionMutationIntent(
                kind: .restoreActiveCheckpoint,
                title: DecisionEvolutionMutationActionLexiconSupport.restoreActiveTitle,
                message: copy.message,
                confirmTitle: DecisionEvolutionMutationActionLexiconSupport.restoreActiveTitle,
                isDestructive: false,
                preview: DecisionEvolutionMutationPreview(
                    kind: .restoreActiveCheckpoint,
                    scope: .activePath,
                    headline: copy.headline,
                    summary: copy.summary,
                    targetCheckpointIDs: intent.preview.targetCheckpointIDs,
                    currentActiveCheckpointID: intent.preview.currentActiveCheckpointID,
                    projectedActiveCheckpointID: intent.preview.projectedActiveCheckpointID,
                    currentReviewCheckpointID: intent.preview.currentReviewCheckpointID,
                    projectedReviewCheckpointID: intent.preview.projectedReviewCheckpointID,
                    changeHighlights: intent.preview.changeHighlights,
                    retainedHighlights: intent.preview.retainedHighlights,
                    warningHighlights: intent.preview.warningHighlights
                )
            )
        }
    }

    static func rollbackActiveCheckpoint(
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        guard let rollbackID = controlSurface.activeRollbackCheckpointID else {
            return nil
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.rollbackActiveCheckpoint(
            checkpointID: rollbackID
        )

        let targetPresentation = controlSurface.presentation(for: rollbackID)
        let projectedActiveID = projectedRestoredActiveCheckpointID(
            targetCheckpointID: rollbackID,
            targetPresentation: targetPresentation,
            currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID
        )
        var changes = [
            projectedActiveID == rollbackID
                ? DecisionEvolutionMutationPhraseSupport.activeCheckpointTransitionLine(
                    currentCheckpointID: controlSurface.activePresentation?.checkpointID,
                    projectedCheckpointID: rollbackID
                )
                : DecisionEvolutionMutationPhraseSupport.restoredBrainStateLine(
                    checkpointID: rollbackID,
                    projectedActiveID: projectedActiveID
                )
        ]

        if let reviewID = controlSurface.reviewPresentation?.checkpointID {
            changes.append(
                DecisionEvolutionMutationPhraseSupport.reviewHeadRemainsLine(
                    checkpointID: reviewID
                )
            )
        }

        var retained = ["Rollback keeps the persisted checkpoint history intact."]
        if let targetPresentation {
            retained += retainedHighlights(for: targetPresentation)
        }

        var warnings = ["Rollback restores the previous checkpoint without changing review approvals."]
        if targetPresentation?.hasLineage != true {
            warnings.append("The rollback target does not currently carry recovered lineage details.")
        }

        return DecisionEvolutionMutationIntent(
            kind: .rollbackActiveCheckpoint,
            title: DecisionEvolutionMutationActionLexiconSupport.rollbackActiveTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.rollbackActiveTitle,
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .rollbackActiveCheckpoint,
                scope: .activePath,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: [rollbackID],
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                changeHighlights: changes,
                retainedHighlights: retained,
                warningHighlights: warnings
            )
        )
    }

    static func approvePendingCheckpoints(
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let targets = controlSurface.pendingReviewPresentations.map(\.checkpointID)
        guard !targets.isEmpty else { return nil }

        let lineageBackedCount = controlSurface.pendingReviewLineagePresentations.count
        let currentActiveCheckpointID = controlSurface.activePresentation?.checkpointID
        let projectedActiveCheckpointID: String?
        switch controlSurface.activeCheckpointSource {
        case .pinnedHint:
            projectedActiveCheckpointID = currentActiveCheckpointID
        case .automaticFallback, .none:
            projectedActiveCheckpointID = controlSurface.projectedAutomaticCheckpointIDAfterApprovingPendingQueue
        }

        var changeHighlights = [
            DecisionEvolutionMutationPhraseSupport.pendingCheckpointsMoveToAutomaticLine(
                count: targets.count
            ),
            DecisionEvolutionMutationPhraseSupport.reviewQueueWillBeEmptiedLine
        ]
        var retained: [String] = []

        if projectedActiveCheckpointID == currentActiveCheckpointID {
            retained.append(
                DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                    checkpointID: currentActiveCheckpointID
                )
            )
        } else {
            changeHighlights.append(
                DecisionEvolutionMutationPhraseSupport.automaticActiveSlotTransitionLine(
                    currentCheckpointID: currentActiveCheckpointID,
                    projectedCheckpointID: projectedActiveCheckpointID
                )
            )
        }

        if let retainedLine = DecisionEvolutionLineagePresentationSupport.retainedPendingReviewFactsLine(
            lineageBackedCount: lineageBackedCount
        ) {
            retained.append(retainedLine)
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.approvePendingCheckpoints(
            count: targets.count,
            keepsActiveBrainStateStable: projectedActiveCheckpointID == currentActiveCheckpointID
        )

        return DecisionEvolutionMutationIntent(
            kind: .approvePendingCheckpoints,
            title: DecisionEvolutionMutationActionLexiconSupport.approvePendingTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.approvePendingTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approvePendingCheckpoints,
                scope: .reviewQueue,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: targets,
                currentActiveCheckpointID: currentActiveCheckpointID,
                projectedActiveCheckpointID: projectedActiveCheckpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: nil,
                changeHighlights: changeHighlights,
                retainedHighlights: retained,
                warningHighlights: ["Approval does not clear kill-switch recommendations or lineage facts."]
            )
        )
    }

    static func clearPendingReviewLineage(
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let targets = controlSurface.pendingReviewPresentations
            .filter(\.hasLineage)
        guard !targets.isEmpty else { return nil }

        let ticketCount = targets.reduce(0) { $0 + $1.updateTicketSummaries.count }
        let auditCount = targets.reduce(0) { $0 + $1.auditFindings.count }
        let killSwitchCount = targets.reduce(0) { $0 + $1.killSwitches.count }

        var warnings: [String] = []
        if ticketCount > 0 {
            warnings.append("\(ticketCount) recovered ticket summary entry/entries will be removed from review previews.")
        }
        if auditCount > 0 {
            warnings.append("\(auditCount) audit finding(s) will no longer be recoverable from those checkpoints.")
        }
        if killSwitchCount > 0 {
            warnings.append(
                DecisionEvolutionMutationPhraseSupport.suggestedKillSwitchRemovalWarning(
                    count: killSwitchCount
                )
            )
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.clearPendingReviewLineage(
            count: targets.count
        )

        return DecisionEvolutionMutationIntent(
            kind: .clearPendingReviewLineage,
            title: DecisionEvolutionMutationActionLexiconSupport.clearReviewLineageTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.clearReviewLineageTitle,
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearPendingReviewLineage,
                scope: .reviewQueue,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: targets.map(\.checkpointID),
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                changeHighlights: [
                    "\(targets.count) review checkpoint(s) will lose persisted lineage details.",
                    "Review queue membership remains unchanged."
                ],
                retainedHighlights: [
                    "Checkpoint records remain available for review.",
                    DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                        checkpointID: controlSurface.activePresentation?.checkpointID
                    )
                ],
                warningHighlights: warnings
            )
        )
    }

    static func approveSelectedCheckpoints(
        presentations: [DecisionEvolutionCheckpointPresentation],
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let selectedReviewPresentations = presentations.filter {
            $0.approvalState == .reviewSuggested
        }
        let targets = orderedUniqueCheckpointIDs(
            selectedReviewPresentations.map(\.checkpointID)
        )
        guard !targets.isEmpty else { return nil }

        let targetSet = Set(targets)
        let remainingQueue = controlSurface.pendingReviewPresentations.filter {
            !targetSet.contains($0.checkpointID)
        }
        let lineageBackedCount = selectedReviewPresentations.filter(\.hasLineage).count

        var retained = [
            DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                checkpointID: controlSurface.activePresentation?.checkpointID
            )
        ]
        if let retainedLine = DecisionEvolutionLineagePresentationSupport.retainedSelectedFactsAfterApprovalLine(
            lineageBackedCount: lineageBackedCount
        ) {
            retained.append(retainedLine)
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.approveSelectedCheckpoints(
            count: targets.count
        )

        return DecisionEvolutionMutationIntent(
            kind: .approveSelectedCheckpoints,
            title: DecisionEvolutionMutationActionLexiconSupport.approveSelectedTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.approveSelectedTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approveSelectedCheckpoints,
                scope: .selection,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: targets,
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: remainingQueue.first?.checkpointID,
                changeHighlights: [
                    DecisionEvolutionMutationPhraseSupport.selectedCheckpointsMoveToAutomaticLine(
                        count: targets.count
                    ),
                    remainingQueue.isEmpty
                        ? DecisionEvolutionMutationPhraseSupport.reviewQueueWillBeEmptiedLine
                        : DecisionEvolutionMutationPhraseSupport.reviewQueueRetainedAfterApprovalLine(
                            count: remainingQueue.count
                        )
                ],
                retainedHighlights: retained,
                warningHighlights: ["Approval does not restore selected checkpoints as the live active brain state."]
            )
        )
    }

    static func markSelectedCheckpointsForReview(
        presentations: [DecisionEvolutionCheckpointPresentation],
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let targets = orderedUniquePresentations(
            presentations.filter { $0.approvalState == .automatic }
        )
        guard !targets.isEmpty else { return nil }

        let targetIDs = targets.map(\.checkpointID)
        let targetIDSet = Set(targetIDs)
        let projectedReviewID = preferredCheckpointID(
            from: (controlSurface.reviewPresentation.map { [$0] } ?? []) + targets
        )
        let currentActiveID = controlSurface.activePresentation?.checkpointID
        let projectedActiveID = currentActiveID.flatMap { targetIDSet.contains($0) ? nil : $0 }
        let copy = DecisionEvolutionMutationIntentCopySupport.markSelectedCheckpointsForReview(
            count: targetIDs.count
        )

        return DecisionEvolutionMutationIntent(
            kind: .markSelectedCheckpointsForReview,
            title: DecisionEvolutionMutationActionLexiconSupport.markSelectedTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.markSelectedTitle,
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .markSelectedCheckpointsForReview,
                scope: .selection,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: targetIDs,
                currentActiveCheckpointID: currentActiveID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: projectedReviewID,
                changeHighlights: [
                    DecisionEvolutionMutationPhraseSupport.selectedCheckpointsEnterReviewQueueLine(
                        count: targetIDs.count
                    ),
                    projectedActiveID == nil
                        ? "The automatic active slot will no longer point at the selected active checkpoint."
                        : DecisionEvolutionMutationPhraseSupport.automaticActiveSlotRemainsLine(
                            projectedActiveID: checkpointToken(projectedActiveID)
                        )
                ],
                retainedHighlights: [
                    "Restoring the live active brain state still requires an explicit apply action."
                ],
                warningHighlights: ["Marking for review changes approval state only; it does not restore any checkpoint."]
            )
        )
    }

    static func clearSelectedCheckpointLineages(
        presentations: [DecisionEvolutionCheckpointPresentation],
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let targets = orderedUniquePresentations(presentations.filter(\.hasLineage))
        guard !targets.isEmpty else { return nil }

        let ticketCount = targets.reduce(0) { $0 + $1.updateTicketSummaries.count }
        let auditCount = targets.reduce(0) { $0 + $1.auditFindings.count }
        let killSwitchCount = targets.reduce(0) { $0 + $1.killSwitches.count }

        var warnings: [String] = []
        if ticketCount > 0 {
            warnings.append("\(ticketCount) recovered ticket summary entry/entries will be removed from the selected checkpoints.")
        }
        if auditCount > 0 {
            warnings.append("\(auditCount) audit finding(s) will no longer be recoverable from the selected checkpoints.")
        }
        if killSwitchCount > 0 {
            warnings.append(
                DecisionEvolutionMutationPhraseSupport.suggestedKillSwitchRemovalWarning(
                    count: killSwitchCount
                )
            )
        }
        let copy = DecisionEvolutionMutationIntentCopySupport.clearSelectedCheckpointLineages(
            count: targets.count
        )

        return DecisionEvolutionMutationIntent(
            kind: .clearSelectedCheckpointLineages,
            title: DecisionEvolutionMutationActionLexiconSupport.clearSelectedLineageTitle,
            message: copy.message,
            confirmTitle: DecisionEvolutionMutationActionLexiconSupport.clearSelectedLineageTitle,
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearSelectedCheckpointLineages,
                scope: .selection,
                headline: copy.headline,
                summary: copy.summary,
                targetCheckpointIDs: targets.map(\.checkpointID),
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                changeHighlights: [
                    "\(targets.count) selected checkpoint(s) will lose persisted lineage details.",
                    "Approval state and queue membership remain unchanged."
                ],
                retainedHighlights: [
                    DecisionEvolutionMutationPhraseSupport.activeCheckpointRemainsLine(
                        checkpointID: controlSurface.activePresentation?.checkpointID
                    ),
                    "Review queue placement is preserved for review-suggested selections."
                ],
                warningHighlights: warnings
            )
        )
    }

    private static func resolvedPresentation(
        checkpointID: String,
        controlSurface: DecisionEvolutionControlSurface,
        override: DecisionEvolutionCheckpointPresentation?
    ) -> DecisionEvolutionCheckpointPresentation? {
        if let override {
            return override
        }

        return controlSurface.presentation(for: checkpointID)
    }

    private static func retainedHighlights(
        for presentation: DecisionEvolutionCheckpointPresentation
    ) -> [String] {
        var highlights: [String] = []

        if presentation.applyReady {
            highlights.append("A restorable brain-state snapshot is attached.")
        }
        if presentation.hasLineage {
            highlights.append("Recovered lineage remains available: \(presentation.summaryText)")
        }
        if !presentation.updateTicketSummaries.isEmpty {
            highlights.append("\(presentation.updateTicketSummaries.count) update ticket summary/ies remain attached.")
        }

        return highlights
    }

    private static func applyWarnings(
        for presentation: DecisionEvolutionCheckpointPresentation
    ) -> [String] {
        var warnings: [String] = []
        if presentation.approvalState == .reviewSuggested {
            warnings.append("Applying does not auto-approve the checkpoint. It will still sit in the review path until approved.")
        }
        if !presentation.killSwitches.isEmpty {
            warnings.append("Existing kill-switch recommendations remain active after restore.")
        }
        return warnings
    }

    private static func approvalWarnings(
        for presentation: DecisionEvolutionCheckpointPresentation
    ) -> [String] {
        var warnings = ["Approval does not restore the checkpoint as the active brain state."]
        if !presentation.killSwitches.isEmpty {
            warnings.append("Approval does not clear existing kill-switch recommendations.")
        }
        return warnings
    }

    private static func lineageRemovalWarnings(
        for presentation: DecisionEvolutionCheckpointPresentation
    ) -> [String] {
        var warnings: [String] = []
        if !presentation.updateTicketSummaries.isEmpty {
            warnings.append("\(presentation.updateTicketSummaries.count) update ticket summary/ies will be removed from recovered lineage.")
        }
        if !presentation.auditFindings.isEmpty {
            warnings.append("\(presentation.auditFindings.count) audit finding(s) will be removed from the checkpoint preview.")
        }
        if !presentation.killSwitches.isEmpty {
            warnings.append("\(presentation.killSwitches.count) suggested kill-switch recommendation(s) will be removed.")
        }
        return warnings
    }

    private static func checkpointToken(_ checkpointID: String?) -> String {
        DecisionEvolutionCheckpointLexiconSupport.checkpointToken(checkpointID)
    }

    private static func orderedUniqueCheckpointIDs(
        _ checkpointIDs: [String]
    ) -> [String] {
        checkpointIDs.reduce(into: [String]()) { uniqueIDs, checkpointID in
            guard !uniqueIDs.contains(checkpointID) else { return }
            uniqueIDs.append(checkpointID)
        }
    }

    private static func orderedUniquePresentations(
        _ presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> [DecisionEvolutionCheckpointPresentation] {
        presentations.reduce(into: [DecisionEvolutionCheckpointPresentation]()) { uniquePresentations, presentation in
            guard !uniquePresentations.contains(where: { $0.checkpointID == presentation.checkpointID }) else {
                return
            }
            uniquePresentations.append(presentation)
        }
    }

    private static func preferredCheckpointID(
        from presentations: [DecisionEvolutionCheckpointPresentation]
    ) -> String? {
        orderedUniquePresentations(presentations).max { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.checkpointID < rhs.checkpointID
        }?.checkpointID
    }

    private static func projectedRestoredActiveCheckpointID(
        targetCheckpointID: String,
        targetPresentation: DecisionEvolutionCheckpointPresentation?,
        currentActiveCheckpointID: String?
    ) -> String? {
        guard let targetPresentation else {
            return targetCheckpointID
        }

        if targetPresentation.approvalState == .automatic {
            return targetCheckpointID
        }

        return currentActiveCheckpointID
    }

    private static func projectedActiveCheckpointIDAfterApproval(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentActivePresentation: DecisionEvolutionCheckpointPresentation?
    ) -> String? {
        guard let currentActivePresentation else {
            return targetPresentation.checkpointID
        }

        if targetPresentation.createdAt != currentActivePresentation.createdAt {
            return targetPresentation.createdAt > currentActivePresentation.createdAt
                ? targetPresentation.checkpointID
                : currentActivePresentation.checkpointID
        }

        return targetPresentation.checkpointID > currentActivePresentation.checkpointID
            ? targetPresentation.checkpointID
            : currentActivePresentation.checkpointID
    }

    private static func projectedActiveCheckpointIDAfterMarkReview(
        targetCheckpointID: String,
        currentActiveCheckpointID: String?
    ) -> String? {
        guard currentActiveCheckpointID == targetCheckpointID else {
            return currentActiveCheckpointID
        }

        return nil
    }

    private static func projectedReviewCheckpointIDAfterMarkReview(
        targetPresentation: DecisionEvolutionCheckpointPresentation,
        currentReviewPresentation: DecisionEvolutionCheckpointPresentation?
    ) -> String? {
        guard let currentReviewPresentation else {
            return targetPresentation.checkpointID
        }

        if targetPresentation.createdAt != currentReviewPresentation.createdAt {
            return targetPresentation.createdAt > currentReviewPresentation.createdAt
                ? targetPresentation.checkpointID
                : currentReviewPresentation.checkpointID
        }

        return targetPresentation.checkpointID > currentReviewPresentation.checkpointID
            ? targetPresentation.checkpointID
            : currentReviewPresentation.checkpointID
    }
}
