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

    // MARK: - Knowledge graph (G9, M856)

    /// When true,builder constructs an in-memory knowledge graph。
    /// (No SQLite-backed graph in M859 — graph is in-memory-only
    /// per M856 doctrine。Persistence is a future commit。)
    public let enableKnowledgeGraph: Bool

    public init(
        enableEventLog: Bool = false,
        eventLogSQLiteURL: URL? = nil,
        enableUserState: Bool = false,
        userStateSQLiteURL: URL? = nil,
        enableVectorIndex: Bool = false,
        vectorIndexSQLiteURL: URL? = nil,
        enableKnowledgeGraph: Bool = false
    ) {
        self.enableEventLog = enableEventLog
        self.eventLogSQLiteURL = eventLogSQLiteURL
        self.enableUserState = enableUserState
        self.userStateSQLiteURL = userStateSQLiteURL
        self.enableVectorIndex = enableVectorIndex
        self.vectorIndexSQLiteURL = vectorIndexSQLiteURL
        self.enableKnowledgeGraph = enableKnowledgeGraph
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

    /// Knowledge graph (G9, M856)。In-memory only。
    public let knowledgeGraph: BASKnowledgeGraph?

    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        userStateStore: (any BASUserStateStorage)? = nil,
        vectorIndex: BASVectorIndex? = nil,
        vectorIndexStorage:
            BASSQLiteVectorIndexStorage? = nil,
        knowledgeGraph: BASKnowledgeGraph? = nil
    ) {
        self.eventLog = eventLog
        self.userStateStore = userStateStore
        self.vectorIndex = vectorIndex
        self.vectorIndexStorage = vectorIndexStorage
        self.knowledgeGraph = knowledgeGraph
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
        return count
    }

    /// Convenience: is this bundle the empty (no-opt-in) state?
    public var isEmpty: Bool {
        populatedCount == 0
    }
}
