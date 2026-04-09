import Foundation
import SwiftData

enum InterventionNotificationPolicyBlockReason: String, Equatable, Sendable {
    case featureDisabled
    case lowRisk
    case expired
    case insufficientEvidence
    case quietHours
    case cooldownActive
    case dailyCapReached
    case recentDismissalSuppression
}

struct InterventionNotificationPolicyDecision: Equatable, Sendable {
    let isAllowed: Bool
    let reason: String
    let blockReason: InterventionNotificationPolicyBlockReason?

    static func allow(_ reason: String) -> InterventionNotificationPolicyDecision {
        InterventionNotificationPolicyDecision(isAllowed: true, reason: reason, blockReason: nil)
    }

    static func block(
        _ reason: InterventionNotificationPolicyBlockReason,
        detail: String
    ) -> InterventionNotificationPolicyDecision {
        InterventionNotificationPolicyDecision(isAllowed: false, reason: detail, blockReason: reason)
    }
}

enum InterventionNotificationPolicyEngine {
    static func decide(
        candidate: InterventionPredictionCandidate,
        preferences: BeforePreferences,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> InterventionNotificationPolicyDecision {
        guard preferences.predictiveInterventionsEnabled else {
            return .block(
                .featureDisabled,
                detail: "Predictive interventions are disabled in preferences."
            )
        }

        guard candidate.riskLevel != .low else {
            return .block(
                .lowRisk,
                detail: "Low-risk candidates stay in-app and do not escalate into notifications."
            )
        }

        guard candidate.expiresAt > now else {
            return .block(
                .expired,
                detail: "Expired intervention candidates cannot schedule new notifications."
            )
        }

        if candidate.evidenceSignalCount < minimumEvidenceSignalCount(for: candidate.riskLevel) {
            return .block(
                .insufficientEvidence,
                detail: "Notification delivery stayed local-only because the evidence signal count is still too thin."
            )
        }

        if isQuietHours(now: now, calendar: calendar), candidate.riskLevel != .high {
            return .block(
                .quietHours,
                detail: "Medium-risk nudges stay quiet during overnight hours."
            )
        }

        let recentTriggers = fetchRecentTriggers(in: context, now: now)
        if deliveredTriggerCount(forSameDayAs: now, triggers: recentTriggers, calendar: calendar) >= BeforePolicy.Notifications.predictiveInterventionDailyCap {
            return .block(
                .dailyCapReached,
                detail: "The predictive intervention daily cap has already been reached."
            )
        }

        if let mostRecentDismissed = recentTriggers
            .filter(\.wasDismissed)
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first,
           now.timeIntervalSince(mostRecentDismissed.createdAt) < BeforePolicy.Notifications.predictiveInterventionDismissalSuppressionInterval {
            return .block(
                .recentDismissalSuppression,
                detail: "A recent dismissal is suppressing another predictive notification for now."
            )
        }

        if let mostRecentDelivered = recentTriggers
            .filter(\.wasDelivered)
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first,
           now.timeIntervalSince(mostRecentDelivered.createdAt) < BeforePolicy.Notifications.predictiveInterventionCooldownInterval {
            return .block(
                .cooldownActive,
                detail: "A predictive intervention notification was delivered too recently to send another one now."
            )
        }

        return .allow(
            "Notification delivery is allowed because evidence is strong enough and no cooldown or quiet-hours rule blocked it."
        )
    }

    private static func minimumEvidenceSignalCount(
        for riskLevel: InterventionRiskLevel
    ) -> Int {
        switch riskLevel {
        case .low:
            99
        case .medium, .high:
            2
        }
    }

    private static func isQuietHours(
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        return hour >= BeforePolicy.Notifications.predictiveQuietHoursStartHour ||
            hour < BeforePolicy.Notifications.predictiveQuietHoursEndHour
    }

    private static func fetchRecentTriggers(
        in context: ModelContext,
        now: Date
    ) -> [InterventionTrigger] {
        let lookback = max(
            BeforePolicy.Notifications.predictiveInterventionCooldownInterval,
            BeforePolicy.Notifications.predictiveInterventionDismissalSuppressionInterval
        )
        let cutoff = now.addingTimeInterval(-lookback)
        let descriptor = FetchDescriptor<InterventionTrigger>(
            predicate: #Predicate<InterventionTrigger> { trigger in
                trigger.createdAt >= cutoff
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func deliveredTriggerCount(
        forSameDayAs now: Date,
        triggers: [InterventionTrigger],
        calendar: Calendar
    ) -> Int {
        triggers.filter { trigger in
            trigger.wasDelivered && calendar.isDate(trigger.createdAt, inSameDayAs: now)
        }.count
    }
}
