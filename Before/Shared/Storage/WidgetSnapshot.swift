import Foundation

struct WidgetSnapshot: Codable, Sendable {
    var safeMessage: WidgetSafeMessage?
    var latestVerdict: CheckVerdict?
    var latestScenario: ScenarioType?
    var updatedAt: Date

    var messageBody: String {
        safeMessage?.body ?? WidgetSafeMessage.generic.body
    }

    static let empty = WidgetSnapshot(
        safeMessage: .generic,
        latestVerdict: nil,
        latestScenario: nil,
        updatedAt: .now
    )
}

enum WidgetSnapshotStore {
    private static let key = "before.widget.snapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        SharedContainer.defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard
            let data = SharedContainer.defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    static func clear() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
