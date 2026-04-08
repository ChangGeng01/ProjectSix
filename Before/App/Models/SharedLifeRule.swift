import Foundation

enum SharedLifeRuleKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case budget
    case delivery
    case sleep
    case screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budget: "Budget"
        case .delivery: "Delivery"
        case .sleep: "Sleep"
        case .screen: "Screen time"
        }
    }

    var symbolName: String {
        switch self {
        case .budget: "creditcard"
        case .delivery: "takeoutbag.and.cup.and.straw"
        case .sleep: "moon.stars"
        case .screen: "iphone"
        }
    }
}

struct SharedLifeRule: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var kind: SharedLifeRuleKind
    var title: String
    var detail: String
    var isEnabled: Bool
    var isSeeded: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: SharedLifeRuleKind,
        title: String,
        detail: String,
        isEnabled: Bool = true,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kind = kind
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.isSeeded = isSeeded
    }
}
