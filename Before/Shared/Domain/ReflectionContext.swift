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
    var updatedAt: Date

    init(
        context: ReflectionContext?,
        shouldPromptOnNextActive: Bool,
        updatedAt: Date = .now
    ) {
        self.context = context
        self.shouldPromptOnNextActive = shouldPromptOnNextActive
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        context = try container.decodeIfPresent(ReflectionContext.self, forKey: .context)
        shouldPromptOnNextActive = try container.decodeIfPresent(Bool.self, forKey: .shouldPromptOnNextActive) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    func isExpired(relativeTo now: Date = .now) -> Bool {
        updatedAt.addingTimeInterval(BeforePolicy.RuntimeState.pendingReflectionRetentionInterval) <= now
    }
}
