import Foundation

struct WidgetSnapshot: Codable, Sendable {
    var safeMessage: WidgetSafeMessage?
    var latestVerdict: CheckVerdict?
    var latestScenario: ScenarioType?
    var updatedAt: Date

    var sanitizedMessage: WidgetSafeMessage {
        WidgetSafeCopy.sanitizedMessage(
            safeMessage,
            scenario: latestScenario,
            verdict: latestVerdict
        )
    }

    var messageHeadline: String {
        sanitizedMessage.headline
    }

    var messageBody: String {
        sanitizedMessage.body
    }

    var messageSurface: WidgetMessageSurface {
        sanitizedMessage.surface
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
        return WidgetSnapshot(
            safeMessage: snapshot.sanitizedMessage,
            latestVerdict: snapshot.latestVerdict,
            latestScenario: snapshot.latestScenario,
            updatedAt: snapshot.updatedAt
        )
    }

    static func clear() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
