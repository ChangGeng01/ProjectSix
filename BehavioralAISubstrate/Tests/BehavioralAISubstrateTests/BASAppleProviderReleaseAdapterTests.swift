import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Provider Release Adapter")
struct BASAppleProviderReleaseAdapterTests {
    @Test("adapter owns preview formatting and referenced facts")
    func adapterOwnsPreviewFormattingAndReferencedFacts() {
        #expect(
            BASAppleProviderReleaseAdapter.keyedPreview(
                fields: [
                    ("Current", "Pause now."),
                    ("After", "Tomorrow will feel lighter.")
                ]
            ) == "Current: Pause now.\nAfter: Tomorrow will feel lighter."
        )
        #expect(
            BASAppleProviderReleaseAdapter.keyedPreview(
                fields: [
                    ("Headline", "Protect sleep"),
                    ("Focus", "This adds one more obligation."),
                    ("Next", "Wait until tomorrow.")
                ]
            ) == "Headline: Protect sleep\nFocus: This adds one more obligation.\nNext: Wait until tomorrow."
        )
        #expect(
            BASAppleProviderReleaseAdapter.keyedPreview(
                fields: [
                    ("Headline", "This is the same pattern"),
                    ("Tension", "Hope versus depletion"),
                    ("Next", "Name the cost first.")
                ]
            ) == "Headline: This is the same pattern\nTension: Hope versus depletion\nNext: Name the cost first."
        )
        #expect(
            BASAppleProviderReleaseAdapter.selectionPreview(content: "Hold this for tomorrow.") == "Hold this for tomorrow."
        )
        #expect(
            BASAppleProviderReleaseAdapter.referencedFacts(from: blockedGuidanceBrainState()) == [
                "current_goal": "Protect tomorrow's judgment.",
                "primary_context_goal": "Protect tomorrow's judgment."
            ]
        )
    }

    @Test("adapter verdict keeps provider release decisions package-owned")
    func adapterVerdictKeepsReleaseDecisionPackageOwned() {
        let verdict = BASAppleProviderReleaseAdapter.verdict(
            traceKindRawValue: "primary",
            outputPreview: "Current: pause and let the urge settle.\nAfter: come back tomorrow.",
            kernelSnapshot: kernelWithoutTruthState(),
            brainState: blockedGuidanceBrainState()
        )

        switch verdict {
        case .allow:
            Issue.record("Expected provider release adapter to reject blocked guidance.")
        case let .reject(assessment):
            #expect(assessment.consistencyCheck?.violations.contains(where: { $0.kind == .forbiddenAction }) == true)
        }
    }

    @Test("adapter can pass host-specific structured truth behavior through release evaluation")
    func adapterVerdictPassesHostSpecificStructuredTruthBehavior() {
        let verdict = BASAppleProviderReleaseAdapter.verdict(
            traceKindRawValue: "primary",
            outputPreview: "Current: pause and let the urge settle.\nAfter: come back tomorrow.",
            kernelSnapshot: kernelWithoutTruthState(),
            brainState: blockedGuidanceBrainState(),
            structuredTruthBehavior: BASStructuredTruthBehavior(
                modeNamesByKindID: [
                    BASAdaptiveTraceKind.primary.rawValue: "before.primary"
                ],
                kernelPersonaRulesByKindID: [
                    BASAdaptiveTraceKind.primary.rawValue: "Keep the interruption short, calm, and non-shaming."
                ]
            )
        )

        switch verdict {
        case .allow:
            Issue.record("Expected provider release adapter to preserve blocked guidance under host-specific truth behavior.")
        case let .reject(assessment):
            #expect(assessment.consistencyCheck?.violations.contains(where: { $0.kind == BASConsistencyViolationKind.forbiddenAction }) == true)
        }
    }

    @Test("adapter rejected detail preserves source framing")
    func adapterRejectedDetailPreservesSourceFraming() {
        let detail = BASAppleProviderReleaseAdapter.rejectedConsistencyDetail(
            base: "The host rejected the result.",
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(kind: .forbiddenAction, message: "Action drifted outside the allowed space.")
                ]
            ),
            source: "cached reflective refinement"
        )

        #expect(detail.contains("cached reflective refinement"))
        #expect(detail.contains("Action drifted outside the allowed space."))
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
            reactionWeights: .defaults(forModeName: BASDecisionMode.primary.rawValue),
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
}
