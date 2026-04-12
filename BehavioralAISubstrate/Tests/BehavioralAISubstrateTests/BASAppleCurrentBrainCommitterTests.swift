import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy

@Suite("BASApple Current Brain Committer")
struct BASAppleCurrentBrainCommitterTests {
    @Model
    final class UpdateFixture: BASAppleCurrentBrainUpdateEntity {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var source: String
        var mode: String
        var dominantGoal: String?
        var dominantReactionWeight: String
        var fingerprint: String
        var activeConstraints: [String]
        var activeTemplateIDs: [String]
        var failureGuardIDs: [String]

        init(fields: BASCurrentBrainUpdateStoredFields) {
            self.id = fields.id
            self.createdAt = fields.createdAt
            self.source = fields.source
            self.mode = fields.mode
            self.dominantGoal = fields.dominantGoal
            self.dominantReactionWeight = fields.dominantReactionWeight
            self.fingerprint = fields.fingerprint
            self.activeConstraints = fields.activeConstraints
            self.activeTemplateIDs = fields.activeTemplateIDs
            self.failureGuardIDs = fields.failureGuardIDs
        }

        static func basMake(from fields: BASCurrentBrainUpdateStoredFields) -> UpdateFixture {
            UpdateFixture(fields: fields)
        }

        var basSnapshot: BASCurrentBrainUpdateStoredFields {
            BASCurrentBrainUpdateStoredFields(
                id: id,
                createdAt: createdAt,
                source: source,
                mode: mode,
                dominantGoal: dominantGoal,
                dominantReactionWeight: dominantReactionWeight,
                fingerprint: fingerprint,
                activeConstraints: activeConstraints,
                activeTemplateIDs: activeTemplateIDs,
                failureGuardIDs: failureGuardIDs
            )
        }
    }

    @Model
    final class CheckpointFixture: BASAppleEvolutionCheckpointEntity {
        @Attribute(.unique) var id: String
        var createdAt: Date
        var fingerprint: String
        var previousCheckpointID: String?
        var modeName: String
        var sourceID: String
        var identityRoleRaw: String
        var boundaryModeRaw: String
        var calibrationStatusRaw: String
        var diffSummary: [String]
        var approvalStateRaw: String
        var rollbackReady: Bool

        init(fields: BASEvolutionCheckpointStoredFields) {
            self.id = fields.id
            self.createdAt = fields.createdAt
            self.fingerprint = fields.fingerprint
            self.previousCheckpointID = fields.previousCheckpointID
            self.modeName = fields.modeName
            self.sourceID = fields.sourceID
            self.identityRoleRaw = fields.identityRole.rawValue
            self.boundaryModeRaw = fields.boundaryMode.rawValue
            self.calibrationStatusRaw = fields.calibrationStatus.rawValue
            self.diffSummary = fields.diffSummary
            self.approvalStateRaw = fields.approvalState.rawValue
            self.rollbackReady = fields.rollbackReady
        }

        static func basMake(from fields: BASEvolutionCheckpointStoredFields) -> CheckpointFixture {
            CheckpointFixture(fields: fields)
        }

        var basSnapshot: BASEvolutionCheckpointStoredFields {
            BASEvolutionCheckpointStoredFields(
                id: id,
                createdAt: createdAt,
                fingerprint: fingerprint,
                previousCheckpointID: previousCheckpointID,
                modeName: modeName,
                sourceID: sourceID,
                identityRole: BASIdentityRole(rawValue: identityRoleRaw) ?? .pauseCompanion,
                boundaryMode: BASBoundaryPolicyMode(rawValue: boundaryModeRaw) ?? .localOnlyAdvisory,
                calibrationStatus: BASCalibrationStatus(rawValue: calibrationStatusRaw) ?? .stable,
                diffSummary: diffSummary,
                approvalState: BASEvolutionApprovalState(rawValue: approvalStateRaw) ?? .automatic,
                rollbackReady: rollbackReady
            )
        }
    }

    @Test("committer records checkpoint state and persists brain updates in one package-owned flow")
    func committerRecordsCheckpointAndUpdate() throws {
        let container = try ModelContainer(
            for: UpdateFixture.self,
            CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_744_322_200)
        let brainState = BASDecisionBrainState(
            profileCore: ["Protect sleep"],
            activeGoals: ["Wait until morning"],
            relevantMemories: ["Night replies usually backfire."],
            sessionBiases: ["prefer_pause"],
            retrievalTags: ["sleep", "night"],
            reactionWeights: BASReactionWeights(
                warmth: 0.72,
                directness: 0.61,
                brevity: 0.83,
                actionBias: 0.48
            ),
            identityProfile: BASIdentityProfile.default(modeName: "primary"),
            boundaryPolicy: BASBoundaryPolicyState.default(riskLevel: .high),
            calibrationState: BASCalibrationState(
                status: .drifting,
                alerts: [.highPendingInfluence],
                suggestedAdjustments: ["night impulse"],
                driftScore: 0.72,
                generatedAt: now
            ),
            loadedAt: now
        )
        let persistenceInput = BASCurrentBrainPersistenceApplier.updateInput(
            mode: "primary",
            bootstrapped: BASBootstrappedBrainState(
                brainState: brainState,
                dominantGoal: "Wait until morning",
                activeConstraints: ["no_send_tonight"],
                activeTemplateIDs: ["night_message_cooling"],
                failureGuardIDs: ["night_fast_path_failure"],
                taskGraphHint: nil
            )
        )

        let result: BASAppleCurrentBrainCommitWriteResult<UpdateFixture, CheckpointFixture> =
            BASAppleCurrentBrainCommitter.commit(
                modeName: "primary",
                sourceID: "notification",
                brainState: brainState,
                persistenceInput: persistenceInput,
                in: context,
                createdAt: now,
                checkpointLimit: 4,
                checkpointRetentionInterval: 60 * 60,
                updateLimit: 4,
                updateRetentionInterval: 60 * 60
            )

        #expect(result.wroteCheckpoint)
        #expect(result.evolutionState.checkpointCount == 1)
        #expect(result.brainState.evolutionState == result.evolutionState)
        #expect(result.orderedUpdates.count == 1)
        #expect(result.orderedCheckpoints.count == 1)
        #expect(result.orderedUpdates.first?.dominantGoal == "Wait until morning")
        #expect(result.orderedUpdates.first?.activeTemplateIDs == ["night_message_cooling"])
        #expect(result.orderedCheckpoints.first?.sourceID == "notification")
    }
}
