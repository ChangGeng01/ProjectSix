import Foundation
import SwiftData
import BASHostKit

@Model
final class DecisionEvolutionCheckpoint {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var fingerprint: String
    var previousCheckpointID: String?
    var modeRaw: String
    var sourceRaw: String
    var identityRoleRaw: String
    var boundaryModeRaw: String
    var calibrationStatusRaw: String
    var diffSummaryBlob: String
    var approvalStateRaw: String
    var rollbackReady: Bool
    var brainStateSnapshotBlob: String?
    var lineageSummaryBlob: String?

    init(
        id: String,
        createdAt: Date,
        fingerprint: String,
        previousCheckpointID: String?,
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        identityRole: DecisionIdentityRole,
        boundaryMode: DecisionBoundaryPolicyMode,
        calibrationStatus: DecisionCalibrationStatus,
        diffSummary: [String],
        approvalState: DecisionEvolutionApprovalState,
        rollbackReady: Bool,
        brainStateSnapshot: DecisionBrainState? = nil,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fingerprint = fingerprint
        self.previousCheckpointID = previousCheckpointID
        self.modeRaw = mode.rawValue
        self.sourceRaw = source.rawValue
        self.identityRoleRaw = identityRole.rawValue
        self.boundaryModeRaw = boundaryMode.rawValue
        self.calibrationStatusRaw = calibrationStatus.rawValue
        self.diffSummaryBlob = BrainStateUpdate.encode(diffSummary)
        self.approvalStateRaw = approvalState.rawValue
        self.rollbackReady = rollbackReady
        self.brainStateSnapshotBlob = BrainStateUpdate.encodeCodable(brainStateSnapshot)
        self.lineageSummaryBlob = BrainStateUpdate.encodeCodable(lineageSummary)
    }

    convenience init(storedFields: BASEvolutionCheckpointStoredFields) {
        self.init(
            id: storedFields.id,
            createdAt: storedFields.createdAt,
            fingerprint: storedFields.fingerprint,
            previousCheckpointID: storedFields.previousCheckpointID,
            mode: DecisionMode(rawValue: storedFields.modeName) ?? .quick,
            source: BrainStateUpdateSource(rawValue: storedFields.sourceID) ?? .explicitRefresh,
            identityRole: storedFields.identityRole,
            boundaryMode: storedFields.boundaryMode,
            calibrationStatus: storedFields.calibrationStatus,
            diffSummary: storedFields.diffSummary,
            approvalState: storedFields.approvalState,
            rollbackReady: storedFields.rollbackReady,
            brainStateSnapshot: storedFields.brainStateSnapshot,
            lineageSummary: storedFields.lineageSummary
        )
    }

    var mode: DecisionMode {
        DecisionMode(rawValue: modeRaw) ?? .quick
    }

    var source: BrainStateUpdateSource {
        BrainStateUpdateSource(rawValue: sourceRaw) ?? .explicitRefresh
    }

    var identityRole: DecisionIdentityRole {
        DecisionIdentityRole(rawValue: identityRoleRaw) ?? .pauseCompanion
    }

    var boundaryMode: DecisionBoundaryPolicyMode {
        DecisionBoundaryPolicyMode(rawValue: boundaryModeRaw) ?? .localOnlyAdvisory
    }

    var calibrationStatus: DecisionCalibrationStatus {
        DecisionCalibrationStatus(rawValue: calibrationStatusRaw) ?? .stable
    }

    var diffSummary: [String] {
        BrainStateUpdate.decode(diffSummaryBlob)
    }

    var approvalState: DecisionEvolutionApprovalState {
        DecisionEvolutionApprovalState(rawValue: approvalStateRaw) ?? .automatic
    }

    var lineageSummary: BASEvolutionLineageSummary? {
        BrainStateUpdate.decodeCodable(lineageSummaryBlob, as: BASEvolutionLineageSummary.self)
    }

    var brainStateSnapshot: DecisionBrainState? {
        BrainStateUpdate.decodeCodable(brainStateSnapshotBlob, as: DecisionBrainState.self)
    }

    var storedFields: BASEvolutionCheckpointStoredFields {
        BASEvolutionCheckpointStoredFields(
            id: id,
            createdAt: createdAt,
            fingerprint: fingerprint,
            previousCheckpointID: previousCheckpointID,
            modeName: mode.rawValue,
            sourceID: source.rawValue,
            identityRole: identityRole,
            boundaryMode: boundaryMode,
            calibrationStatus: calibrationStatus,
            diffSummary: diffSummary,
            approvalState: approvalState,
            rollbackReady: rollbackReady,
            brainStateSnapshot: brainStateSnapshot,
            lineageSummary: lineageSummary
        )
    }
}
