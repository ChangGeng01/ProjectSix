import Foundation

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case box
    case support
    case history
    case settings

    var id: String { rawValue }
}
