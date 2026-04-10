import XCTest
@testable import Before

final class DecisionIntelligenceExecutionProfileTests: XCTestCase {
    func testSixGigDeviceFallsBackToConservativeDeterministicProfile() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 6 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        XCTAssertEqual(profile.tier, .conservativeDeterministic)
        XCTAssertEqual(profile.effectiveProviderPreference, .template)
        XCTAssertFalse(profile.allowsQuickRefinement)
        XCTAssertFalse(profile.allowsBalanceRefinement)
        XCTAssertFalse(profile.allowsMirrorRefinement)
        XCTAssertFalse(profile.allowsReminderSelection)
        XCTAssertEqual(profile.adaptationMatrix.runtimeGear, .low)
        XCTAssertEqual(profile.adaptationMatrix.deviceClass, .memoryConstrainedPhone)
        XCTAssertEqual(profile.adaptationMatrix.languageMode, .english)
        XCTAssertEqual(profile.strategy(for: .quick).runtimeGear, .low)
        XCTAssertEqual(profile.strategy(for: .mirror).runtimeGear, .low)
        XCTAssertEqual(profile.strategy(for: .quick).preferredProvider, .template)
        XCTAssertEqual(profile.strategy(for: .mirror).outputMode, .deterministicTemplate)
        XCTAssertEqual(profile.strategy(for: .mirror).responseLanguage, .english)
        XCTAssertTrue(profile.detail.contains("iPhone 14"))
    }

    func testSevenGigDeviceKeepsGemmaForHeavierWorkButSkipsQuickRefinement() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 7 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU", "zh-Hans"]
        )

        XCTAssertEqual(profile.tier, .balancedGemma)
        XCTAssertEqual(profile.effectiveProviderPreference, .gemmaE4B)
        XCTAssertFalse(profile.allowsQuickRefinement)
        XCTAssertTrue(profile.allowsBalanceRefinement)
        XCTAssertTrue(profile.allowsMirrorRefinement)
        XCTAssertTrue(profile.allowsReminderSelection)
        XCTAssertEqual(profile.adaptationMatrix.runtimeGear, .balanced)
        XCTAssertEqual(profile.adaptationMatrix.languageMode, .mixed)
        XCTAssertEqual(profile.strategy(for: .quick).runtimeGear, .low)
        XCTAssertEqual(profile.strategy(for: .balance).runtimeGear, .balanced)
        XCTAssertEqual(profile.strategy(for: .mirror).runtimeGear, .balanced)
        XCTAssertEqual(profile.strategy(for: .quick).preferredProvider, .template)
        XCTAssertEqual(profile.strategy(for: .balance).preferredProvider, .gemmaE4B)
        XCTAssertEqual(profile.strategy(for: .mirror).retrievalMode, .filtered)
        XCTAssertEqual(profile.strategy(for: .mirror).responseLanguage, .mixed)
        XCTAssertEqual(profile.strategy(for: .mirror).tone, .groundedDirect)
    }

    func testFoundationAvailabilityWinsOnDevice() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 6 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: DecisionModelProviderStatus(
                kind: .foundationModels,
                isAvailable: true,
                title: "Available",
                detail: "Apple is ready."
            ),
            gemmaStatus: availableGemma,
            preferredLanguages: ["zh-Hans"]
        )

        XCTAssertEqual(profile.tier, .systemManaged)
        XCTAssertEqual(profile.effectiveProviderPreference, .foundationModels)
        XCTAssertTrue(profile.allowsQuickRefinement)
        XCTAssertTrue(profile.allowsBalanceRefinement)
        XCTAssertTrue(profile.allowsMirrorRefinement)
        XCTAssertTrue(profile.allowsReminderSelection)
        XCTAssertEqual(profile.adaptationMatrix.runtimeGear, .balanced)
        XCTAssertEqual(profile.adaptationMatrix.languageMode, .chinese)
        XCTAssertEqual(profile.strategy(for: .quick).runtimeGear, .low)
        XCTAssertEqual(profile.strategy(for: .balance).runtimeGear, .balanced)
        XCTAssertEqual(profile.strategy(for: .quick).preferredProvider, .foundationModels)
        XCTAssertEqual(profile.strategy(for: .reminder).outputMode, .jsonShort)
        XCTAssertEqual(profile.strategy(for: .balance).thinkingMode, .off)
        XCTAssertEqual(profile.strategy(for: .quick).responseLanguage, .chinese)
    }

    func testAdaptiveStrategyShortensMirrorWorkWhenBrainStateRequestsLowLoad() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 8 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        let baseStrategy = profile.strategy(for: .mirror)
        let brainState = DecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect sleep."],
            relevantMemories: ["Heavy analysis backfires at night."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["mirror", "sleep"],
            reactionWeights: DecisionReactionWeights(
                briefLanguage: 0.92,
                warmDirectTone: 0.72,
                lowCognitiveLoad: 0.88,
                interruptiveActionBias: 0.44,
                boundaryNamingBias: 0.74,
                tradeoffClarityBias: 0.42
            ),
            loadedAt: .now
        )
        let neuralState = DecisionNeuralState(
            mode: .mirror,
            dominantActivations: [
                DecisionActivation(signal: .emotionLoad, strength: 0.82)
            ],
            candidateActions: [],
            suppressedBehaviors: [],
            detail: "Low-load preference."
        )

        let adapted = baseStrategy.adapting(
            neuralState: neuralState,
            brainState: brainState
        )

        XCTAssertLessThan(adapted.contextBudget, baseStrategy.contextBudget)
        XCTAssertLessThan(adapted.outputCharacterBudget, baseStrategy.outputCharacterBudget)
        XCTAssertLessThan(adapted.timeBudgetMs, baseStrategy.timeBudgetMs)
        XCTAssertEqual(adapted.runtimeGear, .low)
        XCTAssertEqual(adapted.tone, .briefWarm)
        XCTAssertEqual(adapted.thinkingMode, .off)
        XCTAssertTrue(adapted.actionSpace.contains("stay_brief"))
    }

    func testAdaptiveStrategyCanUpshiftMirrorWorkWhenBoundarySignalIsStrong() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 8 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        let baseStrategy = profile.strategy(for: .mirror)
        XCTAssertEqual(baseStrategy.runtimeGear, .high)

        let adapted = baseStrategy.adapting(
            neuralState: DecisionNeuralState(
                mode: .mirror,
                dominantActivations: [
                    DecisionActivation(signal: .boundaryRisk, strength: 0.91)
                ],
                candidateActions: [],
                suppressedBehaviors: [],
                detail: "Strong boundary signal."
            ),
            brainState: DecisionBrainState(
                profileCore: [],
                activeGoals: ["Name the boundary clearly."],
                relevantMemories: [],
                sessionBiases: [],
                retrievalTags: [],
                reactionWeights: DecisionReactionWeights(
                    briefLanguage: 0.3,
                    warmDirectTone: 0.76,
                    lowCognitiveLoad: 0.34,
                    interruptiveActionBias: 0.2,
                    boundaryNamingBias: 0.92,
                    tradeoffClarityBias: 0.42
                ),
                loadedAt: .now
            )
        )

        XCTAssertEqual(adapted.runtimeGear, .high)
        XCTAssertEqual(adapted.thinkingMode, .gated)
        XCTAssertTrue(adapted.actionSpace.contains("name_boundary"))
        XCTAssertGreaterThanOrEqual(adapted.contextBudget, baseStrategy.contextBudget)
        XCTAssertGreaterThanOrEqual(adapted.outputCharacterBudget, baseStrategy.outputCharacterBudget)
        XCTAssertGreaterThanOrEqual(adapted.timeBudgetMs, baseStrategy.timeBudgetMs)
    }

    func testAdaptiveStrategyGuardsRetrievalWhenLifecycleIsStale() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 8 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        let baseStrategy = profile.strategy(for: .mirror)
        XCTAssertEqual(baseStrategy.retrievalMode, .adaptive)

        let adapted = baseStrategy.adapting(
            contextState: DecisionContextPreparedState(
                rebuiltSession: true,
                generation: 4,
                anchorFields: [.mirrorPrompt],
                activeFields: [.mirrorPrompt],
                staleFields: [.mirrorEmotion]
            ),
            brainState: DecisionBrainState(
                profileCore: [],
                activeGoals: [],
                relevantMemories: [],
                sessionBiases: [],
                retrievalTags: [],
                reactionWeights: .defaults(for: .mirror),
                memoryGovernance: DecisionMemoryGovernanceState(
                    totalRecordCount: 5,
                    totalCandidateCount: 2,
                    pendingCandidateCount: 1,
                    promotedCandidateCount: 4,
                    loadedPromotedMemoryCount: 2,
                    loadedPendingMemoryCount: 1,
                    deferredCandidateCount: 0,
                    admittedCandidateCount: 1,
                    screenedOutMemoryCount: 4,
                    screenedOutPendingMemoryCount: 1
                ),
                loadedAt: .now
            )
        )

        XCTAssertEqual(adapted.retrievalMode, .filtered)
        XCTAssertLessThanOrEqual(adapted.retrievalItemBudget, 3)
    }

    func testAdaptiveStrategyGuardsRetrievalWhenBrainSnapshotShowsLowTrustLoad() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 8 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        let adapted = profile.strategy(for: .mirror).adapting(
            brainState: DecisionBrainState(
                memorySlices: [
                    DecisionGovernedMemorySlice(
                        id: "relevant.low-trust",
                        role: .relevant,
                        type: "semantic",
                        headline: "Low trust memory",
                        source: "history",
                        confidence: 0.62,
                        priority: 0.6,
                        lifecycleState: "active",
                        governanceStatus: .deferred,
                        eligibility: .allowed(.defaultAllowed),
                        sourceTrustScore: 0.41,
                        sourceTrustTier: .low,
                        retrievalTags: ["mirror", "relationship"],
                        isPending: true,
                        provenanceSummary: "Weak inferred memory."
                    )
                ],
                sessionBiases: [],
                retrievalTags: ["mirror"],
                reactionWeights: .defaults(for: .mirror),
                identityProfile: .default(for: .mirror),
                boundaryPolicy: .default(riskLevel: InterventionRiskLevel.medium),
                memoryGovernance: DecisionMemoryGovernanceState(
                    totalRecordCount: 2,
                    totalCandidateCount: 2,
                    pendingCandidateCount: 1,
                    promotedCandidateCount: 1,
                    loadedPromotedMemoryCount: 0,
                    loadedPendingMemoryCount: 1,
                    deferredCandidateCount: 1,
                    admittedCandidateCount: 0,
                    screenedOutMemoryCount: 4,
                    screenedOutPendingMemoryCount: 1
                ),
                loadedAt: .now
            )
        )

        XCTAssertEqual(adapted.retrievalMode, .filtered)
        XCTAssertLessThanOrEqual(adapted.retrievalItemBudget, 3)
    }

    func testAdaptiveStrategyCanShiftResponseLanguageFromBrainStateTags() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 8 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma,
            preferredLanguages: ["en-AU"]
        )

        let baseStrategy = profile.strategy(for: .quick)
        XCTAssertEqual(baseStrategy.responseLanguage, .english)

        let adapted = baseStrategy.adapting(
            brainState: DecisionBrainState(
                profileCore: [],
                activeGoals: [],
                relevantMemories: [],
                sessionBiases: [],
                retrievalTags: ["quick", "lang:chinese", "script:han", "我今晚又想买"],
                reactionWeights: .defaults(for: .quick),
                loadedAt: .now
            )
        )

        XCTAssertEqual(adapted.responseLanguage, .chinese)
    }

    private var assistivePreferences: BeforePreferences {
        BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .gemmaE4B,
            allowModelFallbacks: true
        )
    }

    private var availableGemma: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .gemmaE4B,
            isAvailable: true,
            title: "Ready",
            detail: "Gemma is ready."
        )
    }

    private var unavailableFoundation: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .foundationModels,
            isAvailable: false,
            title: "Unavailable",
            detail: "Apple is not ready."
        )
    }
}
