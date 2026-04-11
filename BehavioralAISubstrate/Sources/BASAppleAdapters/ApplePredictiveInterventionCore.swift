import Foundation
import BASMemory
import BASRuntimeCore

public struct BASApplePredictiveInterventionRiskBehavior: Codable, Equatable, Sendable {
    public var title: String
    public var detail: String
    public var preferredModeID: String?

    public init(
        title: String,
        detail: String,
        preferredModeID: String?
    ) {
        self.title = title
        self.detail = detail
        self.preferredModeID = preferredModeID
    }
}

public struct BASApplePredictiveInterventionBehavior: Codable, Equatable, Sendable {
    public static let generic = BASApplePredictiveInterventionBehavior()

    public var lowRisk: BASApplePredictiveInterventionRiskBehavior
    public var mediumRisk: BASApplePredictiveInterventionRiskBehavior
    public var highRisk: BASApplePredictiveInterventionRiskBehavior
    public var preferredModeIDsByCurrentModeID: [String: String]
    public var mediumRiskNegativeRecentThreshold: Int
    public var highRiskNegativeRecentThreshold: Int
    public var nightWindowReason: String
    public var negativeRecentReason: String
    public var failureGuardReasonsByID: [String: String]
    public var defaultReason: String

    public init(
        lowRisk: BASApplePredictiveInterventionRiskBehavior = BASApplePredictiveInterventionRiskBehavior(
            title: "A lighter pass may be enough.",
            detail: "Current signals suggest a short hold or lower-pressure pass before proceeding.",
            preferredModeID: nil
        ),
        mediumRisk: BASApplePredictiveInterventionRiskBehavior = BASApplePredictiveInterventionRiskBehavior(
            title: "A steadier pass may help here.",
            detail: "Current signals suggest another structured pass before proceeding.",
            preferredModeID: nil
        ),
        highRisk: BASApplePredictiveInterventionRiskBehavior = BASApplePredictiveInterventionRiskBehavior(
            title: "This may need more confirmation.",
            detail: "Current signals suggest raising confirmation and restoring more structure before proceeding.",
            preferredModeID: nil
        ),
        preferredModeIDsByCurrentModeID: [String: String] = [:],
        mediumRiskNegativeRecentThreshold: Int = 1,
        highRiskNegativeRecentThreshold: Int = 2,
        nightWindowReason: String = "The current time window lowers decision reliability.",
        negativeRecentReason: String = "Recent low-structure passes in comparable conditions ended poorly.",
        failureGuardReasonsByID: [String: String] = [:],
        defaultReason: String = "Current signals suggest a steadier next step."
    ) {
        self.lowRisk = lowRisk
        self.mediumRisk = mediumRisk
        self.highRisk = highRisk
        self.preferredModeIDsByCurrentModeID = preferredModeIDsByCurrentModeID
        self.mediumRiskNegativeRecentThreshold = mediumRiskNegativeRecentThreshold
        self.highRiskNegativeRecentThreshold = highRiskNegativeRecentThreshold
        self.nightWindowReason = nightWindowReason
        self.negativeRecentReason = negativeRecentReason
        self.failureGuardReasonsByID = failureGuardReasonsByID
        self.defaultReason = defaultReason
    }
}

public struct BASApplePredictiveInterventionInput: Codable, Equatable, Sendable {
    public var predictiveInterventionsEnabled: Bool
    public var currentModeID: String?
    public var negativeRecentCount: Int
    public var failureGuardIDs: [String]
    public var now: Date
    public var behavior: BASApplePredictiveInterventionBehavior

    public init(
        predictiveInterventionsEnabled: Bool,
        currentModeID: String?,
        negativeRecentCount: Int,
        failureGuardIDs: [String] = [],
        now: Date = .now,
        behavior: BASApplePredictiveInterventionBehavior = .generic
    ) {
        self.predictiveInterventionsEnabled = predictiveInterventionsEnabled
        self.currentModeID = currentModeID
        self.negativeRecentCount = negativeRecentCount
        self.failureGuardIDs = failureGuardIDs
        self.now = now
        self.behavior = behavior
    }
}

public struct BASApplePredictiveInterventionCandidate: Codable, Equatable, Sendable {
    public var riskLevelID: String
    public var title: String
    public var detail: String
    public var evidenceSignalCount: Int
    public var preferredModeID: String?
    public var reason: String
    public var expiresAt: Date

    public init(
        riskLevelID: String,
        title: String,
        detail: String,
        evidenceSignalCount: Int,
        preferredModeID: String?,
        reason: String,
        expiresAt: Date
    ) {
        self.riskLevelID = riskLevelID
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = evidenceSignalCount
        self.preferredModeID = preferredModeID
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

public enum BASApplePredictiveInterventionPredictor {
    public static func predictCandidate(
        input: BASApplePredictiveInterventionInput
    ) -> BASApplePredictiveInterventionCandidate? {
        guard input.predictiveInterventionsEnabled else { return nil }

        let mode = input.currentModeID.flatMap(BASDecisionMode.init(identifier:))
        let isNight = nightWindow(at: input.now)
        let riskLevel = resolvedRiskLevel(
            isNight: isNight,
            negativeRecentCount: input.negativeRecentCount,
            behavior: input.behavior
        )
        let copy = copy(for: riskLevel, behavior: input.behavior)
        let preferredModeID = resolvedPreferredModeID(
            currentModeID: mode?.identifier ?? input.currentModeID,
            preferredModeID: copy.preferredModeID,
            behavior: input.behavior
        )
        let reasons = buildReasons(
            isNight: isNight,
            negativeRecentCount: input.negativeRecentCount,
            failureGuardIDs: input.failureGuardIDs,
            behavior: input.behavior
        )

        return BASApplePredictiveInterventionCandidate(
            riskLevelID: riskLevel.rawValue,
            title: copy.title,
            detail: copy.detail,
            evidenceSignalCount: reasons.count,
            preferredModeID: preferredModeID,
            reason: reasons.isEmpty
                ? input.behavior.defaultReason
                : reasons.joined(separator: " "),
            expiresAt: input.now.addingTimeInterval(60 * 30)
        )
    }

    private static func nightWindow(at date: Date) -> Bool {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        return hour >= 22 || hour < 5
    }

    private static func resolvedRiskLevel(
        isNight: Bool,
        negativeRecentCount: Int,
        behavior: BASApplePredictiveInterventionBehavior
    ) -> BASRiskLevel {
        if isNight && negativeRecentCount >= behavior.highRiskNegativeRecentThreshold {
            return .high
        }
        if negativeRecentCount >= behavior.mediumRiskNegativeRecentThreshold {
            return .medium
        }
        return .low
    }

    private static func resolvedPreferredModeID(
        currentModeID: String?,
        preferredModeID: String?,
        behavior: BASApplePredictiveInterventionBehavior
    ) -> String? {
        if let preferredModeID {
            return preferredModeID
        }
        guard let currentModeID else { return nil }
        if let resolved = behavior.preferredModeIDsByCurrentModeID[currentModeID] {
            return resolved
        }
        if let mode = BASDecisionMode(identifier: currentModeID) {
            return behavior.preferredModeIDsByCurrentModeID[mode.rawValue]
        }
        return nil
    }

    private static func copy(
        for riskLevel: BASRiskLevel,
        behavior: BASApplePredictiveInterventionBehavior
    ) -> (title: String, detail: String, preferredModeID: String?) {
        switch riskLevel {
        case .low:
            return (
                title: behavior.lowRisk.title,
                detail: behavior.lowRisk.detail,
                preferredModeID: behavior.lowRisk.preferredModeID
            )
        case .medium:
            return (
                title: behavior.mediumRisk.title,
                detail: behavior.mediumRisk.detail,
                preferredModeID: behavior.mediumRisk.preferredModeID
            )
        case .high:
            return (
                title: behavior.highRisk.title,
                detail: behavior.highRisk.detail,
                preferredModeID: behavior.highRisk.preferredModeID
            )
        }
    }

    private static func buildReasons(
        isNight: Bool,
        negativeRecentCount: Int,
        failureGuardIDs: [String],
        behavior: BASApplePredictiveInterventionBehavior
    ) -> [String] {
        var reasons: [String] = []
        if isNight {
            reasons.append(behavior.nightWindowReason)
        }
        if negativeRecentCount > 0 {
            reasons.append(behavior.negativeRecentReason)
        }
        for guardID in failureGuardIDs {
            if let reason = behavior.failureGuardReasonsByID[guardID] {
                reasons.append(reason)
            }
        }
        return reasons
    }
}
