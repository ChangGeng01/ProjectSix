import Foundation
import Testing
@testable import BASAdmin
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASEvaluation

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BehavioralAISubstrate")
struct BehavioralAISubstrateTests {
    @Test("runtime local route helpers")
    func runtimeLocalRouteHelpers() {
        let route = BASModelRoute.local("local-model", fallbackModelIDs: ["backup-model"])

        #expect(route.isLocalOnly)
        #expect(route.preferredModelID == "local-model")
        #expect(route.fallbackModelIDs == ["backup-model"])
    }

    @Test("memory structures stay serializable")
    func memoryStructuresAreSerializable() throws {
        let event = BASEventRecord(kind: .episodic, content: "capture", tags: ["task"])
        let candidate = BASMemoryCandidate(
            event: event,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.8,
            sourceType: "user",
            preferredTier: .warm
        )

        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(BASMemoryCandidate.self, from: data)

        #expect(decoded == candidate)
        #expect(decoded.preferredTier == .warm)
    }

    @Test("policy dsl round trips")
    func policyDSLRoundTrips() throws {
        let rule = BASPolicyRule(id: "confirm-cloud", actionClass: .toolCall, minimumRiskForConfirmation: BASRiskScore(0.5), blockedScopes: [.session], blockedSensitivities: [.high], allowCloud: false)
        let doc = BASPolicyDSLDocument(version: "1", rules: [rule])

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(BASPolicyDSLDocument.self, from: data)
        let set = BASPolicySet(rules: decoded.rules)

        let decision = set.decide(actionClass: .toolCall, riskLevel: .high, scope: .task, sensitivity: .medium, cloudRequested: true)

        #expect(decoded == doc)
        #expect(decision.decision == .deny)
    }

    @Test("admin snapshot covers all layers")
    func adminSnapshotCoversAllLayers() {
        let snapshot = BASConsoleSnapshot.eightLayerSnapshot(summary: "subsystem ready")

        #expect(snapshot.reports.count == 8)
        #expect(snapshot.overallScore == 1.0)
        #expect(snapshot.overallSummary == "subsystem ready")
    }

    @Test("evaluation gate blocks regressions")
    func evaluationGateBlocksRegressions() {
        let suite = BASEvaluationSuite(name: "smoke")
        let result = suite.gate(candidateScore: 0.7, baselineScore: 0.9, tolerance: 0.05)

        #expect(result.status == .fail)
        #expect(result.blockedReason == "candidate under baseline")
    }

    @Test("evaluation coverage builder tracks regression drift and evolution signals")
    func evaluationCoverageBuilderTracksSignals() {
        let section = BASEvaluationCoverageBuilder.build(
            input: BASEvaluationCoverageInput(
                regressionHarnessPresent: true,
                calibrationKindCount: 2,
                calibrationAlertKindCount: 3,
                evolutionKindCount: 1
            )
        )

        #expect(section.items.count == 3)
        #expect(section.items.first(where: { $0.id == "evaluation.regression" })?.status == .ready)
        #expect(section.items.first(where: { $0.id == "evaluation.drift" })?.evidence == ["Calibration alerts 3"])
        #expect(section.items.first(where: { $0.id == "evaluation.safe_evolution" })?.status == .ready)
    }

    @Test("apple handoff summary keeps typed metadata")
    func appleHandoffSummaryKeepsTypedMetadata() {
        let envelope = BASAppleHandoffEnvelope(
            surface: .watch,
            taskKind: .plan,
            riskLevel: .medium,
            payloadSummary: "Hold this decision until morning."
        )
        let summary = BASDefaultAppleHandoffSummarizer().summarize(
            envelope,
            route: .local("on-device-planner")
        )

        #expect(envelope.metadata.requiresResume)
        #expect(summary.surface == .watch)
        #expect(summary.taskKind == .plan)
        #expect(summary.routeKind == .local)
        #expect(summary.detail.contains("route local"))
    }

    @Test("apple prompt input adapter normalizes lifecycle and neural inputs")
    func applePromptInputAdapterNormalizesLifecycleAndNeuralInputs() {
        let lifecycle = BASApplePromptInputAdapter.lifecycleSnapshot(
            from: BASApplePromptLifecycleInput(
                rebuiltSession: true,
                generation: 3,
                anchorFields: [" prompt ", "prompt", "mode"],
                activeFields: [" mode ", "goal"],
                staleFields: [" note ", "note"],
                anchorTitles: [" Current prompt ", "", "Mode"]
            )
        )
        let neural = BASApplePromptInputAdapter.neuralSnapshot(
            from: BASApplePromptNeuralInput(
                dominantActivations: [
                    BASApplePromptActivationInput(signal: " urgency ", displayTitle: " Urgency "),
                    BASApplePromptActivationInput(signal: "urgency", displayTitle: "Urgency")
                ],
                candidateActions: [
                    BASApplePromptActionCandidateInput(route: " pause "),
                    BASApplePromptActionCandidateInput(route: "pause"),
                    BASApplePromptActionCandidateInput(route: "reflect")
                ],
                suppressedBehaviors: [" long_explanation ", "", "long_explanation", "topic_switch"]
            )
        )

        #expect(lifecycle.anchorFields == ["prompt", "mode"])
        #expect(lifecycle.activeFields == ["mode", "goal"])
        #expect(lifecycle.staleFields == ["note"])
        #expect(lifecycle.anchorTitles == ["Current prompt", "Mode"])
        #expect(neural.dominantActivations.count == 1)
        #expect(neural.dominantActivations.first?.signal == "urgency")
        #expect(neural.dominantActivations.first?.displayTitle == "Urgency")
        #expect(neural.candidateActions.map(\.route) == ["pause", "reflect"])
        #expect(neural.suppressedBehaviors == ["long_explanation", "topic_switch"])
    }

    @Test("apple prompt input adapter preserves adaptive strategy budgets and dedupes action space")
    func applePromptInputAdapterBuildsAdaptiveStrategy() {
        let strategy = BASApplePromptInputAdapter.adaptiveStrategy(
            from: BASAppleAdaptiveStrategyInput(
                kind: .primary,
                entropy: .low,
                runtimeGear: .low,
                contextBudget: 220,
                outputCharacterBudget: 120,
                timeBudgetMs: 1100,
                toolCallBudget: 0,
                retrievalItemBudget: 1,
                retrievalMode: .off,
                thinkingMode: .off,
                outputMode: .guidedShort,
                tone: .briefWarm,
                actionSpace: ["encourage", "encourage", "next_step", " next_step "],
                responseLanguage: .english,
                allowsModelInvocation: true
            )
        )

        #expect(strategy.kind == .primary)
        #expect(strategy.runtimeGear == .low)
        #expect(strategy.contextBudget == 220)
        #expect(strategy.outputCharacterBudget == 120)
        #expect(strategy.timeBudgetMs == 1100)
        #expect(strategy.toolCallBudget == 0)
        #expect(strategy.retrievalItemBudget == 1)
        #expect(strategy.actionSpace == ["encourage", "next_step"])
        #expect(strategy.responseLanguage == .english)
        #expect(strategy.allowsModelInvocation)
    }

    @Test("console snapshot builder materializes all eight layers")
    func consoleSnapshotBuilderMaterializesAllEightLayers() {
        let metrics = BASFlightDeckMetrics(
            layerInputs: [
                BASLayerAssessmentInput(layer: .runtime, score: 92, summary: "Runtime stable"),
                BASLayerAssessmentInput(layer: .memory, score: 78, summary: "Memory warming", blockers: ["Pending candidates still high"])
            ],
            runtimeSummary: "Route local",
            brainSummary: "Companion coach",
            isPureLocal: true
        )

        let snapshot = BASConsoleSnapshotBuilder.build(from: metrics)

        #expect(snapshot.reports.count == 8)
        #expect(snapshot.reports.first(where: { $0.kind == .runtime })?.health == .healthy)
        #expect(snapshot.reports.first(where: { $0.kind == .memory })?.health == .warning)
        #expect(snapshot.blockerSummary.contains(where: { $0.contains("Pending candidates still high") }))
    }

    @Test("entry intent summary keeps orchestration semantics")
    func entryIntentSummaryKeepsOrchestrationSemantics() {
        let envelope = BASEntryIntentEnvelope(
            kind: .resume,
            surface: .notification,
            taskKind: .plan,
            preferredWorkflowID: "comparative",
            promptSeed: "Resume the decision about moving.",
            riskLevel: .high,
            triggerReason: "predictive_nudge",
            continuityToken: "fp_123",
            expiresAt: .now.addingTimeInterval(300)
        )

        let summary = BASEntryIntentSummarizer.summarize(envelope)

        #expect(summary.requiresResume)
        #expect(summary.headline.contains("Notification"))
        #expect(summary.detail.contains("task plan"))
        #expect(summary.detail.contains("risk high"))
    }
}
#endif
