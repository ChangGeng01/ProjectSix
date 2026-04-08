import Foundation

struct DecisionFrontstageState: Codable, Equatable, Sendable {
    let focusGoal: String
    let dangerSignals: [String]
    let evidenceHeadlines: [String]
    let suppressionHints: [String]
}
