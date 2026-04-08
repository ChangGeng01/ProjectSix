import Foundation

enum MirrorWorkspaceLens: String, CaseIterable, Identifiable, Sendable {
    case emotion
    case relationship
    case reality
    case longTerm
    case selfLens

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emotion: "Emotion"
        case .relationship: "Relationship"
        case .reality: "Reality"
        case .longTerm: "Long-term"
        case .selfLens: "Self"
        }
    }

    var subtitle: String {
        switch self {
        case .emotion: "What is strongest right now?"
        case .relationship: "What keeps repeating underneath the moment?"
        case .reality: "What concrete constraints are in the room?"
        case .longTerm: "What shape does this keep making over time?"
        case .selfLens: "What does this do to your sense of self?"
        }
    }

    var placeholder: String {
        switch self {
        case .emotion: "Name the feeling without defending it."
        case .relationship: "Boundary, trust, respect, communication, pattern..."
        case .reality: "Work, money, family, distance, home, timing..."
        case .longTerm: "Drift, regret, shrinking, repair, rebuilding..."
        case .selfLens: "I feel smaller, split, calmer, freer..."
        }
    }

    var symbolName: String {
        switch self {
        case .emotion: "heart.text.square"
        case .relationship: "person.2"
        case .reality: "building.2"
        case .longTerm: "clock.arrow.circlepath"
        case .selfLens: "person.crop.circle"
        }
    }

    static let openingLenses: [MirrorWorkspaceLens] = [.emotion, .relationship, .reality]
    static let closingLenses: [MirrorWorkspaceLens] = [.longTerm, .selfLens]
}

enum MirrorWorkspaceStage: String, Sendable {
    case opening
    case building
    case ready
    case reflected

    var title: String {
        switch self {
        case .opening: "Opening the mirror"
        case .building: "The mirror is taking shape"
        case .ready: "Ready to reflect"
        case .reflected: "Revisit this mirror"
        }
    }

    var subtitle: String {
        switch self {
        case .opening: "Start with the question and let the lenses collect what is true."
        case .building: "Enough of the question is here to start seeing the outline."
        case .ready: "You have enough to let the mirror speak back without forcing it."
        case .reflected: "This has already been reflected once. You can reopen it, save it, or move it aside."
        }
    }

    var symbolName: String {
        switch self {
        case .opening: "sparkles"
        case .building: "circle.dashed"
        case .ready: "mirror.side.left"
        case .reflected: "clock.arrow.circlepath"
        }
    }
}
