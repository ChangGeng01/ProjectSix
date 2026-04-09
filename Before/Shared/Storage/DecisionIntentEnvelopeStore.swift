import Foundation

enum DecisionIntentEnvelopeStore {
    private static let key = "before.intent.envelopes"
    private static let storage = CodableStateStorage.sharedProtected

    static func enqueue(_ envelope: DecisionIntentEnvelope) {
        let current = loadQueue()
        let merged = Array(
            (current.filter { $0.id != envelope.id } + [envelope])
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
        let valid = queue.filter { $0.expiresAt > now }
        if valid.count != queue.count {
            storage.save(valid, key: key)
        }
        return valid
    }

    static func clear() {
        storage.clear(key: key)
    }
}
