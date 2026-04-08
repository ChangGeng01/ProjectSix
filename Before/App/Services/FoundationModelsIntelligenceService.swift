import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsIntelligenceService {
    static var availabilityStatus: DecisionModelProviderStatus {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if !model.supportsLocale(Locale.current) {
                return DecisionModelProviderStatus(
                    kind: .foundationModels,
                    isAvailable: false,
                    title: "Unavailable",
                    detail: "The current locale is not supported by the system language model."
                )
            }

            switch model.availability {
            case .available:
                return DecisionModelProviderStatus(
                    kind: .foundationModels,
                    isAvailable: true,
                    title: "Available",
                    detail: "Apple on-device generation is ready. Before can refine language locally without sending your decisions away."
                )
            case .unavailable(let reason):
                return DecisionModelProviderStatus(
                    kind: .foundationModels,
                    isAvailable: false,
                    title: "Unavailable",
                    detail: detail(for: reason)
                )
            }
        }
#endif

        return DecisionModelProviderStatus(
            kind: .foundationModels,
            isAvailable: false,
            title: "Unavailable",
            detail: "Requires iOS 26 or newer with Apple Intelligence support."
        )
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) async -> QuickCheckResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: envelope.instructions
            )

            let response = try await session.respond(
                to: envelope.payload,
                generating: QuickPerspectiveRefinement.self
            )

            return QuickCheckResult(
                currentPerspective: DecisionIntelligencePromptContract.sanitized(
                    response.content.currentPerspective,
                    fallback: base.currentPerspective,
                    limit: DecisionIntelligencePromptContract.Limit.quickCurrentPerspective
                ),
                afterPerspective: DecisionIntelligencePromptContract.sanitized(
                    response.content.afterPerspective,
                    fallback: base.afterPerspective,
                    limit: DecisionIntelligencePromptContract.Limit.quickAfterPerspective
                ),
                verdict: base.verdict,
                primaryAction: base.primaryAction,
                secondaryActions: base.secondaryActions
            )
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) async -> BalanceBoardResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }
        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: envelope.instructions
            )

            let response = try await session.respond(
                to: envelope.payload,
                generating: BalanceRefinement.self
            )

            return BalanceBoardResult(
                headline: DecisionIntelligencePromptContract.sanitized(
                    response.content.headline,
                    fallback: base.headline,
                    limit: DecisionIntelligencePromptContract.Limit.balanceHeadline
                ),
                summary: DecisionIntelligencePromptContract.sanitized(
                    response.content.summary,
                    fallback: base.summary,
                    limit: DecisionIntelligencePromptContract.Limit.balanceSummary
                ),
                focusTitle: base.focusTitle,
                focusDescription: DecisionIntelligencePromptContract.sanitized(
                    response.content.focusDescription,
                    fallback: base.focusDescription,
                    limit: DecisionIntelligencePromptContract.Limit.balanceFocusDescription
                ),
                nextAction: DecisionIntelligencePromptContract.sanitized(
                    response.content.nextAction,
                    fallback: base.nextAction,
                    limit: DecisionIntelligencePromptContract.Limit.balanceNextAction
                )
            )
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) async -> MirrorResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }
        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: envelope.instructions
            )

            let response = try await session.respond(
                to: envelope.payload,
                generating: MirrorRefinement.self
            )

            return MirrorResult(
                headline: DecisionIntelligencePromptContract.sanitized(
                    response.content.headline,
                    fallback: base.headline,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorHeadline
                ),
                coreTension: DecisionIntelligencePromptContract.sanitized(
                    response.content.coreTension,
                    fallback: base.coreTension,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorCoreTension
                ),
                nextActionTitle: base.nextActionTitle,
                nextAction: DecisionIntelligencePromptContract.sanitized(
                    response.content.nextAction,
                    fallback: base.nextAction,
                    limit: DecisionIntelligencePromptContract.Limit.mirrorNextAction
                )
            )
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

    static func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }
        let selection = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
        let clippedCandidates = selection.candidates
        guard clippedCandidates.count > 1 else { return clippedCandidates.first }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: selection.prompt.instructions
            )

            let response = try await session.respond(
                to: selection.prompt.payload,
                generating: ReminderSelectionRefinement.self
            )

            guard clippedCandidates.indices.contains(response.content.selectedIndex) else { return nil }
            return clippedCandidates[response.content.selectedIndex]
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func detail(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is available on this device, but it is currently turned off."
        case .modelNotReady:
            "The system language model is still preparing. Try again later."
        @unknown default:
            "The system language model is not ready on this device."
        }
    }
#endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Short rewritten perspectives for a quick decision.")
private struct QuickPerspectiveRefinement {
    let currentPerspective: String
    let afterPerspective: String
}

@available(iOS 26.0, *)
@Generable(description: "Tighter balance board copy that preserves the same focus.")
private struct BalanceRefinement {
    let headline: String
    let summary: String
    let focusDescription: String
    let nextAction: String
}

@available(iOS 26.0, *)
@Generable(description: "Tighter mirror copy that keeps the same reflective direction.")
private struct MirrorRefinement {
    let headline: String
    let coreTension: String
    let nextAction: String
}

@available(iOS 26.0, *)
@Generable(description: "Select the zero-based index of the best reminder candidate.")
private struct ReminderSelectionRefinement {
    let selectedIndex: Int
}
#endif
