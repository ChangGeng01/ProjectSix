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
//   • event/log/provenance — TWO async write paths in `drainIntents()`, both opt-in:
//     (1) ADMIT: when `admitAtom` is wired, each SELF-POPULATED atom is `admit()`ed to the durable
//         store. A `BASEventSourcedMemoryAtomStore.admit` appends a `memoryAtomEvent` (the provenance
//         trail), and a `loadAllAtoms` reading the SAME store reloads it on the next `refresh()`.
//     (2) GOVERNANCE: a promote/freeze calls `updateGovernanceStatus`, which records an event only for
//         an atom ALREADY in the store's projection — so promote/freeze of a self-populated atom is
//         durable only AFTER its admit (path 1) has run, or for atoms the host admitted elsewhere and
//         surfaced via `loadAllAtoms`. nil `admitAtom`/`atomStore` ⇒ pure in-memory (no persistence).
//
// ## HOST-DRIVEN seam + DURABILITY (current state — this was once an in-process-only opt-in; the
//    durable-memory arc made it cross-restart durable + host-consumed):
//   • Host-driven, NOT auto-wired. `refresh()`/`drainIntents()` are NOT on `BASMemoryServicing` (only
//     `retrieve`/`promote`/`freeze`, all sync — ch883), so `BASCognitiveBrain.process()` never calls
//     them. The brain exposes `refreshMemory()` / `drainMemoryIntents()` and a HOST drives them at
//     session/turn boundaries. The DeviceTestApp endurance is the shipping host that consumes this.
//   • CROSS-RESTART durable via the right store. The event-sourced store is IN-PROCESS only (its reducer
//     replays content EMPTY — privacy doctrine — rehydrating from an in-process cache). For durability
//     across a REAL restart, wire the FILE-BACKED `BASSQLiteMemoryAtomStore` (persists full content as
//     payload_json) + `BASSQLiteVectorIndexStorage` (persisted embeddings) via the optional
//     `loadEmbedding`/`upsertEmbedding` closures below: a brand-new process reloads content + embeddings
//     and reproduces recall WITHOUT re-embedding. Proven by
//     `BASL8RoutedMemoryServiceCrossRestartTests` (content) + `…VectorIndexTests` (embeddings).
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

/// Host-supplied persistence hook for the routed memory backend (the Step-2 SQL/event/provenance
/// half). Wire e.g. a `BASEventSourcedMemoryAtomStore` (events + provenance) or
/// `BASSQLiteMemoryAtomStore` so each self-populated atom is `admit()`ed (one provenance event per
/// atom) and reloadable via `loadAllAtoms`. nil ⇒ pure in-memory (the default flip).
///
/// HONEST SCOPE (see the type-level comment on `BASL8RoutedMemoryService`): this is an OPT-IN,
/// host-injected API. As of ch1062 the SHIPPING consumer is the DeviceTestApp endurance runner — it
/// wires a `BASRoutedMemoryPersistence` into `BASCognitiveBrain.makeWithDefaults(memoryPersistence:)`
/// and drives `drainMemoryIntents()` per turn, so it DOES fire through the host's `brain.process()`
/// loop. Durability depends on the wired store: a bare event-sourced store replays content IN-PROCESS
/// (NOT cross-restart-durable on its own), whereas a file-backed `BASSQLiteMemoryAtomStore` +
/// `BASSQLiteVectorIndexStorage` (the DeviceTestApp wiring) IS cross-restart durable — content +
/// embeddings reload from SQLite without re-embedding (ADR-033 §104-120). The library
/// `makeWithDefaults()` default stays legacy/in-memory, byte-equal-off (the flip is host-injected).
///
/// ADR-039 Phase 2 — host-injected Metal cosine-topK seam over the in-Swift SNAPSHOT corpus. Signature:
/// `(query, flatCorpus [row0_d0..row0_dN-1, row1_d0..], dim, k) -> [(rowIndex, score)]?`. A nil RESULT
/// means Metal faulted / timed out ⇒ `retrieve()` retreats to the CPU score-all path (wedge-safe, ADR-038).
/// nil SEAM ⇒ byte-equal-off (ADR-014). The host backs it with `BASMetalTopKDispatcher` + the sync bridge;
/// per the determinism boundary (ADR-039 §2) only `atomID` crosses into the spine — the durable store /
/// event-log / governance verdict are VERIFIED Metal-free. The Metal score becomes `atom.confidence` on the
/// reasoning-side bundle, which IS in the replay-digest preimage; since the Metal score is non-reproducible,
/// this path is APPROXIMATE + NOT replay-stable (default-off; do not enable with replay-over-routed-backend).
public typealias BASMetalCosineTopKSeam =
    @Sendable (_ query: [Float], _ corpus: [Float], _ dim: Int, _ k: Int)
        -> [(rowIndex: Int, score: Float)]?

public struct BASRoutedMemoryPersistence: Sendable {
    public let loadAllAtoms: @Sendable () async -> [BASGovernedMemory]
    public let admitAtom: @Sendable (BASGovernedMemory) async -> Void
    public let atomStore: any BASMemoryAtomStore
    /// Phase 2 — OPTIONAL durable VECTOR-INDEX consumption (e.g. `BASSQLiteVectorIndexStorage`). Both
    /// nil ⇒ Phase-1 behavior (refresh re-embeds every atom via the CoreML model). When wired:
    /// `refresh()` LOADS each persisted embedding (no re-embed; lazy-backfills a miss), and the admit
    /// path UPSERTS each self-populated atom's embedding — so embeddings survive restart too.
    public let loadEmbedding: (@Sendable (_ atomID: String) async -> [Float]?)?
    public let upsertEmbedding: (@Sendable (_ atomID: String, _ embedding: [Float], _ domain: String) async -> Void)?
    /// chapter 一千〇六十二 / WS3 — OPTIONAL host-injected cosineTopK seam (the perf-fast L8 retrieve
    /// takeover, ADR-036). nil ⇒ the orchestrated score-all path (byte-equal-off, ADR-014). When wired,
    /// the host backs it with a cosineTopK-capable routed index (`BASRoutedVectorIndexStorage`) for the
    /// recall domain; NON-byte-equal (rowid tie-break + pre-filter truncation). The host owns the domain
    /// (the closure captures it). This threads the opt-in through the standard `makeWithDefaults(
    /// memoryPersistence:)` factory path — without it the seam is only reachable by constructing
    /// `BASL8RoutedMemoryService` directly. DeviceTestApp leaves it nil while its durable index is
    /// SQLite-only (no cosineTopK engine); on-device adoption is a documented follow-up (ADR-036).
    public let cosineTopKSync:
        (@Sendable (_ query: [Float], _ k: Int) -> [(atomID: String, score: Float)])?
    /// ADR-037 — OPTIONAL host-injected GLOBAL recall seam (full-corpus cosineTopK + atom resolver).
    /// nil ⇒ no global recall. Preferred over `cosineTopKSync` in `retrieve()` when both are wired.
    /// Byte-equal-off by default; the host owns the in-memory engine + resolver map.
    public let globalRecall: BASGlobalRecallSeam?
    /// ADR-039 Phase 2 — OPTIONAL Metal cosine-topK seam over the in-Swift snapshot corpus (nil ⇒
    /// byte-equal-off; a nil result ⇒ CPU fallback). Host-wired to BASMetalTopKDispatcher + sync bridge.
    public let metalCosineTopK: BASMetalCosineTopKSeam?
    public init(
        loadAllAtoms: @escaping @Sendable () async -> [BASGovernedMemory],
        admitAtom: @escaping @Sendable (BASGovernedMemory) async -> Void,
        atomStore: any BASMemoryAtomStore,
        loadEmbedding: (@Sendable (String) async -> [Float]?)? = nil,
        upsertEmbedding: (@Sendable (String, [Float], String) async -> Void)? = nil,
        cosineTopKSync: (@Sendable (_ query: [Float], _ k: Int)
            -> [(atomID: String, score: Float)])? = nil,
        globalRecall: BASGlobalRecallSeam? = nil,
        metalCosineTopK: BASMetalCosineTopKSeam? = nil
    ) {
        self.loadAllAtoms = loadAllAtoms
        self.admitAtom = admitAtom
        self.atomStore = atomStore
        self.loadEmbedding = loadEmbedding
        self.upsertEmbedding = upsertEmbedding
        self.cosineTopKSync = cosineTopKSync
        self.globalRecall = globalRecall
        self.metalCosineTopK = metalCosineTopK
    }
}

/// ADR-037 — GLOBAL durable cosineTopK recall seam. Pairs the full-corpus ranker with an atom
/// resolver so `retrieve()` can return top-K atoms even when they fall OUTSIDE the in-memory
/// ≤selfPopulateCap recall window. nil default ⇒ byte-equal-off (ADR-014 / 红线 7). NON-byte-equal
/// when wired (ADR-036-class semantics — tie membership at the K-th boundary by rowid, pre-filter
/// truncation — now over the full corpus). The host owns the in-memory engine + resolver map
/// lifetime + memory bound (host-side lockstep FIFO eviction of engine + resolver); both closures
/// are synchronous (ch883 retrieve stays sync).
public struct BASGlobalRecallSeam: Sendable {
    /// 1 FFI call: full-corpus cosine top-K → (atomID, score), score DESC. Backed by the host's
    /// in-memory `BASRoutedVectorIndexStorage.cosineTopKAtomIDsSync(forDomain:query:k:)`.
    public let cosineTopK:
        @Sendable (_ query: [Float], _ k: Int) -> [(atomID: String, score: Float)]
    /// atomID → (atom, domain) over the FULL corpus. nil for an unknown id (that hit is skipped, like
    /// the windowed path skips an out-of-window hit). Host-backed by a bounded [String:(atom,domain)].
    public let atomForID:
        @Sendable (_ atomID: String) -> (atom: BASMemoryAtom, domain: String)?
    public init(
        cosineTopK: @escaping @Sendable (_ query: [Float], _ k: Int)
            -> [(atomID: String, score: Float)],
        atomForID: @escaping @Sendable (_ atomID: String)
            -> (atom: BASMemoryAtom, domain: String)?
    ) {
        self.cosineTopK = cosineTopK
        self.atomForID = atomForID
    }
}

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
    private var admitIntents: [BASGovernedMemory] = []  // self-pop atoms to persist via admitAtom
    private var selfPopSeq: Int = 0              // monotonic id source for self-populated atoms

    /// When true, retrieve() also writes the current frame as a new (vector-embedded) atom into the
    /// in-memory snapshot, so the service accumulates recall on its own — a drop-in for
    /// BASMLMemoryService's self-managed LRU, but vector-scored. Bounded by `selfPopulateCap`.
    private let selfPopulate: Bool
    private let selfPopulateCap: Int
    /// Optional persistence hook: when set, self-populated atoms are admitted to a durable store at
    /// drainIntents() — a `BASEventSourcedMemoryAtomStore.admit` emits a provenance event per atom,
    /// so recall survives restart (with a `loadAllAtoms` that reads the same store). The host wires
    /// this (BASHostKit can't take a concrete-store generic); nil ⇒ pure in-memory (no persistence).
    private let admitAtom: (@Sendable (BASGovernedMemory) async -> Void)?
    /// Phase 2 — OPTIONAL durable vector-index consumption. `loadEmbedding` reads a persisted vector
    /// (atomID-keyed) so `refresh()` can skip the CoreML re-embed; `upsertEmbedding` writes each
    /// self-populated atom's vector so it survives restart. Both nil ⇒ Phase-1 re-embed-on-refresh.
    /// Touched ONLY in async refresh()/drainIntents() — never in the sync retrieve() hot path (ch883).
    private let loadEmbedding: (@Sendable (String) async -> [Float]?)?
    private let upsertEmbedding: (@Sendable (String, [Float], String) async -> Void)?
    /// chapter 一千〇六十二 / WS3 — OPTIONAL host-injected perf-fast retrieve seam. When wired,
    /// `retrieve()` ranks via the index's integrated cosine top-K (1 FFI call returning
    /// (atomID, score)) instead of scoring every snapshot atom in Swift. nil ⇒ the orchestrated
    /// score-all path (byte-equal-off, ADR-014 default). NON-byte-equal when wired (the index ties
    /// by rowid + truncates before the Swift floor/constitution filter) — opt-in by the host.
    private let cosineTopKSync:
        (@Sendable (_ query: [Float], _ k: Int) -> [(atomID: String, score: Float)])?
    /// ADR-037 — OPTIONAL global-recall seam (full-corpus cosineTopK + atom resolver). Preferred over
    /// `cosineTopKSync` in retrieve() when both are set; nil ⇒ unchanged paths, byte-equal-off.
    private let globalRecall: BASGlobalRecallSeam?
    /// ADR-039 Phase 2 — OPTIONAL Metal cosine-topK over the in-Swift snapshot corpus (taken ONLY when
    /// neither Rust seam is wired; the Rust corpus has no dump FFI, the snapshot IS already in Swift).
    /// nil seam ⇒ byte-equal-off (the CPU score-all path). A nil RESULT from the seam ⇒ CPU fallback
    /// (wedge-safe, ADR-038). Only atomID crosses the determinism boundary; the Metal score orders the
    /// bundle (reasoning side — verified non-spine).
    private let metalCosineTopK: BASMetalCosineTopKSeam?

    public init(
        loadAllAtoms: @escaping LoadAllAtoms,
        syncEmbed: @escaping SyncEmbed,
        embeddingDimension: Int,
        restrictedMemoryDomains: [String] = [],
        topK: Int = Parameters.topK,
        relevanceFloor: Float = Parameters.relevanceFloor,
        atomStore: (any BASMemoryAtomStore)? = nil,
        selfPopulate: Bool = false,
        selfPopulateCap: Int = 64,
        admitAtom: (@Sendable (BASGovernedMemory) async -> Void)? = nil,
        loadEmbedding: (@Sendable (String) async -> [Float]?)? = nil,
        upsertEmbedding: (@Sendable (String, [Float], String) async -> Void)? = nil,
        cosineTopKSync: (@Sendable (_ query: [Float], _ k: Int)
            -> [(atomID: String, score: Float)])? = nil,
        globalRecall: BASGlobalRecallSeam? = nil,
        metalCosineTopK: BASMetalCosineTopKSeam? = nil
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
        self.admitAtom = admitAtom
        self.loadEmbedding = loadEmbedding
        self.upsertEmbedding = upsertEmbedding
        self.cosineTopKSync = cosineTopKSync
        self.globalRecall = globalRecall
        self.metalCosineTopK = metalCosineTopK
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

        // chapter 一千〇六十二 / WS3 — perf-fast hot path when the host wires the index's integrated
        // cosine top-K seam: ONE FFI call ranks the corpus + resolves atom_ids (vs N Swift cosine
        // calls over the snapshot). NON-byte-equal (the index ties by rowid + truncates before the
        // floor/constitution filter below); the returned atom_ids are mapped to snapshot atoms (a
        // result for an atom not in the recall window is skipped). nil seam ⇒ the orchestrated
        // score-all baseline — fully synchronous (ch883), byte-equal-off (ADR-014).
        let scored: [(score: Float, entry: SnapshotEntry)]
        if let globalRecall {
            // ADR-037 — GLOBAL recall: rank over the FULL durable corpus (the host's in-memory routed
            // index) and resolve winning atom_ids BEYOND the ≤selfPopulateCap snapshot window. A hit
            // whose id the resolver can't map is skipped (compactMap) — exactly as the windowed path
            // skips an out-of-window hit. NON-byte-equal vs the legacy default (ADR-036-class
            // semantics over the full corpus); the shared floor/constitution/sort tail below is
            // unchanged, so the returned bundle stays byte-deterministic within its membership.
            scored = globalRecall.cosineTopK(query, topK).compactMap { hit in
                globalRecall.atomForID(hit.atomID).map { resolved in
                    (hit.score, SnapshotEntry(
                        atomID: hit.atomID, domain: resolved.domain,
                        embedding: [], atom: resolved.atom))
                }
            }
        } else if let cosineTopKSync {
            let byID = Dictionary(
                snap.map { ($0.atomID, $0) }, uniquingKeysWith: { a, _ in a })
            scored = cosineTopKSync(query, topK).compactMap { hit in
                byID[hit.atomID].map { (hit.score, $0) }
            }
        } else if let metalCosineTopK, embeddingDimension > 0,
                  query.count == embeddingDimension, !snap.isEmpty,
                  snap.allSatisfy({ $0.embedding.count == embeddingDimension }) {
            // ADR-039 Phase 2 — Metal cosine-topK over the in-Swift snapshot corpus (opt-in; the host backs
            // it with BASMetalTopKDispatcher + the sync bridge). WEDGE-SAFE: a nil result (Metal fault /
            // timeout) retreats to the CPU score-all path. GUARDS: dim>0 + query.count==dim + uniform-dim
            // snapshot — any mismatch skips Metal (the flat GPU corpus can't tolerate ragged dims; the CPU
            // path can). We request k = snap.count (ALL rows), so the SHARED deterministic tail below
            // (floor → sort by score-desc,atomID-asc → prefix topK) decides membership IDENTICALLY to the
            // CPU path — the dispatcher's own rowIndex tie-break never leaks into the selection. (The GPU
            // does the full O(N·D) cosine regardless of k; truncation is free.)
            //
            // BOUNDARY HONESTY (ADR-039 §2): only the resolved atomID crosses into the spine (governance /
            // durable store / event-log are verified Metal-free). The Metal score becomes atom.confidence
            // on the reasoning-side bundle — which IS in the replay-digest preimage (synthesized Codable,
            // not canonicalized). The Metal score is NON-bit-reproducible, so this path is APPROXIMATE +
            // NOT replay-stable: a host that computes a replay digest over the routed backend must NOT
            // enable it (default-off; the spine stays CPU/Rust). The future large-corpus design snaps the
            // ranking to determinism (Metal screens top-M, CPU re-scores). See ADR-039 §7/§8.
            var corpus: [Float] = []
            corpus.reserveCapacity(snap.count * embeddingDimension)
            for entry in snap { corpus.append(contentsOf: entry.embedding) }
            if let hits = metalCosineTopK(query, corpus, embeddingDimension, snap.count) {
                scored = hits.compactMap { hit in
                    (hit.rowIndex >= 0 && hit.rowIndex < snap.count)
                        ? (hit.score, snap[hit.rowIndex]) : nil
                }
            } else {
                scored = Self.scoreAllSnapshot(query: query, snap: snap)   // wedge-safe CPU retreat
            }
        } else {
            // Rust-SIMD-routed cosine over the pre-materialized snapshot — fully synchronous.
            scored = Self.scoreAllSnapshot(query: query, snap: snap)
        }
        let above = scored.filter { $0.score >= relevanceFloor }

        // Constitution domain filter (no-op when restrictedMemoryDomains is empty — ADR-014).
        let filtered = BASConstitutionEnforcer.filterMemoryDomains(
            above.map { (domain: $0.entry.domain, payload: $0) },
            restrictedMemoryDomains: restrictedMemoryDomains)

        // Score DESC, then a stable tie-break on the unique atom ID ASC. Swift's `sorted` is not
        // documented stable, so without the secondary key two atoms with EXACTLY equal cosine scores
        // could reorder across runs / toolchains / snapshot insertion order. atomID is unique +
        // content-derived, giving a total order ⇒ byte-deterministic top-K (红线 byte-determinism).
        let top = filtered.allowed
            .sorted {
                $0.score != $1.score
                    ? $0.score > $1.score
                    : $0.entry.atomID < $1.entry.atomID
            }
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
                // Persistence: queue the atom for a durable admit (event/provenance) at drain.
                // Bounded like the snapshot: a host that wires `admitAtom` but never calls
                // `drainIntents()` would otherwise grow this unboundedly. Oldest un-drained
                // intents past the cap are dropped (the cap matches the in-memory recall window).
                if admitAtom != nil {
                    admitIntents.append(Self.governedMemory(content: queryText))
                    while admitIntents.count > selfPopulateCap {
                        admitIntents.removeFirst()
                    }
                }
            }
        }
        return bundle
    }

    /// Rust-SIMD cosine over the pre-materialized snapshot — the byte-equal-off baseline AND the Metal
    /// wedge-safe fallback (ADR-039 Phase 2). Pure; the caller passes a snapshot copy (no lock here).
    private static func scoreAllSnapshot(
        query: [Float], snap: [SnapshotEntry]
    ) -> [(score: Float, entry: SnapshotEntry)] {
        snap.map { entry in
            (BASAutoRouteRanker.cosineSimilarity(query, entry.embedding).value, entry)
        }
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

    /// Rebuild the retrieval snapshot from the atom store. Runs off the turn hot path (call at session
    /// start / between turns). Each atom's embedding is LOADED from the durable vector index when one
    /// is wired and present (dimension-consistent) — avoiding a CoreML re-embed; otherwise it is
    /// computed via the SYNC embedder and lazily BACKFILLED into the index for next time.
    public func refresh() async {
        let governed = await loadAllAtoms()
        var entries: [SnapshotEntry] = []
        entries.reserveCapacity(governed.count)
        for record in governed {
            let atom = Self.memoryAtom(from: record)
            let id = atom.memoryID
            let domain = record.sourceType
            let embedding: [Float]
            if let load = loadEmbedding, let persisted = await load(id),
               persisted.count == embeddingDimension {
                embedding = persisted                       // durable vector — no re-embed
            } else {
                let computed = syncEmbed(atom.summary)
                embedding = computed
                if let upsert = upsertEmbedding {
                    await upsert(id, computed, domain)       // lazy backfill for next restart
                }
            }
            entries.append(SnapshotEntry(
                atomID: id, domain: domain, embedding: embedding, atom: atom))
        }
        withLock { snapshot = entries }
    }

    /// Flush queued promote/freeze intents to the atom store. With a
    /// `BASEventSourcedMemoryAtomStore` (whose atoms were already admitted) each successful write
    /// appends an event (event/log/provenance). Semantics are AT-MOST-ONCE: an intent is removed
    /// from the queue when drained, so a write that returns false (atom absent) or throws is NOT
    /// retried — the returned (promoted, frozen) counts let the caller detect a shortfall.
    @discardableResult
    public func drainIntents() async -> (promoted: Int, frozen: Int, admitted: Int) {
        let (promotes, freezes, admits) = withLock {
            () -> ([String], [String], [BASGovernedMemory]) in
            let pendingPromotes = promoteIntents
            let pendingFreezes = freezeIntents
            let pendingAdmits = admitIntents
            promoteIntents.removeAll(keepingCapacity: true)
            freezeIntents.removeAll(keepingCapacity: true)
            admitIntents.removeAll(keepingCapacity: true)
            return (pendingPromotes, pendingFreezes, pendingAdmits)
        }

        // Persist self-populated atoms first (an event-sourced store emits a provenance event per
        // admit) so a later promote/freeze of the same atom finds it in the store. When a durable
        // vector index is wired, also UPSERT each atom's embedding (recomputed here, off the hot path
        // — deterministic, so identical to what refresh() would load back) so embeddings survive
        // restart and refresh() can skip the re-embed.
        var admitted = 0
        if let admit = admitAtom {
            for atom in admits {
                await admit(atom); admitted += 1
                if let upsert = upsertEmbedding {
                    await upsert(atom.id.uuidString, syncEmbed(atom.content), atom.sourceType)
                }
            }
        }

        guard let store = atomStore else { return (0, 0, admitted) }
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
        return (promoted, frozen, admitted)
    }

    // MARK: - Introspection

    public var snapshotCount: Int {
        return withLock { snapshot.count }
    }

    /// Test introspection (internal — exposed only via `@testable`, NOT public API): the snapshot
    /// embedding for an atom, so tests can verify `refresh()` LOADED a persisted vector from the
    /// index rather than re-embedding it.
    func snapshotEmbedding(forAtomID id: String) -> [Float]? {
        return withLock { snapshot.first { $0.atomID == id }?.embedding }
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

    public static func memoryAtom(from record: BASGovernedMemory) -> BASMemoryAtom {
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

    /// Build a durable governed-memory record from a self-populated frame's content (for `admitAtom`).
    static func governedMemory(content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            kind: .semantic, content: content, scope: .session, sensitivity: .low,
            tier: .hot, confidence: 0.7, sourceType: Parameters.atomSource,
            governanceStatus: .governed, provenanceSummary: "routed-self-pop")
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
