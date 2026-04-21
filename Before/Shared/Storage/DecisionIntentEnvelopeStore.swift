import Foundation

enum DecisionIntentEnvelopeStore {
    private static let key = "before.intent.envelopes"
    private static let storage = CodableStateStorage.sharedProtected

    static func enqueue(_ envelope: DecisionIntentEnvelope) {
        let normalizedEnvelope = normalize(envelope)
        let current = loadQueue()
        let merged = Array(
            (current.filter { $0.id != normalizedEnvelope.id } + [normalizedEnvelope])
                .suffix(BeforePolicy.LaunchRequests.maxQueuedRequests)
        )
        storage.save(merged, key: key)
    }

    static func consume(now: Date = .now) -> DecisionIntentEnvelope? {
        var queue = loadQueue(now: now)
        guard !queue.isEmpty else {
            storage.clear(key: key)
            return nil
        }
        let next = queue.removeFirst()
        storage.save(queue, key: key)
        return next
    }

    static func loadQueue(now: Date = .now) -> [DecisionIntentEnvelope] {
        guard let queue = storage.load([DecisionIntentEnvelope].self, key: key) else {
            return []
        }
        let valid = queue
            .filter { $0.expiresAt > now }
            .map(normalize)
        if valid != queue {
            storage.save(valid, key: key)
        }
        return valid
    }

    static func clear() {
        storage.clear(key: key)
    }

    private static func normalize(_ envelope: DecisionIntentEnvelope) -> DecisionIntentEnvelope {
        guard envelope.kind == .openEvolutionControl else {
            return envelope
        }

        return .openEvolutionControl(
            id: envelope.id,
            entrySource: envelope.entrySource,
            promptSeed: envelope.promptSeed,
            instructionDetail: envelope.instructionDetail,
            triggerReason: envelope.triggerReason,
            controlEntryKindID: envelope.controlEntryKindID,
            requestedAt: envelope.requestedAt,
            expiresAt: envelope.expiresAt
        )
    }
}
