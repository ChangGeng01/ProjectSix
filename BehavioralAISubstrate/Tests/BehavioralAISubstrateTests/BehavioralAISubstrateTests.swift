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
        #expect(decision.decision == .requireConfirmation)
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
}
