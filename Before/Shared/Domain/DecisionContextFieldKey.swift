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

    var title: String {
        switch self {
        case .quickNote:
            "Quick note"
        case .balancePrompt:
            "Balance prompt"
        case .balanceDesire:
            "What I want"
        case .balanceConcern:
            "Main concern"
        case .balanceConstraint:
            "Reality constraint"
        case .balanceLongTerm:
            "Long-term lens"
        case .mirrorPrompt:
            "Mirror prompt"
        case .mirrorEmotion:
            "Emotion lens"
        case .mirrorRelationship:
            "Relationship lens"
        case .mirrorReality:
            "Reality lens"
        case .mirrorLongTerm:
            "Long-term lens"
        case .mirrorSelfLens:
            "Self lens"
        }
    }
}
