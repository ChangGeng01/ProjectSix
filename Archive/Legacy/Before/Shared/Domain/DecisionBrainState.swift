import Foundation
import BASHostKit

typealias DecisionReactionWeightKey = BASReactionWeightKey
typealias DecisionReactionWeights = BASReactionWeights
typealias DecisionBrainMemoryRole = BASBrainMemoryRole
typealias DecisionMemorySourceTrustTier = BASMemorySourceTrustTier
typealias DecisionMemoryEligibilityReason = BASMemoryEligibilityReason
typealias DecisionMemoryEligibilityDecision = BASMemoryEligibilityDecision
typealias DecisionGovernedMemoryStatus = BASBrainGovernedMemoryStatus
typealias DecisionGovernedMemorySlice = BASGovernedMemorySlice
typealias DecisionBrainStateRiskFlag = BASBrainStateRiskFlag
typealias DecisionBrainStateSnapshot = BASBrainStateSnapshot
typealias DecisionMemoryGovernanceState = BASMemoryGovernanceState
typealias DecisionBrainState = BASDecisionBrainState

extension DecisionReactionWeights {
    static func defaults(for mode: DecisionMode) -> DecisionReactionWeights {
        BeforeProductLanguage.reactionWeights(for: mode)
    }
}
