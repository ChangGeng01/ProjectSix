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

private struct PendingLaunchRequestEnvelope: Codable, Equatable {
    var id: UUID
    var entrySource: EntrySource
    var preferredModeRaw: String?
    var scenarioRaw: String?
    var requestedAt: Date
    var expiresAt: Date
    var schemaVersion: Int
    var hasProtectedPayload: Bool

    init(request: PendingLaunchRequest, preservingProtectedPayload: Bool = true) {
        self.id = request.id
        self.entrySource = request.entrySource
        self.preferredModeRaw = request.preferredModeRaw
        self.scenarioRaw = request.scenarioRaw
        self.requestedAt = request.requestedAt
        self.expiresAt = request.expiresAt
        self.schemaVersion = request.schemaVersion
        self.hasProtectedPayload = preservingProtectedPayload
            && !(request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var preferredMode: DecisionMode? {
        preferredModeRaw.flatMap(DecisionMode.init(rawValue:))
    }

    var scenario: ScenarioType? {
        scenarioRaw.flatMap(ScenarioType.init(rawValue:))
    }
}

private struct PendingLaunchRequestPayload: Codable, Equatable {
    var prompt: String?
}

private struct LegacyPendingLaunchRequest: Codable {
    var entrySource: EntrySource
    var requestedAt: Date
}

enum PendingLaunchRequestStore {
    private static let key = "before.pending.launch.request"

    static func enqueue(_ request: PendingLaunchRequest) {
        persistProtectedPayload(for: request)

        let current = normalizedEnvelopeQueue(from: SharedContainer.defaults.data(forKey: key))
        let merged = Array((current + [PendingLaunchRequestEnvelope(request: request)]).suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
        pruneProtectedPayloads(previousQueue: current, nextQueue: merged)
        save(merged)
    }

    static func set(_ request: PendingLaunchRequest) {
        enqueue(request)
    }

    static func consume() -> PendingLaunchRequest? {
        var queue = normalizedEnvelopeQueue(from: SharedContainer.defaults.data(forKey: key))
        guard !queue.isEmpty else {
            SharedContainer.defaults.removeObject(forKey: key)
            return nil
        }

        let next = queue.removeFirst()
        save(queue)
        defer { clearProtectedPayload(for: next.id) }
        return materialize(next)
    }

    static func clear() {
        normalizedEnvelopeQueue(from: SharedContainer.defaults.data(forKey: key))
            .forEach { clearProtectedPayload(for: $0.id) }
        SharedContainer.defaults.removeObject(forKey: key)
    }

    static func normalizedQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequest] {
        normalizedEnvelopeQueue(from: data, now: now).map(materialize)
    }

    private static func normalizedEnvelopeQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequestEnvelope] {
        let decoded: [PendingLaunchRequestEnvelope]
        if
            let data,
            let requests = try? JSONDecoder().decode([PendingLaunchRequestEnvelope].self, from: data)
        {
            decoded = requests
        } else if
            let data,
            let requests = try? JSONDecoder().decode([PendingLaunchRequest].self, from: data)
        {
            decoded = requests.map { PendingLaunchRequestEnvelope(request: $0, preservingProtectedPayload: false) }
        } else if
            let data,
            let legacyRequest = try? JSONDecoder().decode(LegacyPendingLaunchRequest.self, from: data)
        {
            decoded = [
                PendingLaunchRequestEnvelope(
                    request: PendingLaunchRequest(entrySource: legacyRequest.entrySource, requestedAt: legacyRequest.requestedAt)
                )
            ]
        } else {
            decoded = []
        }

        let valid = decoded.filter { $0.expiresAt > now }
        return Array(valid.suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
    }

    private static func materialize(_ envelope: PendingLaunchRequestEnvelope) -> PendingLaunchRequest {
        let payload: PendingLaunchRequestPayload?
        if envelope.hasProtectedPayload {
            payload = CodableStateStorage.sharedProtected.load(
                PendingLaunchRequestPayload.self,
                key: payloadKey(for: envelope.id)
            )
        } else {
            payload = nil
        }

        return PendingLaunchRequest(
            id: envelope.id,
            entrySource: envelope.entrySource,
            preferredMode: envelope.preferredMode,
            scenario: envelope.scenario,
            prompt: payload?.prompt,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt,
            schemaVersion: envelope.schemaVersion
        )
    }

    private static func persistProtectedPayload(for request: PendingLaunchRequest) {
        guard
            let prompt = request.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
            !prompt.isEmpty
        else {
            clearProtectedPayload(for: request.id)
            return
        }

        CodableStateStorage.sharedProtected.save(
            PendingLaunchRequestPayload(prompt: prompt),
            key: payloadKey(for: request.id)
        )
    }

    private static func clearProtectedPayload(for id: UUID) {
        CodableStateStorage.sharedProtected.clear(key: payloadKey(for: id))
    }

    private static func pruneProtectedPayloads(
        previousQueue: [PendingLaunchRequestEnvelope],
        nextQueue: [PendingLaunchRequestEnvelope]
    ) {
        let retainedIDs = Set(nextQueue.map(\.id))
        previousQueue
            .filter { !retainedIDs.contains($0.id) }
            .forEach { clearProtectedPayload(for: $0.id) }
    }

    private static func payloadKey(for id: UUID) -> String {
        "before.pending.launch.request.payload.\(id.uuidString.lowercased())"
    }

    private static func save(_ requests: [PendingLaunchRequestEnvelope]) {
        guard !requests.isEmpty else {
            clear()
            return
        }

        guard let data = try? JSONEncoder().encode(requests) else { return }
        SharedContainer.defaults.set(data, forKey: key)
    }
}
