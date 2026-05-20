import Foundation

enum SupportSurfaceTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case buddy
    case sharedLife

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buddy: "Buddy"
        case .sharedLife: "Shared Life"
        }
    }
}
