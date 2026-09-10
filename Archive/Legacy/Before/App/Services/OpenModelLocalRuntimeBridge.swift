import Foundation

enum OpenModelLocalRuntimeMode: String, Equatable, Sendable {
    case heuristicPreview
    case dedicatedRuntime
}

struct OpenModelLocalRuntimeStatus: Equatable, Sendable {
    let canServeRequests: Bool
    let mode: OpenModelLocalRuntimeMode
    let title: String
    let detail: String
}

protocol OpenModelLocalRuntimeBridging: Sendable {
    func status(for asset: OpenModelAsset) -> OpenModelLocalRuntimeStatus

    func refineQuickResult(
        asset: OpenModelAsset,
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult?

    func refineBalanceResult(
        asset: OpenModelAsset,
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult?

    func refineMirrorResult(
        asset: OpenModelAsset,
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult?

    func pickReminder(
        asset: OpenModelAsset,
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate?
}

enum OpenModelLocalRuntimeBridge {
    static let shared: any OpenModelLocalRuntimeBridging = DynamicOpenModelLocalRuntimeBridge()
}

struct DynamicOpenModelLocalRuntimeBridge: OpenModelLocalRuntimeBridging {
    private let localAdapter: any LocalModelAdapting

    init(localAdapter: any LocalModelAdapting = TemplateLocalModelAdapter()) {
        self.localAdapter = localAdapter
    }

    func status(for asset: OpenModelAsset) -> OpenModelLocalRuntimeStatus {
        OpenModelLocalRuntimeStatus(
            canServeRequests: true,
            mode: .heuristicPreview,
            title: "Heuristic preview",
            detail: "\(asset.fileName) is currently routed through the local heuristic adapter. Before can serve reviewable on-device refinements now and swap in a dedicated runtime later without changing the host pipeline."
        )
    }

    func refineQuickResult(
        asset: OpenModelAsset,
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        localAdapter.enhanceQuickResult(base, input: input)
    }

    func refineBalanceResult(
        asset: OpenModelAsset,
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        localAdapter.enhanceBalanceResult(base, input: input)
    }

    func refineMirrorResult(
        asset: OpenModelAsset,
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy?,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        localAdapter.enhanceMirrorResult(base, input: input)
    }

    func pickReminder(
        asset: OpenModelAsset,
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy?
    ) async -> ReminderSelectionCandidate? {
        guard let selectedContent = localAdapter.pickReminder(
            from: candidates.map(\.content),
            scenario: scenario,
            prompt: prompt,
            mode: mode
        ) else {
            return nil
        }

        return candidates.first(where: { $0.content == selectedContent }) ?? candidates.first
    }
}
