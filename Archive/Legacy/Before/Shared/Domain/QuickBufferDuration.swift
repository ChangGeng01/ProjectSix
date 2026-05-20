import Foundation

enum QuickBufferDuration: String, CaseIterable, Codable, Identifiable, Sendable {
    case ninetySeconds
    case fiveMinutes
    case tenMinutes

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .ninetySeconds: 90
        case .fiveMinutes: 5 * 60
        case .tenMinutes: 10 * 60
        }
    }

    var title: String {
        switch self {
        case .ninetySeconds: "90 seconds"
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        }
    }

    var actionTitle: String {
        "Wait \(title)"
    }

    var resetTitle: String {
        "Reset the \(title) buffer"
    }

    var notificationTitle: String {
        switch self {
        case .ninetySeconds:
            "90 seconds are up"
        case .fiveMinutes:
            "5 minutes are up"
        case .tenMinutes:
            "10 minutes are up"
        }
    }
}
