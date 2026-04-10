import Foundation
import SwiftData
import BASPolicy

enum InterventionNotificationPolicyBlockReason: String, Equatable, Sendable {
    case featureDisabled
    case lowRisk
    case expired
    case insufficientEvidence
    case consistencyRejected
    case quietHours
    case cooldownActive
    case dailyCapReached
    case recentDismissalSuppression
}

struct InterventionNotificationPolicyDecision: Equatable, Sendable {
    let isAllowed: Bool
    let reason: String
    let blockReason: InterventionNotificationPolicyBlockReason?
    let consistencyCheck: BASConsistencyCheckResult?

    static func allow(
        _ reason: String,
        consistencyCheck: BASConsistencyCheckResult? = nil
    ) -> InterventionNotificationPolicyDecision {
        InterventionNotificationPolicyDecision(
            isAllowed: true,
            reason: reason,
            blockReason: nil,
            consistencyCheck: consistencyCheck
        )
    }

    static func block(
        _ reason: InterventionNotificationPolicyBlockReason,
        detail: String,
        consistencyCheck: BASConsistencyCheckResult? = nil
    ) -> InterventionNotificationPolicyDecision {
        InterventionNotificationPolicyDecision(
            isAllowed: false,
            reason: detail,
            blockReason: reason,
            consistencyCheck: consistencyCheck
        )
    }
}

enum InterventionNotificationPolicyEngine {
    static func decide(
        candidate: InterventionPredictionCandidate,
        preferences: BeforePreferences,
        currentBrainState: CurrentBrainState? = nil,
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

        let consistencyCheck = currentBrainState.map {
            notificationConsistencyCheck(candidate: candidate, currentBrainState: $0)
        }
        if let consistencyCheck, !consistencyCheck.isConsistent {
            return .block(
                .consistencyRejected,
                detail: rejectedConsistencyDetail(result: consistencyCheck),
                consistencyCheck: consistencyCheck
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
            "Notification delivery is allowed because evidence is strong enough and no cooldown or quiet-hours rule blocked it.",
            consistencyCheck: consistencyCheck
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

    private static func notificationConsistencyCheck(
        candidate: InterventionPredictionCandidate,
        currentBrainState: CurrentBrainState
    ) -> BASConsistencyCheckResult {
        var referencedFacts = [
            "boundary_mode": currentBrainState.boundaryPolicy.mode.rawValue
        ]
        if let dominantGoal = currentBrainState.dominantGoal {
            referencedFacts["current_goal"] = dominantGoal
        }

        let personaRules = Array(
            orderedUnique(
                [
                    "Keep notification copy brief.",
                    "Keep notification copy non-judgmental.",
                    currentBrainState.identityProfile.relationshipBoundary
                ] + currentBrainState.brainState.sessionBiases
            )
            .prefix(4)
        )

        return BASConsistencyHarness.evaluate(
            BASConsistencyCheckInput(
                truthState: BASStructuredTruthState(
                    mode: "predictive_intervention_notification",
                    currentGoal: currentBrainState.dominantGoal,
                    allowedActions: ["send_predictive_notification"],
                    forbiddenActions: currentBrainState.boundaryPolicy.blockedActionClasses,
                    personaRules: personaRules,
                    sessionFacts: [
                        "boundary_mode": currentBrainState.boundaryPolicy.mode.rawValue
                    ]
                ),
                responseMode: "predictive_intervention_notification",
                responseText: [candidate.title, candidate.detail, candidate.reason]
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                proposedActions: ["send_predictive_notification"],
                referencedFacts: referencedFacts
            )
        )
    }

    private static func rejectedConsistencyDetail(
        result: BASConsistencyCheckResult
    ) -> String {
        let violations = result.violations
            .prefix(2)
            .map(\.message)
            .joined(separator: " ")
        return "Notification delivery stayed local-only because the consistency harness rejected the copy. \(violations)"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}
