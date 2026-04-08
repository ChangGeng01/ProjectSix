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
                to: quickPrompt(base: base, input: input),
                generating: QuickPerspectiveRefinement.self
            )

            return QuickCheckResult(
                currentPerspective: sanitized(
                    response.content.currentPerspective,
                    fallback: base.currentPerspective,
                    limit: 140
                ),
                afterPerspective: sanitized(
                    response.content.afterPerspective,
                    fallback: base.afterPerspective,
                    limit: 160
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
                to: balancePrompt(base: base, input: input),
                generating: BalanceRefinement.self
            )

            return BalanceBoardResult(
                headline: sanitized(response.content.headline, fallback: base.headline, limit: 110),
                summary: sanitized(response.content.summary, fallback: base.summary, limit: 180),
                focusTitle: base.focusTitle,
                focusDescription: sanitized(
                    response.content.focusDescription,
                    fallback: base.focusDescription,
                    limit: 170
                ),
                nextAction: sanitized(
                    response.content.nextAction,
                    fallback: base.nextAction,
                    limit: 170
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
                to: mirrorPrompt(base: base, input: input),
                generating: MirrorRefinement.self
            )

            return MirrorResult(
                headline: sanitized(response.content.headline, fallback: base.headline, limit: 120),
                coreTension: sanitized(
                    response.content.coreTension,
                    fallback: base.coreTension,
                    limit: 220
                ),
                nextActionTitle: base.nextActionTitle,
                nextAction: sanitized(
                    response.content.nextAction,
                    fallback: base.nextAction,
                    limit: 180
                )
            )
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

    private static func sanitized(_ value: String, fallback: String, limit: Int) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !trimmed.isEmpty else { return fallback }
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func bullet(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(label): \(trimmed.isEmpty ? "Not provided." : trimmed)"
    }

    private static func quickPrompt(base: QuickCheckResult, input: QuickCheckInput) -> String {
        [
            "Scenario: \(input.scenario.title)",
            "Motivation: \(input.motivation.title)",
            "Expected outcome: \(input.expectedOutcome.title)",
            "Control level: \(input.controlLevel.title)",
            bullet("Optional note", input.note),
            bullet("Current perspective", base.currentPerspective),
            bullet("After perspective", base.afterPerspective),
            "Rewrite those two lines so they feel more precise and human, but keep the same meaning."
        ]
        .joined(separator: "\n")
    }

    private static func balancePrompt(base: BalanceBoardResult, input: BalanceBoardInput) -> String {
        [
            bullet("Prompt", input.prompt),
            bullet("Want", input.desire),
            bullet("Concern", input.concern),
            bullet("Reality", input.constraint),
            bullet("Long-term", input.longTerm),
            bullet("Current headline", base.headline),
            bullet("Current summary", base.summary),
            bullet("Focus title", base.focusTitle),
            bullet("Focus description", base.focusDescription),
            bullet("Next action", base.nextAction),
            "Tighten the wording without changing the underlying focus."
        ]
        .joined(separator: "\n")
    }

    private static func mirrorPrompt(base: MirrorResult, input: MirrorInput) -> String {
        [
            bullet("Prompt", input.prompt),
            bullet("Emotion", input.emotion),
            bullet("Relationship", input.relationship),
            bullet("Reality", input.reality),
            bullet("Long-term", input.longTerm),
            bullet("Self lens", input.selfLens),
            bullet("Current headline", base.headline),
            bullet("Core tension", base.coreTension),
            bullet("Next action title", base.nextActionTitle),
            bullet("Next action", base.nextAction),
            "Clarify the mirror without becoming dramatic or giving a yes-no answer."
        ]
        .joined(separator: "\n")
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
#endif
