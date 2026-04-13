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

struct DecisionEvolutionMutationIntent: Identifiable, Equatable, Sendable {
    let kind: DecisionEvolutionMutationKind
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let preview: DecisionEvolutionMutationPreview

    var id: String { preview.id }
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
        if isSuccess {
            return isDestructive ? "Completed with lineage changes" : "Completed"
        }
        return "Action needs attention"
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
                ? "Active checkpoint will move from \(checkpointToken(currentActiveID)) to \(checkpointID)."
                : "Live brain state will restore from \(checkpointID), but the automatic active slot remains \(checkpointToken(projectedActiveID))."
        ]

        if let currentReviewID {
            if currentReviewID == checkpointID {
                changes.append("Review head stays aligned on \(checkpointID) until its approval state changes.")
            } else {
                changes.append("Review head remains \(currentReviewID).")
            }
        }

        return DecisionEvolutionMutationIntent(
            kind: .applyCheckpoint,
            title: "Apply checkpoint",
            message: "Restore checkpoint \(checkpointID) as the active brain state. This changes the live host state, but it does not auto-approve review status or clear lineage.",
            confirmTitle: "Apply checkpoint",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .applyCheckpoint,
                scope: .checkpoint,
                headline: "Apply \(checkpointID)",
                summary: "Restore this checkpoint as the active brain state while keeping review/audit facts visible.",
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

        let remainingReviewQueue = controlSurface.pendingReviewPresentations
            .filter { $0.checkpointID != checkpointID }
        let projectedReviewID = remainingReviewQueue.first?.checkpointID
        let projectedActiveID = projectedActiveCheckpointIDAfterApproval(
            targetPresentation: presentation,
            currentActivePresentation: controlSurface.activePresentation
        )
        var changes = [
            "Approval state will move from review-suggested to automatic."
        ]

        if projectedActiveID == checkpointID,
           controlSurface.activePresentation?.checkpointID != checkpointID {
            changes.append("Automatic active slot will move to \(checkpointID).")
        } else if let projectedActiveID {
            changes.append("Automatic active slot remains \(projectedActiveID).")
        }

        if controlSurface.reviewPresentation?.checkpointID == checkpointID {
            if let projectedReviewID {
                changes.append("Review head will shift to \(projectedReviewID).")
            } else {
                changes.append("Review queue will be cleared.")
            }
        }

        return DecisionEvolutionMutationIntent(
            kind: .approveCheckpoint,
            title: "Approve checkpoint",
            message: "Move checkpoint \(checkpointID) out of the review queue and back onto the automatic evolution path.",
            confirmTitle: "Approve checkpoint",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approveCheckpoint,
                scope: .checkpoint,
                headline: "Approve \(checkpointID)",
                summary: "This keeps the checkpoint record and lineage, but removes its review-suggested status.",
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

        var changes = ["Checkpoint \(checkpointID) will enter the review queue."]
        if currentActiveID == checkpointID {
            changes.append("Automatic active slot will hand off to the next available automatic checkpoint, if one exists.")
        } else if let projectedActiveID {
            changes.append("Automatic active slot remains \(projectedActiveID).")
        }
        if projectedReviewID == checkpointID {
            changes.append("Review head will shift to \(checkpointID).")
        } else if let projectedReviewID {
            changes.append("Current review head remains \(projectedReviewID).")
        }

        return DecisionEvolutionMutationIntent(
            kind: .markCheckpointForReview,
            title: "Mark review",
            message: "Move checkpoint \(checkpointID) into the review queue. This does not restore the checkpoint or change the active brain state.",
            confirmTitle: "Mark review",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .markCheckpointForReview,
                scope: .checkpoint,
                headline: "Mark \(checkpointID) for review",
                summary: "Queue this checkpoint for explicit host review without altering the live active state.",
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

        return DecisionEvolutionMutationIntent(
            kind: .clearCheckpointLineage,
            title: "Clear lineage",
            message: "Remove recovered lineage from checkpoint \(checkpointID). The checkpoint record stays, but persisted risk, permit, ticket, audit, and kill-switch facts are cleared.",
            confirmTitle: "Clear lineage",
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearCheckpointLineage,
                scope: .checkpoint,
                headline: "Clear lineage on \(checkpointID)",
                summary: "This keeps the checkpoint record but removes recovered L13 lineage facts.",
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
        return applyCheckpoint(
            checkpointID: activePresentation.checkpointID,
            controlSurface: controlSurface,
            presentation: activePresentation
        ).map { intent in
            DecisionEvolutionMutationIntent(
                kind: .restoreActiveCheckpoint,
                title: "Restore active",
                message: intent.message,
                confirmTitle: "Restore active",
                isDestructive: false,
                preview: DecisionEvolutionMutationPreview(
                    kind: .restoreActiveCheckpoint,
                    scope: .activePath,
                    headline: "Restore active checkpoint",
                    summary: "Re-apply the current active checkpoint as the live brain state.",
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

        let targetPresentation = controlSurface.presentation(for: rollbackID)
        let projectedActiveID = projectedRestoredActiveCheckpointID(
            targetCheckpointID: rollbackID,
            targetPresentation: targetPresentation,
            currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID
        )
        var changes = [
            projectedActiveID == rollbackID
                ? "Active checkpoint will move from \(checkpointToken(controlSurface.activePresentation?.checkpointID)) to \(rollbackID)."
                : "Live brain state will restore from \(rollbackID), but the automatic active slot remains \(checkpointToken(projectedActiveID))."
        ]

        if let reviewID = controlSurface.reviewPresentation?.checkpointID {
            changes.append("Review head remains \(reviewID).")
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
            title: "Rollback active",
            message: "Restore the previous checkpoint \(rollbackID) and move the active brain state back to that saved version.",
            confirmTitle: "Rollback active",
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .rollbackActiveCheckpoint,
                scope: .activePath,
                headline: "Rollback to \(rollbackID)",
                summary: "Restore the previous checkpoint in the active chain.",
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
        var retained = ["Active checkpoint remains \(checkpointToken(controlSurface.activePresentation?.checkpointID))."]
        if lineageBackedCount > 0 {
            retained.append("\(lineageBackedCount) lineage-backed review checkpoint(s) keep their recovered facts.")
        }

        return DecisionEvolutionMutationIntent(
            kind: .approvePendingCheckpoints,
            title: "Approve pending",
            message: "Approve \(targets.count) pending review checkpoint\(targets.count == 1 ? "" : "s") and move them back to the automatic evolution path.",
            confirmTitle: "Approve pending",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approvePendingCheckpoints,
                scope: .reviewQueue,
                headline: "Approve \(targets.count) pending checkpoint\(targets.count == 1 ? "" : "s")",
                summary: "Empty the review queue without restoring or rewriting the active brain state.",
                targetCheckpointIDs: targets,
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: nil,
                changeHighlights: [
                    "\(targets.count) checkpoint(s) will move from review-suggested to automatic.",
                    "Review queue will be emptied."
                ],
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
            warnings.append("\(killSwitchCount) suggested kill-switch recommendation(s) will be removed with the lineage payload.")
        }

        return DecisionEvolutionMutationIntent(
            kind: .clearPendingReviewLineage,
            title: "Clear review lineage",
            message: "Remove persisted lineage from \(targets.count) review checkpoint\(targets.count == 1 ? "" : "s"). Review records remain, but recovered risk, permit, ticket, audit, and kill-switch facts will be cleared.",
            confirmTitle: "Clear review lineage",
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearPendingReviewLineage,
                scope: .reviewQueue,
                headline: "Clear lineage on \(targets.count) pending checkpoint\(targets.count == 1 ? "" : "s")",
                summary: "This preserves the review queue but removes recovered lineage payloads from lineage-backed entries.",
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
                    "Active checkpoint remains \(checkpointToken(controlSurface.activePresentation?.checkpointID))."
                ],
                warningHighlights: warnings
            )
        )
    }

    static func approveSelectedCheckpoints(
        presentations: [DecisionEvolutionCheckpointPresentation],
        controlSurface: DecisionEvolutionControlSurface
    ) -> DecisionEvolutionMutationIntent? {
        let targets = orderedUniqueCheckpointIDs(
            presentations
                .filter { $0.approvalState == .reviewSuggested }
                .map(\.checkpointID)
        )
        guard !targets.isEmpty else { return nil }

        let targetSet = Set(targets)
        let remainingQueue = controlSurface.pendingReviewPresentations.filter {
            !targetSet.contains($0.checkpointID)
        }
        let lineageBackedCount = presentations.filter(\.hasLineage).count

        var retained = ["Active checkpoint remains \(checkpointToken(controlSurface.activePresentation?.checkpointID))."]
        if lineageBackedCount > 0 {
            retained.append("\(lineageBackedCount) selected checkpoint(s) keep their recovered lineage facts after approval.")
        }

        return DecisionEvolutionMutationIntent(
            kind: .approveSelectedCheckpoints,
            title: "Approve selected",
            message: "Approve \(targets.count) selected review checkpoint\(targets.count == 1 ? "" : "s") and move only that slice back to the automatic evolution path.",
            confirmTitle: "Approve selected",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .approveSelectedCheckpoints,
                scope: .selection,
                headline: "Approve \(targets.count) selected checkpoint\(targets.count == 1 ? "" : "s")",
                summary: "Only the selected review checkpoints leave the queue. The untouched review head and queue tail stay visible.",
                targetCheckpointIDs: targets,
                currentActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                projectedActiveCheckpointID: controlSurface.activePresentation?.checkpointID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: remainingQueue.first?.checkpointID,
                changeHighlights: [
                    "\(targets.count) selected checkpoint(s) will move from review-suggested to automatic.",
                    remainingQueue.isEmpty
                        ? "Review queue will be emptied."
                        : "Review queue will keep \(remainingQueue.count) checkpoint(s) after approval."
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

        return DecisionEvolutionMutationIntent(
            kind: .markSelectedCheckpointsForReview,
            title: "Mark selected",
            message: "Move \(targetIDs.count) selected automatic checkpoint\(targetIDs.count == 1 ? "" : "s") into the explicit review path without restoring them.",
            confirmTitle: "Mark selected",
            isDestructive: false,
            preview: DecisionEvolutionMutationPreview(
                kind: .markSelectedCheckpointsForReview,
                scope: .selection,
                headline: "Mark \(targetIDs.count) selected checkpoint\(targetIDs.count == 1 ? "" : "s") for review",
                summary: "Only the selected automatic checkpoints move into the review queue.",
                targetCheckpointIDs: targetIDs,
                currentActiveCheckpointID: currentActiveID,
                projectedActiveCheckpointID: projectedActiveID,
                currentReviewCheckpointID: controlSurface.reviewPresentation?.checkpointID,
                projectedReviewCheckpointID: projectedReviewID,
                changeHighlights: [
                    "\(targetIDs.count) selected checkpoint(s) will enter the review queue.",
                    projectedActiveID == nil
                        ? "The automatic active slot will no longer point at the selected active checkpoint."
                        : "The automatic active slot remains \(checkpointToken(projectedActiveID))."
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
            warnings.append("\(killSwitchCount) suggested kill-switch recommendation(s) will be removed with the lineage payload.")
        }

        return DecisionEvolutionMutationIntent(
            kind: .clearSelectedCheckpointLineages,
            title: "Clear selected lineage",
            message: "Remove persisted lineage from \(targets.count) selected checkpoint\(targets.count == 1 ? "" : "s"). The checkpoint records remain in place.",
            confirmTitle: "Clear selected lineage",
            isDestructive: true,
            preview: DecisionEvolutionMutationPreview(
                kind: .clearSelectedCheckpointLineages,
                scope: .selection,
                headline: "Clear lineage on \(targets.count) selected checkpoint\(targets.count == 1 ? "" : "s")",
                summary: "This keeps the selected checkpoint records but removes their recovered L13 lineage facts.",
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
                    "The active checkpoint remains \(checkpointToken(controlSurface.activePresentation?.checkpointID)).",
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
        checkpointID ?? "none"
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
