import Foundation
import BASRuntimeCore

public enum BASAppleReflectionAdaptationAdvisor {
    public static func reward(outcomeID: String) -> Bool {
        switch outcomeID {
        case "betterThanExpected", "okay", "notNeeded":
            return true
        case "regrettedIt", "feltEmptier":
            return false
        default:
            return false
        }
    }

    public static func chosenArmID(finalActionID: String) -> String {
        switch finalActionID {
        case "decideTomorrow", "wait90s":
            return "tomorrow_box_interrupt"
        case "leaveStimulus":
            return "slow_delay_guard"
        case "goAheadAnyway", "continueMindfully":
            return "brief_warm_nudge"
        default:
            return "brief_warm_nudge"
        }
    }

    public static func riskLevel(
        finalActionID: String,
        outcomeID: String
    ) -> BASRiskLevel {
        switch outcomeID {
        case "regrettedIt", "feltEmptier":
            return .high
        case "okay":
            return .medium
        case "betterThanExpected", "notNeeded":
            switch finalActionID {
            case "goAheadAnyway", "continueMindfully":
                return .medium
            case "wait90s", "leaveStimulus", "decideTomorrow":
                return .low
            default:
                return .medium
            }
        default:
            return .medium
        }
    }
}
