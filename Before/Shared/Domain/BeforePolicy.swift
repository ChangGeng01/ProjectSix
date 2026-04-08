import Foundation
import CoreGraphics

enum BeforePolicy {
    enum QuickCheck {
        static let defaultBufferDuration: QuickBufferDuration = .ninetySeconds
        static let recentHistoryLimit = 30
    }

    enum Widget {
        static let timelineRefreshInterval: TimeInterval = 60 * 30
    }

    enum LetGo {
        static let motionUpdateInterval = 1.0 / 60.0
        static let horizontalAccelerationThreshold = 1.08
        static let directionalDominanceRatio = 1.15
        static let triggerCooldownInterval: TimeInterval = 0.9
        static let longPressDuration: TimeInterval = 0.55
        static let pressFeedbackScale: CGFloat = 0.985
        static let pressFeedbackAnimationDuration: TimeInterval = 0.12
        static let releaseAnimationDuration = 0.24
        static let completionTransitionDuration = 0.18
        static let releaseTravelDistance: CGFloat = 520
        static let releaseRotationDegrees = 8.0
    }

    enum Reflection {
        static let reminderMaxCharacters = 80
        static let maxStoredReminders = 10
    }

    enum Settings {
        static let developerCenterUnlockTapCount = 7
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
