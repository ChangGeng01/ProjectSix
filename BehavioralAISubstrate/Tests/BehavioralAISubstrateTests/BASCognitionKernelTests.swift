import Foundation
import Testing
@testable import BASOrchestration
@testable import BASPolicy

@Suite("BASCognitionKernel")
struct BASCognitionKernelTests {
    @Test("kernel compile preserves required anchors and applies drop order after compaction")
    func kernelCompilePreservesAnchorsAndAppliesDropOrder() {
        let snapshot = BASCognitionKernel.compile(
            BASCognitionKernelRequest(
                blocks: [
                    block(
                        id: "frontstage_state",
                        layer: .kernel,
                        title: "Frontstage",
                        content: "Stay local and slow the decision down.",
                        retention: .required,
                        priority: 120
                    ),
                    block(
                        id: "task_state",
                        layer: .active,
                        title: "Task",
                        content: "User is deciding whether to send a late-night message.",
                        retention: .required,
                        priority: 100
                    ),
                    block(
                        id: "structured_truth",
                        layer: .active,
                        title: "Truth",
                        content: "mode=quick; allow=wait; forbid=send_now",
                        retention: .preferred,
                        priority: 90
                    ),
                    block(
                        id: "runtime_strategy",
                        layer: .summary,
                        title: "Runtime",
                        content: "low gear, filtered retrieval, short output",
                        retention: .preferred,
                        priority: 50
                    ),
                    block(
                        id: "brain_state",
                        layer: .retrieval,
                        title: "Brain",
                        content: "A long reflective retrieval block that should be dropped first once the suffix budget tightens.",
                        retention: .onDemand,
                        priority: 30
                    )
                ],
                compilationPolicy: BASContextCompilationPolicy(
                    targetCharacters: 170,
                    maximumRetrievalBlocks: 1,
                    blockSeparator: "\n",
                    sectionSeparator: "\n"
                ),
                kernelPolicy: BASContextKernelPolicy(
                    preservedBlockIDs: ["frontstage_state", "task_state"],
                    preferredBlockIDs: ["structured_truth"],
                    dropOrderIDs: ["brain_state", "runtime_strategy", "structured_truth"]
                )
            )
        )

        #expect(snapshot.compiledPrompt.retainedBlocks.map(\.id).contains("frontstage_state"))
        #expect(snapshot.compiledPrompt.retainedBlocks.map(\.id).contains("task_state"))
        #expect(snapshot.compiledPrompt.droppedBlocks.map(\.id).contains("brain_state"))
        #expect(snapshot.frontstageBlockCount >= 2)
        #expect(snapshot.compiledPrompt.renderedPrompt.count <= 170)
        #expect(snapshot.compiledPrompt.stablePrefixFingerprint.isEmpty == false)
        #expect(snapshot.compiledPrompt.semanticFingerprint.isEmpty == false)
    }

    @Test("release decision rejects forbidden drift and repairs softer persona drift")
    func releaseDecisionRejectsOrRepairsBasedOnViolationSeverity() {
        let truth = BASStructuredTruthState(
            mode: "predictive_intervention_notification",
            currentGoal: "protect sleep",
            allowedActions: ["send_predictive_notification"],
            forbiddenActions: ["send_now"],
            personaRules: ["brief", "non-judgmental"],
            sessionFacts: ["boundary_mode": "local_only_protective"]
        )

        let kernel = BASCognitionKernel.compile(
            BASCognitionKernelRequest(
                blocks: [
                    block(
                        id: "frontstage_state",
                        layer: .kernel,
                        title: "Frontstage",
                        content: "Protect sleep first.",
                        retention: .required,
                        priority: 120
                    )
                ],
                compilationPolicy: BASContextCompilationPolicy(targetCharacters: 120),
                truthState: truth
            )
        )

        let rejected = BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernel,
                responseMode: "predictive_intervention_notification",
                responseText: "Send it right now. You should have fixed this already.",
                proposedActions: ["send_now"]
            )
        )

        let repaired = BASCognitionKernel.releaseDecision(
            for: BASCognitionKernelReleaseRequest(
                kernel: kernel,
                responseMode: "predictive_intervention_notification",
                responseText: String(repeating: "briefly ", count: 60),
                proposedActions: ["send_predictive_notification"]
            )
        )

        #expect(rejected.kind == .reject)
        #expect(rejected.consistencyCheck?.violations.contains(where: { $0.kind == .forbiddenAction }) == true)
        #expect(repaired.kind == .repair)
        #expect(repaired.consistencyCheck?.violations.contains(where: { $0.kind == .personaDrift }) == true)
    }

    private func block(
        id: String,
        layer: BASContextLayerKind,
        title: String,
        content: String,
        retention: BASContextLayerRetention,
        priority: Int
    ) -> BASContextBlock {
        BASContextBlock(
            id: id,
            layer: layer,
            title: title,
            content: content,
            retention: retention,
            priority: priority
        )
    }
}
