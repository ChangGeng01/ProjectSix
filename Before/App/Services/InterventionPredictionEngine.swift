import Foundation
import SwiftData

enum InterventionPredictionEngine {
    static func predictCandidate(
        currentBrainState: CurrentBrainState?,
        context: ModelContext,
        preferences: BeforePreferences,
        now: Date = .now
    ) -> InterventionPredictionCandidate? {
        guard preferences.predictiveInterventionsEnabled else { return nil }

        let quickEvents = (try? context.fetch(
            FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
        let recentQuick = Array(quickEvents.prefix(5))
        let negativeRecentCount = recentQuick.filter {
            guard let outcome = $0.reflectionOutcome else { return false }
            return outcome == .regrettedIt || outcome == .feltEmptier
        }.count

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        let isNight = hour >= 22 || hour < 5
        let mode = currentBrainState?.mode ?? .quick
        let riskLevel: InterventionRiskLevel = {
            if isNight && negativeRecentCount >= 2 { return .high }
            if negativeRecentCount >= 1 || mode == .mirror { return .medium }
            return .low
        }()

        let title: String
        let detail: String
        let suggestedMode: DecisionMode

        switch riskLevel {
        case .low:
            title = "Put this out of the fast lane."
            detail = "A short delay may be enough. Tomorrow Box can hold it without pretending it disappeared."
            suggestedMode = .quick
        case .medium:
            title = "You may need one cleaner mirror before acting."
            detail = "Recent patterns suggest a pause plus one honest question will help more than a fast answer."
            suggestedMode = .mirror
        case .high:
            title = "Do not decide from this level of blur."
            detail = "Night pressure and recent regret patterns suggest slowing this down before you move."
            suggestedMode = .mirror
        }

        let reasons = buildReasons(
            isNight: isNight,
            negativeRecentCount: negativeRecentCount,
            currentBrainState: currentBrainState
        )

        return InterventionPredictionCandidate(
            riskLevel: riskLevel,
            title: title,
            detail: detail,
            evidenceSignalCount: reasons.count,
            suggestedMode: suggestedMode,
            reason: reasons.isEmpty
                ? "A low-friction pause is still the cleanest move."
                : reasons.joined(separator: " "),
            expiresAt: now.addingTimeInterval(60 * 30)
        )
    }

    private static func buildReasons(
        isNight: Bool,
        negativeRecentCount: Int,
        currentBrainState: CurrentBrainState?
    ) -> [String] {
        var reasons: [String] = []
        if isNight {
            reasons.append("It is late enough that fast decisions are less trustworthy.")
        }
        if negativeRecentCount > 0 {
            reasons.append("Recent quick calls have ended in regret or emptiness.")
        }
        if let currentBrainState, currentBrainState.failureGuardIDs.contains("night_fast_path_failure") {
            reasons.append("Your current brain state is already suppressing night fast paths.")
        }
        return reasons
    }
}
