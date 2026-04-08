import Foundation

struct DecisionFrontstageState: Codable, Equatable, Sendable {
    let focusGoal: String
    let activeStateSignalCount: Int
    let openTextSignalCount: Int
    let dangerSignals: [String]
    let evidenceHeadlines: [String]
    let anchorHeadlines: [String]
    let memoryHeadlines: [String]
    let retainedEvidenceCount: Int
    let droppedEvidenceCount: Int
    let droppedInjectedEvidenceCount: Int
    let droppedDuplicateEvidenceCount: Int
    let droppedBudgetEvidenceCount: Int
    let suppressionHints: [String]
    let sessionBiases: [String]
}
