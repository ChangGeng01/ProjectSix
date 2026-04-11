import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Current Brain Host Lifecycle Runtime")
struct BASAppleCurrentBrainHostLifecycleRuntimeTests {
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

    @Test("host lifecycle runtime centralizes lifecycle commit and host materialization")
    func hostLifecycleRuntimeBuildsHostBrainFromLifecycleCommit() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_500)
        let container = try ModelContainer(
            for: UpdateFixture.self,
            CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var preparedLifecycleState = false

        let built: (String, String, String, String, [String], [String], Int, Int) =
            BASAppleCurrentBrainHostLifecycleRuntimeExecutor.bootstrapAndBuildCurrentBrain(
            input: BASAppleCurrentBrainHostLifecycleRuntimeInput(
                bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput(
                    modeID: BASDecisionMode.quick.rawValue,
                    prompt: "Should I hold this until tomorrow?",
                    triggerID: BASCurrentBrainBootstrapTrigger.notification.rawValue,
                    sourceSurfaceOverrideID: BASInteractionSurface.notification.rawValue,
                    riskLevelOverrideID: BASRiskLevel.high.rawValue,
                    preferredLanguages: ["en-AU"],
                    now: now,
                    projection: BASBrainProjection(
                        records: [
                            BASGovernedMemory(
                                kind: .goal,
                                content: "Protect sleep before midnight",
                                scope: .user,
                                sensitivity: .low,
                                tier: .hot,
                                confidence: 0.94,
                                sourceType: "history",
                                governanceStatus: .governed,
                                provenanceSummary: "goal"
                            )
                        ],
                        candidates: [],
                        recentEvents: []
                    ),
                    embeddingScores: [BASAppleEmbeddingScoreInput(id: "goal-1", score: 0.92)],
                    taskGraphHeadline: "Pause before replying.",
                    taskGraphActiveNodeCount: 1,
                    taskGraphHasResumeCandidate: true,
                    taskGraphResumeHint: "Sleep on it.",
                    retrievalMode: "filtered"
                ),
                checkpointLimit: 4,
                checkpointRetentionInterval: 60 * 60
            ),
            in: context,
            prepareLifecycleState: {
                preparedLifecycleState = true
            },
            recommendTemplateIDs: { _ in ["night_message_cooling"] },
            selectTemplates: { _, _ in
                [
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: "night_message_cooling",
                        modeID: BASDecisionMode.quick.rawValue,
                        riskLevelID: BASRiskLevel.high.rawValue,
                        isPinned: true,
                        successCount: 5,
                        updatedAt: now
                    )
                ]
            },
            selectFailurePatterns: { _ in
                [
                    BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                        id: "night_fast_path_failure",
                        modeID: BASDecisionMode.quick.rawValue,
                        suppressionWeight: 0.8,
                        evidenceCount: 3,
                        updatedAt: now
                    )
                ]
            },
            mapTemplate: { $0 },
            mapFailurePattern: { $0 },
            buildCurrentBrain: { (
                result: BASAppleCurrentBrainLifecycleResult<UpdateFixture, CheckpointFixture>
            ) in
                (
                    result.triggerID,
                    result.modeID,
                    result.sourceSurfaceID,
                    result.riskLevelID,
                    result.activeTemplateIDs,
                    result.failureGuardIDs,
                    result.commit.orderedUpdates.count,
                    result.commit.orderedCheckpoints.count
                )
            }
        )

        #expect(preparedLifecycleState)
        #expect(built.0 == BASCurrentBrainBootstrapTrigger.notification.rawValue)
        #expect(built.1 == BASDecisionMode.quick.rawValue)
        #expect(built.2 == BASInteractionSurface.notification.rawValue)
        #expect(built.3 == BASRiskLevel.high.rawValue)
        #expect(built.4 == ["night_message_cooling"])
        #expect(built.5 == ["night_fast_path_failure"])
        #expect(built.6 == 1)
        #expect(built.7 == 1)
    }
}
