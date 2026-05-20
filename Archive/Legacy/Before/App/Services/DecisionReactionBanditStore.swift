import Foundation
import BASHostKit

enum DecisionReactionBanditStore {
    private static let key = "before.reaction.bandit.snapshot"
    private static let storage = CodableStateStorage.protectedLocal

    static func recommendedArmIDs(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        now: Date = .now
    ) -> [String] {
        BASAppleInterventionBanditAdvisor.orderedArmIDs(
            snapshot: loadSnapshot(),
            bucketID: bucketID(
                mode: mode,
                riskLevel: riskLevel,
                languageMode: languageMode,
                now: now
            )
        )
    }

    static func update(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        chosenArmID: String,
        reward: Bool,
        now: Date = .now
    ) {
        let snapshot = BASAppleInterventionBanditAdvisor.updatedSnapshot(
            snapshot: loadSnapshot(),
            bucketID: bucketID(
                mode: mode,
                riskLevel: riskLevel,
                languageMode: languageMode,
                now: now
            ),
            chosenArmID: chosenArmID,
            reward: reward
        )
        storage.save(snapshot, key: key)
    }

    static func clear() {
        storage.clear(key: key)
    }

    private static func loadSnapshot() -> BASAppleInterventionBanditSnapshot {
        storage.load(BASAppleInterventionBanditSnapshot.self, key: key) ??
            BASAppleInterventionBanditAdvisor.emptySnapshot()
    }

    private static func bucketID(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        now: Date
    ) -> String {
        BASAppleInterventionBanditAdvisor.bucketID(
            modeID: mode.rawValue,
            riskLevelID: riskLevel.rawValue,
            languageModeID: languageMode.rawValue,
            now: now
        )
    }
}
