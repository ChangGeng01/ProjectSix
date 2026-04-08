import Foundation

enum TomorrowBoxDelay: String, CaseIterable, Codable, Identifiable, Sendable {
    case oneDay
    case threeDays
    case oneWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneDay: "1 more day"
        case .threeDays: "3 more days"
        case .oneWeek: "1 more week"
        }
    }

    func reschedule(
        from date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let daysToAdd: Int
        switch self {
        case .oneDay:
            daysToAdd = 1
        case .threeDays:
            daysToAdd = 3
        case .oneWeek:
            daysToAdd = 7
        }

        let shifted = calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
        return BeforePolicy.Notifications.normalizedReminderDate(after: shifted, calendar: calendar)
    }
}
