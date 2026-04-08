import Foundation

struct PendingLaunchRequest: Codable, Sendable, Equatable {
    var id: UUID
    var entrySource: EntrySource
    var preferredModeRaw: String?
    var scenarioRaw: String?
    var prompt: String?
    var requestedAt: Date
    var expiresAt: Date
    var schemaVersion: Int

    init(
        id: UUID = UUID(),
        entrySource: EntrySource,
        preferredMode: DecisionMode? = nil,
        scenario: ScenarioType? = nil,
        prompt: String? = nil,
        requestedAt: Date,
        expiresAt: Date? = nil,
        schemaVersion: Int = BeforePolicy.LaunchRequests.schemaVersion
    ) {
        self.id = id
        self.entrySource = entrySource
        self.preferredModeRaw = preferredMode?.rawValue
        self.scenarioRaw = scenario?.rawValue
        self.prompt = prompt
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt ?? requestedAt.addingTimeInterval(BeforePolicy.LaunchRequests.expirationInterval)
        self.schemaVersion = schemaVersion
    }

    var isExpired: Bool {
        expiresAt <= .now
    }

    var preferredMode: DecisionMode? {
        preferredModeRaw.flatMap(DecisionMode.init(rawValue:))
    }

    var scenario: ScenarioType? {
        scenarioRaw.flatMap(ScenarioType.init(rawValue:))
    }
}

private struct LegacyPendingLaunchRequest: Codable {
    var entrySource: EntrySource
    var requestedAt: Date
}

enum PendingLaunchRequestStore {
    private static let key = "before.pending.launch.request"

    static func enqueue(_ request: PendingLaunchRequest) {
        let current = normalizedQueue(from: SharedContainer.defaults.data(forKey: key))
        let merged = Array((current + [request]).suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
        save(merged)
    }

    static func set(_ request: PendingLaunchRequest) {
        enqueue(request)
    }

    static func consume() -> PendingLaunchRequest? {
        var queue = normalizedQueue(from: SharedContainer.defaults.data(forKey: key))
        guard !queue.isEmpty else {
            SharedContainer.defaults.removeObject(forKey: key)
            return nil
        }

        let next = queue.removeFirst()
        save(queue)
        return next
    }

    static func clear() {
        SharedContainer.defaults.removeObject(forKey: key)
    }

    static func normalizedQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequest] {
        let decoded: [PendingLaunchRequest]

        if
            let data,
            let requests = try? JSONDecoder().decode([PendingLaunchRequest].self, from: data)
        {
            decoded = requests
        } else if
            let data,
            let legacyRequest = try? JSONDecoder().decode(LegacyPendingLaunchRequest.self, from: data)
        {
            decoded = [PendingLaunchRequest(entrySource: legacyRequest.entrySource, requestedAt: legacyRequest.requestedAt)]
        } else {
            decoded = []
        }

        let valid = decoded.filter { $0.expiresAt > now }
        return Array(valid.suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
    }

    private static func save(_ requests: [PendingLaunchRequest]) {
        guard !requests.isEmpty else {
            clear()
            return
        }

        guard let data = try? JSONEncoder().encode(requests) else { return }
        SharedContainer.defaults.set(data, forKey: key)
    }
}
