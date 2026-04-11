import Foundation
import SwiftData
import BASHostKit

enum InterventionPredictionEngine {
    static func predictCandidate(
        currentBrainState: CurrentBrainState?,
        context: ModelContext,
        preferences: BeforePreferences,
        now: Date = .now
    ) -> InterventionPredictionCandidate? {
        let quickEvents = (try? context.fetch(
            FetchDescriptor<CheckEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
        let recentQuick = Array(quickEvents.prefix(5))
        let negativeRecentCount = recentQuick.filter {
            guard let outcome = $0.reflectionOutcome else { return false }
            return outcome == .regrettedIt || outcome == .feltEmptier
        }.count
        let candidate = BASApplePredictiveInterventionPredictor.predictCandidate(
            input: BASApplePredictiveInterventionInput(
                predictiveInterventionsEnabled: preferences.predictiveInterventionsEnabled,
                currentModeID: currentBrainState?.mode.substrateModeID,
                negativeRecentCount: negativeRecentCount,
                failureGuardIDs: currentBrainState?.failureGuardIDs ?? [],
                now: now,
                behavior: BeforeProductLanguage.predictiveInterventionBehavior
            )
        )

        return candidate.map {
            InterventionPredictionCandidate(
                riskLevel: InterventionRiskLevel(rawValue: $0.riskLevelID) ?? .low,
                title: $0.title,
                detail: $0.detail,
                evidenceSignalCount: $0.evidenceSignalCount,
                suggestedMode: DecisionMode.fromSubstrateModeID($0.preferredModeID),
                reason: $0.reason,
                expiresAt: $0.expiresAt
            )
        }
    }
}
