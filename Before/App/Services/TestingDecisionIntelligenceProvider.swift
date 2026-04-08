import Foundation

struct TestingDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    let profile: DecisionTestingStubProfile

    var kind: DecisionModelProviderKind { .testingStub }
    var availabilityStatus: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .testingStub,
            isAvailable: true,
            title: "Stub ready",
            detail: profile.detail
        )
    }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        switch profile {
        case .smoke:
            let currentDetail = fallbackClause(from: input.note, fallback: "Testing stub is active.")
            return QuickCheckResult(
                currentPerspective: DecisionIntelligencePromptContract.sanitized(
                    "Stub current: \(input.motivation.title). \(currentDetail)",
                    fallback: base.currentPerspective,
                    limit: DecisionIntelligencePromptContract.Limit.quickCurrentPerspective
                ),
                afterPerspective: DecisionIntelligencePromptContract.sanitized(
                    "Stub after: \(input.expectedOutcome.title). The model path can now be verified without a live runtime.",
                    fallback: base.afterPerspective,
                    limit: DecisionIntelligencePromptContract.Limit.quickAfterPerspective
                ),
                verdict: base.verdict,
                primaryAction: base.primaryAction,
                secondaryActions: base.secondaryActions
            )
        }
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        switch profile {
        case .smoke:
            let summaryDetail = fallbackClause(from: input.prompt, fallback: "Trade-offs are being tested.")
            let focusDetail = firstNonEmpty(
                input.constraint,
                input.concern,
                input.desire,
                input.longTerm,
                fallback: "The testing provider picked a deterministic focus."
            )
            return BalanceBoardResult(
                headline: DecisionIntelligencePromptContract.sanitized(
                    "Stub balance board",
                    fallback: base.headline,
                    limit: DecisionIntelligencePromptContract.Limit.balanceHeadline
                ),
                summary: DecisionIntelligencePromptContract.sanitized(
                    "Stub summary: \(summaryDetail)",
                    fallback: base.summary,
                    limit: DecisionIntelligencePromptContract.Limit.balanceSummary
                ),
                focusTitle: "Stub priority",
                focusDescription: DecisionIntelligencePromptContract.sanitized(
                    "Stub focus: \(focusDetail)",
                    fallback: base.focusDescription,
                    limit: DecisionIntelligencePromptContract.Limit.balanceFocusDescription
                ),
                nextAction: DecisionIntelligencePromptContract.sanitized(
                    "Use this board to confirm the AI refinement path updates cleanly.",
                    fallback: base.nextAction,
                    limit: DecisionIntelligencePromptContract.Limit.balanceNextAction
                )
            )
        }
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        switch profile {
        case .smoke:
            let tensionDetail = firstNonEmpty(
                input.selfLens,
                input.relationship,
                input.emotion,
                fallback: "The testing provider is surfacing a predictable mirror output."
            )
            return MirrorResult(
                headline: DecisionIntelligencePromptContract.sanitized(
                    "Stub mirror",
                    fallback: base.headline,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorHeadline
                ),
                coreTension: DecisionIntelligencePromptContract.sanitized(
                    "Stub tension: \(tensionDetail)",
                    fallback: base.coreTension,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorCoreTension
                ),
                nextActionTitle: "Stub next move",
                nextAction: DecisionIntelligencePromptContract.sanitized(
                    "Verify that the mirror can refine without a live on-device model.",
                    fallback: base.nextAction,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorNextAction
                )
            )
        }
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        switch profile {
        case .smoke:
            return candidates.last
        }
    }

    private func fallbackClause(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func firstNonEmpty(_ values: String..., fallback: String) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? fallback
    }
}
