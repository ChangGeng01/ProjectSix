import Foundation

enum BeforePolicy {
    enum QuickCheck {
        static let defaultBufferDuration: QuickBufferDuration = .ninetySeconds
        static let recentHistoryLimit = 30
    }

    enum Widget {
        static let timelineRefreshInterval: TimeInterval = 60 * 30
    }

    enum Reflection {
        static let reminderMaxCharacters = 80
        static let maxStoredReminders = 10
    }

    enum Notifications {
        static let tomorrowReminderHour = 9
        static let tomorrowReminderMinute = 0

        static func normalizedReminderDate(
            after baseDate: Date,
            calendar: Calendar = .autoupdatingCurrent
        ) -> Date {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = tomorrowReminderHour
            components.minute = tomorrowReminderMinute
            return calendar.date(from: components) ?? tomorrow
        }
    }

    enum LaunchRequests {
        static let schemaVersion = 1
        static let maxQueuedRequests = 5
        static let expirationInterval: TimeInterval = 60 * 10
    }
}
