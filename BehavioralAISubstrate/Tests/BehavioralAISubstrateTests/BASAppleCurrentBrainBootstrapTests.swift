import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASPolicy

@Suite("BASApple Current Brain Bootstrap")
struct BASAppleCurrentBrainBootstrapTests {
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
}
