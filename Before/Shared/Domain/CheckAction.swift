import Foundation

enum CheckAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case wait90s
    case leaveStimulus
    case decideTomorrow
    case goAheadAnyway
    case continueMindfully

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wait90s: "Wait 90 seconds"
        case .leaveStimulus: "Step away first"
        case .decideTomorrow: "Move it to tomorrow"
        case .goAheadAnyway: "I still want to do it"
        case .continueMindfully: "Do it mindfully"
        }
    }
}
