import Foundation

private struct DecisionBanditArmState: Codable, Equatable, Sendable {
    var alpha: Double
    var beta: Double

    var score: Double {
        alpha / max(1, alpha + beta)
    }
}

private struct DecisionBanditBucketState: Codable, Equatable, Sendable {
    var arms: [String: DecisionBanditArmState]
}

private struct DecisionBanditSnapshot: Codable, Equatable, Sendable {
    var buckets: [String: DecisionBanditBucketState]
}

enum DecisionReactionBanditStore {
    private static let key = "before.reaction.bandit.snapshot"
    private static let storage = CodableStateStorage.protectedLocal
    private static let arms = [
        "brief_warm_nudge",
        "tomorrow_box_interrupt",
        "reflective_question",
        "slow_delay_guard"
    ]

    static func recommendedArmIDs(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        now: Date = .now
    ) -> [String] {
        let bucket = bucketKey(mode: mode, riskLevel: riskLevel, languageMode: languageMode, now: now)
        let snapshot = loadSnapshot()
        let states = snapshot.buckets[bucket]?.arms ?? defaultArmStates()
        return states
            .sorted {
                if $0.value.score == $1.value.score {
                    return $0.key < $1.key
                }
                return $0.value.score > $1.value.score
            }
            .map(\.key)
    }

    static func update(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        chosenArmID: String,
        reward: Bool,
        now: Date = .now
    ) {
        let bucket = bucketKey(mode: mode, riskLevel: riskLevel, languageMode: languageMode, now: now)
        var snapshot = loadSnapshot()
        var bucketState = snapshot.buckets[bucket] ?? DecisionBanditBucketState(arms: defaultArmStates())
        var armState = bucketState.arms[chosenArmID] ?? DecisionBanditArmState(alpha: 1, beta: 1)
        if reward {
            armState.alpha += 1
        } else {
            armState.beta += 1.4
        }
        bucketState.arms[chosenArmID] = armState
        snapshot.buckets[bucket] = bucketState
        storage.save(snapshot, key: key)
    }

    static func clear() {
        storage.clear(key: key)
    }

    private static func loadSnapshot() -> DecisionBanditSnapshot {
        storage.load(DecisionBanditSnapshot.self, key: key) ?? DecisionBanditSnapshot(buckets: [:])
    }

    private static func defaultArmStates() -> [String: DecisionBanditArmState] {
        Dictionary(uniqueKeysWithValues: arms.map { ($0, DecisionBanditArmState(alpha: 1, beta: 1)) })
    }

    private static func bucketKey(
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        languageMode: DecisionLanguageMode,
        now: Date
    ) -> String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        let daypart: String
        switch hour {
        case 0..<6: daypart = "late_night"
        case 6..<12: daypart = "morning"
        case 12..<18: daypart = "afternoon"
        default: daypart = "night"
        }
        return [mode.rawValue, riskLevel.rawValue, languageMode.rawValue, daypart].joined(separator: "::")
    }
}
