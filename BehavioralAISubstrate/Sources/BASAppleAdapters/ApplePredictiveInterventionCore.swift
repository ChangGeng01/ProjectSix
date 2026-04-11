import Foundation
import BASMemory
import BASRuntimeCore

public struct BASApplePredictiveInterventionInput: Codable, Equatable, Sendable {
    public var predictiveInterventionsEnabled: Bool
    public var currentModeID: String?
    public var negativeRecentCount: Int
    public var failureGuardIDs: [String]
    public var now: Date

    public init(
        predictiveInterventionsEnabled: Bool,
        currentModeID: String?,
        negativeRecentCount: Int,
        failureGuardIDs: [String] = [],
        now: Date = .now
    ) {
        self.predictiveInterventionsEnabled = predictiveInterventionsEnabled
        self.currentModeID = currentModeID
        self.negativeRecentCount = negativeRecentCount
        self.failureGuardIDs = failureGuardIDs
        self.now = now
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

        let mode = BASDecisionMode(rawValue: input.currentModeID ?? "") ?? .quick
        let isNight = nightWindow(at: input.now)
        let riskLevel = resolvedRiskLevel(
            isNight: isNight,
            negativeRecentCount: input.negativeRecentCount,
            mode: mode
        )
        let copy = copy(for: riskLevel)
        let reasons = buildReasons(
            isNight: isNight,
            negativeRecentCount: input.negativeRecentCount,
            failureGuardIDs: input.failureGuardIDs
        )

        return BASApplePredictiveInterventionCandidate(
            riskLevelID: riskLevel.rawValue,
            title: copy.title,
            detail: copy.detail,
            evidenceSignalCount: reasons.count,
            preferredModeID: copy.preferredModeID,
            reason: reasons.isEmpty
                ? "A low-friction pause is still the cleanest move."
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
        mode: BASDecisionMode
    ) -> BASRiskLevel {
        if isNight && negativeRecentCount >= 2 {
            return .high
        }
        if negativeRecentCount >= 1 || mode == .mirror {
            return .medium
        }
        return .low
    }

    private static func copy(
        for riskLevel: BASRiskLevel
    ) -> (title: String, detail: String, preferredModeID: String?) {
        switch riskLevel {
        case .low:
            return (
                title: "Put this out of the fast lane.",
                detail: "A short delay may be enough. Tomorrow Box can hold it without pretending it disappeared.",
                preferredModeID: BASDecisionMode.quick.rawValue
            )
        case .medium:
            return (
                title: "You may need one cleaner mirror before acting.",
                detail: "Recent patterns suggest a pause plus one honest question will help more than a fast answer.",
                preferredModeID: BASDecisionMode.mirror.rawValue
            )
        case .high:
            return (
                title: "Do not decide from this level of blur.",
                detail: "Night pressure and recent regret patterns suggest slowing this down before you move.",
                preferredModeID: BASDecisionMode.mirror.rawValue
            )
        }
    }

    private static func buildReasons(
        isNight: Bool,
        negativeRecentCount: Int,
        failureGuardIDs: [String]
    ) -> [String] {
        var reasons: [String] = []
        if isNight {
            reasons.append("It is late enough that fast decisions are less trustworthy.")
        }
        if negativeRecentCount > 0 {
            reasons.append("Recent quick calls have ended in regret or emptiness.")
        }
        if failureGuardIDs.contains("night_fast_path_failure") {
            reasons.append("Your current brain state is already suppressing night fast paths.")
        }
        return reasons
    }
}
