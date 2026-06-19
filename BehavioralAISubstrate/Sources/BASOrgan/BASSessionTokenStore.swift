import Foundation

/// Cross-turn corpus pool: one `BASSuffixAutomaton` per conversation (`sessionID`), so a later turn's draft can
/// reuse tokens from earlier turns of the SAME conversation. Mirrors the `MLXOrganAdapter.sessions` pool
/// (keyed by conversation, explicitly cleared via `clearSession`/`clearAllSessions`) but holds only token
/// corpora — plain RAM, no MLX residency. Doubly bounded: each automaton caps its corpus (`capacityPerSession`),
/// and the pool caps the number of live conversations (`maxSessions`, LRU-evicted). Evicting an idle
/// conversation only forfeits its cross-turn speedup if it later resumes — never correctness (the verifier still
/// emits the target's argmax; the source merely falls back to current-sequence scope).
///
/// Pure value type (BASOrgan, no MLX) → host-unit-testable. Intended to live as actor-isolated state inside
/// `MLXOrganAdapter`, so its `mutating` methods are serialized by the actor.
public struct BASSessionTokenStore: Sendable {

    public let ngramMin: Int
    public let ngramMax: Int
    public let numDraftTokens: Int
    /// Per-conversation corpus cap (forwarded to each `BASSuffixAutomaton`).
    public let capacityPerSession: Int
    /// Max live conversations; the least-recently-appended is evicted past this.
    public let maxSessions: Int

    private var automata: [String: BASSuffixAutomaton]
    /// Least-recently-used first, most-recently-used last.
    private var lru: [String]

    public init(
        ngramMin: Int = 1, ngramMax: Int = 3, numDraftTokens: Int = 4,
        capacityPerSession: Int = 8192, maxSessions: Int = 16
    ) {
        self.ngramMin = max(1, ngramMin)
        self.ngramMax = max(self.ngramMin, ngramMax)
        self.numDraftTokens = max(1, numDraftTokens)
        self.capacityPerSession = capacityPerSession
        self.maxSessions = max(1, maxSessions)
        self.automata = [:]
        self.lru = []
    }

    /// Number of live conversations.
    public var sessionCount: Int { automata.count }

    /// Append one committed token to the conversation's corpus (creating it on first use, LRU-evicting if full).
    public mutating func append(session: String, token: Int) {
        ensureSession(session)
        automata[session]?.append(token)   // dict modify-accessor → in-place, no COW copy
        touch(session)
        evictIfNeeded()
    }

    /// Append a run of committed tokens (a prior turn, the prompt, or a decoded turn) to the conversation.
    public mutating func append(session: String, contentsOf tokens: [Int]) {
        guard !tokens.isEmpty else { return }
        ensureSession(session)
        automata[session]?.append(contentsOf: tokens)
        touch(session)
        evictIfNeeded()
    }

    /// The cross-turn draft for the conversation — `[]` if the conversation is unknown (falls back to no draft).
    public func propose(session: String, k: Int? = nil) -> [Int] {
        automata[session]?.propose(k: k) ?? []
    }

    /// The retained corpus for the conversation (for seeding / inspection) — `[]` if unknown.
    public func tokens(session: String) -> [Int] {
        automata[session]?.currentTokens() ?? []
    }

    /// Drop one conversation's corpus (mirrors `clearSession`).
    public mutating func clear(session: String) {
        automata.removeValue(forKey: session)
        if let i = lru.firstIndex(of: session) { lru.remove(at: i) }
    }

    /// Drop all corpora (mirrors `clearAllSessions`).
    public mutating func clearAll() {
        automata.removeAll()
        lru.removeAll()
    }

    // MARK: - internals

    private mutating func ensureSession(_ session: String) {
        if automata[session] == nil {
            automata[session] = BASSuffixAutomaton(
                ngramMin: ngramMin, ngramMax: ngramMax,
                numDraftTokens: numDraftTokens, capacity: capacityPerSession)
        }
    }

    private mutating func touch(_ session: String) {
        if let i = lru.firstIndex(of: session) { lru.remove(at: i) }
        lru.append(session)
    }

    private mutating func evictIfNeeded() {
        while automata.count > maxSessions, let oldest = lru.first {
            lru.removeFirst()
            automata.removeValue(forKey: oldest)
        }
    }
}
