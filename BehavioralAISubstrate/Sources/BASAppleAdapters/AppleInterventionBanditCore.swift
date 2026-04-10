import Foundation

public struct BASAppleInterventionBanditArmState: Codable, Equatable, Sendable {
    public var alpha: Double
    public var beta: Double

    public var score: Double {
        alpha / max(1, alpha + beta)
    }

    public init(alpha: Double, beta: Double) {
        self.alpha = alpha
        self.beta = beta
    }
}

public struct BASAppleInterventionBanditBucketState: Codable, Equatable, Sendable {
    public var arms: [String: BASAppleInterventionBanditArmState]

    public init(arms: [String: BASAppleInterventionBanditArmState]) {
        self.arms = arms
    }
}

public struct BASAppleInterventionBanditSnapshot: Codable, Equatable, Sendable {
    public var buckets: [String: BASAppleInterventionBanditBucketState]

    public init(buckets: [String: BASAppleInterventionBanditBucketState]) {
        self.buckets = buckets
    }
}

public enum BASAppleInterventionBanditAdvisor {
    public static let defaultArmIDs = [
        "brief_warm_nudge",
        "tomorrow_box_interrupt",
        "reflective_question",
        "slow_delay_guard"
    ]

    public static func orderedArmIDs(
        snapshot: BASAppleInterventionBanditSnapshot,
        bucketID: String
    ) -> [String] {
        let states = snapshot.buckets[bucketID]?.arms ?? defaultArmStates()
        return states
            .sorted {
                if $0.value.score == $1.value.score {
                    return $0.key < $1.key
                }
                return $0.value.score > $1.value.score
            }
            .map(\.key)
    }

    public static func updatedSnapshot(
        snapshot: BASAppleInterventionBanditSnapshot,
        bucketID: String,
        chosenArmID: String,
        reward: Bool
    ) -> BASAppleInterventionBanditSnapshot {
        var next = snapshot
        var bucketState = next.buckets[bucketID] ?? BASAppleInterventionBanditBucketState(arms: defaultArmStates())
        var armState = bucketState.arms[chosenArmID] ?? BASAppleInterventionBanditArmState(alpha: 1, beta: 1)
        if reward {
            armState.alpha += 1
        } else {
            armState.beta += 1.4
        }
        bucketState.arms[chosenArmID] = armState
        next.buckets[bucketID] = bucketState
        return next
    }

    public static func bucketID(
        modeID: String,
        riskLevelID: String,
        languageModeID: String,
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
        return [modeID, riskLevelID, languageModeID, daypart].joined(separator: "::")
    }

    public static func emptySnapshot() -> BASAppleInterventionBanditSnapshot {
        BASAppleInterventionBanditSnapshot(buckets: [:])
    }

    public static func defaultArmStates() -> [String: BASAppleInterventionBanditArmState] {
        Dictionary(
            uniqueKeysWithValues: defaultArmIDs.map {
                ($0, BASAppleInterventionBanditArmState(alpha: 1, beta: 1))
            }
        )
    }
}
