import Foundation
import Testing
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASExecutionGovernance")
struct BASExecutionGovernanceTests {
    @Test("quick admission skips when deterministic template already covers the turn")
    func quickAdmissionSkipsTemplateCoveredTurn() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .quick,
                budget: BASPromptBudgetSnapshot(targetCharacters: 600, prefixCharacters: 180, suffixCharacters: 180),
                frontstageState: BASFrontstageSignalSummary(
                    openTextSignalCount: 0,
                    evidenceHeadlineCount: 2,
                    anchorHeadlineCount: 0,
                    suppressionHintCount: 0
                )
            )
        )

        #expect(!decision.isAllowed)
        #expect(decision.skipReason == .templateAlreadySufficient)
        #expect(decision.pressure == .elevated)
    }

    @Test("balance admission skips when open text material is too thin")
    func balanceAdmissionSkipsThinOpenText() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .balance,
                budget: BASPromptBudgetSnapshot(targetCharacters: 900, prefixCharacters: 240, suffixCharacters: 300),
                frontstageState: BASFrontstageSignalSummary(
                    openTextSignalCount: 2,
                    evidenceHeadlineCount: 3,
                    anchorHeadlineCount: 0,
                    suppressionHintCount: 0
                )
            )
        )

        #expect(!decision.isAllowed)
        #expect(decision.skipReason == .insufficientSourceMaterial)
    }

    @Test("reminder admission distinguishes insufficient choice from real knowledge pressure")
    func reminderAdmissionRespectsReminderSelectionNeed() {
        let insufficientChoice = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .reminder,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 2),
                reminderCandidateCount: 1
            )
        )
        let controlNeed = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .reminder,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 2),
                reminderCandidateCount: 3,
                reminderSelectionAssessment: BASReminderSelectionAssessment(
                    need: .control,
                    reason: "Leader is already clear enough.",
                    promptTokenCount: 4,
                    topCandidateScore: 4,
                    secondCandidateScore: 1,
                    distinctCandidateCount: 3
                )
            )
        )
        let knowledgeNeed = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .reminder,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 3),
                reminderCandidateCount: 3,
                reminderSelectionAssessment: BASReminderSelectionAssessment(
                    need: .knowledge,
                    reason: "There is a real conflict between top candidates.",
                    promptTokenCount: 6,
                    topCandidateScore: 3,
                    secondCandidateScore: 2,
                    distinctCandidateCount: 3
                )
            )
        )

        #expect(!insufficientChoice.isAllowed)
        #expect(insufficientChoice.skipReason == .insufficientReminderChoice)
        #expect(insufficientChoice.reminderSelectionNeed == .control)
        #expect(!controlNeed.isAllowed)
        #expect(controlNeed.skipReason == .retrievalNotNeeded)
        #expect(controlNeed.reminderSelectionNeed == .control)
        #expect(knowledgeNeed.isAllowed)
        #expect(knowledgeNeed.reminderSelectionNeed == .knowledge)
    }

    @Test("severe reminder pressure skips on-device pass")
    func severeReminderPressureSkipsPrefillHeavyPass() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .reminder,
                budget: BASPromptBudgetSnapshot(targetCharacters: 300, prefixCharacters: 220, suffixCharacters: 160),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 4),
                reminderCandidateCount: 3,
                reminderSelectionAssessment: BASReminderSelectionAssessment(
                    need: .knowledge,
                    reason: "Knowledge need is real.",
                    promptTokenCount: 8,
                    topCandidateScore: 2,
                    secondCandidateScore: 2,
                    distinctCandidateCount: 3
                )
            )
        )

        #expect(!decision.isAllowed)
        #expect(decision.pressure == .severe)
        #expect(decision.skipReason == .prefillPressureTooHigh)
    }

    @Test("release governance fills fallback truth state and default action classes")
    func releaseGovernanceUsesFallbackTruthAndKindDefaults() {
        let kernel = BASCognitionKernel.compile(
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
                compilationPolicy: BASContextCompilationPolicy(targetCharacters: 200)
            )
        )

        let decision = BASExecutionGovernance.releaseDecision(
            for: BASReleaseEvaluationRequest(
                kind: .reminder,
                outputPreview: "Reminder: wait and use the best-fitting note.",
                kernelSnapshot: kernel,
                truthStateFallback: BASStructuredTruthState(
                    mode: "reminder",
                    currentGoal: "protect sleep",
                    allowedActions: ["load_governed_memory"],
                    forbiddenActions: ["send_now"],
                    personaRules: ["brief"],
                    sessionFacts: ["current_goal": "protect sleep"]
                ),
                referencedFacts: ["current_goal": "protect sleep"]
            )
        )

        #expect(decision.kind == .allow)
        #expect(decision.consistencyCheck?.isConsistent == true)
    }
}
