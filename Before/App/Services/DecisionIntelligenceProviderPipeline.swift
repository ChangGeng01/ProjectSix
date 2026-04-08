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
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool = true
    ) -> [DecisionModelProviderKind] {
        if !allowFallbacks {
            return [preference.kind]
        }

        switch preference {
        case .gemmaE4B:
            return [.gemmaE4B, .foundationModels]
        case .foundationModels:
            return [.foundationModels, .gemmaE4B]
        case .template:
            return [.template]
        }
    }

    static func runtimeStatus(
        preferences: BeforePreferences,
        statusesByKind: [DecisionModelProviderKind: DecisionModelProviderStatus] = defaultStatusesByKind()
    ) -> DecisionModelRuntimeStatus {
        let preferred = preferences.preferredIntelligenceProvider.kind

        guard preferences.onDeviceIntelligenceMode.isEnabled else {
            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .template,
                fallback: nil,
                detail: "On-device intelligence is off, so Before is using the deterministic decision system only."
            )
        }

        if preferred == .template {
            return DecisionModelRuntimeStatus(
                preferred: .template,
                active: .template,
                fallback: nil,
                detail: "Deterministic local copy is pinned, so Before is not using a model provider for assistive refinement."
            )
        }

        let orderedStatuses = orderedKinds(
            for: preferences.preferredIntelligenceProvider,
            allowFallbacks: preferences.allowModelFallbacks
        )
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

        if !preferences.allowModelFallbacks {
            let detail = "\(preferred.title) is not available. Automatic model fallback is off, so Before is using deterministic local copy instead."

            return DecisionModelRuntimeStatus(
                preferred: preferred,
                active: .template,
                fallback: .template,
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
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool
    ) async -> QuickCheckResult? {
        guard preference != .template else { return nil }

        for provider in orderedProviders(for: preference, allowFallbacks: allowFallbacks) {
            if let refined = await provider.refineQuickResult(base: base, input: input) {
                return refined
            }
        }

        return nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool
    ) async -> BalanceBoardResult? {
        guard preference != .template else { return nil }

        for provider in orderedProviders(for: preference, allowFallbacks: allowFallbacks) {
            if let refined = await provider.refineBalanceResult(base: base, input: input) {
                return refined
            }
        }

        return nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool
    ) async -> MirrorResult? {
        guard preference != .template else { return nil }

        for provider in orderedProviders(for: preference, allowFallbacks: allowFallbacks) {
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

    private static func orderedProviders(
        for preference: DecisionModelProviderPreference,
        allowFallbacks: Bool
    ) -> [any DecisionIntelligenceProviding] {
        orderedKinds(for: preference, allowFallbacks: allowFallbacks).compactMap { providersByKind[$0] }
    }
}
