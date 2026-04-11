import Foundation

public enum BASPredictiveNotificationPolicyBlockReason: String, Codable, Equatable, Sendable {
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

public struct BASPredictiveNotificationHistorySignal: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var wasDelivered: Bool
    public var wasDismissed: Bool

    public init(createdAt: Date, wasDelivered: Bool, wasDismissed: Bool) {
        self.createdAt = createdAt
        self.wasDelivered = wasDelivered
        self.wasDismissed = wasDismissed
    }
}

public struct BASPredictiveNotificationPolicyInput: Codable, Equatable, Sendable {
    public var predictiveInterventionsEnabled: Bool
    public var riskLevelID: String
    public var evidenceSignalCount: Int
    public var title: String
    public var detail: String
    public var reason: String
    public var expiresAt: Date
    public var currentGoal: String?
    public var boundaryModeID: String?
    public var forbiddenActions: [String]
    public var personaRules: [String]
    public var recentSignals: [BASPredictiveNotificationHistorySignal]
    public var now: Date
    public var quietHoursStartHour: Int
    public var quietHoursEndHour: Int
    public var dailyCap: Int
    public var cooldownInterval: TimeInterval
    public var dismissalSuppressionInterval: TimeInterval

    public init(
        predictiveInterventionsEnabled: Bool,
        riskLevelID: String,
        evidenceSignalCount: Int,
        title: String,
        detail: String,
        reason: String,
        expiresAt: Date,
        currentGoal: String? = nil,
        boundaryModeID: String? = nil,
        forbiddenActions: [String] = [],
        personaRules: [String] = [],
        recentSignals: [BASPredictiveNotificationHistorySignal] = [],
        now: Date = .now,
        quietHoursStartHour: Int,
        quietHoursEndHour: Int,
        dailyCap: Int,
        cooldownInterval: TimeInterval,
        dismissalSuppressionInterval: TimeInterval
    ) {
        self.predictiveInterventionsEnabled = predictiveInterventionsEnabled
        self.riskLevelID = riskLevelID
        self.evidenceSignalCount = evidenceSignalCount
        self.title = title
        self.detail = detail
        self.reason = reason
        self.expiresAt = expiresAt
        self.currentGoal = currentGoal
        self.boundaryModeID = boundaryModeID
        self.forbiddenActions = forbiddenActions
        self.personaRules = personaRules
        self.recentSignals = recentSignals
        self.now = now
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursEndHour = quietHoursEndHour
        self.dailyCap = dailyCap
        self.cooldownInterval = cooldownInterval
        self.dismissalSuppressionInterval = dismissalSuppressionInterval
    }
}

public struct BASPredictiveNotificationPolicyDecision: Codable, Equatable, Sendable {
    public var isAllowed: Bool
    public var reason: String
    public var blockReason: BASPredictiveNotificationPolicyBlockReason?
    public var consistencyCheck: BASConsistencyCheckResult?

    public init(
        isAllowed: Bool,
        reason: String,
        blockReason: BASPredictiveNotificationPolicyBlockReason?,
        consistencyCheck: BASConsistencyCheckResult? = nil
    ) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.blockReason = blockReason
        self.consistencyCheck = consistencyCheck
    }
}

public enum BASPredictiveNotificationPolicyEngine {
    public static func decide(
        input: BASPredictiveNotificationPolicyInput,
        calendar: Calendar = .autoupdatingCurrent
    ) -> BASPredictiveNotificationPolicyDecision {
        guard input.predictiveInterventionsEnabled else {
            return block(
                .featureDisabled,
                detail: "Predictive notifications are disabled by host policy."
            )
        }

        let riskLevel = input.riskLevelID
        guard riskLevel != "low" else {
            return block(
                .lowRisk,
                detail: "Lower-risk candidates stay local and do not escalate into notifications."
            )
        }

        guard input.expiresAt > input.now else {
            return block(
                .expired,
                detail: "Expired intervention candidates cannot schedule new notifications."
            )
        }

        if input.evidenceSignalCount < minimumEvidenceSignalCount(for: riskLevel) {
            return block(
                .insufficientEvidence,
                detail: "Notification delivery stayed local because the evidence signal count is still too thin."
            )
        }

        let consistencyCheck = notificationConsistencyCheck(input: input)
        if let consistencyCheck, !consistencyCheck.isConsistent {
            return block(
                .consistencyRejected,
                detail: rejectedConsistencyDetail(result: consistencyCheck),
                consistencyCheck: consistencyCheck
            )
        }

        if isQuietHours(input: input, calendar: calendar), riskLevel != "high" {
            return block(
                .quietHours,
                detail: "Medium-risk nudges stay quiet during low-attention hours."
            )
        }

        if deliveredTriggerCount(forSameDayAs: input.now, signals: input.recentSignals, calendar: calendar) >= input.dailyCap {
            return block(
                .dailyCapReached,
                detail: "The predictive intervention daily cap has already been reached."
            )
        }

        if let mostRecentDismissed = input.recentSignals
            .filter(\.wasDismissed)
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first,
           input.now.timeIntervalSince(mostRecentDismissed.createdAt) < input.dismissalSuppressionInterval {
            return block(
                .recentDismissalSuppression,
                detail: "A recent dismissal is suppressing another predictive notification for now."
            )
        }

        if let mostRecentDelivered = input.recentSignals
            .filter(\.wasDelivered)
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first,
           input.now.timeIntervalSince(mostRecentDelivered.createdAt) < input.cooldownInterval {
            return block(
                .cooldownActive,
                detail: "A predictive intervention notification was delivered too recently to send another one now."
            )
        }

        return BASPredictiveNotificationPolicyDecision(
            isAllowed: true,
            reason: "Notification delivery is allowed because evidence is strong enough and no scheduling rule blocked it.",
            blockReason: nil,
            consistencyCheck: consistencyCheck
        )
    }

    private static func minimumEvidenceSignalCount(for riskLevelID: String) -> Int {
        switch riskLevelID {
        case "medium", "high":
            2
        default:
            99
        }
    }

    private static func isQuietHours(
        input: BASPredictiveNotificationPolicyInput,
        calendar: Calendar
    ) -> Bool {
        let hour = calendar.component(.hour, from: input.now)
        return hour >= input.quietHoursStartHour || hour < input.quietHoursEndHour
    }

    private static func deliveredTriggerCount(
        forSameDayAs now: Date,
        signals: [BASPredictiveNotificationHistorySignal],
        calendar: Calendar
    ) -> Int {
        signals.filter { signal in
            signal.wasDelivered && calendar.isDate(signal.createdAt, inSameDayAs: now)
        }.count
    }

    private static func notificationConsistencyCheck(
        input: BASPredictiveNotificationPolicyInput
    ) -> BASConsistencyCheckResult? {
        guard input.boundaryModeID != nil || !input.personaRules.isEmpty || !input.forbiddenActions.isEmpty else {
            return nil
        }

        var referencedFacts: [String: String] = [:]
        if let boundaryModeID = input.boundaryModeID {
            referencedFacts["boundary_mode"] = boundaryModeID
        }
        if let currentGoal = input.currentGoal {
            referencedFacts["current_goal"] = currentGoal
        }

        return BASConsistencyHarness.evaluate(
            BASConsistencyCheckInput(
                truthState: BASStructuredTruthState(
                    mode: "predictive_intervention_notification",
                    currentGoal: input.currentGoal,
                    allowedActions: ["send_predictive_notification"],
                    forbiddenActions: input.forbiddenActions,
                    personaRules: input.personaRules,
                    sessionFacts: input.boundaryModeID.map { ["boundary_mode": $0] } ?? [:]
                ),
                responseMode: "predictive_intervention_notification",
                responseText: [input.title, input.detail, input.reason]
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

    private static func block(
        _ reason: BASPredictiveNotificationPolicyBlockReason,
        detail: String,
        consistencyCheck: BASConsistencyCheckResult? = nil
    ) -> BASPredictiveNotificationPolicyDecision {
        BASPredictiveNotificationPolicyDecision(
            isAllowed: false,
            reason: detail,
            blockReason: reason,
            consistencyCheck: consistencyCheck
        )
    }
}
