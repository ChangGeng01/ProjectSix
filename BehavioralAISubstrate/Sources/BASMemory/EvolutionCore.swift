import Foundation

public struct BASEvolutionCheckpointInput: Codable, Equatable, Sendable {
    public let modeName: String
    public let sourceID: String
    public let fingerprint: String
    public let identityRole: BASIdentityRole
    public let boundaryMode: BASBoundaryPolicyMode
    public let calibrationStatus: BASCalibrationStatus
    public let brainStateSnapshot: BASDecisionBrainState?
    public let lineageSummary: BASEvolutionLineageSummary?

    public init(
        modeName: String,
        sourceID: String,
        fingerprint: String,
        identityRole: BASIdentityRole,
        boundaryMode: BASBoundaryPolicyMode,
        calibrationStatus: BASCalibrationStatus,
        brainStateSnapshot: BASDecisionBrainState? = nil,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) {
        self.modeName = modeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fingerprint = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.identityRole = identityRole
        self.boundaryMode = boundaryMode
        self.calibrationStatus = calibrationStatus
        self.brainStateSnapshot = brainStateSnapshot
        self.lineageSummary = lineageSummary
    }
}

public struct BASEvolutionCheckpointStoredFields: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let createdAt: Date
    public let fingerprint: String
    public let previousCheckpointID: String?
    public let modeName: String
    public let sourceID: String
    public let identityRole: BASIdentityRole
    public let boundaryMode: BASBoundaryPolicyMode
    public let calibrationStatus: BASCalibrationStatus
    public let diffSummary: [String]
    public let approvalState: BASEvolutionApprovalState
    public let rollbackReady: Bool
    public let brainStateSnapshot: BASDecisionBrainState?
    public let lineageSummary: BASEvolutionLineageSummary?

    public init(
        id: String,
        createdAt: Date,
        fingerprint: String,
        previousCheckpointID: String?,
        modeName: String,
        sourceID: String,
        identityRole: BASIdentityRole,
        boundaryMode: BASBoundaryPolicyMode,
        calibrationStatus: BASCalibrationStatus,
        diffSummary: [String],
        approvalState: BASEvolutionApprovalState,
        rollbackReady: Bool,
        brainStateSnapshot: BASDecisionBrainState? = nil,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fingerprint = fingerprint
        self.previousCheckpointID = previousCheckpointID
        self.modeName = modeName
        self.sourceID = sourceID
        self.identityRole = identityRole
        self.boundaryMode = boundaryMode
        self.calibrationStatus = calibrationStatus
        self.diffSummary = diffSummary
        self.approvalState = approvalState
        self.rollbackReady = rollbackReady
        self.brainStateSnapshot = brainStateSnapshot
        self.lineageSummary = lineageSummary
    }
}

public enum BASEvolutionCheckpointPlanner {
    public static let defaultCheckpointLimit = 40
    public static let defaultRetentionInterval: TimeInterval = 60 * 60 * 24 * 30

    public static func checkpointInput(
        modeName: String,
        sourceID: String,
        brainState: BASDecisionBrainState,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) -> BASEvolutionCheckpointInput {
        BASEvolutionCheckpointInput(
            modeName: modeName,
            sourceID: sourceID,
            fingerprint: brainState.verificationSnapshot.fingerprint,
            identityRole: brainState.identityProfile.role,
            boundaryMode: brainState.boundaryPolicy.mode,
            calibrationStatus: brainState.calibrationState.status,
            brainStateSnapshot: brainState,
            lineageSummary: lineageSummary
        )
    }

    public static func shouldDeduplicate(
        latest: BASEvolutionCheckpointStoredFields?,
        input: BASEvolutionCheckpointInput
    ) -> Bool {
        guard let latest else {
            return false
        }

        return latest.fingerprint == input.fingerprint &&
            latest.identityRole == input.identityRole &&
            latest.boundaryMode == input.boundaryMode &&
            latest.calibrationStatus == input.calibrationStatus
    }

    public static func checkpointFields(
        id: String = UUID().uuidString,
        createdAt: Date,
        latest: BASEvolutionCheckpointStoredFields?,
        input: BASEvolutionCheckpointInput
    ) -> BASEvolutionCheckpointStoredFields {
        let diffSummary = buildDiffSummary(previous: latest, input: input)
        let approvalState: BASEvolutionApprovalState =
            input.calibrationStatus == .drifting ? .reviewSuggested : .automatic

        return BASEvolutionCheckpointStoredFields(
            id: id,
            createdAt: createdAt,
            fingerprint: input.fingerprint,
            previousCheckpointID: latest?.id,
            modeName: input.modeName,
            sourceID: input.sourceID,
            identityRole: input.identityRole,
            boundaryMode: input.boundaryMode,
            calibrationStatus: input.calibrationStatus,
            diffSummary: diffSummary,
            approvalState: approvalState,
            rollbackReady: true,
            brainStateSnapshot: input.brainStateSnapshot,
            lineageSummary: input.lineageSummary
        )
    }

    public static func currentState(
        from checkpoints: [BASEvolutionCheckpointStoredFields]
    ) -> BASEvolutionState {
        let ordered = checkpoints.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id > rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }

        guard let latest = ordered.first else {
            return .empty
        }

        let summary = BASEvolutionCheckpointSummary(
            id: latest.id,
            previousCheckpointID: latest.previousCheckpointID,
            createdAt: latest.createdAt,
            diffSummary: latest.diffSummary,
            rollbackReady: latest.rollbackReady,
            approvalState: latest.approvalState,
            lineageSummary: latest.lineageSummary
        )

        return BASEvolutionState(
            latestCheckpoint: summary,
            checkpointCount: ordered.count,
            rollbackReady: latest.rollbackReady,
            pendingReviewCount: ordered.filter { $0.approvalState == .reviewSuggested }.count,
            recentDiffSummary: summary.diffSummary
        )
    }

    public static func withLineageSummary(
        _ lineageSummary: BASEvolutionLineageSummary?,
        appliedTo checkpoint: BASEvolutionCheckpointStoredFields
    ) -> BASEvolutionCheckpointStoredFields {
        BASEvolutionCheckpointStoredFields(
            id: checkpoint.id,
            createdAt: checkpoint.createdAt,
            fingerprint: checkpoint.fingerprint,
            previousCheckpointID: checkpoint.previousCheckpointID,
            modeName: checkpoint.modeName,
            sourceID: checkpoint.sourceID,
            identityRole: checkpoint.identityRole,
            boundaryMode: checkpoint.boundaryMode,
            calibrationStatus: checkpoint.calibrationStatus,
            diffSummary: checkpoint.diffSummary,
            approvalState: checkpoint.approvalState,
            rollbackReady: checkpoint.rollbackReady,
            brainStateSnapshot: checkpoint.brainStateSnapshot,
            lineageSummary: lineageSummary
        )
    }

    public static func withApprovalState(
        _ approvalState: BASEvolutionApprovalState,
        appliedTo checkpoint: BASEvolutionCheckpointStoredFields
    ) -> BASEvolutionCheckpointStoredFields {
        BASEvolutionCheckpointStoredFields(
            id: checkpoint.id,
            createdAt: checkpoint.createdAt,
            fingerprint: checkpoint.fingerprint,
            previousCheckpointID: checkpoint.previousCheckpointID,
            modeName: checkpoint.modeName,
            sourceID: checkpoint.sourceID,
            identityRole: checkpoint.identityRole,
            boundaryMode: checkpoint.boundaryMode,
            calibrationStatus: checkpoint.calibrationStatus,
            diffSummary: checkpoint.diffSummary,
            approvalState: approvalState,
            rollbackReady: checkpoint.rollbackReady,
            brainStateSnapshot: checkpoint.brainStateSnapshot,
            lineageSummary: checkpoint.lineageSummary
        )
    }

    /// Selects checkpoints for automatic retention while protecting every checkpoint from the last 72 hours.
    ///
    /// `maxEntries` is a soft target: zero and negative values keep no optional older checkpoints, but
    /// cannot remove protected checkpoints. A zero, negative, NaN, or negative-infinite interval grants
    /// no optional age window; positive infinity disables optional age expiry subject to the soft cap.
    public static func retainedCheckpointIDs(
        in checkpoints: [BASEvolutionCheckpointStoredFields],
        now: Date,
        maxEntries: Int = defaultCheckpointLimit,
        retentionInterval: TimeInterval = defaultRetentionInterval
    ) -> Set<String> {
        let ordered = checkpoints.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id > rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }

        return BASMinimumRecoveryRetention.retainedIDs(
            in: ordered.map { (id: $0.id, createdAt: $0.createdAt) },
            now: now,
            maxEntries: maxEntries,
            retentionInterval: retentionInterval
        )
    }

    private static func buildDiffSummary(
        previous: BASEvolutionCheckpointStoredFields?,
        input: BASEvolutionCheckpointInput
    ) -> [String] {
        let boundaryModeLabel = input.boundaryMode.rawValue.replacingOccurrences(of: "_", with: " ")

        guard let previous else {
            return [
                "Established the first local cognition checkpoint.",
                "Locked the role into \(input.identityRole.title).",
                "Started with \(boundaryModeLabel)."
            ]
        }

        var diffs: [String] = []
        if previous.identityRole != input.identityRole {
            diffs.append("Role shifted from \(previous.identityRole.title) to \(input.identityRole.title).")
        }
        if previous.boundaryMode != input.boundaryMode {
            diffs.append("Boundary mode tightened toward \(boundaryModeLabel).")
        }
        if previous.calibrationStatus != input.calibrationStatus {
            diffs.append("Calibration state moved to \(input.calibrationStatus.rawValue).")
        }
        if diffs.isEmpty {
            diffs.append("Recorded a new safe checkpoint without changing role or boundary posture.")
        }
        return Array(diffs.prefix(3))
    }
}
