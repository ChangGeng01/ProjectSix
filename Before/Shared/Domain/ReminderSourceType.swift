import Foundation

enum ReminderSourceType: String, CaseIterable, Codable, Identifiable, Sendable {
    case userWritten
    case compressed
    case template

    var id: String { rawValue }
}
