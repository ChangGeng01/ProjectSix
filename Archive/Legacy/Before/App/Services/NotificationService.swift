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

struct BeforePredictiveInterventionNotificationPresentation: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let timeInterval: TimeInterval
}

enum BeforePredictiveInterventionNotificationPresentationSupport {
    static func presentation(
        for candidate: InterventionPredictionCandidate,
        now: Date = .now
    ) -> BeforePredictiveInterventionNotificationPresentation {
        let fallback = BeforeProductCompatibility.predictiveInterventionPresentation
        let fallbackTitle = candidate.riskLevel == .high
            ? fallback.highRiskTitle
            : fallback.mediumRiskTitle
        let fallbackDetail = candidate.riskLevel == .high
            ? fallback.highRiskDetail
            : fallback.mediumRiskDetail

        return BeforePredictiveInterventionNotificationPresentation(
            identifier: BeforeNotificationIdentifier.predictiveIntervention(for: candidate.id),
            title: cleaned(candidate.title) ?? fallbackTitle,
            body: cleaned(candidate.detail) ?? fallbackDetail,
            timeInterval: candidate.expiresAt > now ? 90 : 60
        )
    }

    private static func cleaned(_ text: String) -> String? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText.isEmpty ? nil : cleanedText
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var notificationsDisabledForTesting: Bool {
        DecisionTestingInterface.runtimeTestingContextDetected()
    }

    func requestAuthorizationIfNeeded() async {
        guard !notificationsDisabledForTesting else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleWaitFinishedNotification(
        sessionID: UUID,
        duration: QuickBufferDuration = BeforePolicy.QuickCheck.defaultBufferDuration
    ) async {
        guard !notificationsDisabledForTesting else { return }
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
        guard !notificationsDisabledForTesting else { return }
        let fireDate = Self.nextTomorrowReminderDate(after: baseDate)
        await scheduleTomorrowNotification(eventID: eventID, at: fireDate)
    }

    func scheduleTomorrowNotification(eventID: UUID, at fireDate: Date) async {
        guard !notificationsDisabledForTesting else { return }
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
        guard !notificationsDisabledForTesting else { return }
        await requestAuthorizationIfNeeded()

        let presentation = BeforePredictiveInterventionNotificationPresentationSupport.presentation(
            for: candidate
        )
        let content = UNMutableNotificationContent()
        content.title = presentation.title
        content.body = presentation.body
        content.sound = .default

        let identifier = presentation.identifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: presentation.timeInterval,
            repeats: false
        )
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
