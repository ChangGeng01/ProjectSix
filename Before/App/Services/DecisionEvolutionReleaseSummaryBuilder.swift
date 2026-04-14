import Foundation

enum DecisionEvolutionReleaseSummaryBuilder {
    static func build(
        evolutionControlSurface: DecisionEvolutionControlSurface,
        eBrainSummary: DecisionSystemEBrainSummary?,
        dominantBlockers: [String],
        activeKillSwitches: [String],
        recommendedKillSwitchesHint: [String]
    ) -> DecisionSystemReleaseControlSummary {
        let blockerSignals = eBrainSummary?.source == .persistedCheckpoint ? [] : dominantBlockers
        let resolvedActiveKillSwitches = orderedUnique(
            activeKillSwitches
            + runtimeActiveKillSwitches(
                from: eBrainSummary,
                controlSurface: evolutionControlSurface
            )
        )
        let queueAuditFindings = evolutionControlSurface.queueAuditFindings
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
        let state: DecisionSystemReleaseState
        let headline: String
        var reasons: [String] = []

        if !resolvedActiveKillSwitches.isEmpty {
            state = .blocked
            headline = "Blocked by active kill switches"
            reasons.append("Kill switches are active on the current release path.")
        } else if !recommendedKillSwitches.isEmpty {
            state = .watch
            headline = "Watching recommended kill switches"
            reasons.append("Recommended kill switches are waiting for operator review before wider rollout.")
        } else if !blockerSignals.isEmpty {
            state = .blocked
            headline = "Blocked by runtime guardrails"
            reasons.append(contentsOf: blockerSignals)
        } else if evolutionControlSurface.activePresentation == nil {
            state = .watch
            headline = "Watching for the first active checkpoint"
            reasons.append("No active checkpoint is attached to the current release path yet.")
            if evolutionControlSurface.pendingReviewCount > 0 {
                reasons.append("\(evolutionControlSurface.pendingReviewCount) checkpoint(s) still require review before promotion.")
                appendQueueSignals(
                    to: &reasons,
                    auditFindings: queueAuditFindings,
                    killSwitches: queueKillSwitches
                )
            }
        } else if !canRestoreActiveCheckpoint {
            state = .blocked
            headline = "Blocked until the active checkpoint is restorable"
            reasons.append("The active checkpoint does not currently have a restorable brain-state snapshot.")
        } else if evolutionControlSurface.pendingReviewCount > 0 {
            state = .watch
            headline = "Watching the pending review queue"
            reasons.append("\(evolutionControlSurface.pendingReviewCount) checkpoint(s) still require review.")
            appendQueueSignals(
                to: &reasons,
                auditFindings: queueAuditFindings,
                killSwitches: queueKillSwitches
            )
        } else if !evolutionControlSurface.reviewAuditFindings.isEmpty {
            state = .watch
            headline = "Watching audit findings before wider rollout"
            reasons.append(contentsOf: evolutionControlSurface.reviewAuditFindings)
        } else if !canRollbackActiveCheckpoint {
            state = .watch
            headline = "Watching rollback readiness"
            reasons.append("The active checkpoint does not currently expose a previous checkpoint for rollback.")
        } else {
            state = .ready
            headline = "Ready for guarded pilot rollout"
            if let checkpointID = evolutionControlSurface.activePresentation?.checkpointID {
                reasons.append("Active checkpoint \(checkpointID) is restorable.")
            } else {
                reasons.append("The active checkpoint is restorable.")
            }
        }

        return DecisionSystemReleaseControlSummary(
            state: state,
            headline: headline,
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
            reviewCheckpointID: evolutionControlSurface.reviewPresentation?.checkpointID
        )
    }

    private static func appendQueueSignals(
        to reasons: inout [String],
        auditFindings: [String],
        killSwitches: [String]
    ) {
        if !killSwitches.isEmpty {
            reasons.append("Pending review kill switches: \(killSwitches.joined(separator: " • "))")
        }

        if !auditFindings.isEmpty {
            reasons.append("Pending review findings: \(auditFindings.joined(separator: " • "))")
        }
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

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}
