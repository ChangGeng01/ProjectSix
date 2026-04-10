import Foundation
import Testing
@testable import BASMemory
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASObservability")
struct BASObservabilityCoreTests {
    @Test("replay fingerprint is stable for identical bundles")
    func replayFingerprintIsStable() {
        let bundle = makeReplayBundle()

        let first = BASObservabilityInspector.replayFingerprint(for: bundle)
        let second = BASObservabilityInspector.replayFingerprint(for: bundle)

        #expect(first == second)
        #expect(first.value.count == 64)
    }

    @Test("anomaly inspector catches release mismatches and latency spikes")
    func anomalyInspectorCatchesReleaseMismatchesAndLatencySpikes() {
        let trace = BASExecutionTrace(
            inputSummary: "Should I send this?",
            selectedRoute: .cloud("cloud-large"),
            memoriesRecalled: ["same memory", "same memory"],
            toolsCalled: ["send_message"],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 200,
                retrievalMs: 400,
                generationMs: 4700,
                toolMs: 0
            ),
            outputSummary: "Drafted a reply."
        )

        let signals = BASObservabilityInspector.anomalySignals(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
        )

        #expect(signals.contains(where: { $0.kind == "latency_spike" }))
        #expect(signals.contains(where: { $0.kind == "tool_timing_gap" }))
        #expect(signals.contains(where: { $0.kind == "release_mismatch" }))
        #expect(signals.contains(where: { $0.kind == "duplicate_memory_recall" }))
    }

    @Test("release decision mirrors policy outcome")
    func releaseDecisionMirrorsPolicyOutcome() {
        let trace = BASExecutionTrace(
            inputSummary: "quick",
            selectedRoute: .local("local-fast"),
            memoriesRecalled: [],
            toolsCalled: [],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 20,
                retrievalMs: 0,
                generationMs: 100,
                toolMs: 0
            ),
            outputSummary: "ok"
        )

        let allow = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed")
        )
        let confirm = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .requireConfirmation, reason: "need confirm")
        )
        let deny = BASObservabilityInspector.releaseDecision(
            for: trace,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked")
        )

        #expect(allow.kind == .allow)
        #expect(confirm.kind == .requireConfirmation)
        #expect(deny.kind == .deny)
    }

    @Test("inspection bundle packages replay release anomalies and calibration")
    func inspectionBundlePackagesUnifiedInspectionState() {
        let bundle = BASObservabilityInspector.inspectionBundle(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_123),
            trace: BASExecutionTrace(
                inputSummary: "Should I send this?",
                selectedRoute: .cloud("cloud-large"),
                memoriesRecalled: ["same memory", "same memory"],
                toolsCalled: ["send_message"],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 100,
                    retrievalMs: 200,
                    generationMs: 4_800,
                    toolMs: 0
                ),
                outputSummary: "Drafted a reply."
            ),
            brainState: makeReplayBundle().brainState,
            runtimeContext: makeReplayBundle().runtimeContext,
            policyDecision: BASPolicyDecisionRecord(decision: .deny, reason: "blocked by boundary"),
            calibration: BASInspectionCalibrationSummary(
                score: 0.62,
                status: "warn",
                summary: "Retrieval drift rising.",
                alertCount: 2,
                alertReasons: ["retrieval drift", "route instability"]
            )
        )

        #expect(bundle.generatedAt == Date(timeIntervalSince1970: 1_700_000_123))
        #expect(bundle.releaseDecision.kind == .deny)
        #expect(bundle.replayFingerprint.value.count == 64)
        #expect(bundle.anomalySignals.contains(where: { $0.kind == "latency_spike" }))
        #expect(bundle.calibration?.status == "warn")
        #expect(bundle.summary.contains("Release deny"))
        #expect(bundle.blockerSummary.contains("blocked by boundary"))
    }

    private func makeReplayBundle() -> BASReplayBundle {
        BASReplayBundle(
            trace: BASExecutionTrace(
                inputSummary: "replay this",
                selectedRoute: .local("local-fast"),
                memoriesRecalled: ["Memory A"],
                toolsCalled: ["toolA"],
                latency: BASTraceLatencyBreakdown(
                    routeSelectionMs: 12,
                    retrievalMs: 35,
                    generationMs: 180,
                    toolMs: 45
                ),
                outputSummary: "Released"
            ),
            brainState: BASCurrentBrainState(
                mode: "quick",
                dominantGoals: ["stay calm"],
                activeConstraints: ["sleep first"],
                reactionWeights: BASReactionWeights(warmth: 0.7, directness: 0.5, brevity: 0.8, actionBias: 0.6),
                activeTemplateIDs: [],
                recentFailurePatternIDs: [],
                retrievalTags: ["night"],
                verificationSnapshot: "fp_1"
            ),
            runtimeContext: BASRuntimeContext(
                taskKind: .chat,
                gear: .balanced,
                deviceProfile: BASDeviceProfile(
                    modelName: "iPhone",
                    memoryMB: 6144,
                    batteryLevel: 0.8,
                    lowPowerMode: false,
                    thermalState: "nominal"
                ),
                privacyMode: .localOnly,
                riskLevel: .medium,
                networkAvailable: false,
                budget: BASExecutionBudget(
                    contextTokens: 1200,
                    outputTokens: 300,
                    retrievalItems: 3,
                    toolCalls: 1,
                    timeBudgetMs: 1500
                )
            ),
            policyDecision: BASPolicyDecisionRecord(decision: .allow, reason: "allowed")
        )
    }
}
