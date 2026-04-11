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
                modeID: BASDecisionMode.quick.rawValue,
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
                recommendedTemplateIDs: ["night_message_cooling"]
            ),
            templates: [
                BASAppleCurrentBrainBootstrapHostTemplateInput(
                    id: "night_message_cooling",
                    modeID: BASDecisionMode.quick.rawValue,
                    riskLevelID: BASRiskLevel.high.rawValue,
                    isPinned: true,
                    successCount: 3,
                    updatedAt: now
                )
            ],
            failurePatterns: [
                BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                    id: "night_fast_path_failure",
                    modeID: BASDecisionMode.quick.rawValue,
                    suppressionWeight: 0.9,
                    evidenceCount: 2,
                    updatedAt: now
                )
            ],
            mapTemplate: { $0 },
            mapFailurePattern: { $0 }
        )

        #expect(input.modeID == BASDecisionMode.quick.rawValue)
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
            modeID: BASDecisionMode.quick.rawValue,
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
            recommendedTemplateIDs: ["night_message_cooling"]
        )

        #expect(context.prompt == "Should I sleep on this?")
        #expect(context.embeddingScores.map(\.id) == ["memory-1"])
        #expect(context.taskGraphHint?.headline == "Pause before replying.")
        #expect(context.taskGraphHint?.activeNodeCount == 2)
        #expect(context.recommendedTemplateIDs == ["night_message_cooling"])
    }

    @Test("brain bootstrap request adapter compiles minimal local request without host bridge")
    func brainBootstrapRequestAdapterBuildsRequest() {
        let now = Date(timeIntervalSince1970: 1_744_322_120)
        let request = BASAppleBrainBootstrapRequestAdapter.request(
            modeID: BASDecisionMode.quick.rawValue,
            prompt: "Should I send this tonight?",
            triggerID: BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue,
            sourceSurfaceOverrideID: BASInteractionSurface.app.rawValue,
            riskLevelOverrideID: BASRiskLevel.low.rawValue,
            preferredLanguages: ["en-AU"],
            now: now,
            retrievalMode: "filtered"
        )

        #expect(request.mode == BASDecisionMode.quick)
        #expect(request.source == BASMemorySource.pattern)
        #expect(request.sourceSurface == BASInteractionSurface.app)
        #expect(request.riskLevel == BASRiskLevel.low)
        #expect(request.retrievalMode == "filtered")
        #expect(request.now == now)
    }

    @Test("brain state compiler keeps request defaults package-owned")
    func currentBrainStateCompilerBuildsBrainStateFromProjection() {
        let brainState = BASAppleCurrentBrainStateCompiler.brainState(
            modeID: BASDecisionMode.quick.rawValue,
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
                        sourceType: "history",
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
            BASAppleCurrentBrainRuntimeCoordinator.bootstrapAndCommit(
                context: BASAppleCurrentBrainBootstrapHostBuildContext(
                    modeID: BASDecisionMode.quick.rawValue,
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
                                sourceType: "history",
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
                            modeID: BASDecisionMode.quick.rawValue,
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
                            modeID: BASDecisionMode.quick.rawValue,
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
            BASAppleCurrentBrainBootstrapBridgeBuilder.bootstrapAndCommit(
                input: BASAppleCurrentBrainBootstrapBridgeInput(
                    modeID: BASDecisionMode.quick.rawValue,
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
                                sourceType: "history",
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
                    retrievalMode: "filtered"
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
                            modeID: BASDecisionMode.quick.rawValue,
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
                            modeID: BASDecisionMode.quick.rawValue,
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

    @Test("prepare resolves default surface, language mode, memory source, and risk overrides")
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
                mode: .quick,
                prompt: "我想现在就发这条消息",
                trigger: .watchHandoff,
                riskLevelOverride: .high,
                preferredLanguages: ["zh-Hans-AU", "en-AU"],
                now: now
            )
        )

        #expect(preparation.sourceSurface == .watch)
        #expect(preparation.languageMode == .chinese)
        #expect(preparation.memorySource == .reminder)
        #expect(preparation.riskLevel == .high)
    }

    @Test("bootstrap orders interventions and enriches the projection before cognition bootstrap")
    func bootstrapOrdersInterventionsAndBuildsBrainState() {
        let now = Date(timeIntervalSince1970: 1_744_321_800)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .quick,
            prompt: "Should I send this tonight?",
            trigger: .notification,
            sourceSurface: .app,
            riskLevel: .medium,
            languageMode: .english,
            memorySource: .reminder,
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
                    sourceType: "history",
                    governanceStatus: .governed,
                    provenanceSummary: "goal"
                ),
                BASGovernedMemory(
                    kind: .support,
                    content: "Tomorrow Box usually breaks the late-night loop.",
                    scope: .user,
                    sensitivity: .medium,
                    tier: .warm,
                    confidence: 0.84,
                    sourceType: "history",
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
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASInterventionTemplateDescriptor(
                        id: "fallback_template",
                        mode: .quick,
                        riskLevel: .medium,
                        isPinned: false,
                        successCount: 5,
                        updatedAt: now
                    ),
                    BASInterventionTemplateDescriptor(
                        id: "night_message_cooling",
                        mode: .quick,
                        riskLevel: .medium,
                        isPinned: true,
                        successCount: 1,
                        updatedAt: now.addingTimeInterval(-60)
                    )
                ],
                failurePatterns: [
                    BASFailurePatternDescriptor(
                        id: "night_fast_path_failure",
                        mode: .quick,
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
        #expect(execution.bootstrapped.brainState.memorySlices.contains(where: { $0.role == .goal }))
    }

    @Test("apple bootstrap adapter owns projection enrichment and intervention descriptor shaping")
    func appleBootstrapAdapterOwnsProjectionEnrichmentAndDescriptors() {
        let now = Date(timeIntervalSince1970: 1_744_321_900)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .mirror,
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
                    sourceType: "history",
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
                        mode: .mirror,
                        riskLevel: .high,
                        isPinned: false,
                        successCount: 4,
                        updatedAt: now
                    ),
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: "night_message_cooling",
                        mode: .mirror,
                        riskLevel: .high,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now.addingTimeInterval(-30)
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapFailurePatternInput(
                        id: "night_fast_path_failure",
                        mode: .mirror,
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

    @Test("apple bootstrap artifact also owns persistence input shaping")
    func appleBootstrapArtifactOwnsPersistenceInputShaping() {
        let now = Date(timeIntervalSince1970: 1_744_322_000)
        let preparation = BASCurrentBrainBootstrapPreparation(
            mode: .quick,
            prompt: "Should I wait until tomorrow?",
            trigger: .notification,
            sourceSurface: .notification,
            riskLevel: .medium,
            languageMode: .english,
            memorySource: .reminder,
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
                            sourceType: "history",
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
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASAppleCurrentBrainBootstrapTemplateInput(
                        id: "night_message_cooling",
                        mode: .quick,
                        riskLevel: .medium,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapFailurePatternInput(
                        id: "night_fast_path_failure",
                        mode: .quick,
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.persistenceInput.mode == BASDecisionMode.quick.rawValue)
        #expect(artifact.persistenceInput.fingerprint == artifact.execution.bootstrapped.brainState.verificationSnapshot.fingerprint)
        #expect(Set(artifact.persistenceInput.activeTemplateIDs) == Set(artifact.execution.orderedTemplateIDs))
        #expect(Set(artifact.persistenceInput.failureGuardIDs) == Set(artifact.execution.orderedFailurePatternIDs))
    }

    @Test("source input artifact owns preparation plus execution assembly")
    func sourceInputArtifactOwnsPreparationAndExecutionAssembly() {
        let now = Date(timeIntervalSince1970: 1_744_322_100)
        let artifact = BASAppleCurrentBrainBootstrapAdapter.artifact(
            source: BASAppleCurrentBrainBootstrapSourceInput(
                preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                    mode: .quick,
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
                            sourceType: "history",
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
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASInterventionTemplateDescriptor(
                        id: "night_message_cooling",
                        mode: .quick,
                        riskLevel: .high,
                        isPinned: true,
                        successCount: 2,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASFailurePatternDescriptor(
                        id: "night_fast_path_failure",
                        mode: .quick,
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
        #expect(artifact.persistenceInput.mode == BASDecisionMode.quick.rawValue)
    }

    @Test("host bootstrap adapter compiles raw bridge inputs into artifact semantics")
    func hostBootstrapAdapterCompilesRawBridgeInputsIntoArtifactSemantics() {
        let now = Date(timeIntervalSince1970: 1_744_322_200)

        let artifact = BASAppleCurrentBrainBootstrapHostAdapter.artifact(
            from: BASAppleCurrentBrainBootstrapHostSourceInput(
                modeID: "quick",
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
                            sourceType: "history",
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
                recommendedTemplateIDs: ["night_message_cooling"],
                templates: [
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: "night_message_cooling",
                        modeID: "quick",
                        riskLevelID: "high",
                        isPinned: true,
                        successCount: 3,
                        updatedAt: now
                    )
                ],
                failurePatterns: [
                    BASAppleCurrentBrainBootstrapHostFailurePatternInput(
                        id: "night_fast_path_failure",
                        modeID: "quick",
                        suppressionWeight: 0.95,
                        evidenceCount: 2,
                        updatedAt: now
                    )
                ]
            )
        )

        #expect(artifact.execution.preparation.trigger == .notification)
        #expect(artifact.execution.preparation.sourceSurface == .notification)
        #expect(artifact.execution.preparation.riskLevel == .high)
        #expect(artifact.execution.orderedTemplateIDs == ["night_message_cooling"])
        #expect(artifact.execution.orderedFailurePatternIDs == ["night_fast_path_failure"])
        #expect(artifact.persistenceInput.mode == BASDecisionMode.quick.rawValue)
    }

    @Test("bootstrap coordinator sequences recommendation and selection before compiling artifact")
    func bootstrapCoordinatorSequencesRecommendationAndSelection() {
        let now = Date(timeIntervalSince1970: 1_744_322_300)
        let baseInput = BASAppleCurrentBrainBootstrapHostSourceInput(
            modeID: "quick",
            prompt: "Should I send this tonight?",
            triggerID: "sessionPrime",
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
                        sourceType: "history",
                        governanceStatus: .governed,
                        provenanceSummary: "goal"
                    )
                ],
                candidates: [],
                recentEvents: []
            ),
            retrievalMode: "filtered",
            templates: [],
            failurePatterns: []
        )

        var sawPreparation = false
        let artifact = BASAppleCurrentBrainBootstrapCoordinator.artifact(
            baseInput: baseInput,
            recommendTemplateIDs: { preparation in
                sawPreparation = true
                #expect(preparation.mode == .quick)
                return ["night_message_cooling"]
            },
            selectTemplates: { _, recommendedTemplateIDs in
                #expect(recommendedTemplateIDs == ["night_message_cooling"])
                return recommendedTemplateIDs.map {
                    BASAppleCurrentBrainBootstrapHostTemplateInput(
                        id: $0,
                        modeID: "quick",
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
                        modeID: "quick",
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
