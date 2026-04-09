import Foundation

struct QuickCheckInput: Codable, Sendable {
    var scenario: ScenarioType
    var motivation: MotivationChoice
    var expectedOutcome: OutcomeChoice
    var controlLevel: ControlChoice
    var note: String
}

struct QuickCheckResult: Codable, Equatable, Sendable {
    var currentPerspective: String
    var afterPerspective: String
    var verdict: CheckVerdict
    var primaryAction: CheckAction
    var secondaryActions: [CheckAction]
}
