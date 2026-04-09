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
    private static let storage = CodableStateStorage.sharedPublic

    static func save(_ snapshot: WidgetSnapshot) {
        storage.save(sanitized(snapshot), key: key)
        scrubLegacyStorage()
    }

    static func load() -> WidgetSnapshot {
        if let snapshot = storage.load(WidgetSnapshot.self, key: key) {
            return sanitized(snapshot)
        }

        if
            let data = SharedContainer.defaults.data(forKey: key),
            let legacy = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        {
            let sanitizedSnapshot = sanitized(legacy)
            storage.save(sanitizedSnapshot, key: key)
            scrubLegacyStorage()
            return sanitizedSnapshot
        }

        scrubLegacyStorage()
        return .empty
    }

    static func clear() {
        storage.clear(key: key)
        scrubLegacyStorage()
    }

    private static func sanitized(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
        WidgetSnapshot(
            safeMessage: snapshot.sanitizedMessage,
            latestVerdict: snapshot.latestVerdict,
            latestScenario: snapshot.latestScenario,
            updatedAt: snapshot.updatedAt
        )
    }

    private static func scrubLegacyStorage() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
