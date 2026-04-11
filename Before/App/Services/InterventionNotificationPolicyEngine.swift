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
        let recentTriggers = fetchRecentTriggers(in: context, now: now)
        let decision = BASPredictiveNotificationPolicyEngine.decide(
            input: BASPredictiveNotificationPolicyInput(
                predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled,
                riskLevelID: candidate.riskLevel.rawValue,
                evidenceSignalCount: candidate.evidenceSignalCount,
                title: candidate.title,
                detail: candidate.detail,
                reason: candidate.reason,
                expiresAt: candidate.expiresAt,
                currentGoal: currentBrainState?.dominantGoal,
                boundaryModeID: currentBrainState?.boundaryPolicy.mode.rawValue,
                forbiddenActions: currentBrainState?.boundaryPolicy.blockedActionClasses ?? [],
                personaRules: currentBrainState.map(personaRules(from:)) ?? [],
                recentSignals: recentTriggers.map {
                    BASPredictiveNotificationHistorySignal(
                        createdAt: $0.createdAt,
                        wasDelivered: $0.wasDelivered,
                        wasDismissed: $0.wasDismissed
                    )
                },
                now: now,
                quietHoursStartHour: BeforePolicy.Notifications.predictiveQuietHoursStartHour,
                quietHoursEndHour: BeforePolicy.Notifications.predictiveQuietHoursEndHour,
                dailyCap: BeforePolicy.Notifications.predictiveInterventionDailyCap,
                cooldownInterval: BeforePolicy.Notifications.predictiveInterventionCooldownInterval,
                dismissalSuppressionInterval: BeforePolicy.Notifications.predictiveInterventionDismissalSuppressionInterval
            ),
            calendar: calendar
        )

        if decision.isAllowed {
            return .allow(
                decision.reason,
                consistencyCheck: decision.consistencyCheck
            )
        }

        return .block(
            decision.blockReason.map(mapBlockReason(_:)) ?? .consistencyRejected,
            detail: decision.reason,
            consistencyCheck: decision.consistencyCheck
        )
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


    private static func personaRules(from currentBrainState: CurrentBrainState) -> [String] {
        let values = [
            "Keep notification copy brief.",
            "Keep notification copy non-judgmental.",
            currentBrainState.identityProfile.relationshipBoundary
        ] + currentBrainState.brainState.sessionBiases

        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return Array(ordered.prefix(4))
    }

    private static func mapBlockReason(
        _ reason: BASPredictiveNotificationPolicyBlockReason
    ) -> InterventionNotificationPolicyBlockReason {
        switch reason {
        case .featureDisabled:
            .featureDisabled
        case .lowRisk:
            .lowRisk
        case .expired:
            .expired
        case .insufficientEvidence:
            .insufficientEvidence
        case .consistencyRejected:
            .consistencyRejected
        case .quietHours:
            .quietHours
        case .cooldownActive:
            .cooldownActive
        case .dailyCapReached:
            .dailyCapReached
        case .recentDismissalSuppression:
            .recentDismissalSuppression
        }
    }
}
