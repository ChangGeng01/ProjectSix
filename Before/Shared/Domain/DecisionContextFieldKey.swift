import Foundation

enum DecisionContextFieldKey: String, Codable, CaseIterable, Sendable {
    case quickNote
    case balancePrompt
    case balanceDesire
    case balanceConcern
    case balanceConstraint
    case balanceLongTerm
    case mirrorPrompt
    case mirrorEmotion
    case mirrorRelationship
    case mirrorReality
    case mirrorLongTerm
    case mirrorSelfLens
}
