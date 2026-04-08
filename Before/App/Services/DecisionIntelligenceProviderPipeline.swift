import Foundation

protocol DecisionIntelligenceProviding: Sendable {
    var kind: DecisionModelProviderKind { get }
    var availabilityStatus: DecisionModelProviderStatus { get }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult?
}

struct GemmaDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .gemmaE4B }
    var availabilityStatus: DecisionModelProviderStatus { GemmaE4BIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await GemmaE4BIntelligenceService.refineQuickResult(base: base, input: input)
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await GemmaE4BIntelligenceService.refineBalanceResult(base: base, input: input)
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await GemmaE4BIntelligenceService.refineMirrorResult(base: base, input: input)
    }
}

struct FoundationDecisionIntelligenceProvider: DecisionIntelligenceProviding {
    var kind: DecisionModelProviderKind { .foundationModels }
    var availabilityStatus: DecisionModelProviderStatus { FoundationModelsIntelligenceService.availabilityStatus }

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        await FoundationModelsIntelligenceService.refineQuickResult(base: base, input: input)
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        await FoundationModelsIntelligenceService.refineBalanceResult(base: base, input: input)
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        await FoundationModelsIntelligenceService.refineMirrorResult(base: base, input: input)
    }
}

enum DecisionIntelligenceProviderPipeline {
    private static let providersByKind: [DecisionModelProviderKind: any DecisionIntelligenceProviding] = [
        .gemmaE4B: GemmaDecisionIntelligenceProvider(),
        .foundationModels: FoundationDecisionIntelligenceProvider()
    ]

    static func orderedKinds(
        for preference: DecisionModelProviderPreference
    ) -> [DecisionModelProviderKind] {
        switch preference {
        case .gemmaE4B:
            [.gemmaE4B, .foundationModels]
        case .foundationModels:
            [.foundationModels, .gemmaE4B]
        }
    }

    static func runtimeStatus(
        preferences: BeforePreferences,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = defaultStatusesByKind()
    ) -> DecisionModelRuntimeStatus {
        let preferred = preferredKind(for: preferences.preferredIntelligenceProvider)

        guard preferences.onDeviceIntelligenceMode.isEnabled else {
            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .template,
                fallback: nil,
                detail: "On-device intelligence is off, so Before is using the deterministic decision system only."
            )
        }

        let orderedStatuses = orderedKinds(for: preferences.preferredIntelligenceProvider)
            .compactMap { statusesByKind[$0] }

        if let active = orderedStatuses.first(where: \.isAvailable) {
            let fallback = active.kind == preferred ? nil : active.kind
            let detail: String
            if active.kind == preferred {
                detail = "\(active.title). \(active.detail)"
            } else {
                detail = "\(preferred.title) is not available. Before is using \(active.title.lowercased()) instead."
            }

            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: active.kind,
                fallback: fallback,
                detail: detail
            )
        }

        let fallbackSource = orderedStatuses.first(where: { !$0.isAvailable && $0.kind == preferred }) ?? orderedStatuses.first
        let detail = fallbackSource.map { "\(preferred.title) is not available. \($0.detail) Before is falling back to deterministic local copy." }
            ?? "No assistive provider is available. Before is falling back to deterministic local copy."

        return DecisionModelRuntimeStatus(
            preferred: preferred,
            active: .template,
            fallback: .template,
            detail: detail
        )
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        preference: DecisionModelProviderPreference
    ) async -> QuickCheckResult? {
        for provider in orderedProviders(for: preference) {
            if let refined = await provider.refineQuickResult(base: base, input: input) {
                return refined
            }
        }

        return nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        preference: DecisionModelProviderPreference
    ) async -> BalanceBoardResult? {
        for provider in orderedProviders(for: preference) {
            if let refined = await provider.refineBalanceResult(base: base, input: input) {
                return refined
            }
        }

        return nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        preference: DecisionModelProviderPreference
    ) async -> MirrorResult? {
        for provider in orderedProviders(for: preference) {
            if let refined = await provider.refineMirrorResult(base: base, input: input) {
                return refined
            }
        }

        return nil
    }

    static func defaultStatusesByKind() -> [DecisionModelProviderKind: DecisionModelProviderStatus] {
        providersByKind.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.availabilityStatus
        }
    }

    private static func preferredKind(for preference: DecisionModelProviderPreference) -> DecisionModelProviderKind {
        switch preference {
        case .gemmaE4B:
            .gemmaE4B
        case .foundationModels:
            .foundationModels
        }
    }

    private static func orderedProviders(
        for preference: DecisionModelProviderPreference
    ) -> [any DecisionIntelligenceProviding] {
        orderedKinds(for: preference).compactMap { providersByKind[$0] }
    }
}
