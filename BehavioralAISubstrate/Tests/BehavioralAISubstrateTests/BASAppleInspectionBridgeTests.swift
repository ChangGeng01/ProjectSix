import Foundation
import Testing
@testable import BASAdmin
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASAppleInspectionBridge")
struct BASAppleInspectionBridgeTests {
    @Test("runtime context builder compiles deterministic local runtime view")
    func runtimeContextBuilderCompilesRuntimeView() {
        let context = BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRuntimeContextSourceInput(
                primaryTraceKind: "balance",
                runtimeGear: .high,
                environmentClass: .lowPower,
                deviceClass: .balancedPhone,
                riskLevel: .high,
                budget: BASAdaptiveRuntimeBudget(
                    contextBudget: 420,
                    outputCharacterBudget: 240,
                    timeBudgetMs: 9000,
                    toolCallBudget: 2,
                    retrievalItemBudget: 4
                )
            )
        )

        #expect(context.taskKind == .plan)
        #expect(context.gear == .high)
        #expect(context.deviceProfile.memoryMB == 6144)
        #expect(context.deviceProfile.lowPowerMode)
        #expect(context.privacyMode == .localOnly)
        #expect(context.riskLevel == .high)
        #expect(context.budget.contextTokens == 420)
    }

    @Test("raw runtime, intent, and handoff builders normalize host raw values")
    func rawBuildersNormalizeHostValues() {
        let context = BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRawRuntimeContextSourceInput(
                primaryTraceKindID: "mirror",
                runtimeGearID: "low",
                environmentClassID: "memoryConstrained",
                deviceClassID: "memoryConstrainedPhone",
                riskLevelID: "medium",
                budget: BASAdaptiveRuntimeBudget(
                    contextBudget: 180,
                    outputCharacterBudget: 90,
                    timeBudgetMs: 2400,
                    toolCallBudget: 0,
                    retrievalItemBudget: 1
                )
            )
        )
        let intent = BASEntryIntentBridgeBuilder.envelope(
            kindID: "resumeCurrentDecision",
            surfaceID: "notification",
            preferredWorkflowID: "balance",
            promptSeed: "Resume the decision.",
            riskLevelID: "high",
            triggerReason: "prediction",
            continuityToken: "fp-1",
            requestedAt: Date(timeIntervalSince1970: 1_800_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_800_003_600)
        )
        let handoff = BASAppleHandoffBridgeBuilder.summary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            surfaceID: "siri",
            preferredWorkflowID: "mirror",
            riskLevelID: "medium",
            payloadSummary: "Hold this until tomorrow morning.",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(context.taskKind == .retrieve)
        #expect(context.gear == .low)
        #expect(context.deviceProfile.memoryMB == 4096)
        #expect(intent.kind == .resume)
        #expect(intent.surface == .notification)
        #expect(intent.taskKind == .plan)
        #expect(intent.riskLevel == .high)
        #expect(handoff.surface == .shortcut)
        #expect(handoff.taskKind == .retrieve)
        #expect(handoff.riskLevel == .medium)
    }

    @Test("role profile and brain snapshot builders normalize host raw values")
    func roleAndBrainBuildersNormalizeHostState() {
        let role = BASAppleInspectionBridgeBuilder.roleProfile(
            from: BASAppleRoleProfileSourceInput(
                name: "Risk Sentinel",
                postureID: "protective",
                initiativeID: "guided",
                confidenceCeiling: 0.72,
                roleBoundaryPreset: "reflective_guarded"
            )
        )
        let brain = BASAppleInspectionBridgeBuilder.brainSnapshot(
            from: BASAppleBrainSnapshotSourceInput(
                mode: "quick",
                dominantGoals: ["Protect sleep"],
                activeConstraints: ["Delay irreversible action"],
                warmth: 0.58,
                directness: 0.71,
                brevity: 0.88,
                actionBias: 0.62,
                activeTemplateIDs: [
                    "A8D79B8C-10D5-4F4F-BC72-555555555555"
                ],
                recentFailurePatternIDs: [
                    "B8D79B8C-10D5-4F4F-BC72-666666666666"
                ],
                retrievalTags: ["sleep", "night"],
                verificationSnapshot: "brain-fingerprint"
            )
        )

        #expect(role?.posture == .guardian)
        #expect(role?.initiative == .balanced)
        #expect(brain?.mode == "quick")
        #expect(brain?.dominantGoals == ["Protect sleep"])
        #expect(brain?.activeTemplateIDs.count == 1)
        #expect(brain?.verificationSnapshot == "brain-fingerprint")
    }

    @Test("console snapshot builder packages runtime and brain summaries")
    func consoleSnapshotBuilderPackagesRuntimeAndBrain() {
        let runtimeContext = BASAppleInspectionBridgeBuilder.runtimeContext(
            from: BASAppleRuntimeContextSourceInput(
                primaryTraceKind: "quick",
                runtimeGear: .balanced,
                environmentClass: .normal,
                deviceClass: .fullPhone,
                riskLevel: .medium,
                budget: BASAdaptiveRuntimeBudget(
                    contextBudget: 320,
                    outputCharacterBudget: 180,
                    timeBudgetMs: 6000,
                    toolCallBudget: 1,
                    retrievalItemBudget: 3
                )
            )
        )
        let role = BASAppleInspectionBridgeBuilder.roleProfile(
            from: BASAppleRoleProfileSourceInput(
                name: "Reflective Coach",
                postureID: "coaching",
                initiativeID: "assertive",
                confidenceCeiling: 0.8,
                roleBoundaryPreset: "coach"
            )
        )
        let brain = BASAppleInspectionBridgeBuilder.brainSnapshot(
            from: BASAppleBrainSnapshotSourceInput(
                mode: "mirror",
                dominantGoals: ["Avoid regret"],
                activeConstraints: ["Show evidence first"],
                warmth: 0.7,
                directness: 0.66,
                brevity: 0.52,
                actionBias: 0.4,
                activeTemplateIDs: [],
                recentFailurePatternIDs: [],
                retrievalTags: ["mirror"],
                verificationSnapshot: "fp-123"
            )
        )
        let snapshot = BASAppleInspectionBridgeBuilder.consoleSnapshot(
            from: BASAppleConsoleBridgeSourceInput(
                generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                flightDeckCompilation: BASAppleFlightDeckCompilation(
                    generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                    overallScore: 91,
                    overallHealthID: "strong",
                    layerReports: [
                        BASAppleFlightDeckLayerReport(
                            layerID: "runtime",
                            score: 92,
                            healthID: "strong",
                            headline: "Runtime stable",
                            signals: ["local-first"],
                            blockers: []
                        ),
                        BASAppleFlightDeckLayerReport(
                            layerID: "memory",
                            score: 88,
                            healthID: "strong",
                            headline: "Memory governed",
                            signals: ["hot/warm/cold"],
                            blockers: []
                        )
                    ],
                    isPureLocalClosedLoop: true,
                    dominantBlockers: []
                ),
                activeProviderTitle: "Gemma Local",
                totalRequests: 14,
                totalProviderAttempts: 17,
                runtimeContext: runtimeContext,
                roleProfile: role,
                boundaryModeID: "reflective_guarded",
                calibrationStatusID: "stable",
                brainState: brain
            )
        )

        #expect(snapshot.isPureLocal)
        #expect(snapshot.runtimeSummary?.contains("Gemma Local") == true)
        #expect(snapshot.runtimeSummary?.contains("gear balanced") == true)
        #expect(snapshot.brainSummary?.contains("Reflective Coach") == true)
        #expect(snapshot.brainSummary?.contains("fp-123") == true)
    }
}
