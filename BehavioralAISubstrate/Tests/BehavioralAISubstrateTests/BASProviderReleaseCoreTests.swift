import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASProviderReleaseGate")
struct BASProviderReleaseCoreTests {
    @Test("verdict rejects quick guidance when fallback truth state blocks local guidance")
    func verdictRejectsBlockedGuidance() {
        let verdict = BASProviderReleaseGate.verdict(
            for: BASProviderReleaseEvaluationRequest(
                kind: .quick,
                outputPreview: "Current: pause and let the urge settle.\nAfter: come back tomorrow.",
                kernelSnapshot: kernelWithoutTruthState(),
                brainState: blockedGuidanceBrainState()
            )
        )

        switch verdict {
        case .allow:
            Issue.record("Expected the release gate to reject blocked local guidance.")
        case let .reject(assessment):
            #expect(assessment.outputPreview.contains("Current:"))
            #expect(assessment.consistencyCheck?.violations.contains(where: { $0.kind == .forbiddenAction }) == true)
        }
    }

    @Test("verdict allows reminder retrieval when governed memory remains permitted")
    func verdictAllowsReminderRetrieval() {
        let verdict = BASProviderReleaseGate.verdict(
            for: BASProviderReleaseEvaluationRequest(
                kind: .reminder,
                outputPreview: "Wait and reuse the sleep-protection reminder you already trust.",
                kernelSnapshot: kernelWithoutTruthState(),
                brainState: reminderBrainState(),
                reminderSurfaceMode: .quick
            )
        )

        switch verdict {
        case let .allow(assessment):
            #expect(assessment.consistencyCheck?.isConsistent == true)
        case .reject:
            Issue.record("Expected reminder release to stay allowed when governed memory is still permitted.")
        }
    }

    @Test("rejected detail keeps source framing and trims to first three violations")
    func rejectedDetailTrimsViolationList() {
        let result = BASConsistencyCheckResult(
            violations: [
                BASConsistencyViolation(kind: .forbiddenAction, message: "First."),
                BASConsistencyViolation(kind: .factConflict, message: "Second."),
                BASConsistencyViolation(kind: .personaDrift, message: "Third."),
                BASConsistencyViolation(kind: .modeMismatch, message: "Fourth.")
            ]
        )

        let detail = BASProviderReleaseGate.rejectedConsistencyDetail(
            base: "Base detail.",
            result: result,
            source: "cached primary refinement"
        )

        #expect(detail.contains("Base detail."))
        #expect(detail.contains("cached primary refinement"))
        #expect(detail.contains("First."))
        #expect(detail.contains("Second."))
        #expect(detail.contains("Third."))
        #expect(!detail.contains("Fourth."))
    }

    @Test("raw value evaluator bridges host trace kinds without host-owned mapping")
    func rawValueEvaluatorBridgesTraceKinds() {
        let verdict = BASProviderReleaseEvaluator.verdict(
            traceKindRawValue: "reminder",
            outputPreview: "Wait and reuse the reminder you trust.",
            kernelSnapshot: kernelWithoutTruthState(),
            brainState: reminderBrainState(),
            reminderSurfaceModeRawValue: "quick",
            referencedFacts: ["current_goal": "Protect sleep"]
        )

        switch verdict {
        case let .allow(assessment):
            #expect(assessment.consistencyCheck?.isConsistent == true)
        case .reject:
            Issue.record("Expected raw-value evaluator to preserve allowed reminder release.")
        }
    }

    @Test("release gate honors host-specific structured truth behavior")
    func releaseGateHonorsHostSpecificStructuredTruthBehavior() {
        let verdict = BASProviderReleaseGate.verdict(
            for: BASProviderReleaseEvaluationRequest(
                kind: .quick,
                outputPreview: "Current: pause now.\nAfter: revisit this tomorrow.",
                kernelSnapshot: kernelWithoutTruthState(),
                brainState: blockedGuidanceBrainState(),
                structuredTruthBehavior: BASStructuredTruthBehavior(
                    modeNamesByKindID: [
                        BASAdaptiveTraceKind.quick.rawValue: "before.quick"
                    ],
                    kernelPersonaRulesByKindID: [
                        BASAdaptiveTraceKind.quick.rawValue: "Keep the interruption short, calm, and non-shaming."
                    ]
                )
            )
        )

        switch verdict {
        case .allow:
            Issue.record("Expected the release gate to keep honoring blocked guidance even with host-specific truth behavior.")
        case let .reject(assessment):
            #expect(assessment.consistencyCheck?.violations.contains(where: { $0.kind == .forbiddenAction }) == true)
        }
    }

    private func kernelWithoutTruthState() -> BASCognitionKernelSnapshot {
        BASCognitionKernel.compile(
            BASCognitionKernelRequest(
                blocks: [
                    BASContextBlock(
                        id: "frontstage_state",
                        layer: .kernel,
                        title: "Frontstage",
                        content: "Keep it local and structured.",
                        retention: .required,
                        priority: 100
                    )
                ],
                compilationPolicy: BASContextCompilationPolicy(targetCharacters: 220)
            )
        )
    }

    private func blockedGuidanceBrainState() -> BASDecisionBrainState {
        BASDecisionBrainState(
            profileCore: ["Values clarity over speed."],
            activeGoals: ["Protect tomorrow's judgment."],
            relevantMemories: ["Waiting overnight usually helps."],
            sessionBiases: ["句子短"],
            retrievalTags: ["cooldown"],
            reactionWeights: .defaults(forModeName: BASDecisionMode.quick.rawValue),
            boundaryPolicy: BASBoundaryPolicyState(
                mode: .localOnlyProtective,
                riskLevel: .high,
                allowedActionClasses: ["load_governed_memory"],
                blockedActionClasses: ["render_local_guidance", "cloud_escalation"],
                requiredConfirmations: ["irreversible_decision"],
                activeConstraints: [.noCloudEscalation, .lockSensitiveMemory],
                auditHeadline: "Stay local and avoid new guidance."
            ),
            loadedAt: .now
        )
    }

    private func reminderBrainState() -> BASDecisionBrainState {
        BASDecisionBrainState(
            profileCore: ["Protect sleep before making night decisions."],
            activeGoals: ["Protect sleep"],
            relevantMemories: ["Reusing a proven reminder keeps things calmer."],
            sessionBiases: ["brief"],
            retrievalTags: ["sleep"],
            reactionWeights: .defaults(forModeName: BASDecisionMode.quick.rawValue),
            boundaryPolicy: BASBoundaryPolicyState(
                mode: .localOnlyAdvisory,
                riskLevel: .low,
                allowedActionClasses: ["load_governed_memory"],
                blockedActionClasses: ["cloud_escalation"],
                requiredConfirmations: [],
                activeConstraints: [.noCloudEscalation],
                auditHeadline: "Stay local."
            ),
            loadedAt: .now
        )
    }
}
