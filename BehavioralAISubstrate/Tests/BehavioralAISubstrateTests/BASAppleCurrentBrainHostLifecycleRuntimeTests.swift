import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASAppleLifecycleKit
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Current Brain Host Lifecycle Runtime")
struct BASAppleCurrentBrainHostLifecycleRuntimeTests {
    @Model
    final class HostLifecycleUpdateFixture: BASAppleCurrentBrainUpdateEntity {
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

        static func basMake(from fields: BASCurrentBrainUpdateStoredFields) -> HostLifecycleUpdateFixture {
            HostLifecycleUpdateFixture(fields: fields)
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
    final class HostLifecycleCheckpointFixture: BASAppleEvolutionCheckpointEntity {
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

        static func basMake(from fields: BASEvolutionCheckpointStoredFields) -> HostLifecycleCheckpointFixture {
            HostLifecycleCheckpointFixture(fields: fields)
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
            for: HostLifecycleUpdateFixture.self,
            HostLifecycleCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var preparedLifecycleState = false

        let built: (String, String, String, String, [String], [String], Int, Int) =
            try BASAppleCurrentBrainHostLifecycleRuntimeExecutor.bootstrapAndBuildCurrentBrain(
            input: BASAppleCurrentBrainHostLifecycleRuntimeInput(
                bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput(
                    modeID: BASDecisionMode.primary.rawValue,
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
                                sourceType: "archive",
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
                    retrievalMode: "filtered",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
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
                        modeID: BASDecisionMode.primary.rawValue,
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
                        modeID: BASDecisionMode.primary.rawValue,
                        suppressionWeight: 0.8,
                        evidenceCount: 3,
                        updatedAt: now
                    )
                ]
            },
            mapTemplate: { $0 },
            mapFailurePattern: { $0 },
            buildCurrentBrain: { (
                result: BASAppleCurrentBrainLifecycleResult<HostLifecycleUpdateFixture, HostLifecycleCheckpointFixture>
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
        #expect(built.1 == BASDecisionMode.primary.rawValue)
        #expect(built.2 == BASInteractionSurface.notification.rawValue)
        #expect(built.3 == BASRiskLevel.high.rawValue)
        #expect(built.4 == ["night_message_cooling"])
        #expect(built.5 == ["night_fast_path_failure"])
        #expect(built.6 == 1)
        #expect(built.7 == 1)
    }

    @Test("host support runtime centralizes template and failure mapping")
    func hostSupportRuntimeUsesDescriptorOwnedSupportWiring() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_640)
        let container = try ModelContainer(
            for: HostLifecycleUpdateFixture.self,
            HostLifecycleCheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var preparedLifecycleState = false

        struct TemplateFixture {
            var id: String
            var modeID: String
            var riskLevelID: String
            var isPinned: Bool
            var successCount: Int
            var updatedAt: Date
        }

        struct FailurePatternFixture {
            var id: String
            var modeID: String
            var suppressionWeight: Double
            var evidenceCount: Int
            var updatedAt: Date
        }

        let built: (String, [String], [String], Int, Int) =
            try BASAppleCurrentBrainHostSupportRuntimeExecutor.bootstrapAndBuildCurrentBrain(
                input: BASAppleCurrentBrainHostLifecycleRuntimeInput(
                    bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput(
                        modeID: BASDecisionMode.primary.rawValue,
                        prompt: "Should I sleep on this?",
                        triggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue,
                        sourceSurfaceOverrideID: BASInteractionSurface.app.rawValue,
                        riskLevelOverrideID: BASRiskLevel.medium.rawValue,
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
                                    confidence: 0.9,
                                    sourceType: "archive",
                                    governanceStatus: .governed,
                                    provenanceSummary: "goal"
                                )
                            ],
                            candidates: [],
                            recentEvents: []
                        ),
                        embeddingScores: [],
                        retrievalMode: "filtered",
                        bootstrapBehavior: .generic,
                        cognitionBehavior: .generic
                    )
                ),
                in: context,
                support: BASAppleCurrentBrainHostSupportDescriptor(
                    prepareLifecycleState: {
                        preparedLifecycleState = true
                    },
                    recommendTemplateIDs: { _ in ["night_message_cooling"] },
                    selectTemplates: { _, _ in
                        [
                            TemplateFixture(
                                id: "night_message_cooling",
                                modeID: BASDecisionMode.primary.rawValue,
                                riskLevelID: BASRiskLevel.medium.rawValue,
                                isPinned: true,
                                successCount: 4,
                                updatedAt: now
                            )
                        ]
                    },
                    selectFailurePatterns: { _ in
                        [
                            FailurePatternFixture(
                                id: "long_explanation_backfires",
                                modeID: BASDecisionMode.primary.rawValue,
                                suppressionWeight: 0.7,
                                evidenceCount: 2,
                                updatedAt: now
                            )
                        ]
                    },
                    templateMapper: BASAppleCurrentBrainHostTemplateMapper(
                        id: \.id,
                        modeID: \.modeID,
                        riskLevelID: \.riskLevelID,
                        isPinned: \.isPinned,
                        successCount: \.successCount,
                        updatedAt: \.updatedAt
                    ),
                    failurePatternMapper: BASAppleCurrentBrainHostFailurePatternMapper(
                        id: \.id,
                        modeID: \.modeID,
                        suppressionWeight: \.suppressionWeight,
                        evidenceCount: \.evidenceCount,
                        updatedAt: \.updatedAt
                    )
                ),
                buildCurrentBrain: { (
                    result: BASAppleCurrentBrainLifecycleResult<HostLifecycleUpdateFixture, HostLifecycleCheckpointFixture>
                ) in
                    (
                        result.riskLevelID,
                        result.activeTemplateIDs,
                        result.failureGuardIDs,
                        result.commit.orderedUpdates.count,
                        result.commit.orderedCheckpoints.count
                    )
                }
            )

        #expect(preparedLifecycleState)
        #expect(built.0 == BASRiskLevel.medium.rawValue)
        #expect(built.1 == ["night_message_cooling"])
        #expect(built.2 == ["long_explanation_backfires"])
        #expect(built.3 == 1)
        #expect(built.4 == 1)
    }

    @Test("host lifecycle does not build current brain after transaction configuration refusal")
    func hostLifecycleDoesNotBuildAfterConfigurationRefusal() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_700)
        let schema = Schema([
            HostLifecycleUpdateFixture.self,
            HostLifecycleCheckpointFixture.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(
                    "updates",
                    schema: Schema([HostLifecycleUpdateFixture.self]),
                    isStoredInMemoryOnly: true
                ),
                ModelConfiguration(
                    "checkpoints",
                    schema: Schema([HostLifecycleCheckpointFixture.self]),
                    isStoredInMemoryOnly: true
                )
            ]
        )
        let context = ModelContext(container)
        var buildCallCount = 0

        do {
            let _: String = try BASAppleCurrentBrainHostLifecycleRuntimeExecutor
                .bootstrapAndBuildCurrentBrain(
                    input: BASAppleCurrentBrainHostLifecycleRuntimeInput(
                        bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput(
                            modeID: BASDecisionMode.primary.rawValue,
                            prompt: "Pause before publishing.",
                            triggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue,
                            preferredLanguages: ["en-AU"],
                            now: now,
                            projection: BASBrainProjection(
                                records: [],
                                candidates: [],
                                recentEvents: []
                            ),
                            embeddingScores: [],
                            retrievalMode: "filtered",
                            bootstrapBehavior: .generic,
                            cognitionBehavior: .generic
                        )
                    ),
                    in: context,
                    recommendTemplateIDs: { _ in [] },
                    selectTemplates: { _, _ in [BASAppleCurrentBrainBootstrapHostTemplateInput]() },
                    selectFailurePatterns: { _ in [BASAppleCurrentBrainBootstrapHostFailurePatternInput]() },
                    mapTemplate: { $0 },
                    mapFailurePattern: { $0 },
                    buildCurrentBrain: { (
                        _: BASAppleCurrentBrainLifecycleResult<HostLifecycleUpdateFixture, HostLifecycleCheckpointFixture>
                    ) in
                        buildCallCount += 1
                        return "published"
                    }
                )
            Issue.record("Expected the multiple configuration set to be rejected")
        } catch {
            #expect(
                error as? BASAppleCurrentBrainPersistenceTransactionError
                    == .requiresSingleConfiguration(actual: 2)
            )
        }

        #expect(buildCallCount == 0)
    }
}
