import Foundation
import SwiftData

@Model
final class SelfReminder {
    @Attribute(.unique) var id: UUID
    var content: String
    var scenarioRaw: String
    var sourceRaw: String
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int

    init(
        id: UUID = UUID(),
        content: String,
        scenario: ScenarioType,
        source: ReminderSourceType,
        createdAt: Date = .now,
        lastUsedAt: Date = .now,
        useCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.scenarioRaw = scenario.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }
}

extension SelfReminder {
    var scenario: ScenarioType { ScenarioType(rawValue: scenarioRaw) ?? .other }
    var source: ReminderSourceType { ReminderSourceType(rawValue: sourceRaw) ?? .template }
}
