import Foundation

struct DecisionFrontstageState: Codable, Equatable, Sendable {
    let focusGoal: String
    let dangerSignals: [String]
    let evidenceHeadlines: [String]
    let anchorHeadlines: [String]
    let droppedEvidenceCount: Int
    let suppressionHints: [String]
}
