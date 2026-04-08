import Foundation

struct ReflectionContext: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let eventID: UUID
    let scenario: ScenarioType
    let finalAction: CheckAction
}

struct PendingReflectionState: Codable, Equatable, Sendable {
    var context: ReflectionContext?
    var shouldPromptOnNextActive: Bool
}
