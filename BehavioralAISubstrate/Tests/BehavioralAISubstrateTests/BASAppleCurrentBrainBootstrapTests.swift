import Foundation
import SwiftData
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Current Brain Bootstrap")
struct BASAppleCurrentBrainBootstrapTests {
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

    @Test("host input builder centralizes host-source compilation for apple bootstrap")
    func hostInputBuilderCompilesContextAndDescriptors() {
        let now = Date(timeIntervalSince1970: 1_744_322_100)
        let input = BASAppleCurrentBrainBootstrapHostInputBuilder.build(
            context: BASAppleCurrentBrainBootstrapHostBuildContext(
                modeID: BASDecisionMode.primary.rawValue,
                prompt: "Should I wait until tomorrow?",
                triggerID: BASCurrentBrainBootstrapTrigger.notification.rawValue,
                sourceSurfaceOverrideID: BASInteractionSurface.notification.rawValue,
                riskLevelOverrideID: BASRiskLevel.high.rawValue,
                preferredLanguages: ["en-AU"],
                now: now,
                projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                embeddingScores: [
                    BASAppleEmbeddingScoreInput(id: "memory-1", score: 0.91)
                ],
                taskGraphHint: BASAppleCurrentBrainBootstrapHostInputBuilder.taskGraphInput(
                    headline: "Pause before sending.",
                    activeNodeCount: 1,
                    hasResumeCandidate: true,
                    resumeHint: "Resume tomorrow."
                ),
                retrievalMode: "filtered",
                bootstrapBehavior: .generic,
                cognitionBehavior: .generic,
                recommendedTemplateIDs: ["night_message_cooling"]
            ),
            templates: [
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "night_message_cooling",
                    modeID: BASDecisionMode.primary.rawValue,
                    riskLevelID: BASRiskLevel.high.rawValue,
                    isPinned: true,
                    successCount: 3,
                    updatedAt: now
                )
            ],
            failurePatterns: [
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "night_fast_path_failure",
                    modeID: BASDecisionMode.primary.rawValue,
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now
                )
            ],
            mapTemplate: { $0 },
            mapFailurePattern: { $0 }
        )

        #expect(input.modeID == BASDecisionMode.primary.rawValue)
        #expect(input.embeddingScores.map { $0.id } == ["memory-1"])
        #expect(input.taskGraphHint?.headline == "Pause before sending.")
        #expect(input.templates.map { $0.id } == ["night_message_cooling"])
        #expect(input.failurePatterns.map { $0.id } == ["night_fast_path_failure"])
    }

    @Test("host input builder can compile context directly from task graph carriers")
    func hostInputBuilderBuildsContextFromTaskGraphCarrier() {
        struct MockTaskGraph: Equatable {
            let headline: String?
            let activeNodeCount: Int
            let hasResumeCandidate: Bool
            let resumeHint: String?
        }

        let context = BASAppleCurrentBrainBootstrapHostInputBuilder.context(
            modeID: BASDecisionMode.primary.rawValue,
            prompt: "Should I sleep on this?",
            triggerID: BASCurrentBrainBootstrapTrigger.notification.rawValue,
            sourceSurfaceOverrideID: BASInteractionSurface.notification.rawValue,
            riskLevelOverrideID: BASRiskLevel.high.rawValue,
            preferredLanguages: ["en-AU"],
            now: Date(timeIntervalSince1970: 1_744_322_180),
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            embeddingScores: [BASAppleEmbeddingScoreInput(id: "memory-1", score: 0.88)],
            taskGraph: MockTaskGraph(
                headline: "Pause before replying.",
                activeNodeCount: 2,
                hasResumeCandidate: true,
                resumeHint: "Reopen tomorrow."
            ),
            headline: \.headline,
            activeNodeCount: \.activeNodeCount,
            hasResumeCandidate: \.hasResumeCandidate,
            resumeHint: \.resumeHint,
            retrievalMode: "filtered",
            bootstrapBehavior: .generic,
            cognitionBehavior: .generic,
            recommendedTemplateIDs: ["night_message_cooling"]
        )

        #expect(context.prompt == "Should I sleep on this?")
        #expect(context.embeddingScores.map { $0.id } == ["memory-1"])
        #expect(context.taskGraphHint?.headline == "Pause before replying.")
        #expect(context.taskGraphHint?.activeNodeCount == 2)
        #expect(context.recommendedTemplateIDs == ["night_message_cooling"])
    }

    @Test("brain bootstrap request adapter compiles minimal local request with neutral package defaults")
    func brainBootstrapRequestAdapterBuildsRequest() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_120)
        let request = try BASAppleBrainBootstrapRequestAdapter.request(
            modeID: BASDecisionMode.primary.rawValue,
            prompt: "Should I send this tonight?",
            triggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
            sourceSurfaceOverrideID: BASInteractionSurface.app.rawValue,
            riskLevelOverrideID: BASRiskLevel.low.rawValue,
            bootstrapBehavior: .generic,
            cognitionBehavior: .generic,
            preferredLanguages: ["en-AU"],
            now: now,
            retrievalMode: "filtered"
        )

        #expect(request.mode == BASDecisionMode.primary)
        #expect(request.source == BASMemorySource.pattern)
        #expect(request.sourceSurface == BASInteractionSurface.app)
        #expect(request.riskLevel == BASRiskLevel.low)
        #expect(request.retrievalMode == "filtered")
        #expect(request.now == now)
    }

    @Test("brain state compiler keeps request defaults package-owned")
    func currentBrainStateCompilerBuildsBrainStateFromProjection() throws {
        let brainState = try BASAppleCurrentBrainStateCompiler.brainState(
            modeID: BASDecisionMode.primary.rawValue,
            prompt: "Should I sleep on this?",
            projection: BASBrainProjection(
                records: [
                    BASGovernedMemory(
                        kind: .goal,
                        content: "Protect sleep before midnight",
                        scope: .user,
                        sensitivity: .low,
                        tier: .hot,
                        confidence: 0.93,
                        sourceType: "archive",
                        governanceStatus: .governed,
                        provenanceSummary: "goal"
                    )
                ],
                candidates: [],
                recentEvents: []
            ),
            retrievalMode: "filtered",
            preferredLanguages: ["en-AU"],
            now: Date(timeIntervalSince1970: 1_744_322_120)
        )

        #expect(brainState.activeGoals.contains { $0.contains("Protect sleep before midnight") })
        #expect(brainState.retrievalTags.contains("lang:english"))
    }

    @Test("projection brain state compiler owns app-session defaults")
    func projectionBrainStateCompilerBuildsAppSessionDefaults() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_180)
        let brainState = try BASAppleCurrentBrainProjectionStateCompiler.appSessionBrainState(
            modeID: BASDecisionMode.primary.rawValue,
            prompt: "Should I buy this tonight?",
            projection: BASBrainProjection(
                records: [
                    BASGovernedMemory(
                        kind: .goal,
                        content: "Protect sleep before midnight",
                        scope: .user,
                        sensitivity: .low,
                        tier: .hot,
                        confidence: 0.92,
                        sourceType: "archive",
                        governanceStatus: .governed,
                        provenanceSummary: "goal"
                    )
                ],
                candidates: [],
                recentEvents: []
            ),
            retrievalMode: "filtered",
            preferredLanguages: ["en-AU"],
            now: now
        )

        #expect(brainState.retrievalTags.contains(BASDecisionMode.primaryID))
        #expect(brainState.retrievalTags.contains("lang:english"))
        #expect(brainState.memoryGovernance.totalRecordCount == 1)
        #expect(brainState.activeGoals.contains { $0.contains("Protect sleep before midnight") })
    }

    @Test("runtime coordinator bootstraps and commits current brain state in one package-owned flow")
    func runtimeCoordinatorBootstrapsAndCommits() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_220)
        let container = try ModelContainer(
            for: UpdateFixture.self,
            CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let result: BASAppleCurrentBrainBootstrapCommitResult<UpdateFixture, CheckpointFixture> =
            try BASAppleCurrentBrainRuntimeCoordinator.bootstrapAndCommit(
                context: BASAppleCurrentBrainBootstrapHostBuildContext(
                    modeID: BASDecisionMode.primary.rawValue,
                    prompt: "Should I send this tonight?",
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
                    embeddingScores: [
                        BASAppleEmbeddingScoreInput(id: "goal-1", score: 0.9)
                    ],
                    taskGraphHint: BASAppleCurrentBrainBootstrapHostInputBuilder.taskGraphInput(
                        headline: "Pause before sending.",
                        activeNodeCount: 1,
                        hasResumeCandidate: true,
                        resumeHint: "Sleep on it."
                    ),
                    retrievalMode: "filtered"
                    ,
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                in: context,
                createdAt: now,
                checkpointLimit: 4,
                checkpointRetentionInterval: 60 * 60,
                recommendTemplateIDs: { _ in ["night_message_cooling"] },
                selectTemplates: { _, _ in
                    [
                        BASAppleCurrentBrainBootstrapHostTemplateInput(
                            id: "night_message_cooling",
                            modeID: BASDecisionMode.primary.rawValue,
                            riskLevelID: BASRiskLevel.high.rawValue,
                            isPinned: true,
                            successCount: 3,
                            updatedAt: now
                        )
                    ]
                },
                selectFailurePatterns: { _ in
                    [
                        BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                            id: "night_fast_path_failure",
                            modeID: BASDecisionMode.primary.rawValue,
                            suppressionWeight: 0.9,
                            evidenceCount: 2,
                            updatedAt: now
                        )
                    ]
                },
                mapTemplate: { $0 },
                mapFailurePattern: { $0 }
            )

        #expect(result.preparation.sourceSurface == .notification)
        #expect(result.preparation.riskLevel == .high)
        #expect(result.dominantGoal == "Protect sleep before midnight")
        #expect(result.orderedTemplateIDs == ["night_message_cooling"])
        #expect(result.orderedFailurePatternIDs == ["night_fast_path_failure"])
        #expect(result.commit.wroteCheckpoint)
        #expect(result.commit.orderedUpdates.count == 1)
        #expect(result.commit.orderedCheckpoints.count == 1)
    }

    @Test("bridge builder compacts host bootstrap orchestration into raw package output")
    func bridgeBuilderBootstrapsAndCommitsRawHostOutput() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_260)
        let container = try ModelContainer(
            for: UpdateFixture.self,
            CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let result: BASAppleCurrentBrainBootstrapBridgeResult<UpdateFixture, CheckpointFixture> =
            try BASAppleCurrentBrainBootstrapBridgeBuilder.bootstrapAndCommit(
                input: BASAppleCurrentBrainBootstrapBridgeInput(
                    modeID: BASDecisionMode.primary.rawValue,
                    prompt: "Should I send this tonight?",
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
                    embeddingScores: [
                        BASAppleEmbeddingScoreInput(id: "goal-1", score: 0.9)
                    ],
                    taskGraphHeadline: "Pause before sending.",
                    taskGraphActiveNodeCount: 1,
                    taskGraphHasResumeCandidate: true,
                    taskGraphResumeHint: "Sleep on it.",
                    retrievalMode: "filtered",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                in: context,
                createdAt: now,
                checkpointLimit: 4,
                checkpointRetentionInterval: 60 * 60,
                recommendTemplateIDs: { _ in ["night_message_cooling"] },
                selectTemplates: { _, _ in
                    [
                        BASAppleCurrentBrainBootstrapHostTemplateInput(
                            id: "night_message_cooling",
                            modeID: BASDecisionMode.primary.rawValue,
                            riskLevelID: BASRiskLevel.high.rawValue,
                            isPinned: true,
                            successCount: 3,
                            updatedAt: now
                        )
                    ]
                },
                selectFailurePatterns: { _ in
                    [
                        BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                            id: "night_fast_path_failure",
                            modeID: BASDecisionMode.primary.rawValue,
                            suppressionWeight: 0.9,
                            evidenceCount: 2,
                            updatedAt: now
                        )
                    ]
                },
                mapTemplate: { $0 },
                mapFailurePattern: { $0 }
            )

        #expect(result.sourceSurfaceID == BASInteractionSurface.notification.rawValue)
        #expect(result.riskLevelID == BASRiskLevel.high.rawValue)
        #expect(result.dominantGoal == "Protect sleep before midnight")
        #expect(result.activeTemplateIDs == ["night_message_cooling"])
        #expect(result.failureGuardIDs == ["night_fast_path_failure"])
        #expect(result.commit.wroteCheckpoint)
        #expect(result.commit.orderedUpdates.count == 1)
        #expect(result.commit.orderedCheckpoints.count == 1)
    }

    @Test("lifecycle executor owns current-brain bootstrap orchestration beyond the host bridge")
    func lifecycleExecutorBootstrapsAndCommitsCurrentBrainLifecycle() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_300)
        let container = try ModelContainer(
            for: UpdateFixture.self,
            CheckpointFixture.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var preparedLifecycleState = false

        let result: BASAppleCurrentBrainLifecycleResult<UpdateFixture, CheckpointFixture> =
            try BASAppleCurrentBrainLifecycleExecutor.bootstrapAndCommit(
                input: BASAppleCurrentBrainBootstrapBridgeInput(
                    modeID: BASDecisionMode.primary.rawValue,
                    prompt: "Should I pause before sending this?",
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
                    embeddingScores: [
                        BASAppleEmbeddingScoreInput(id: "goal-1", score: 0.91)
                    ],
                    taskGraphHeadline: "Pause before replying.",
                    taskGraphActiveNodeCount: 1,
                    taskGraphHasResumeCandidate: true,
                    taskGraphResumeHint: "Sleep on it.",
                    retrievalMode: "filtered",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic
                ),
                in: context,
                createdAt: now,
                checkpointLimit: 4,
                checkpointRetentionInterval: 60 * 60,
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
                mapFailurePattern: { $0 }
            )

        #expect(preparedLifecycleState)
        #expect(result.triggerID == BASCurrentBrainBootstrapTrigger.notification.rawValue)
        #expect(result.modeID == BASDecisionMode.primary.rawValue)
        #expect(result.sourceSurfaceID == BASInteractionSurface.notification.rawValue)
        #expect(result.riskLevelID == BASRiskLevel.high.rawValue)
        #expect(result.loadedAt == now)
        #expect(result.activeTemplateIDs == ["night_message_cooling"])
        #expect(result.failureGuardIDs == ["night_fast_path_failure"])
        #expect(result.commit.wroteCheckpoint)
        #expect(result.commit.orderedUpdates.count == 1)
        #expect(result.commit.orderedCheckpoints.count == 1)
    }

    @Test("prepare resolves neutral default surface, language mode, memory source, and risk overrides")
    func prepareResolvesBootstrapInputs() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.autoupdatingCurrent
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 23
        components.minute = 30
        let now = components.date ?? .distantPast

        let preparation = BASCurrentBrainBootstrapCoordinator.prepare(
            request: BASCurrentBrainBootstrapPreparationRequest(
                mode: .primary,
                prompt: "我想现在就发这条消息",
                trigger: .watchHandoff,
                riskLevelOverride: .high,
                preferredLanguages: ["zh-Hans-AU", "en-AU"],
                now: now
            )
        )

        #expect(preparation.sourceSurface == .watch)
        #expect(preparation.languageMode == .chinese)
        #expect(preparation.memorySource == .pattern)
        #expect(preparation.riskLevel == .high)
    }

    @Test("prepare honors host-injected bootstrap behavior for surface and memory source")
    func prepareHonorsHostInjectedBootstrapBehavior() {
        let preparation = BASCurrentBrainBootstrapCoordinator.prepare(
            request: BASCurrentBrainBootstrapPreparationRequest(
                mode: .comparative,
                prompt: "Compare these two options with more structure.",
                trigger: .watchHandoff,
                preferredLanguages: ["en-AU"],
                behavior: BASCurrentBrainBootstrapBehavior(
                    sourceSurfaceOverridesByTriggerID: [
                        BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.shortcut.rawValue
                    ],
                    enforcedSourceSurfaceByTriggerID: [:],
                    memorySourceOverridesByTriggerID: [
                        BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASMemorySource.archive.rawValue
                    ],
                    memorySourceOverridesByModeID: [
                        BASDecisionMode.comparative.identifier: BASMemorySource.pattern.rawValue
                    ]
                ),
                now: Date(timeIntervalSince1970: 1_744_322_320)
            )
        )

        #expect(preparation.sourceSurface == .shortcut)
        #expect(preparation.memorySource == .pattern)
    }

    @Test("bootstrap orders interventions and enriches the projection before cognition bootstrap")
    func bootstrapOrdersInterventionsAndBuildsBrainState() {
        let now = Date(timeIntervalSince1970: 1_744_321_800)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .primary,
            prompt: "Should I send this tonight?",
            trigger: .notification,
            sourceSurface: .app,
            riskLevel: .medium,
            languageMode: .english,
            memorySource: .cue,
            now: now
        )
        let projection = BASBrainProjection(
            records: [
                BASGovernedMemory(
                    kind: .goal,
                    content: "Protect sleep before midnight",
                    scope: .user,
                    sensitivity: .low,
                    tier: .hot,
                    confidence: 0.92,
                    sourceType: "archive",
                    governanceStatus: .governed,
                    provenanceSummary: "goal"
                ),
                BASGovernedMemory(
                    kind: .support,
                    content: "Holding the decision usually breaks the late-night loop.",
                    scope: .user,
                    sensitivity: .medium,
                    tier: .warm,
                    confidence: 0.84,
                    sourceType: "archive",
                    governanceStatus: .governed,
                    provenanceSummary: "support"
                )
            ],
            candidates: [],
            recentEvents: []
        )

        let execution = BASCurrentBrainBootstrapCoordinator.bootstrap(
            request: BASCurrentBrainBootstrapExecutionRequest(
                preparation: preparation,
                projection: projection,
                taskGraphHint: BASBrainTaskGraphHint(
                    headline: "Pause before you send.",
                    activeNodeCount: 1,
                    hasResumeCandidate: true,
                    resumeHint: "Pause before you send."
                ),
                retrievalMode: "filtered",
                cognitionBehavior: .generic,
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASInterventionTemplateDescriptor(
                        id: "fallback_template",
                        mode: .primary,
                        riskLevel: .medium,
                        isPinned: false,
                        successCount: 5,
                        updatedAt: now
                    ),
                    BASInterventionTemplateDescriptor(
                        id: "night_message_cooling",
                        mode: .primary,
                        riskLevel: .medium,
                        isPinned: true,
                        successCount: 1,
                        updatedAt: now.addingTimeInterval(-60)
                    )
                ],
                failurePatterns: [
                    BASFailurePatternDescriptor(
                        id: "night_fast_path_failure",
                        mode: .primary,
                        suppressionWeight: 0.9,
                        evidenceCount: 3,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(execution.orderedTemplateIDs == ["night_message_cooling", "fallback_template"])
        #expect(execution.orderedFailurePatternIDs == ["night_fast_path_failure"])
        #expect(execution.bootstrapped.activeTemplateIDs == execution.orderedTemplateIDs)
        #expect(execution.bootstrapped.failureGuardIDs == execution.orderedFailurePatternIDs)
        #expect(execution.bootstrapped.taskGraphHint?.headline == "Pause before you send.")
        #expect(execution.bootstrapped.brainState.boundaryPolicy.riskLevel == .medium)
        #expect(execution.bootstrapped.brainState.memorySlices.contains(where: { $0.role == BASBrainMemoryRole.goal }))
    }

    @Test("apple bootstrap adapter owns projection enrichment and intervention descriptor shaping")
    func appleBootstrapAdapterOwnsProjectionEnrichmentAndDescriptors() {
        let now = Date(timeIntervalSince1970: 1_744_321_900)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .reflective,
            prompt: "Should I reopen this conflict tonight?",
            trigger: .watchHandoff,
            sourceSurface: .watch,
            riskLevel: .high,
            languageMode: .english,
            memorySource: .reflection,
            now: now
        )
        let baseProjection = BASBrainProjection(
            records: [
                BASGovernedMemory(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
                    kind: .goal,
                    content: "Protect sleep before replying at night.",
                    scope: .user,
                    sensitivity: .low,
                    tier: .hot,
                    confidence: 0.95,
                    sourceType: "archive",
                    governanceStatus: .governed,
                    provenanceSummary: "Repeated reflection"
                )
            ],
            candidates: [],
            recentEvents: []
        )

        let execution = BASAppleCurrentBrainBootstrapAdapter.bootstrap(
            request: BASAppleCurrentBrainBootstrapRequest(
                preparation: preparation,
                baseProjection: baseProjection,
                embeddingScores: [
                    BASAppleEmbeddingScoreInput(
                        id: "00000000-0000-0000-0000-000000000111",
                        score: 0.88
                    )
                ],
                taskGraphHint: BASBrainTaskGraphHint(
                    headline: "Wait until morning before sending anything.",
                    activeNodeCount: 2,
                    hasResumeCandidate: true,
                    resumeHint: "Review after sleep."
                ),
                retrievalMode: "adaptive",
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: "fallback_template",
                        mode: .reflective,
                        riskLevel: .high,
                        isPinned: false,
                        successCount: 4,
                        updatedAt: now
                    ),
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: "night_message_cooling",
                        mode: .reflective,
                        riskLevel: .high,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now.addingTimeInterval(-30)
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapFailurePatternInput(
                        id: "night_fast_path_failure",
                        mode: .reflective,
                        suppressionWeight: 0.95,
                        evidenceCount: 3,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(execution.orderedTemplateIDs == ["night_message_cooling", "fallback_template"])
        #expect(execution.orderedFailurePatternIDs == ["night_fast_path_failure"])
        #expect(execution.bootstrapped.taskGraphHint?.headline == "Wait until morning before sending anything.")
        #expect(execution.bootstrapped.activeTemplateIDs == execution.orderedTemplateIDs)
        #expect(execution.bootstrapped.failureGuardIDs == execution.orderedFailurePatternIDs)
        #expect(execution.bootstrapped.brainState.boundaryPolicy.riskLevel == .high)
        #expect(execution.bootstrapped.brainState.memorySlices.contains(where: { $0.headline.contains("Protect sleep") }))
    }

    @Test("apple bootstrap request path preserves host cognition seeds")
    func appleBootstrapRequestPathPreservesHostCognitionSeeds() {
        let now = Date(timeIntervalSince1970: 1_744_321_950)
        let seed = BASReactionWeights(
            briefLanguage: 0.91,
            warmDirectTone: 0.33,
            lowCognitiveLoad: 0.22,
            interruptiveActionBias: 0.11,
            boundaryNamingBias: 0.44,
            tradeoffClarityBias: 0.55
        )
        let identity = BASIdentityProfile(
            role: .pauseCompanion,
            posture: .coaching,
            initiative: .guided,
            confidenceCeiling: 0.72,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Host-owned coaching boundary."
        )

        let execution = BASAppleCurrentBrainBootstrapAdapter.bootstrap(
            request: BASAppleCurrentBrainBootstrapRequest(
                preparation: BASCurrentBrainBootstrapPreparation(
                    mode: .primary,
                    prompt: "Should I wait until tomorrow?",
                    trigger: .launch,
                    sourceSurface: .app,
                    riskLevel: .low,
                    languageMode: .english,
                    memorySource: .archive,
                    now: now
                ),
                baseProjection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                retrievalMode: "filtered",
                reactionWeightSeed: seed,
                identityProfileOverride: identity,
                templates: [],
                failurePatterns: []
            )
        )

        #expect(execution.bootstrapped.brainState.reactionWeights == seed)
        #expect(execution.bootstrapped.brainState.identityProfile == identity)
        #expect(execution.bootstrapped.brainState.boundaryPolicy.mode == .localOnlyAdvisory)
    }

    @Test("apple bootstrap artifact also owns persistence input shaping")
    func appleBootstrapArtifactOwnsPersistenceInputShaping() {
        let now = Date(timeIntervalSince1970: 1_744_322_000)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .primary,
            prompt: "Should I wait until tomorrow?",
            trigger: .notification,
            sourceSurface: .notification,
            riskLevel: .medium,
            languageMode: .english,
            memorySource: .cue,
            now: now
        )

        let artifact = BASAppleCurrentBrainBootstrapAdapter.artifact(
            request: BASAppleCurrentBrainBootstrapRequest(
                preparation: preparation,
                baseProjection: BASBrainProjection(
                    records: [
                        BASGovernedMemory(
                            kind: .goal,
                            content: "Protect tomorrow morning energy.",
                            scope: .user,
                            sensitivity: .low,
                            tier: .hot,
                            confidence: 0.92,
                            sourceType: "archive",
                            governanceStatus: .governed,
                            provenanceSummary: "Repeated reflection"
                        )
                    ],
                    candidates: [],
                    recentEvents: []
                ),
                taskGraphHint: BASBrainTaskGraphHint(
                    headline: "Pause until morning.",
                    activeNodeCount: 1,
                    hasResumeCandidate: true,
                    resumeHint: "Reopen after sleep."
                ),
                retrievalMode: "filtered",
                cognitionBehavior: .generic,
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: "night_message_cooling",
                        mode: .primary,
                        riskLevel: .medium,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapFailurePatternInput(
                        id: "night_fast_path_failure",
                        mode: .primary,
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.persistenceInput.mode == BASDecisionMode.primary.identifier)
        #expect(artifact.persistenceInput.fingerprint == artifact.execution.bootstrapped.brainState.verificationSnapshot.fingerprint)
        #expect(Set(artifact.persistenceInput.activeTemplateIDs) == Set(artifact.execution.orderedTemplateIDs))
        #expect(Set(artifact.persistenceInput.failureGuardIDs) == Set(artifact.execution.orderedFailurePatternIDs))
    }

    @Test("source input artifact owns preparation plus execution assembly")
    func sourceInputArtifactOwnsPreparationAndExecutionAssembly() {
        let now = Date(timeIntervalSince1970: 1_744_322_100)
        let seed = BASReactionWeights(
            briefLanguage: 0.18,
            warmDirectTone: 0.22,
            lowCognitiveLoad: 0.31,
            interruptiveActionBias: 0.84,
            boundaryNamingBias: 0.27,
            tradeoffClarityBias: 0.16
        )
        let identity = BASIdentityProfile(
            role: .pauseCompanion,
            posture: .coaching,
            initiative: .guided,
            confidenceCeiling: 0.68,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Host-owned pause boundary."
        )
        let artifact = BASAppleCurrentBrainBootstrapAdapter.artifact(
            source: BASAppleCurrentBrainBootstrapSourceInput(
                preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                    mode: .primary,
                    prompt: "我是不是该等到明天？",
                    trigger: .notification,
                    riskLevelOverride: .high,
                    preferredLanguages: ["zh-Hans-AU"],
                    now: now
                ),
                projection: BASBrainProjection(
                    records: [
                        BASGovernedMemory(
                            kind: .goal,
                            content: "Sleep before sending night messages.",
                            scope: .user,
                            sensitivity: .low,
                            tier: .hot,
                            confidence: 0.9,
                            sourceType: "archive",
                            governanceStatus: .governed,
                            provenanceSummary: "Repeated goal"
                        )
                    ],
                    candidates: [],
                    recentEvents: []
                ),
                embeddingScores: [
                    BASAppleEmbeddingScoreInput(
                        id: "00000000-0000-0000-0000-000000000001",
                        score: 0.82
                    )
                ],
                taskGraphHint: BASBrainTaskGraphHint(
                    headline: "Wait until tomorrow morning.",
                    activeNodeCount: 1,
                    hasResumeCandidate: true,
                    resumeHint: "Resume after sleep."
                ),
                retrievalMode: "filtered",
                reactionWeightSeed: seed,
                identityProfileOverride: identity,
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASInterventionTemplateDescriptor(
                        id: "night_message_cooling",
                        mode: .primary,
                        riskLevel: .high,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASFailurePatternDescriptor(
                        id: "night_fast_path_failure",
                        mode: .primary,
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(artifact.execution.preparation.languageMode == .chinese)
        #expect(artifact.execution.preparation.riskLevel == .high)
        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.persistenceInput.mode == BASDecisionMode.primary.identifier)
        #expect(artifact.execution.bootstrapped.brainState.reactionWeights.dominantKey == .interruptiveActionBias)
    }

    @Test("source input artifact preserves host cognition seeds on neutral app surfaces")
    func sourceInputArtifactPreservesHostCognitionSeedsOnNeutralAppSurfaces() {
        let now = Date(timeIntervalSince1970: 1_744_322_101)
        let seed = BASReactionWeights(
            briefLanguage: 0.87,
            warmDirectTone: 0.24,
            lowCognitiveLoad: 0.31,
            interruptiveActionBias: 0.18,
            boundaryNamingBias: 0.29,
            tradeoffClarityBias: 0.12
        )
        let identity = BASIdentityProfile(
            role: .pauseCompanion,
            posture: .coaching,
            initiative: .guided,
            confidenceCeiling: 0.69,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Host-owned neutral app boundary."
        )

        let artifact = BASAppleCurrentBrainBootstrapAdapter.artifact(
            source: BASAppleCurrentBrainBootstrapSourceInput(
                preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                    mode: .primary,
                    prompt: "Should I wait?",
                    trigger: .launch,
                    sourceSurfaceOverride: .app,
                    riskLevelOverride: .low,
                    preferredLanguages: ["en-AU"],
                    now: now
                ),
                projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                retrievalMode: "filtered",
                reactionWeightSeed: seed,
                identityProfileOverride: identity,
                templates: [],
                failurePatterns: []
            )
        )

        #expect(artifact.execution.bootstrapped.brainState.reactionWeights == seed)
        #expect(artifact.execution.bootstrapped.brainState.identityProfile == identity)
        #expect(artifact.execution.bootstrapped.brainState.boundaryPolicy.mode == .localOnlyAdvisory)
    }

    @Test("host bootstrap adapter compiles raw bridge inputs into artifact semantics")
    func hostBootstrapAdapterCompilesRawBridgeInputsIntoArtifactSemantics() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_200)

        let artifact = try BASAppleCurrentBrainBootstrapHostAdapter.artifact(
            from: BASAppleCurrentBrainBootstrapHostSourceInput(
                modeID: BASDecisionMode.primaryID,
                prompt: "Should I wait until morning?",
                triggerID: "notification",
                sourceSurfaceOverrideID: "notification",
                riskLevelOverrideID: "high",
                preferredLanguages: ["en-AU"],
                now: now,
                projection: BASBrainProjection(
                    records: [
                        BASGovernedMemory(
                            kind: .goal,
                            content: "Protect tomorrow morning energy.",
                            scope: .user,
                            sensitivity: .low,
                            tier: .hot,
                            confidence: 0.91,
                            sourceType: "archive",
                            governanceStatus: .governed,
                            provenanceSummary: "goal"
                        )
                    ],
                    candidates: [],
                    recentEvents: []
                ),
                embeddingScores: [
                    BASAppleEmbeddingScoreInput(
                        id: "00000000-0000-0000-0000-000000000999",
                        score: 0.8
                    )
                ],
                taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput(
                    headline: "Pause before you send.",
                    activeNodeCount: 1,
                    hasResumeCandidate: true,
                    resumeHint: "Pause before you send."
                ),
                retrievalMode: "filtered",
                bootstrapBehavior: .generic,
                cognitionBehavior: .generic,
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: "night_message_cooling",
                        modeID: BASDecisionMode.primaryID,
                        riskLevelID: "high",
                        isPinned: true,
                        successCount: 3,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                        id: "night_fast_path_failure",
                        modeID: BASDecisionMode.primaryID,
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(artifact.execution.preparation.trigger == BASCurrentBrainBootstrapTrigger.notification)
        #expect(artifact.execution.preparation.sourceSurface == BASInteractionSurface.notification)
        #expect(artifact.execution.preparation.riskLevel == BASRiskLevel.high)
        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.execution.orderedFailurePatternIDs == ["night_fast_path_failure"])
        #expect(artifact.persistenceInput.mode == BASDecisionMode.primary.identifier)
    }

    @Test("host bootstrap adapter rejects unmapped descriptor identifiers")
    func hostBootstrapAdapterRejectsUnmappedDescriptorIdentifiers() {
        let now = Date(timeIntervalSince1970: 1_744_322_260)

        #expect(throws: BASAppleCurrentBrainBootstrapHostResolutionError.self) {
            try BASAppleCurrentBrainBootstrapHostAdapter.request(
                from: BASAppleCurrentBrainBootstrapHostSourceInput(
                    modeID: BASDecisionMode.reflectiveID,
                    prompt: "Reject unmapped descriptor identifiers.",
                    triggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue,
                    preferredLanguages: ["en-AU"],
                    now: now,
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "compact",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic,
                    templates: [
                        BASAppleCurrentBrainBootstrapHostTemplateInput(
                            id: "fallback-template",
                            modeID: "foreign-template-mode",
                            riskLevelID: BASRiskLevel.high.rawValue,
                            isPinned: false,
                            successCount: 1,
                            updatedAt: now
                        )
                    ],
                    failurePatterns: [
                        BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                            id: "fallback-pattern",
                            modeID: "foreign-pattern-mode",
                            suppressionWeight: 0.6,
                            evidenceCount: 1,
                            updatedAt: now
                        )
                    ]
                )
            )
        }
    }

    @Test("host bootstrap adapter rejects unmapped requested identifiers")
    func hostBootstrapAdapterRejectsUnmappedRequestedIdentifiers() {
        let now = Date(timeIntervalSince1970: 1_744_322_260)

        #expect(throws: BASAppleCurrentBrainBootstrapHostResolutionError.self) {
            try BASAppleCurrentBrainBootstrapHostAdapter.request(
                from: BASAppleCurrentBrainBootstrapHostSourceInput(
                    modeID: "unmapped-host-mode",
                    prompt: "Reject unmapped host identifiers.",
                    triggerID: "unmapped-host-trigger",
                    riskLevelOverrideID: "unmapped-risk",
                    preferredLanguages: ["en-AU"],
                    now: now,
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "compact",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic,
                    templates: [],
                    failurePatterns: []
                )
            )
        }
    }

    @Test("host bootstrap adapter rejects invalid source surface overrides")
    func hostBootstrapAdapterRejectsInvalidSourceSurfaceOverrides() {
        let now = Date(timeIntervalSince1970: 1_744_322_261)

        #expect(throws: BASAppleCurrentBrainBootstrapHostResolutionError.self) {
            try BASAppleCurrentBrainBootstrapHostAdapter.request(
                from: BASAppleCurrentBrainBootstrapHostSourceInput(
                    modeID: BASDecisionMode.primaryID,
                    prompt: "Reject invalid source surfaces.",
                    triggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
                    sourceSurfaceOverrideID: "foreign-surface",
                    preferredLanguages: ["en-AU"],
                    now: now,
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "compact",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic,
                    templates: [],
                    failurePatterns: []
                )
            )
        }
    }

    @Test("current brain bootstrap trigger rejects legacy sessionPrime vocabulary")
    func currentBrainBootstrapTriggerRejectsLegacySessionPrimeVocabulary() {
        #expect(BASCurrentBrainBootstrapTrigger(identifier: "sessionPrime") == nil)
    }

    @Test("generic bootstrap behavior defaults to strict requested identifier rejection")
    func genericBootstrapBehaviorDefaultsToStrictRequestedIdentifierRejection() {
        let behavior = BASCurrentBrainBootstrapBehavior.generic

        #expect(behavior.unknownRequestedModeFallbackPolicy == .reject)
        #expect(behavior.unknownRequestedTriggerFallbackPolicy == .reject)
        #expect(behavior.defaultTriggerID == BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue)
        #expect(behavior.defaultMemorySourceID == BASMemorySource.pattern.rawValue)
    }

    @Test("host bootstrap adapter supports foreign host ontology without before vocabulary")
    func hostBootstrapAdapterSupportsForeignHostOntology() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_262)
        let behavior = BASCurrentBrainBootstrapBehavior(
            defaultModeID: BASDecisionMode.primaryID,
            defaultTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue,
            defaultRiskLevelID: BASRiskLevel.low.rawValue,
            defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
            modeIDAliasesByID: [
                "vector-pass": BASDecisionMode.primaryID,
                "counterweight-pass": BASDecisionMode.comparativeID,
                "echo-pass": BASDecisionMode.reflectiveID
            ],
            triggerIDAliasesByID: [
                "wake-cycle": BASCurrentBrainBootstrapTrigger.sceneActive.rawValue,
                "ping": BASCurrentBrainBootstrapTrigger.notification.rawValue
            ],
            riskLevelIDAliasesByID: [
                "guarded": BASRiskLevel.medium.rawValue,
                "critical": BASRiskLevel.high.rawValue
            ],
            memorySourceIDAliasesByID: [
                "trace-cache": BASMemorySource.pattern.rawValue,
                "field-note": BASMemorySource.reflection.rawValue
            ],
            memorySourceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.sceneActive.rawValue: "trace-cache"
            ],
            memorySourceOverridesByModeID: [
                BASDecisionMode.reflectiveID: "field-note"
            ]
        )

        let request = try BASAppleCurrentBrainBootstrapHostAdapter.request(
            from: BASAppleCurrentBrainBootstrapHostSourceInput(
                modeID: "echo-pass",
                prompt: "Map the signal before the system reacts.",
                triggerID: "wake-cycle",
                riskLevelOverrideID: "guarded",
                preferredLanguages: ["en-AU"],
                now: now,
                projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                retrievalMode: "signal-grid",
                bootstrapBehavior: behavior,
                cognitionBehavior: .generic,
                recommendedTemplateIDs: ["foreign.template.echo"],
                templates: [
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: "foreign.template.echo",
                        modeID: "echo-pass",
                        riskLevelID: "critical",
                        isPinned: true,
                        successCount: 3,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                        id: "foreign.pattern.echo-loop",
                        modeID: "echo-pass",
                        suppressionWeight: 0.72,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(request.preparation.mode == BASDecisionMode.reflective)
        #expect(request.preparation.trigger == BASCurrentBrainBootstrapTrigger.sceneActive)
        #expect(request.preparation.riskLevel == BASRiskLevel.medium)
        #expect(behavior.memorySource(for: .sceneActive, mode: .reflective) == .reflection)
        #expect(request.templates.map { $0.id } == ["foreign.template.echo"])
        #expect(request.failurePatterns.map { $0.id } == ["foreign.pattern.echo-loop"])
    }

    @Test("host bootstrap adapter rejects invalid template risk levels")
    func hostBootstrapAdapterRejectsInvalidTemplateRiskLevels() {
        let now = Date(timeIntervalSince1970: 1_744_322_261.5)

        #expect(throws: BASAppleCurrentBrainBootstrapHostResolutionError.self) {
            try BASAppleCurrentBrainBootstrapHostAdapter.request(
                from: BASAppleCurrentBrainBootstrapHostSourceInput(
                    modeID: BASDecisionMode.primaryID,
                    prompt: "Reject invalid template risk levels.",
                    triggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue,
                    preferredLanguages: ["en-AU"],
                    now: now,
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: "compact",
                    bootstrapBehavior: .generic,
                    cognitionBehavior: .generic,
                    templates: [
                        BASAppleCurrentBrainBootstrapHostTemplateInput(
                            id: "configured-template",
                            modeID: BASDecisionMode.primaryID,
                            riskLevelID: "foreign-risk",
                            isPinned: false,
                            successCount: 1,
                            updatedAt: now
                        )
                    ],
                    failurePatterns: []
                )
            )
        }
    }

    @Test("bridge input builder compiles task graph hint into raw bridge payload")
    func bridgeInputBuilderCompilesTaskGraphHint() {
        let now = Date(timeIntervalSince1970: 1_744_322_205)
        let input = BASAppleCurrentBrainBootstrapBridgeInputBuilder.build(
            modeID: BASDecisionMode.primary.rawValue,
            prompt: "Should I wait until morning?",
            triggerID: BASCurrentBrainBootstrapTrigger.notification.rawValue,
            sourceSurfaceOverrideID: BASInteractionSurface.notification.rawValue,
            riskLevelOverrideID: BASRiskLevel.high.rawValue,
            preferredLanguages: ["en-AU"],
            now: now,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            embeddingScores: [BASAppleEmbeddingScoreInput(id: "goal-1", score: 0.8)],
            taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput(
                headline: "Pause before you send.",
                activeNodeCount: 1,
                hasResumeCandidate: true,
                resumeHint: "Sleep on it."
            ),
            retrievalMode: "filtered",
            bootstrapBehavior: .generic,
            cognitionBehavior: .generic
        )

        #expect(input.taskGraphHeadline == "Pause before you send.")
        #expect(input.taskGraphActiveNodeCount == 1)
        #expect(input.taskGraphHasResumeCandidate == true)
        #expect(input.taskGraphResumeHint == "Sleep on it.")
        #expect(input.embeddingScores.map { $0.id } == ["goal-1"])
    }

    @Test("bootstrap coordinator sequences recommendation and selection before compiling artifact")
    func bootstrapCoordinatorSequencesRecommendationAndSelection() throws {
        let now = Date(timeIntervalSince1970: 1_744_322_300)
        let baseInput = BASAppleCurrentBrainBootstrapHostSourceInput(
            modeID: BASDecisionMode.primaryID,
            prompt: "Should I send this tonight?",
            triggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
            riskLevelOverrideID: "medium",
            preferredLanguages: ["en-AU"],
            now: now,
            projection: BASBrainProjection(
                records: [
                    BASGovernedMemory(
                        kind: .goal,
                        content: "Protect sleep before late-night replies.",
                        scope: .user,
                        sensitivity: .low,
                        tier: .hot,
                        confidence: 0.93,
                        sourceType: "archive",
                        governanceStatus: .governed,
                        provenanceSummary: "goal"
                    )
                ],
                candidates: [],
                recentEvents: []
            ),
            retrievalMode: "filtered",
            bootstrapBehavior: .generic,
            cognitionBehavior: .generic,
            templates: [],
            failurePatterns: []
        )

        var sawPreparation = false
        let artifact = try BASAppleCurrentBrainBootstrapCoordinator.artifact(
            baseInput: baseInput,
            recommendTemplateIDs: { preparation in
                sawPreparation = true
                #expect(preparation.mode == .primary)
                return ["night_message_cooling"]
            },
            selectTemplates: { _, recommendedTemplateIDs in
                #expect(recommendedTemplateIDs == ["night_message_cooling"])
                return recommendedTemplateIDs.map {
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: $0,
                        modeID: BASDecisionMode.primaryID,
                        riskLevelID: "medium",
                        isPinned: true,
                        successCount: 4,
                        updatedAt: now
                    )
                }
            },
            selectFailurePatterns: { _ in
                [
                    BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                        id: "night_fast_path_failure",
                        modeID: BASDecisionMode.primaryID,
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            },
            mapTemplate: { $0 },
            mapFailurePattern: { $0 }
        )

        #expect(sawPreparation)
        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.execution.orderedFailurePatternIDs == ["night_fast_path_failure"])
    }
}
