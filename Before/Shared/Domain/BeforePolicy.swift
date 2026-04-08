import Foundation

enum BeforePolicy {
    enum QuickCheck {
        static let waitDurationSeconds = 90
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
    }

    enum LaunchRequests {
        static let schemaVersion = 1
        static let maxQueuedRequests = 5
        static let expirationInterval: TimeInterval = 60 * 10
    }
}
