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
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You refine copy for a local decision app.
                Rewrite only the two perspective lines.
                Keep them short, calm, and non-shaming.
                Do not change the verdict, actions, or overall direction.
                Never mention AI, therapy, or morality.
                """
            )

            let response = try await session.respond(
                to: DecisionIntelligencePromptContract.quickRefinementPrompt(base: base, input: input),
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
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You refine copy for a balance-board style decision tool.
                Keep the board concise and useful.
                Do not invent new facts.
                Do not turn the result into a verdict.
                Preserve the same focus and next-step intent.
                """
            )

            let response = try await session.respond(
                to: DecisionIntelligencePromptContract.balanceRefinementPrompt(base: base, input: input),
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
        input: MirrorInput
    ) async -> MirrorResult? {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availabilityStatus.isAvailable else { return nil }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You refine copy for a structured mirror inside a local decision app.
                Keep the tone honest, restrained, and non-therapeutic.
                Do not hand out life verdicts.
                Clarify the tension and the next reflective move only.
                """
            )

            let response = try await session.respond(
                to: DecisionIntelligencePromptContract.mirrorRefinementPrompt(base: base, input: input),
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
        let clippedCandidates = Array(candidates.prefix(DecisionIntelligencePromptContract.Limit.reminderCandidates))
        guard clippedCandidates.count > 1 else { return clippedCandidates.first }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You pick the single best self-reminder for a local decision app.
                Choose only from the provided candidates.
                Do not rewrite or invent text.
                Prefer the reminder that most directly matches the user's current state.
                """
            )

            let response = try await session.respond(
                to: DecisionIntelligencePromptContract.reminderSelectionPrompt(
                    candidates: clippedCandidates,
                    scenario: scenario,
                    prompt: prompt,
                    mode: mode
                ),
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
