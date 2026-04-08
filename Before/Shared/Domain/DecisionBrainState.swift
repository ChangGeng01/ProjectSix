import Foundation

struct DecisionBrainState: Codable, Equatable, Sendable {
    var profileCore: [String]
    var activeGoals: [String]
    var relevantMemories: [String]
    var sessionBiases: [String]
    var retrievalTags: [String]
    var loadedAt: Date

    var isEmpty: Bool {
        profileCore.isEmpty &&
            activeGoals.isEmpty &&
            relevantMemories.isEmpty &&
            sessionBiases.isEmpty &&
            retrievalTags.isEmpty
    }
}
