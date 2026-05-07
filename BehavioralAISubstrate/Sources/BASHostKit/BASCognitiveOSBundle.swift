// MARK: - BASCognitiveOSBundle — chapter 三百七二 / M859
//
// A2 Builder integration: typed bundle that carries optional
// cognitive-OS primitives constructed by `BASCognitiveOSBuilder`。
// Closes the M858-audit hidden gap H2: M841-M858 primitives were
// callable but not wired into any builder,so hosts had to
// construct each manually + thread through their turn loop。
//
// ## What this ships (M859 第一刀)
//
//   - `BASCognitiveOSBundleOptions` — typed flags + URL
//     parameters that callers pass to the builder to opt in
//     to specific primitives
//   - `BASCognitiveOSBundle` — typed Sendable bundle holding the
//     constructed primitives (event log / state store / vector
//     index / knowledge graph)
//
// Companion file:
//   - `BASCognitiveOSBuilder.swift` (also chapter 三百七二) —
//     namespace with `build(...)` async factory
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — bundle is composition,no
//     permit/verdict mutation
//   - 红线 7 hint-only — primitives remain hint-class
//   - 单提交口 (L11/L14) 不变 — bundle feeds the gate as INPUT
//   - chapter 二百一一 single-source-of-truth — ONE bundle type
//     for all cognitive-OS primitives;hosts compose via it
//   - chapter 三百四七 (M834) bundle-lifecycle — same destructure-
//     and-drop warning applies
//   - ADR-014 OPT-IN → PROD — every flag defaults false → bundle
//     is empty → zero behavior change for hosts that don't opt in

import Foundation
import BASMemory
import BASRuntimeCore

// MARK: - Options

/// Typed flags + URL parameters that callers pass to
/// `BASCognitiveOSBuilder.build(...)` to opt in to specific
/// cognitive-OS primitives。All flags default to `false` —
/// passing `default` produces an empty bundle (zero behavior
/// change for ADR-014 OPT-IN compliance)。
public struct BASCognitiveOSBundleOptions: Sendable, Equatable {

    // MARK: - Event log (G1, M841)

    /// When true,builder constructs an event log conformer。
    public let enableEventLog: Bool

    /// Optional SQLite URL for persistent event log。If nil
    /// (default) when `enableEventLog == true`,builder
    /// constructs an in-memory `BASInMemoryEventLogStorage`
    /// instead。
    public let eventLogSQLiteURL: URL?

    // MARK: - User state (G2, M842)

    /// When true,builder constructs a user state store。
    public let enableUserState: Bool

    /// Optional SQLite URL for persistent state store。
    public let userStateSQLiteURL: URL?

    // MARK: - Vector RAG (G4, M847+M849)

    /// When true,builder constructs a vector index。
    public let enableVectorIndex: Bool

    /// Optional SQLite URL for persistent vector index storage。
    public let vectorIndexSQLiteURL: URL?

    // MARK: - Knowledge graph (G9, M856 + M866)

    /// When true,builder constructs an in-memory knowledge graph。
    public let enableKnowledgeGraph: Bool

    /// Optional SQLite URL for persistent knowledge graph storage
    /// (M866)。If nil (default) when `enableKnowledgeGraph == true`,
    /// builder constructs an in-memory `BASKnowledgeGraph` only,
    /// no persistence companion。If a URL is supplied,builder also
    /// constructs `BASSQLiteKnowledgeGraphStorage` and surfaces it
    /// as `bundle.knowledgeGraphStorage`。Caller calls
    /// `storage.preload(into: graph)` at session start to restore
    /// the graph from disk + write-throughs after each insert。
    public let knowledgeGraphSQLiteURL: URL?

    public init(
        enableEventLog: Bool = false,
        eventLogSQLiteURL: URL? = nil,
        enableUserState: Bool = false,
        userStateSQLiteURL: URL? = nil,
        enableVectorIndex: Bool = false,
        vectorIndexSQLiteURL: URL? = nil,
        enableKnowledgeGraph: Bool = false,
        knowledgeGraphSQLiteURL: URL? = nil
    ) {
        self.enableEventLog = enableEventLog
        self.eventLogSQLiteURL = eventLogSQLiteURL
        self.enableUserState = enableUserState
        self.userStateSQLiteURL = userStateSQLiteURL
        self.enableVectorIndex = enableVectorIndex
        self.vectorIndexSQLiteURL = vectorIndexSQLiteURL
        self.enableKnowledgeGraph = enableKnowledgeGraph
        self.knowledgeGraphSQLiteURL =
            knowledgeGraphSQLiteURL
    }

    /// Default options:everything disabled (ADR-014 OPT-IN
    /// — pre-M859 hosts see this as zero behavior change)。
    public static let allDisabled = BASCognitiveOSBundleOptions()
}

// MARK: - Bundle

/// Typed Sendable bundle of constructed cognitive-OS primitives。
/// Returned by `BASCognitiveOSBuilder.build(...)`。Each field is
/// optional — only populated for primitives the caller opted into
/// via `BASCognitiveOSBundleOptions`。
///
/// **⚠️ Lifecycle gotcha** (chapter 三百四七 / M834 bundle pin):
/// hosts MUST retain this bundle (or the contained primitives)
/// for them to remain alive。Destructuring (`let log = bundle
/// .eventLog`) drops the rest — the dropped primitives stop
/// receiving writes,silently losing audit trail。
///
/// **Correct usage**:
///
///     let bundle = try await BASCognitiveOSBuilder.build(
///         options: opts)
///     useBundle(bundle)  // hold the whole bundle
///
/// **Incorrect usage**:
///
///     let bundle = try await BASCognitiveOSBuilder.build(
///         options: opts)
///     let log = bundle.eventLog  // ← destructure
///     // bundle drops here → all OTHER primitives deallocate
///     useLog(log)
public struct BASCognitiveOSBundle: Sendable {

    /// Event log primitive (G1, M841)。`nil` when
    /// `options.enableEventLog == false`。Concrete type is
    /// either `BASInMemoryEventLogStorage` or
    /// `BASSQLiteEventLogStorage` based on whether
    /// `options.eventLogSQLiteURL` was provided。
    public let eventLog: (any BASEventLogStorage)?

    /// User state store (G2, M842)。
    public let userStateStore: (any BASUserStateStorage)?

    /// Vector index actor (G4, M847)。In-memory by design;
    /// `vectorIndexStorage` companion is the SQLite-backed
    /// persistence。
    public let vectorIndex: BASVectorIndex?

    /// Optional SQLite-backed vector storage (G4, M849)。
    /// Only populated when caller passed
    /// `options.vectorIndexSQLiteURL`。Caller calls
    /// `vectorIndexStorage.preload(into: vectorIndex)` at
    /// session start to restore index from disk。
    public let vectorIndexStorage:
        BASSQLiteVectorIndexStorage?

    /// Knowledge graph (G9, M856)。In-memory by design;
    /// `knowledgeGraphStorage` companion is the SQLite-backed
    /// persistence (M866)。
    public let knowledgeGraph: BASKnowledgeGraph?

    /// Optional SQLite-backed knowledge graph storage (G9, M866)。
    /// Only populated when caller passed
    /// `options.knowledgeGraphSQLiteURL`。Caller calls
    /// `knowledgeGraphStorage.preload(into: knowledgeGraph)` at
    /// session start to restore graph from disk,then write-throughs
    /// for every node + edge insert。
    public let knowledgeGraphStorage:
        BASSQLiteKnowledgeGraphStorage?

    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        userStateStore: (any BASUserStateStorage)? = nil,
        vectorIndex: BASVectorIndex? = nil,
        vectorIndexStorage:
            BASSQLiteVectorIndexStorage? = nil,
        knowledgeGraph: BASKnowledgeGraph? = nil,
        knowledgeGraphStorage:
            BASSQLiteKnowledgeGraphStorage? = nil
    ) {
        self.eventLog = eventLog
        self.userStateStore = userStateStore
        self.vectorIndex = vectorIndex
        self.vectorIndexStorage = vectorIndexStorage
        self.knowledgeGraph = knowledgeGraph
        self.knowledgeGraphStorage =
            knowledgeGraphStorage
    }

    /// Empty bundle convenience。Used by builder when caller
    /// passes `BASCognitiveOSBundleOptions.allDisabled`
    /// (zero behavior change pin)。
    public static let empty = BASCognitiveOSBundle()

    /// Convenience: how many primitives are populated。Used by
    /// audit emission + tests。
    public var populatedCount: Int {
        var count = 0
        if eventLog != nil { count += 1 }
        if userStateStore != nil { count += 1 }
        if vectorIndex != nil { count += 1 }
        if vectorIndexStorage != nil { count += 1 }
        if knowledgeGraph != nil { count += 1 }
        if knowledgeGraphStorage != nil { count += 1 }
        return count
    }

    /// Convenience: is this bundle the empty (no-opt-in) state?
    public var isEmpty: Bool {
        populatedCount == 0
    }

    // MARK: - M889 query API (chapter 三百九〇)

    /// M889 typed snapshot of cognitive OS state at query time。
    /// Hosts use this to pull current cognitive OS status for
    /// observability / decision-making without manually poking
    /// each primitive。All counts are async-fetched from the
    /// underlying actor storage,so the snapshot is a coherent
    /// point-in-time view (mod actor scheduling latency)。
    public struct Snapshot:
        Sendable, Equatable, Codable, Hashable
    {
        public let eventCount: Int
        public let stateCount: Int
        public let graphNodeCount: Int
        public let graphEdgeCount: Int
        /// Number of populated bundle slots (mirrors the
        /// existing `populatedCount` property)。
        public let populatedSlotCount: Int
        public init(
            eventCount: Int,
            stateCount: Int,
            graphNodeCount: Int,
            graphEdgeCount: Int,
            populatedSlotCount: Int
        ) {
            self.eventCount = eventCount
            self.stateCount = stateCount
            self.graphNodeCount = graphNodeCount
            self.graphEdgeCount = graphEdgeCount
            self.populatedSlotCount = populatedSlotCount
        }
    }

    /// M889:fetch a typed point-in-time snapshot of cognitive
    /// OS state。Async because the underlying primitives are
    /// actors。Cheap (4 actor reads max);hosts can call per-
    /// turn without overhead concerns。
    public func snapshot() async -> Snapshot {
        let events = await eventLog?.totalCount ?? 0
        let states = await userStateStore?.totalCount ?? 0
        let nodes = await knowledgeGraph?.nodeCount ?? 0
        let edges = await knowledgeGraph?.edgeCount ?? 0
        return Snapshot(
            eventCount: events,
            stateCount: states,
            graphNodeCount: nodes,
            graphEdgeCount: edges,
            populatedSlotCount: populatedCount)
    }

    /// M889:detect user-vision §10 'complexity addiction'
    /// loops in the current graph。Returns cycles that contain
    /// at least one `delays` edge — those are the candidate
    /// loops per user-vision §10 (anxiety → add tech → can't
    /// finish → anxiety)。Returns empty when graph not wired
    /// or no matching cycles found。
    public func detectComplexityLoops()
        async -> [BASKnowledgeCycle]
    {
        guard let graph = knowledgeGraph else { return [] }
        return await graph.detectCycles(
            filter: { cycle in
                cycle.containsEdgeKind(.delays)
            })
    }
}
