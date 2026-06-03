// MARK: - BASL8RoutedMemoryService — Step 2 (routed vector memory: Rust-SIMD cosine + OPTIONAL SQL/event store)
//
// A `BASMemoryServicing` conformer that composes the production L8 backends behind the SAME
// synchronous `retrieve()` the protocol requires — replacing the in-memory Jaccard recall of
// `BASMLMemoryService` with embedding-based (vector) retrieval over a persistent atom store.
//
// ## The load-bearing constraint (chapter 883)
//
// `BASMemoryServicing.retrieve(...)` and `BASEBrainRuntimeCoordinator.runTurn(...)` are
// SYNCHRONOUS, and chapter 883 formally DECLINED making them async (a substrate-wide breaking
// change pinned by `testMemoryServicingRetrieveIsSync`). Every real backend
// (`BASSQLiteMemoryAtomStore`, `BASEventSourcedMemoryAtomStore`, `BASRoutedVectorIndexStorage`)
// is an async actor, and `BASEmbeddingProvider.embed` is async. This service therefore:
//
//   • keeps `retrieve()` SYNC by reading a PRE-MATERIALIZED in-memory snapshot and scoring it
//     with `BASAutoRouteRanker.cosineSimilarity` (a SYNC, Rust-SIMD-routed cosine) over a SYNC
//     query embedding — NO `await`, NO blocking semaphore (the latter is an anti-pattern flagged
//     at `BASLLMNeuralCoreService.swift:16`);
//   • touches the async backends ONLY in `refresh()` / `drainIntents()`, which the host calls at
//     session boundaries / between turns.
//
// ## What "Rust+SQL vector/event/log/provenance" maps to here
//   • vector  — embedding cosine top-K, routed to Rust SIMD via `BASAutoRouteRanker`.
//   • SQL/event — the injected `BASMemoryAtomStore` (a `BASSQLiteMemoryAtomStore` for SQL, or a
//     `BASEventSourcedMemoryAtomStore` for event-sourcing).
//   • event/log/provenance — when the injected store is a `BASEventSourcedMemoryAtomStore`, a
//     governance write in `drainIntents()` appends a replayable event (the provenance trail).
//     PRECONDITION (honest): the store's `updateGovernanceStatus` only records an event for an atom
//     ALREADY in its projection — i.e. the host must have `admit()`ed the atoms into the SAME
//     event-sourced store first. This service reads atoms via `loadAllAtoms` and does NOT `admit()`
//     them itself, so the event trail materializes only under that host wiring (it is the Step-2
//     flip's job to establish it; the current unit tests use an in-memory store and don't cover it).
//
// ## Embedding seam
//
// The query/atom embedder is an injected SYNC closure (`SyncEmbed`). In production it is backed by
// the host-supplied semantic model (e.g. a CoreML `.mlpackage` — CoreML prediction is synchronous);
// `lexicalEmbed(...)` is a deterministic, model-free default (bag-of-hashed-tokens) suitable as a
// fallback and for hermetic tests. A NON-semantic embedder is fine for opt-in proving but MUST NOT
// be the basis of a default-flip (亏的不要上) — see ADR-033.
//
// ## Posture
//
// ADR-014 OPT-IN: this service is NOT the brain's default. Vector ≠ Jaccard, so its output is
// intentionally NOT byte-equal to `BASMLMemoryService`; the default-flip is a separate, gated,
// model-conditioned step. Constructing this service changes nothing until a host opts in.

import Foundation
import BASRuntimeCore
import BASMemory
import BASOrchestration

public final class BASL8RoutedMemoryService: BASMemoryServicing,
    @unchecked Sendable
{

    /// Named retrieval parameters (chapter 一百八十五 — no magic literals).
    public enum Parameters {
        /// Top-K atoms returned per `retrieve()`.
        public static let topK: Int = 3
        /// Cosine-similarity floor below which an atom is not relevant. Cosine ∈ [-1, 1];
        /// 0.30 mirrors the Jaccard floor's "meaningful overlap" intent for the lexical default.
        public static let relevanceFloor: Float = 0.30
        /// Source identifier stamped on atoms surfaced by this backend.
        public static let atomSource: String =
            "bas.cognitive.brain.memory.routed_vector"
        /// Default embedding dimension for the model-free lexical embedder.
        public static let defaultLexicalDimension: Int = 64
    }

    /// Synchronous embedding seam: text → dense vector. Backed by the host's semantic model in
    /// production; `lexicalEmbed(...)` is the model-free default.
    public typealias SyncEmbed = @Sendable (String) -> [Float]

    /// Async source of the atoms to materialize into the retrieval snapshot. The host wires this
    /// to its concrete store (e.g. `{ (try? await sqliteStore.allAtoms()) ?? [] }`); the bulk-read
    /// is intentionally NOT on the `BASMemoryAtomStore` protocol, so it is supplied as a closure.
    public typealias LoadAllAtoms = @Sendable () async -> [BASGovernedMemory]

    // MARK: - Injected dependencies

    private let loadAllAtoms: LoadAllAtoms
    private let syncEmbed: SyncEmbed
    private let embeddingDimension: Int
    private let restrictedMemoryDomains: [String]
    private let topK: Int
    private let relevanceFloor: Float
    /// Write target for promote/freeze. Wiring a `BASEventSourcedMemoryAtomStore` yields the
    /// event/log/provenance trail. `nil` ⇒ writes are skipped (read-only retrieval).
    private let atomStore: (any BASMemoryAtomStore)?

    // MARK: - State (NSLock-guarded; the service is a value-free reference type)

    private struct SnapshotEntry {
        let atomID: String
        let domain: String
        let embedding: [Float]
        let atom: BASMemoryAtom
    }

    private let lock = NSLock()
    private var snapshot: [SnapshotEntry] = []
    private var promoteIntents: [String] = []   // atom IDs to mark governed
    private var freezeIntents: [String] = []     // atom IDs to mark archived/frozen
    private var selfPopSeq: Int = 0              // monotonic id source for self-populated atoms

    /// When true, retrieve() also writes the current frame as a new (vector-embedded) atom into the
    /// in-memory snapshot, so the service accumulates recall on its own — a drop-in for
    /// BASMLMemoryService's self-managed LRU, but vector-scored. Bounded by `selfPopulateCap`.
    private let selfPopulate: Bool
    private let selfPopulateCap: Int

    public init(
        loadAllAtoms: @escaping LoadAllAtoms,
        syncEmbed: @escaping SyncEmbed,
        embeddingDimension: Int,
        restrictedMemoryDomains: [String] = [],
        topK: Int = Parameters.topK,
        relevanceFloor: Float = Parameters.relevanceFloor,
        atomStore: (any BASMemoryAtomStore)? = nil,
        selfPopulate: Bool = false,
        selfPopulateCap: Int = 64
    ) {
        self.loadAllAtoms = loadAllAtoms
        self.syncEmbed = syncEmbed
        self.embeddingDimension = embeddingDimension
        self.restrictedMemoryDomains = restrictedMemoryDomains
        self.topK = topK
        self.relevanceFloor = relevanceFloor
        self.atomStore = atomStore
        self.selfPopulate = selfPopulate
        self.selfPopulateCap = max(1, selfPopulateCap)
    }

    /// Synchronous critical section. Safe to call from async contexts because it never holds the
    /// lock across a suspension point (NSLock.lock/unlock are unavailable directly in async code).
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - BASMemoryServicing (SYNC hot path — ch883)

    public func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        let queryText = Self.queryText(from: decomposeFrame)
        let query = syncEmbed(queryText)

        let snap = withLock { snapshot }

        // Rust-SIMD-routed cosine over the pre-materialized snapshot — fully synchronous.
        let scored: [(score: Float, entry: SnapshotEntry)] = snap.map { entry in
            let score = BASAutoRouteRanker
                .cosineSimilarity(query, entry.embedding).value
            return (score, entry)
        }
        let above = scored.filter { $0.score >= relevanceFloor }

        // Constitution domain filter (no-op when restrictedMemoryDomains is empty — ADR-014).
        let filtered = BASConstitutionEnforcer.filterMemoryDomains(
            above.map { (domain: $0.entry.domain, payload: $0) },
            restrictedMemoryDomains: restrictedMemoryDomains)

        let top = filtered.allowed
            .sorted { $0.score > $1.score }
            .prefix(topK)

        let atoms: [BASMemoryAtom] = top.map { tuple in
            // Echo the cosine score as the surfaced confidence (real per-atom relevance).
            var atom = tuple.entry.atom
            atom.confidence = Double(tuple.score)
            return atom
        }

        let bundle = BASMemoryBundle(
            atoms: atoms,
            retrievalTags: Self.retrievalTags(
                count: atoms.count,
                dropped: filtered.droppedReasonCodes),
            conflictRefs: atoms.filter(\.frozen).map(\.memoryID),
            activeHostVersion: hostContext.activeVersion)

        // Self-population (drop-in recall): append THIS frame as a new vector-embedded atom for
        // FUTURE turns. Appended AFTER scoring, so it is NOT in the current bundle — single-turn
        // determinism is preserved (a fresh service returns an empty bundle on turn 1). Bounded LRU.
        if selfPopulate && !queryText.isEmpty {
            withLock {
                let id = "memory.routed.\(selfPopSeq)"
                selfPopSeq += 1
                let atom = BASMemoryAtom(
                    memoryID: id, summary: queryText, contentType: .hot,
                    source: Parameters.atomSource,
                    timestamp: Date(timeIntervalSince1970: 0),
                    confidence: 0.7, conflictFingerprint: id)
                snapshot.append(SnapshotEntry(
                    atomID: id, domain: "session", embedding: query, atom: atom))
                while snapshot.count > selfPopulateCap { snapshot.removeFirst() }
            }
        }
        return bundle
    }

    public func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        // Transition: candidate -> admitted; admitted stays; frozen/retired terminal (matches
        // BASMLMemoryService). The `atom.frozen ? .frozen` wrapper below mirrors
        // BASHostRuntimeEBrainMemoryService (NOT BASMLMemoryService, which returns the switch
        // result directly) — it only diverges for a candidate+frozen atom, which this service's
        // own mapping never produces (frozen <=> archived <=> promotionState .frozen). The durable
        // write is deferred to drainIntents() (sync-safe).
        let next: BASPromotionState
        switch atom.promotionState {
        case .candidate: next = .admitted
        case .admitted: next = .admitted
        case .frozen: next = .frozen
        case .retired: next = .retired
        }
        if next == .admitted {
            withLock { promoteIntents.append(atom.memoryID) }
        }
        return atom.frozen ? .frozen : next
    }

    public func freeze(memoryID: String) -> Bool {
        return withLock {
            let present = snapshot.contains { $0.atomID == memoryID }
            if present { freezeIntents.append(memoryID) }
            return present
        }
    }

    // MARK: - Async session-boundary operations

    /// Rebuild the retrieval snapshot from the atom store. Embeds each atom's content via the
    /// SYNC embedder (cheap; runs off the turn hot path). Call at session start / between turns.
    public func refresh() async {
        let governed = await loadAllAtoms()
        let entries: [SnapshotEntry] = governed.map { record in
            let atom = Self.memoryAtom(from: record)
            return SnapshotEntry(
                atomID: atom.memoryID,
                domain: record.sourceType,
                embedding: syncEmbed(atom.summary),
                atom: atom)
        }
        withLock { snapshot = entries }
    }

    /// Flush queued promote/freeze intents to the atom store. With a
    /// `BASEventSourcedMemoryAtomStore` (whose atoms were already admitted) each successful write
    /// appends an event (event/log/provenance). Semantics are AT-MOST-ONCE: an intent is removed
    /// from the queue when drained, so a write that returns false (atom absent) or throws is NOT
    /// retried — the returned (promoted, frozen) counts let the caller detect a shortfall.
    @discardableResult
    public func drainIntents() async -> (promoted: Int, frozen: Int) {
        let (promotes, freezes) = withLock {
            () -> ([String], [String]) in
            let pendingPromotes = promoteIntents
            let pendingFreezes = freezeIntents
            promoteIntents.removeAll(keepingCapacity: true)
            freezeIntents.removeAll(keepingCapacity: true)
            return (pendingPromotes, pendingFreezes)
        }

        guard let store = atomStore else { return (0, 0) }
        var promoted = 0
        var frozen = 0
        for id in promotes {
            if await store.updateGovernanceStatus(forID: id, to: .governed) {
                promoted += 1
            }
        }
        for id in freezes {
            if await store.updateGovernanceStatus(forID: id, to: .archived) {
                frozen += 1
            }
        }
        return (promoted, frozen)
    }

    // MARK: - Introspection

    public var snapshotCount: Int {
        return withLock { snapshot.count }
    }

    // MARK: - Query-text derivation

    /// Build the retrieval query string from a decompose frame: the mirror text + the meaningful
    /// shard arrays. Joining gives the embedder a semantic anchor (richer than the typed-signal
    /// set the Jaccard backend used).
    static func queryText(from frame: BASDecomposeFrame) -> String {
        var parts: [String] = []
        if !frame.mirrorText.isEmpty { parts.append(frame.mirrorText) }
        parts.append(contentsOf: frame.facts)
        parts.append(contentsOf: frame.goals)
        parts.append(contentsOf: frame.emotions)
        parts.append(contentsOf: frame.pressureSignals)
        parts.append(contentsOf: frame.manipulationSignals)
        parts.append(contentsOf: frame.unknowns)
        parts.append(contentsOf: frame.contradictions)
        return parts.joined(separator: " ")
    }

    // MARK: - Mapping (mirrors BASHostRuntimeEBrainMemoryService:95-151; kept self-contained so
    // this additive backend touches no existing code — a future refactor may dedup into a shared
    // BASGovernedMemoryAtomProjection, chapter 二百一一)

    static func memoryAtom(from record: BASGovernedMemory) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: record.id.uuidString,
            summary: record.content,
            contentType: contentType(for: record.tier),
            source: record.sourceType,
            timestamp: record.lastConfirmedAt ?? Date(timeIntervalSince1970: 0),
            confidence: record.confidence,
            emotionalWeight: record.kind == .semantic ? 0.55 : 0.22,
            riskRelevance: record.sensitivity == .high ? 0.82 : 0.38,
            hostRelevance: record.kind == .profile ? 0.88 : 0.54,
            conflictFingerprint: record.id.uuidString,
            promotionState: promotionState(for: record.governanceStatus),
            frozen: record.governanceStatus == .archived)
    }

    private static func contentType(
        for tier: BASMemoryTier
    ) -> BASMemoryAtomContentType {
        switch tier {
        case .hot: .hot
        case .warm: .warm
        case .cold: .cold
        }
    }

    private static func promotionState(
        for status: BASMemoryGovernanceStatus
    ) -> BASPromotionState {
        switch status {
        case .candidate: .candidate
        case .governed: .admitted
        case .archived: .frozen
        case .quarantined, .rejected: .retired
        }
    }

    private static func retrievalTags(
        count: Int,
        dropped: [String]
    ) -> [String] {
        var tags: [String] = count == 0
            ? ["memory.no_relevant_atoms"]
            : ["memory.\(count)_recalled", "memory.routed_vector"]
        tags.append(contentsOf: dropped)
        return tags
    }

    // MARK: - Model-free default embedder

    /// Deterministic, model-free SYNC embedder: bag-of-hashed-tokens, L2-normalized. Texts that
    /// share tokens get higher cosine similarity (lexical similarity). Suitable as a fallback and
    /// for hermetic tests; the host-supplied semantic model replaces it for the default-flip.
    public static func lexicalEmbed(
        dimension: Int = Parameters.defaultLexicalDimension
    ) -> SyncEmbed {
        return { text in
            var vector = [Float](repeating: 0, count: dimension)
            let lowered = text.lowercased()
            let tokens = lowered.split { !$0.isLetter && !$0.isNumber }
            for token in tokens where !token.isEmpty {
                var hash: UInt64 = 1_469_598_103_934_665_603 // FNV-1a offset basis
                for byte in token.utf8 {
                    hash ^= UInt64(byte)
                    hash = hash &* 1_099_511_628_211
                }
                let bucket = Int(hash % UInt64(dimension))
                vector[bucket] += 1
            }
            // L2 normalize (cosine is scale-invariant, but normalizing keeps values bounded).
            let norm = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
            if norm > 0 {
                for i in vector.indices { vector[i] /= norm }
            }
            return vector
        }
    }
}
