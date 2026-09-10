import Foundation
import Testing
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASExecutionGovernance")
struct BASExecutionGovernanceTests {
    @Test("primary admission skips when deterministic template already covers the turn")
    func primaryAdmissionSkipsTemplateCoveredTurn() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .primary,
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

    @Test("comparative admission skips when open text material is too thin")
    func comparativeAdmissionSkipsThinOpenText() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .comparative,
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

    @Test("selection admission distinguishes insufficient choice from real knowledge pressure")
    func selectionAdmissionRespectsSelectionNeed() {
        let insufficientChoice = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .selection,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 2),
                selectionCandidateCount: 1
            )
        )
        let controlNeed = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .selection,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 2),
                selectionCandidateCount: 3,
                selectionAssessment: BASSelectionAssessment(
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
                kind: .selection,
                budget: BASPromptBudgetSnapshot(targetCharacters: 500, prefixCharacters: 120, suffixCharacters: 120),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 3),
                selectionCandidateCount: 3,
                selectionAssessment: BASSelectionAssessment(
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
        #expect(insufficientChoice.skipReason == .insufficientChoiceSpread)
        #expect(insufficientChoice.selectionNeed == .control)
        #expect(!controlNeed.isAllowed)
        #expect(controlNeed.skipReason == .retrievalNotNeeded)
        #expect(controlNeed.selectionNeed == .control)
        #expect(knowledgeNeed.isAllowed)
        #expect(knowledgeNeed.selectionNeed == .knowledge)
    }

    @Test("severe selection pressure skips on-device pass")
    func severeSelectionPressureSkipsPrefillHeavyPass() {
        let decision = BASExecutionGovernance.admissionDecision(
            for: BASAdmissionRequest(
                kind: .selection,
                budget: BASPromptBudgetSnapshot(targetCharacters: 300, prefixCharacters: 220, suffixCharacters: 160),
                frontstageState: BASFrontstageSignalSummary(openTextSignalCount: 4),
                selectionCandidateCount: 3,
                selectionAssessment: BASSelectionAssessment(
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
                kind: .selection,
                outputPreview: "Selection: wait and use the best-fitting note.",
                kernelSnapshot: kernel,
                truthStateFallback: BASStructuredTruthState(
                    mode: BASAdaptiveTraceKind.selectionID,
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
