import XCTest
import BASHostKit
@testable import Before

private actor CapturedRuntimePolicyResolutionBox {
    private var resolution: BeforeRuntimePolicyResolution?

    func store(_ resolution: BeforeRuntimePolicyResolution) {
        self.resolution = resolution
    }

    func load() -> BeforeRuntimePolicyResolution? {
        resolution
    }
}

@MainActor
final class OnDeviceIntelligenceSessionTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        BeforeRuntimePolicyStore.clearOverride()
        DecisionIntelligenceDebugStore.shared.clear()
        await DecisionIntelligenceResponseCache.shared.clear()
        await DecisionIntelligenceCoordinator.resetTestingRefinementHandlers()
    }

    override func tearDown() async throws {
        BeforeRuntimePolicyStore.clearOverride()
        DecisionIntelligenceDebugStore.shared.clear()
        await DecisionIntelligenceResponseCache.shared.clear()
        await DecisionIntelligenceCoordinator.resetTestingRefinementHandlers()
        try await super.tearDown()
    }

    func testQuickSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = QuickCheckSession(entrySource: .app)
        session.scenario = .buy
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "long day"

        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "long day"
        )

        let expected = DecisionIntelligenceCoordinator.quickResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result?.verdict, expected.verdict)
        XCTAssertEqual(session.result?.primaryAction, expected.primaryAction)
        XCTAssertEqual(session.result?.secondaryActions, expected.secondaryActions)
        XCTAssertEqual(session.result?.currentPerspective, expected.currentPerspective)
        XCTAssertEqual(session.result?.afterPerspective, expected.afterPerspective)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    func testQuickSessionUsesProtectiveEBrianTurnToShortCircuitRefinement() async {
        let session = QuickCheckSession(entrySource: .app)
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "The prompt is pushing me to answer now."

        let turn = protectiveTurn(
            mode: .delay,
            headline: "Pause before deciding",
            body: "Use the safer pause path first.",
            alternativeActions: ["Wait 90 seconds", "Decide tomorrow"]
        )

        let preferences = assistedPreferences
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "The prompt is pushing me to answer now."
        )
        let deterministic = DecisionIntelligenceCoordinator.quickResult(for: input, preferences: preferences)

        await session.evaluateWithIntelligence(preferences: preferences, eBrainTurn: turn)

        XCTAssertFalse(session.isRefiningWithModel)
        XCTAssertEqual(session.result?.currentPerspective, turn.renderedOutput.headline)
        XCTAssertEqual(session.result?.afterPerspective, turn.renderedOutput.body)
        XCTAssertEqual(session.result?.primaryAction, .wait90s)
        XCTAssertEqual(session.result?.secondaryActions, [.decideTomorrow, .continueMindfully])
        XCTAssertEqual(session.result?.verdict, .pause)
        XCTAssertNotEqual(session.result?.currentPerspective, deterministic.currentPerspective)
    }

    func testQuickSessionProtectivePermitWinsBeforeAnyDeterministicResultWhenIntelligenceIsOff() async {
        let session = QuickCheckSession(entrySource: .app)
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "Answer right now."

        let turn = protectiveTurn(
            mode: .replace,
            headline: "Use the safer step",
            body: "Do not publish the baseline answer before the protective gate resolves.",
            alternativeActions: ["Use the safer step", "Decide tomorrow"]
        )

        await session.evaluateWithIntelligence(preferences: offPreferences, eBrainTurn: turn)

        XCTAssertFalse(session.isRefiningWithModel)
        XCTAssertEqual(session.result?.currentPerspective, turn.renderedOutput.headline)
        XCTAssertEqual(session.result?.afterPerspective, turn.renderedOutput.body)
        XCTAssertEqual(session.result?.primaryAction, .decideTomorrow)
    }

    func testBalanceSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = BalanceBoardSession(entrySource: .app, prompt: "Should I take this freelance job?")
        session.desire = "I want the extra money."
        session.concern = "I do not want to burn out."
        session.constraint = "My week is already full."

        let input = BalanceBoardInput(
            prompt: "Should I take this freelance job?",
            desire: "I want the extra money.",
            concern: "I do not want to burn out.",
            constraint: "My week is already full.",
            longTerm: ""
        )

        let expected = DecisionIntelligenceCoordinator.balanceResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result, expected)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    func testBalanceSessionUsesProtectiveEBrianTurnToShortCircuitRefinement() async {
        let session = BalanceBoardSession(entrySource: .app, prompt: "Should I take this freelance job?")
        session.desire = "I want the extra money."
        session.concern = "I do not want to burn out."
        session.constraint = "My week is already full."

        let turn = protectiveTurn(
            mode: .block,
            headline: "Hold the boundary",
            body: "Pause this path and keep the boundary intact.",
            alternativeActions: ["Leave the stimulus", "Decide tomorrow"]
        )

        let preferences = assistedPreferences

        await session.evaluateWithIntelligence(preferences: preferences, eBrainTurn: turn)

        XCTAssertFalse(session.isRefiningWithModel)
        XCTAssertEqual(session.result?.headline, turn.renderedOutput.headline)
        XCTAssertEqual(session.result?.summary, turn.renderedOutput.body)
        XCTAssertEqual(session.result?.nextAction, "Leave the stimulus")
    }

    func testMirrorSessionEvaluateWithIntelligenceOffKeepsDeterministicResult() async {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I stay in this relationship?")
        session.emotion = "I feel tired and sad."
        session.relationship = "We keep repeating the same argument."
        session.reality = "We live far apart and avoid hard conversations."

        let input = MirrorInput(
            prompt: "Should I stay in this relationship?",
            emotion: "I feel tired and sad.",
            relationship: "We keep repeating the same argument.",
            reality: "We live far apart and avoid hard conversations.",
            longTerm: "",
            selfLens: ""
        )

        let expected = DecisionIntelligenceCoordinator.mirrorResult(for: input, preferences: offPreferences)

        await session.evaluateWithIntelligence(preferences: offPreferences)

        XCTAssertEqual(session.result, expected)
        XCTAssertFalse(session.isRefiningWithModel)
    }

    func testMirrorSessionUsesProtectiveEBrianTurnToShortCircuitRefinement() async {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I stay in this relationship?")
        session.emotion = "I feel tired and sad."
        session.relationship = "We keep repeating the same argument."
        session.reality = "We live far apart and avoid hard conversations."
        session.longTerm = "I want steadier relationships."
        session.selfLens = "I feel pulled between hope and exhaustion."

        let turn = protectiveTurn(
            mode: .replace,
            headline: "Take the safer step",
            body: "Use the safer path instead of forcing the current one.",
            alternativeActions: ["Use the safer step", "Continue mindfully"]
        )

        let preferences = assistedPreferences

        await session.evaluateWithIntelligence(preferences: preferences, eBrainTurn: turn)

        XCTAssertFalse(session.isRefiningWithModel)
        XCTAssertEqual(session.result?.headline, turn.renderedOutput.headline)
        XCTAssertEqual(session.result?.coreTension, turn.renderedOutput.body)
        XCTAssertEqual(session.result?.nextActionTitle, "Use the safer step")
        XCTAssertEqual(session.result?.nextAction, "Use the safer step")
    }

    func testQuickSessionEvaluateWithIntelligenceHonorsProvidedRuntimePolicyResolutionInsteadOfLiveOverride() async throws {
        BeforeRuntimePolicyStore.clearOverride()
        DecisionIntelligenceDebugStore.shared.clear()
        await DecisionIntelligenceResponseCache.shared.clear()

        let baselineResolution = BeforeProductCompatibility.resolvedRuntimePolicy
        XCTAssertEqual(
            baselineResolution.lineage.providerRoutingPolicyID,
            "before.provider-routing.v1"
        )

        let overrideBundle = sessionRuntimePolicyBundle(
            bundleVersion: "override.v2",
            providerRoutingPolicyID: "override.provider-routing.v2"
        )
        XCTAssertTrue(BeforeRuntimePolicyStore.saveOverride(overrideBundle))
        XCTAssertEqual(
            BeforeProductCompatibility.resolvedRuntimePolicy.lineage.providerRoutingPolicyID,
            "override.provider-routing.v2"
        )

        let capturedResolution = CapturedRuntimePolicyResolutionBox()
        await DecisionIntelligenceCoordinator.setTestingQuickRefinementHandler {
            base,
            _,
            _,
            _,
            _,
            _,
            _,
            runtimePolicyResolution in
            await capturedResolution.store(runtimePolicyResolution)
            return base
        }

        let baselineSession = QuickCheckSession(entrySource: .app)
        configureQuickSession(baselineSession)
        await baselineSession.evaluateWithIntelligence(
            preferences: assistedPreferences,
            runtimePolicyResolution: baselineResolution
        )

        let recordedResolution = await capturedResolution.load()
        let unwrappedResolution = try XCTUnwrap(recordedResolution)
        XCTAssertEqual(
            unwrappedResolution.lineage.providerRoutingPolicyID,
            baselineResolution.lineage.providerRoutingPolicyID
        )
        XCTAssertEqual(
            unwrappedResolution.lineage.bundleVersion,
            baselineResolution.lineage.bundleVersion
        )
    }

    private var offPreferences: BeforePreferences {
        BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .off,
            preferredIntelligenceProvider: .gemmaE4B,
            allowModelFallbacks: true
        )
    }

    private var assistedPreferences: BeforePreferences {
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

    private func configureQuickSession(_ session: QuickCheckSession) {
        session.scenario = .buy
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.note = "I want relief from a hard day."
    }

    private func sessionRuntimePolicyBundle(
        bundleVersion: String,
        providerRoutingPolicyID: String
    ) -> BeforeRuntimePolicyBundle {
        let providerRoutingRegistry = BASProviderRoutingPolicyRegistry(
            schemaVersion: "before.provider-routing-registry.session-tests.v1",
            defaultPolicyID: "before.provider-routing.v1",
            policiesByID: [
                "before.provider-routing.v1": BASProviderRoutingPolicy(
                    schemaVersion: "before.provider-routing.v1",
                    deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                    testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                    preferenceOrderings: [
                        BASProviderPreferenceOrdering(
                            preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                            orderedProviderIDs: [
                                BASReferenceProviderRuntime.gemmaE4BProviderID,
                                BASReferenceProviderRuntime.foundationModelsProviderID
                            ]
                        )
                    ]
                ),
                "override.provider-routing.v2": BASProviderRoutingPolicy(
                    schemaVersion: "override.provider-routing.v2",
                    deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                    testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                    preferenceOrderings: [
                        BASProviderPreferenceOrdering(
                            preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                            orderedProviderIDs: [
                                BASReferenceProviderRuntime.gemmaE4BProviderID,
                                BASReferenceProviderRuntime.openModelProviderID
                            ]
                        )
                    ]
                )
            ]
        )

        return BeforeRuntimePolicyBundle(
            schemaVersion: "before.runtime-policy-bundle.v1",
            bundleVersion: bundleVersion,
            providerRoutingRegistry: providerRoutingRegistry,
            providerRoutingPolicyID: providerRoutingPolicyID,
            runtimeTuningRegistry: BeforeProductCompatibility.resolvedRuntimePolicy.bundle.runtimeTuningRegistry,
            runtimeTuningPolicyID: BeforeProductCompatibility.resolvedRuntimePolicy.lineage.runtimeTuningPolicyID,
            updatedAt: Date(timeIntervalSince1970: 1_713_715_200)
        )
    }

    private func protectiveTurn(
        mode: BASActionPermitMode,
        headline: String,
        body: String,
        alternativeActions: [String]
    ) -> BASEBrainTurnResult {
        let deviceState = BASDeviceState(
            batteryLevel: 0.66,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.31,
            gpuLoad: 0.12,
            npuAvailable: true,
            latencyBudgetMs: 1_400
        )
        let budgetFrame = BASBudgetFrame.guardedLocal(maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 160, retrievalDepth: 2)
        let hostContext = BASHostProfile(hostID: "host.primary", longTermGoals: ["Stay calm"], noGoZones: ["unsafe"])
        let contextFrame = BASContextFrame(
            utterance: body,
            taskType: .highPressure,
            emotionalLoad: 0.82,
            timePressure: 0.74,
            relationPattern: "self",
            ambiguityScore: 0.63,
            consequenceLevel: 0.81,
            manipulationHints: ["time_pressure"],
            hostRelevance: 0.91
        )
        let decomposeFrame = BASDecomposeFrame(
            facts: [headline],
            goals: ["Keep the boundary"],
            emotions: ["alert"],
            unknowns: ["best next step"],
            contradictions: [],
            pressureSignals: ["urgency"],
            manipulationSignals: ["forced-now"],
            mirrorText: body
        )
        let memoryAtom = BASMemoryAtom(
            memoryID: "mem-1",
            summary: "Protect the boundary first.",
            contentType: .warm,
            source: "session",
            confidence: 0.86,
            conflictFingerprint: "fp-1"
        )
        let memoryBundle = BASMemoryBundle(
            atoms: [memoryAtom],
            retrievalTags: ["boundary"],
            conflictRefs: [],
            activeHostVersion: hostContext.activeVersion
        )
        let candidate = BASCandidatePath(
            candidateID: "cand-1",
            title: "Pause and protect",
            actionSummary: "Hold for a moment before acting.",
            requiredEvidence: ["high pressure"],
            expectedBenefit: 0.9,
            expectedCost: 0.2,
            reversibility: 0.8,
            confidence: 0.87
        )
        let forecast = BASForecastItem(
            candidateID: candidate.candidateID,
            shortTermOutcome: "Less immediate pressure",
            midTermOutcome: "Better boundary clarity",
            worstCase: "Minor delay",
            uncertainty: 0.2,
            affectedRelations: ["self"]
        )
        let critique = BASCritiqueItem(
            candidateID: candidate.candidateID,
            critiqueType: .boundaryConflict,
            critiqueText: "The safer route avoids forcing the choice too early.",
            severity: 0.74
        )
        let triScore = BASTriSelfScore(
            candidateID: candidate.candidateID,
            idScore: 0.42,
            egoScore: 0.81,
            superegoScore: 0.91,
            mergedScore: 0.83,
            veto: false
        )
        let mergedChoice = BASMergedChoice(
            candidateID: candidate.candidateID,
            title: "Pause first",
            actionSummary: "Use the safer next step."
        )
        let riskCard = BASRiskCard(
            totalRisk: 0.88,
            riskLevel: .high,
            factors: ["pressure", "uncertainty"],
            uncertainty: 0.56,
            irreversibility: 0.79,
            manipulationStrength: 0.73,
            gsiScore: 0.68,
            recommendedMode: mode
        )
        let actionPermit = BASActionPermit(
            mode: mode,
            reasonCodes: ["risk.high", "gsi.elevated"],
            requireSecondCheck: true,
            outputLengthCap: 120,
            tonePolicy: "clear_firm",
            templatePolicy: "protective_alternative"
        )
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-1",
            memoryRefs: [memoryAtom.memoryID],
            candidates: [candidate],
            forecasts: [forecast],
            critiques: [critique],
            triScores: [triScore],
            riskCard: riskCard,
            actionPermit: actionPermit,
            stabilityScore: 0.91,
            stopReason: .blocked
        )
        let thoughtFold = BASThoughtFold(
            foldID: "fold-1",
            compactSlots: ["headline": headline, "body": body],
            candidateSignatures: [candidate.candidateID],
            riskSnapshot: riskCard,
            hostEffectSummary: "Host boundary remains primary.",
            restorePointer: "restore-1",
            checksum: "checksum-1"
        )
        let updateTicket = BASUpdateTicket(
            ticketID: "ticket-1",
            sessionRef: "session-1",
            summary: "Record a protective turn.",
            memoryWriteSuggestion: "Keep the boundary signal in warm memory.",
            hostProfileChangeSuggestion: nil,
            ruleCandidateRef: "rule-1",
            confidence: 0.84,
            conflictFlag: false,
            requiresReview: true
        )
        let runtimeTrace = BASRuntimeTrace(
            sessionID: "session-1",
            layerEvents: [
                BASRuntimeTraceEvent(layerID: "L11", event: "gate", detail: "Protective mode short-circuited refinement.")
            ],
            latencyBreakdownMs: ["guard": 3],
            powerEstimate: 0.12,
            thermalTrace: ["cool"],
            modelRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            guardrailFindings: [
                BASRuntimeAuditFinding(
                    code: "budget.high_risk_fast_path",
                    layerID: "L1",
                    summary: "Protective short-circuit requested.",
                    severity: .high,
                    enforced: true
                )
            ],
            recommendedKillSwitches: [.forceGuardMode]
        )

        return BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: BASWakeIntent(
                intentLevel: .guard,
                estimatedValue: 0.72,
                estimatedRisk: 0.91,
                estimatedCost: 0.24,
                preferredMode: budgetFrame.runMode
            ),
            vitalState: BASVitalState(
                wakeState: budgetFrame.runMode,
                survivalMargin: 0.76,
                thermalMargin: 0.88,
                powerMargin: 0.74,
                continuityScore: 0.81,
                stabilityScore: 0.86
            ),
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: [triScore],
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: 0.37,
            renderedOutput: BASRenderedOutput(
                mode: mode,
                headline: headline,
                body: body,
                alternativeActions: alternativeActions,
                explanationCodes: ["risk.high", "gsi.elevated"]
            ),
            updateTickets: [updateTicket],
            runtimeTrace: runtimeTrace
        )
    }
}
