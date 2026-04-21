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
        self.prompt = Self.cleanedPrompt(prompt)
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

    var sanitizedPrompt: String {
        Self.cleanedPrompt(prompt) ?? ""
    }

    var decisionIntentEnvelope: DecisionIntentEnvelope {
        if let scenario {
            return .quickCapture(
                entrySource: entrySource,
                scenario: scenario,
                promptSeed: prompt,
                requestedAt: requestedAt,
                expiresAt: expiresAt
            )
        }

        if let preferredMode {
            return .openMode(
                entrySource: entrySource,
                mode: preferredMode,
                promptSeed: prompt,
                requestedAt: requestedAt,
                expiresAt: expiresAt
            )
        }

        return .routedInput(
            entrySource: entrySource,
            promptSeed: prompt,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func quickCapture(
        id: UUID = UUID(),
        entrySource: EntrySource,
        scenario: ScenarioType? = nil,
        prompt: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> PendingLaunchRequest {
        PendingLaunchRequest(
            id: id,
            entrySource: entrySource,
            preferredMode: nil,
            scenario: scenario,
            prompt: prompt,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func openMode(
        id: UUID = UUID(),
        entrySource: EntrySource,
        mode: DecisionMode,
        prompt: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> PendingLaunchRequest {
        PendingLaunchRequest(
            id: id,
            entrySource: entrySource,
            preferredMode: mode,
            scenario: nil,
            prompt: prompt,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func routedPrompt(
        id: UUID = UUID(),
        entrySource: EntrySource,
        prompt: String,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> PendingLaunchRequest {
        PendingLaunchRequest(
            id: id,
            entrySource: entrySource,
            preferredMode: nil,
            scenario: nil,
            prompt: prompt,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    private static func cleanedPrompt(_ text: String?) -> String? {
        let cleanedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText?.isEmpty == true ? nil : cleanedText
    }
}

private struct PendingLaunchRequestEnvelope: Codable, Equatable {
    var id: UUID
    var kindRaw: String?
    var entrySource: EntrySource
    var preferredModeRaw: String?
    var scenarioRaw: String?
    var triggerReason: String?
    var controlEntryKindID: String?
    var requestedAt: Date
    var expiresAt: Date
    var schemaVersion: Int
    var hasProtectedPayload: Bool

    init(request: PendingLaunchRequest, preservingProtectedPayload: Bool = true) {
        self.id = request.id
        self.kindRaw = nil
        self.entrySource = request.entrySource
        self.preferredModeRaw = request.preferredModeRaw
        self.scenarioRaw = request.scenarioRaw
        self.triggerReason = nil
        self.controlEntryKindID = nil
        self.requestedAt = request.requestedAt
        self.expiresAt = request.expiresAt
        self.schemaVersion = request.schemaVersion
        self.hasProtectedPayload = preservingProtectedPayload && !request.sanitizedPrompt.isEmpty
    }

    init(envelope: DecisionIntentEnvelope, preservingProtectedPayload: Bool = true) {
        self.id = envelope.id
        self.kindRaw = envelope.kind.rawValue
        self.entrySource = envelope.entrySource
        self.preferredModeRaw = envelope.preferredModeRaw
        self.scenarioRaw = envelope.scenarioRaw
        self.triggerReason = envelope.triggerReason
        self.controlEntryKindID = envelope.controlEntryKindID
        self.requestedAt = envelope.requestedAt
        self.expiresAt = envelope.expiresAt
        self.schemaVersion = BeforePolicy.LaunchRequests.schemaVersion
        self.hasProtectedPayload = preservingProtectedPayload && !envelope.sanitizedPromptSeed.isEmpty
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
    private static let payloadKeyPrefix = "before.pending.launch.request.payload."
    private static let queueStorage = CodableStateStorage.sharedProtected

    static func enqueue(_ request: PendingLaunchRequest) {
        enqueueStoredEnvelope(
            PendingLaunchRequestEnvelope(request: request),
            protectedPrompt: request.prompt
        )
    }

    static func enqueue(_ envelope: DecisionIntentEnvelope) {
        enqueueStoredEnvelope(
            PendingLaunchRequestEnvelope(envelope: envelope),
            protectedPrompt: envelope.promptSeed
        )
    }

    static func set(_ request: PendingLaunchRequest) {
        enqueue(request)
    }

    static func set(_ envelope: DecisionIntentEnvelope) {
        enqueue(envelope)
    }

    private static func enqueueStoredEnvelope(
        _ envelope: PendingLaunchRequestEnvelope,
        protectedPrompt: String?
    ) {
        let current = loadStoredEnvelopeQueue()
        let merged = Array(
            (current.filter { $0.id != envelope.id } + [envelope])
                .suffix(BeforePolicy.LaunchRequests.maxQueuedRequests)
        )

        guard persistProtectedPayload(for: envelope.id, prompt: protectedPrompt) else { return }
        let queuePersisted = persistQueue(merged)
        if !queuePersisted {
            if !current.contains(where: { $0.id == envelope.id }) {
                clearProtectedPayload(for: envelope.id)
            }
            cleanupOrphanProtectedPayloads(referencedBy: current)
            scrubLegacyStorage()
            return
        }

        pruneProtectedPayloads(previousQueue: current, nextQueue: merged)
        cleanupOrphanProtectedPayloads(referencedBy: merged)
        scrubLegacyStorage()
    }

    static func consume() -> PendingLaunchRequest? {
        consumeStoredValue(materialize)
    }

    static func consumeEnvelope() -> DecisionIntentEnvelope? {
        consumeStoredValue(materializeDecisionIntentEnvelope)
    }

    static func consumeDecisionIntentEnvelope() -> DecisionIntentEnvelope? {
        consumeEnvelope()
    }

    static func clear() {
        loadStoredEnvelopeQueue()
            .forEach { clearProtectedPayload(for: $0.id) }
        queueStorage.clear(key: key)
        cleanupOrphanProtectedPayloads(referencedBy: [])
        scrubLegacyStorage()
    }

    static func normalizedQueue(from data: Data?, now: Date = .now) -> [PendingLaunchRequest] {
        normalizedEnvelopeQueue(from: data, now: now).map(materialize)
    }

    static func normalizedDecisionIntentEnvelopeQueue(
        from data: Data?,
        now: Date = .now
    ) -> [DecisionIntentEnvelope] {
        normalizedEnvelopeQueue(from: data, now: now).map(materializeDecisionIntentEnvelope)
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
            let persisted = persistQueue(valid)
            if persisted {
                pruneProtectedPayloads(previousQueue: stored, nextQueue: valid)
                cleanupOrphanProtectedPayloads(referencedBy: valid)
            } else {
                cleanupOrphanProtectedPayloads(referencedBy: stored)
            }
        } else {
            cleanupOrphanProtectedPayloads(referencedBy: valid)
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
        cleanupOrphanProtectedPayloads(referencedBy: [])
    }

    private static func materialize(_ envelope: PendingLaunchRequestEnvelope) -> PendingLaunchRequest {
        return PendingLaunchRequest(
            id: envelope.id,
            entrySource: envelope.entrySource,
            preferredMode: envelope.preferredMode,
            scenario: envelope.scenario,
            prompt: protectedPrompt(for: envelope),
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt,
            schemaVersion: envelope.schemaVersion
        )
    }

    private static func materializeDecisionIntentEnvelope(
        _ envelope: PendingLaunchRequestEnvelope
    ) -> DecisionIntentEnvelope {
        let kind: DecisionIntentKind
        if let storedKind = envelope.kindRaw.flatMap(DecisionIntentKind.init(rawValue:)) {
            kind = storedKind
        } else if envelope.scenario != nil {
            kind = .quickCapture
        } else if envelope.preferredMode != nil {
            kind = .openMode
        } else {
            kind = .routedInput
        }

        return DecisionIntentEnvelope(
            id: envelope.id,
            kind: kind,
            sourceSurface: envelope.entrySource.intentSourceSurface,
            entrySource: envelope.entrySource,
            preferredMode: envelope.preferredMode,
            scenario: envelope.scenario,
            promptSeed: protectedPrompt(for: envelope),
            triggerReason: envelope.triggerReason,
            controlEntryKindID: envelope.controlEntryKindID,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt
        )
    }

    private static func protectedPrompt(for envelope: PendingLaunchRequestEnvelope) -> String? {
        guard envelope.hasProtectedPayload else { return nil }
        return CodableStateStorage.sharedProtected.load(
            PendingLaunchRequestPayload.self,
            key: payloadKey(for: envelope.id)
        )?.prompt
    }

    private static func consumeStoredValue<T>(
        _ materialize: (PendingLaunchRequestEnvelope) -> T
    ) -> T? {
        var queue = loadStoredEnvelopeQueue()
        guard !queue.isEmpty else {
            queueStorage.clear(key: key)
            cleanupOrphanProtectedPayloads(referencedBy: [])
            scrubLegacyStorage()
            return nil
        }

        let next = queue.removeFirst()
        let persisted = persistQueue(queue)
        if !persisted {
            return nil
        }
        let restored = materialize(next)
        cleanupOrphanProtectedPayloads(referencedBy: queue)
        defer { clearProtectedPayload(for: next.id) }
        return restored
    }

    @discardableResult
    private static func persistProtectedPayload(for id: UUID, prompt: String?) -> Bool {
        let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else {
            clearProtectedPayload(for: id)
            return true
        }

        return CodableStateStorage.sharedProtected.save(
            PendingLaunchRequestPayload(prompt: prompt),
            key: payloadKey(for: id)
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
        "\(payloadKeyPrefix)\(id.uuidString.lowercased())"
    }

    @discardableResult
    private static func persistQueue(_ requests: [PendingLaunchRequestEnvelope]) -> Bool {
        guard !requests.isEmpty else {
            queueStorage.clear(key: key)
            return true
        }

        return queueStorage.save(requests, key: key)
    }

    private static func cleanupOrphanProtectedPayloads(referencedBy queue: [PendingLaunchRequestEnvelope]) {
        let retainedIDs = Set(queue.filter(\.hasProtectedPayload).map(\.id))
        SharedProtectedStateStore.storedKeys(withPrefix: payloadKeyPrefix).forEach { storedKey in
            guard
                let id = payloadID(from: storedKey),
                !retainedIDs.contains(id)
            else {
                return
            }
            CodableStateStorage.sharedProtected.clear(key: storedKey)
        }
    }

    private static func payloadID(from storedKey: String) -> UUID? {
        guard storedKey.hasPrefix(payloadKeyPrefix) else { return nil }
        let suffix = storedKey.dropFirst(payloadKeyPrefix.count)
        return UUID(uuidString: String(suffix))
    }

    private static func scrubLegacyStorage() {
        SharedContainer.defaults.removeObject(forKey: key)
    }
}
