import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASOrchestration")
struct BASOrchestrationTests {
    @Test("intent envelope round trips and maps capture")
    func captureIntentPlansRunningWithCheckpoint() throws {
        let intent = BASIntentEnvelope(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            entryKind: .capture,
            surface: .watch,
            taskKind: .chat,
            routeKind: .local,
            riskLevel: .low,
            payloadSummary: "quick capture"
        )

        let data = try JSONEncoder().encode(intent)
        let decoded = try JSONDecoder().decode(BASIntentEnvelope.self, from: data)
        let plan = BASWorkflowState().plan(for: decoded)

        #expect(decoded == intent)
        #expect(plan.workflowStatus == .running)
        #expect(plan.shouldCheckpoint)
        #expect(!plan.shouldResume)
        #expect(!plan.shouldPredict)
        #expect(plan.currentNodeID == "capture")
        #expect(plan.surface == .watch)
        #expect(plan.approvalRequirement == .none)
    }

    @Test("reopen intent pauses and requires explicit review")
    func reopenIntentCreatesPausedPlan() {
        let intent = BASIntentEnvelope(
            entryKind: .reopen,
            surface: .notification,
            taskKind: .plan,
            routeKind: .hybrid,
            riskLevel: .medium,
            payloadSummary: "reopen the cooling flow",
            resumeHint: "resume after review"
        )

        let plan = BASWorkflowState(status: .running).plan(for: intent)

        #expect(plan.workflowStatus == .paused)
        #expect(plan.shouldCheckpoint)
        #expect(plan.shouldResume)
        #expect(!plan.shouldPredict)
        #expect(plan.currentNodeID == "reopen")
        #expect(plan.approvalRequirement == .manual(reason: "reopen requires explicit resume context"))
    }

    @Test("predictive intent stays lightweight but visible")
    func predictiveIntentCreatesPredictivePlan() {
        let intent = BASIntentEnvelope(
            entryKind: .predictive,
            surface: .system,
            taskKind: .retrieve,
            routeKind: .local,
            riskLevel: .high,
            payloadSummary: "predictive nudge candidate"
        )

        let plan = BASWorkflowState().plan(for: intent)

        #expect(plan.workflowStatus == .paused)
        #expect(!plan.shouldCheckpoint)
        #expect(!plan.shouldResume)
        #expect(plan.shouldPredict)
        #expect(plan.currentNodeID == "predictive")
        #expect(plan.approvalRequirement == .manual(reason: "high risk intent requires review"))
    }

    @Test("resume intent advances workflow without forcing checkpoint")
    func resumeIntentResumesWorkflow() {
        let intent = BASIntentEnvelope(
            entryKind: .resume,
            surface: .app,
            taskKind: .summarize,
            routeKind: .local,
            riskLevel: .low,
            payloadSummary: "resume the prior state",
            resumeHint: "continue from checkpoint"
        )

        let plan = BASWorkflowState(status: .paused).plan(for: intent)

        #expect(plan.workflowStatus == .running)
        #expect(!plan.shouldCheckpoint)
        #expect(plan.shouldResume)
        #expect(!plan.shouldPredict)
        #expect(plan.currentNodeID == "resume")
        #expect(plan.resumeHint == "continue from checkpoint")
        #expect(plan.routeKind == .local)
    }

    @Test("workflow checkpoint rewind restores prior node and trims later history")
    func workflowCheckpointRewindRestoresPriorNode() throws {
        var workflow = BASWorkflowState(
            status: .running,
            currentNodeID: "interpret",
            nodes: [
                BASWorkflowNode(id: "interpret", title: "Interpret", actionClass: .memoryRecall),
                BASWorkflowNode(id: "respond", title: "Respond", actionClass: .outputRelease)
            ]
        )

        workflow.checkpoint(brainState: brainState(snapshot: "fp_1"))
        let firstCheckpointID = try #require(workflow.checkpoints.first?.id)

        workflow.resume(at: "respond")
        workflow.checkpoint(brainState: brainState(snapshot: "fp_2"))

        #expect(workflow.currentNodeID == "respond")
        #expect(workflow.checkpoints.count == 2)

        let rewound = workflow.rewind(to: firstCheckpointID)

        #expect(rewound)
        #expect(workflow.status == .running)
        #expect(workflow.currentNodeID == "interpret")
        #expect(workflow.checkpoints.count == 1)
    }

    @Test("workflow apply pause resume and complete preserve orchestration state")
    func workflowApplyPauseResumeAndCompletePreserveState() {
        let intent = BASIntentEnvelope(
            entryKind: .capture,
            surface: .app,
            taskKind: .chat,
            routeKind: .local,
            riskLevel: .medium,
            payloadSummary: "capture thought"
        )
        let plan = BASWorkflowState().plan(for: intent)
        var workflow = BASWorkflowState()

        workflow.apply(
            plan,
            nodes: [
                BASWorkflowNode(id: "capture", title: "Capture", actionClass: .memoryWrite),
                BASWorkflowNode(id: "respond", title: "Respond", actionClass: .outputRelease)
            ]
        )

        #expect(workflow.status == .running)
        #expect(workflow.currentNodeID == "capture")
        #expect(workflow.nodes.count == 2)

        workflow.pause(at: "approval")
        #expect(workflow.status == .paused)
        #expect(workflow.currentNodeID == "approval")

        workflow.resume(at: "respond")
        #expect(workflow.status == .running)
        #expect(workflow.currentNodeID == "respond")

        workflow.complete()
        #expect(workflow.status == .completed)
        #expect(workflow.currentNodeID == "respond")
    }

    @Test("context compactor preserves kernel and active state before retrieval overflow")
    func contextCompactorPreservesKernelAndActiveState() {
        let plan = BASContextCompactor.compact(
            BASContextCompactionRequest(
                targetCharacters: 210,
                maximumRetrievalBlocks: 1,
                blocks: [
                    BASContextBlock(
                        id: "kernel.identity",
                        layer: .kernel,
                        title: "Identity",
                        content: "Local decision support only.",
                        retention: .required,
                        priority: 100
                    ),
                    BASContextBlock(
                        id: "active.intent",
                        layer: .active,
                        title: "Intent",
                        content: "Decide whether to send the message tonight.",
                        retention: .required,
                        priority: 90
                    ),
                    BASContextBlock(
                        id: "summary.goal",
                        layer: .summary,
                        title: "Goal",
                        content: "Protect sleep and avoid regret.",
                        retention: .preferred,
                        priority: 70
                    ),
                    BASContextBlock(
                        id: "retrieval.history-a",
                        layer: .retrieval,
                        title: "History",
                        content: "Last month a similar late-night reply led to regret.",
                        retention: .onDemand,
                        priority: 60
                    ),
                    BASContextBlock(
                        id: "retrieval.history-b",
                        layer: .retrieval,
                        title: "History",
                        content: "Another night you waited until morning and felt relief.",
                        retention: .onDemand,
                        priority: 50
                    )
                ]
            )
        )

        #expect(plan.retainedBlocks.contains(where: { $0.id == "kernel.identity" }))
        #expect(plan.retainedBlocks.contains(where: { $0.id == "active.intent" }))
        #expect(plan.retainedSummaryCount >= 1)
        #expect(plan.retainedRetrievalCount == 1)
        #expect(plan.droppedBlocks.contains(where: { $0.id == "retrieval.history-b" }))
        #expect(plan.usedCharacters >= plan.retainedBlocks.map(\.estimatedCharacters).reduce(0, +))
    }

    private func brainState(snapshot: String) -> BASCurrentBrainState {
        BASCurrentBrainState(
            mode: "quick",
            dominantGoals: ["stay calm"],
            activeConstraints: ["pause first"],
            reactionWeights: BASReactionWeights(warmth: 0.6, directness: 0.5, brevity: 0.7, actionBias: 0.4),
            activeTemplateIDs: [],
            recentFailurePatternIDs: [],
            retrievalTags: ["night"],
            verificationSnapshot: snapshot
        )
    }
}
