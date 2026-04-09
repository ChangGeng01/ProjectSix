import Foundation
import UserNotifications

enum BeforeNotificationIdentifier {
    static func waitFinished(for sessionID: UUID) -> String {
        "before.wait.finished.\(sessionID.uuidString.lowercased())"
    }

    static func tomorrowCheckin(for eventID: UUID) -> String {
        "before.tomorrow.checkin.\(eventID.uuidString.lowercased())"
    }

    static func predictiveIntervention(for candidateID: UUID) -> String {
        "before.predictive.intervention.\(candidateID.uuidString.lowercased())"
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
        let fireDate = Self.nextTomorrowReminderDate(after: baseDate)
        await scheduleTomorrowNotification(eventID: eventID, at: fireDate)
    }

    func scheduleTomorrowNotification(eventID: UUID, at fireDate: Date) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Check it in daylight"
        content.body = "What felt urgent yesterday may look different today."
        content.sound = .default

        let identifier = BeforeNotificationIdentifier.tomorrowCheckin(for: eventID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

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

    func schedulePredictiveInterventionNotification(_ candidate: InterventionPredictionCandidate) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = candidate.riskLevel == .high
            ? "Slow this one down"
            : "Pause before you decide"
        content.body = candidate.riskLevel == .high
            ? "Your recent pattern suggests a slower reopen is safer right now."
            : "A small pause may help this land cleaner."
        content.sound = .default

        let identifier = BeforeNotificationIdentifier.predictiveIntervention(for: candidate.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval: TimeInterval = max(60, candidate.expiresAt.timeIntervalSinceNow > 0 ? 90 : 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelPredictiveInterventionNotification(candidateID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [BeforeNotificationIdentifier.predictiveIntervention(for: candidateID)]
        )
    }

    nonisolated static func nextTomorrowReminderDate(
        after baseDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        BeforePolicy.Notifications.normalizedReminderDate(after: baseDate, calendar: calendar)
    }
}
