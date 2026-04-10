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
}
