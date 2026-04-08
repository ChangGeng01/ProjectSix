import Foundation

enum ReminderSelectionPolicy {
    static func bestReminder(in reminders: [SelfReminder], for scenario: ScenarioType) -> SelfReminder? {
        ranked(reminders: reminders.filter { $0.scenario == scenario }).first
    }

    static func remindersToTrim(from reminders: [SelfReminder]) -> [SelfReminder] {
        Array(ranked(reminders: reminders).dropFirst(BeforePolicy.Reflection.maxStoredReminders))
    }

    static func ranked(reminders: [SelfReminder]) -> [SelfReminder] {
        reminders.sorted(by: isHigherPriority)
    }

    static func sourcePriority(_ source: ReminderSourceType) -> Int {
        switch source {
        case .userWritten: 0
        case .compressed: 1
        case .template: 2
        }
    }

    private static func isHigherPriority(_ lhs: SelfReminder, _ rhs: SelfReminder) -> Bool {
        let lhsPriority = sourcePriority(lhs.source)
        let rhsPriority = sourcePriority(rhs.source)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.useCount != rhs.useCount {
            return lhs.useCount > rhs.useCount
        }

        if lhs.lastUsedAt != rhs.lastUsedAt {
            return lhs.lastUsedAt > rhs.lastUsedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
