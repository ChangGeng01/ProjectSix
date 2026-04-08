import Foundation

struct DecisionFrontstageState: Codable, Equatable, Sendable {
    let focusGoal: String
    let dangerSignals: [String]
    let evidenceHeadlines: [String]
    let anchorHeadlines: [String]
    let retainedEvidenceCount: Int
    let droppedEvidenceCount: Int
    let droppedInjectedEvidenceCount: Int
    let droppedDuplicateEvidenceCount: Int
    let droppedBudgetEvidenceCount: Int
    let suppressionHints: [String]
}
