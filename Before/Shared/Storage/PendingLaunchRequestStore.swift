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

private enum PendingLaunchRequestEnvelopeDecodeResult {
    case missing
    case success([PendingLaunchRequestEnvelope])
    case unreadable
}

enum PendingLaunchRequestStore {
    private static let key = "before.pending.launch.request"
    private static let queueStorage = CodableStateStorage.sharedProtected

    static func enqueue(_ request: PendingLaunchRequest) {
        persistProtectedPayload(for: request)

        let current = loadStoredEnvelopeQueue()
        let merged = Array((current + [PendingLaunchRequestEnvelope(request: request)]).suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
        pruneProtectedPayloads(previousQueue: current, nextQueue: merged)
        save(merged)
    }

    static func set(_ request: PendingLaunchRequest) {
        enqueue(request)
    }

    static func consume() -> PendingLaunchRequest? {
        var queue = loadStoredEnvelopeQueue()
        guard !queue.isEmpty else {
            queueStorage.clear(key: key)
            scrubLegacyStorage()
            return nil
        }

        let next = queue.removeFirst()
        save(queue)
        defer { clearProtectedPayload(for: next.id) }
        return materialize(next)
    }

    static func clear() {
        loadStoredEnvelopeQueue()
            .forEach { clearProtectedPayload(for: $0.id) }
        queueStorage.clear(key: key)
        scrubLegacyStorage()
    }

    static func normalizedQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequest] {
        normalizedEnvelopeQueue(from: data, now: now).map(materialize)
    }

    private static func loadStoredEnvelopeQueue(now: Date = .now) -> [PendingLaunchRequestEnvelope] {
        scrubLegacyStorage()
        let storedData = queueStorage.loadData(key: key)
        let stored: [PendingLaunchRequestEnvelope]
        switch decodeEnvelopeQueue(from: storedData) {
        case .missing:
            stored = []
        case .success(let queue):
            stored = queue
        case .unreadable:
            quarantineUnreadableQueuePayload(storedData!)
            return []
        }

        let valid = Array(
            stored
                .filter { $0.expiresAt > now }
                .suffix(BeforePolicy.LaunchRequests.maxQueuedRequests)
        )

        if stored != valid {
            pruneProtectedPayloads(previousQueue: stored, nextQueue: valid)
            persistQueue(valid)
        }

        return valid
    }

    private static func normalizedEnvelopeQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequestEnvelope] {
        let decoded: [PendingLaunchRequestEnvelope]
        switch decodeEnvelopeQueue(from: data) {
        case .missing, .unreadable:
            decoded = []
        case .success(let queue):
            decoded = queue
        }
        let valid = decoded.filter { $0.expiresAt > now }
        return Array(valid.suffix(BeforePolicy.LaunchRequests.maxQueuedRequests))
    }

    private static func decodeEnvelopeQueue(from data: Data?) -> PendingLaunchRequestEnvelopeDecodeResult {
        guard let data else { return .missing }
        if
            let requests = try? JSONDecoder().decode([PendingLaunchRequestEnvelope].self, from: data)
        {
            return .success(requests)
        }

        if
            let requests = try? JSONDecoder().decode([PendingLaunchRequest].self, from: data)
        {
            return .success(
                requests.map { PendingLaunchRequestEnvelope(request: $0, preservingProtectedPayload: false) }
            )
        }

        if
            let legacyRequest = try? JSONDecoder().decode(LegacyPendingLaunchRequest.self, from: data)
        {
            return .success([
                PendingLaunchRequestEnvelope(
                    request: PendingLaunchRequest(entrySource: legacyRequest.entrySource, requestedAt: legacyRequest.requestedAt)
                )
            ])
        }

        return .unreadable
    }

    private static func quarantineUnreadableQueuePayload(_ data: Data) {
        SharedProtectedStateStore.quarantineData(
            data,
            key: key,
            operation: "loading pending launch queue",
            reason: "Unreadable pending launch queue was isolated to protect launch-state continuity."
        )
        queueStorage.clear(key: key)
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
        persistQueue(requests)
        scrubLegacyStorage()
    }

    private static func persistQueue(_ requests: [PendingLaunchRequestEnvelope]) {
        guard !requests.isEmpty else {
            queueStorage.clear(key: key)
            return
        }

        queueStorage.save(requests, key: key)
    }

    private static func scrubLegacyStorage() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
