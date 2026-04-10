import Foundation
import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy

@Suite("BASApple Provider Release Adapter")
struct BASAppleProviderReleaseAdapterTests {
    @Test("adapter verdict keeps provider release decisions package-owned")
    func adapterVerdictKeepsReleaseDecisionPackageOwned() {
        let verdict = BASAppleProviderReleaseAdapter.verdict(
            from: BASAppleProviderReleaseInput(
                traceKindRawValue: "quick",
                outputPreview: "Current: pause and let the urge settle.\nAfter: come back tomorrow.",
                kernelSnapshot: kernelWithoutTruthState(),
                brainState: blockedGuidanceBrainState()
            )
        )

        switch verdict {
        case .allow:
            Issue.record("Expected provider release adapter to reject blocked guidance.")
        case let .reject(assessment):
            #expect(assessment.consistencyCheck?.violations.contains(where: { $0.kind == .forbiddenAction }) == true)
        }
    }

    @Test("adapter rejected detail preserves source framing")
    func adapterRejectedDetailPreservesSourceFraming() {
        let detail = BASAppleProviderReleaseAdapter.rejectedConsistencyDetail(
            base: "Before rejected the result.",
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(kind: .forbiddenAction, message: "Action drifted outside the allowed space.")
                ]
            ),
            source: "cached mirror refinement"
        )

        #expect(detail.contains("cached mirror refinement"))
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
}
