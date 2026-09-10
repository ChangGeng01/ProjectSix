import Foundation

enum MotivationChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case genuineNeed
    case reward
    case stressed
    case avoiding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .genuineNeed: "It feels genuinely useful or needed"
        case .reward: "I want a reward"
        case .stressed: "I want relief fast"
        case .avoiding: "I don't want to sit with this moment"
        }
    }
}

enum OutcomeChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case satisfied
    case temporaryRelief
    case regret
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .satisfied: "I'll probably feel good about it"
        case .temporaryRelief: "It might help, but only briefly"
        case .regret: "I'll probably regret it"
        case .unsure: "I'm not sure"
        }
    }
}

enum ControlChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case yes
    case maybe
    case no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: "Yes, I can still pull back"
        case .maybe: "Maybe, but I need help"
        case .no: "Not really"
        }
    }
}

enum ReflectionOutcome: String, CaseIterable, Codable, Identifiable, Sendable {
    case betterThanExpected
    case okay
    case notNeeded
    case regrettedIt
    case feltEmptier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .betterThanExpected: "Better than I expected"
        case .okay: "It was okay"
        case .notNeeded: "I did not need it"
        case .regrettedIt: "I regretted it"
        case .feltEmptier: "I felt even emptier"
        }
    }
}
