import Foundation
import UserNotifications

enum BeforeNotificationIdentifier {
    static func waitFinished(for sessionID: UUID) -> String {
        "before.wait.finished.\(sessionID.uuidString.lowercased())"
    }

    static func tomorrowCheckin(for eventID: UUID) -> String {
        "before.tomorrow.checkin.\(eventID.uuidString.lowercased())"
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleWaitFinishedNotification(
        sessionID: UUID,
        duration: QuickBufferDuration = BeforePolicy.QuickCheck.defaultBufferDuration
    ) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = duration.notificationTitle
        content.body = "You have a little more space now. Decide from there."
        content.sound = .default

        let identifier = BeforeNotificationIdentifier.waitFinished(for: sessionID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(duration.seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelWaitFinishedNotification(sessionID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [BeforeNotificationIdentifier.waitFinished(for: sessionID)]
        )
    }

    func scheduleTomorrowNotification(eventID: UUID, from baseDate: Date = .now) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Check it in daylight"
        content.body = "What felt urgent yesterday may look different today."
        content.sound = .default

        let identifier = BeforeNotificationIdentifier.tomorrowCheckin(for: eventID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let fireDate = Self.nextTomorrowReminderDate(after: baseDate)
        let dateComponents = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelTomorrowNotification(eventID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [BeforeNotificationIdentifier.tomorrowCheckin(for: eventID)]
        )
    }

    nonisolated static func nextTomorrowReminderDate(
        after baseDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = BeforePolicy.Notifications.tomorrowReminderHour
        components.minute = BeforePolicy.Notifications.tomorrowReminderMinute
        return calendar.date(from: components) ?? tomorrow
    }
}
