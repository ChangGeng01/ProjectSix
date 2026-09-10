import Foundation

protocol LocalModelAdapting: Sendable {
    func route(prompt: String, scenario: ScenarioType?, fallback: RoutedDecision) -> RoutedDecision
    func enhanceQuickResult(_ result: QuickCheckResult, input: QuickCheckInput) -> QuickCheckResult
    func enhanceBalanceResult(_ result: BalanceBoardResult, input: BalanceBoardInput) -> BalanceBoardResult
    func enhanceMirrorResult(_ result: MirrorResult, input: MirrorInput) -> MirrorResult
    func pickReminder(
        from orderedCandidates: [String],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> String?
}
