import Foundation
import SwiftData

enum DecisionEvolutionEngine {
    @discardableResult
    static func recordCheckpoint(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        brainState: DecisionBrainState,
        context: ModelContext,
        now: Date = .now
    ) -> DecisionEvolutionState {
        let existing = fetchCheckpoints(in: context)
        let latest = existing.first

        if let latest,
           latest.fingerprint == brainState.verificationSnapshot.fingerprint,
           latest.identityRole == brainState.identityProfile.role,
           latest.boundaryMode == brainState.boundaryPolicy.mode,
           latest.calibrationStatus == brainState.calibrationState.status {
            return currentState(from: existing, latest: latest)
        }

        let diffSummary = buildDiffSummary(previous: latest, brainState: brainState)
        let approvalState: DecisionEvolutionApprovalState =
            brainState.calibrationState.status == .drifting ? .reviewSuggested : .automatic

        let checkpoint = DecisionEvolutionCheckpoint(
            id: UUID().uuidString,
            createdAt: now,
            fingerprint: brainState.verificationSnapshot.fingerprint,
            previousCheckpointID: latest?.id,
            mode: mode,
            source: source,
            identityRole: brainState.identityProfile.role,
            boundaryMode: brainState.boundaryPolicy.mode,
            calibrationStatus: brainState.calibrationState.status,
            diffSummary: diffSummary,
            approvalState: approvalState,
            rollbackReady: true
        )
        context.insert(checkpoint)
        trimOldCheckpoints(in: context, now: now)
        try? context.save()

        return currentState(from: fetchCheckpoints(in: context), latest: checkpoint)
    }

    static func currentState(in context: ModelContext) -> DecisionEvolutionState {
        let checkpoints = fetchCheckpoints(in: context)
        return currentState(from: checkpoints, latest: checkpoints.first)
    }

    private static func fetchCheckpoints(in context: ModelContext) -> [DecisionEvolutionCheckpoint] {
        let descriptor = FetchDescriptor<DecisionEvolutionCheckpoint>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func currentState(
        from checkpoints: [DecisionEvolutionCheckpoint],
        latest: DecisionEvolutionCheckpoint?
    ) -> DecisionEvolutionState {
        guard let latest else { return .empty }

        let summary = DecisionEvolutionCheckpointSummary(
            id: latest.id,
            previousCheckpointID: latest.previousCheckpointID,
            createdAt: latest.createdAt,
            diffSummary: latest.diffSummary,
            rollbackReady: latest.rollbackReady,
            approvalState: latest.approvalState
        )

        return DecisionEvolutionState(
            latestCheckpoint: summary,
            checkpointCount: checkpoints.count,
            rollbackReady: latest.rollbackReady,
            pendingReviewCount: checkpoints.filter { $0.approvalState == .reviewSuggested }.count,
            recentDiffSummary: summary.diffSummary
        )
    }

    private static func buildDiffSummary(
        previous: DecisionEvolutionCheckpoint?,
        brainState: DecisionBrainState
    ) -> [String] {
        let boundaryModeLabel = brainState.boundaryPolicy.mode.rawValue.replacingOccurrences(of: "_", with: " ")

        guard let previous else {
            return [
                "Established the first local cognition checkpoint.",
                "Locked the role into \(brainState.identityProfile.role.title).",
                "Started with \(boundaryModeLabel)."
            ]
        }

        var diffs: [String] = []
        if previous.identityRole != brainState.identityProfile.role {
            diffs.append("Role shifted from \(previous.identityRole.title) to \(brainState.identityProfile.role.title).")
        }
        if previous.boundaryMode != brainState.boundaryPolicy.mode {
            diffs.append("Boundary mode tightened toward \(boundaryModeLabel).")
        }
        if previous.calibrationStatus != brainState.calibrationState.status {
            diffs.append("Calibration state moved to \(brainState.calibrationState.status.rawValue).")
        }
        if diffs.isEmpty {
            diffs.append("Recorded a new safe checkpoint without changing role or boundary posture.")
        }
        return Array(diffs.prefix(3))
    }

    private static func trimOldCheckpoints(in context: ModelContext, now: Date) {
        let checkpoints = fetchCheckpoints(in: context)
        for stale in checkpoints.dropFirst(BeforePolicy.RuntimeState.evolutionCheckpointLimit) {
            context.delete(stale)
        }
        for stale in checkpoints where stale.createdAt.addingTimeInterval(BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval) < now {
            context.delete(stale)
        }
    }
}
