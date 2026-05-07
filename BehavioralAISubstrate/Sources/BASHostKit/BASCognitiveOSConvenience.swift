// MARK: - BASCognitiveOSConvenience — chapter 三百七八 / M865
//
// Single-call helper that composes the three observation
// primitives — event log append (M841) + state reducer fold
// (M842) + knowledge graph extract (M857 + M860 heuristic 7) —
// behind ONE typed entry point。Reduces boilerplate for hosts
// that want the full data loop on every event。
//
// ## Why this exists (M862 audit observation)
//
// M862's `SampleHostChengluStressCognitiveOSObserver` hand-rolled
// per-iter event-log append + per-100-iter state-fold + per-1000-
// iter graph-extract logic。Other hosts wanting the same loop
// would have to duplicate that pattern。This file extracts the
// pattern into a typed helper that handles the cadence + the
// composition,leaving hosts to provide just:
//   - the bundle (from M859 builder)
//   - the session ID
//   - the event entry
//
// ## What this ships
//
//   - `BASCognitiveOSConvenienceCadence` typed struct holding
//     the per-event / per-N-event / per-M-event cadence。Default
//     mirrors the M862 observer (1 / 100 / 1000)。chapter 一百
//     八十五 anti-magic-number — every cadence value typed。
//   - `BASCognitiveOSConvenienceResult` typed Sendable struct
//     reporting which primitives fired this call (eventAppended /
//     stateFolded / graphExtracted) so hosts can surface stats。
//   - `BASCognitiveOSConvenience` actor:owns the rolling state
//     + iteration counter + invokes the right primitives at the
//     right cadence。Ergonomic single-call surface
//     `observe(event:)` → result。
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — convenience is observation only,
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — the result is a HINT;L11 gate decides
// - chapter 二百一一 single-source-of-truth — ONE convenience
//   actor module owns the cadence + composition
// - chapter 一百八十五 anti-magic-number — cadence values typed
// - chapter 三百四七 (M834) bundle-lifecycle — convenience owns
//   the bundle for its lifetime,no destructure-and-drop
// - ADR-014 OPT-IN → PROD — host opts in by passing a non-empty
//   bundle;empty bundle → no-op observe call (zero behavior change)
//
// **Module placement**: BASHostKit (not BASRuntimeCore) because
// `BASUserStateStorage` lives in BASMemory and the convenience
// composes BOTH module boundaries — BASHostKit is the natural
// composition point that already imports both via @_exported。

import Foundation
import BASMemory
import BASRuntimeCore

// MARK: - Cadence

/// Typed Sendable struct holding the convenience helper's cadence。
/// Defaults mirror M862 SampleHost observer values (1 / 100 / 1000)。
public struct BASCognitiveOSConvenienceCadence:
    Sendable, Equatable, Hashable
{
    /// State reducer fold interval (in `observe(event:)` calls)。
    /// Default 100 — fold once per 100 events to keep state
    /// vector cheap on long sessions。
    public let stateFoldInterval: Int

    /// Knowledge graph extract interval (in `observe(event:)`
    /// calls)。Default 1000 — re-extract once per 1000 events。
    public let graphExtractInterval: Int

    /// Defensive event-log size cap above which graph extract
    /// is SKIPPED (avoids long-session UI stall)。Default 5000
    /// (matches M862 observer cap)。
    public let graphExtractEventCap: Int

    public init(
        stateFoldInterval: Int = Self.defaultStateFoldInterval,
        graphExtractInterval: Int =
            Self.defaultGraphExtractInterval,
        graphExtractEventCap: Int =
            Self.defaultGraphExtractEventCap
    ) {
        precondition(stateFoldInterval > 0,
            "stateFoldInterval must be > 0")
        precondition(graphExtractInterval > 0,
            "graphExtractInterval must be > 0")
        precondition(graphExtractEventCap > 0,
            "graphExtractEventCap must be > 0")
        self.stateFoldInterval = stateFoldInterval
        self.graphExtractInterval = graphExtractInterval
        self.graphExtractEventCap = graphExtractEventCap
    }

    /// chapter 一百八十五 anti-magic-number — typed defaults
    public static let defaultStateFoldInterval: Int = 100
    public static let defaultGraphExtractInterval: Int = 1_000
    public static let defaultGraphExtractEventCap: Int = 5_000

    /// Default cadence (1 / 100 / 1000 / 5000)。
    public static let `default` =
        BASCognitiveOSConvenienceCadence()
}

// MARK: - Result

/// Typed Sendable struct reporting which primitives fired during
/// one `observe(event:)` call。Hosts surface these to UI / logs。
public struct BASCognitiveOSConvenienceResult:
    Sendable, Equatable, Hashable
{
    /// True iff the event was appended to the event log
    /// (false when `eventLog` is nil in the bundle)。
    public let eventAppended: Bool

    /// True iff this call triggered a state reducer fold
    /// (cadence + state store both required)。
    public let stateFolded: Bool

    /// True iff this call triggered a graph extract pass
    /// (cadence + graph + event log all required + event count
    /// under cap)。
    public let graphExtracted: Bool

    /// Iteration index at the time of this call (zero-based)。
    public let iterationIndex: Int

    public init(
        eventAppended: Bool,
        stateFolded: Bool,
        graphExtracted: Bool,
        iterationIndex: Int
    ) {
        self.eventAppended = eventAppended
        self.stateFolded = stateFolded
        self.graphExtracted = graphExtracted
        self.iterationIndex = iterationIndex
    }

    /// True iff at least one primitive fired this call。
    public var anyFired: Bool {
        eventAppended || stateFolded || graphExtracted
    }
}

// MARK: - Convenience actor

/// Actor that owns the rolling iteration counter + state vector
/// + delegates to the underlying primitives at the right cadence。
///
/// Hosts pass a Sendable triple (eventLog / userStateStore /
/// knowledgeGraph) — typically destructured from
/// `BASCognitiveOSBundle` (M859) — plus a session ID。Each
/// `observe(event:)` call increments the iteration counter,
/// appends the event,folds state at the configured interval,
/// extracts the graph at the configured interval。
///
/// **No-op behavior**: when all three storage refs are nil,
/// `observe(event:)` increments only the counter and reports
/// all-false flags。This matches the ADR-014 OPT-IN pin。
public actor BASCognitiveOSConvenience {

    // MARK: - Dependencies

    private let eventLog: (any BASEventLogStorage)?
    private let userStateStore: (any BASUserStateStorage)?
    private let knowledgeGraph: BASKnowledgeGraph?
    /// Chapter 三百八二 / M869: optional SQLite write-through for
    /// graph mutations。When set,after each `extractGraph()` fires,
    /// the convenience walks the in-memory graph + idempotent-
    /// appends every node + edge to storage。M866's append APIs
    /// are idempotent on duplicate IDs,so repeated write-throughs
    /// are no-ops on already-persisted nodes/edges。
    private let knowledgeGraphStorage:
        BASSQLiteKnowledgeGraphStorage?
    /// Post-M872 deep-review fix:optional callback fired when a
    /// graph write-through fails。Without this,storage failures
    /// were silently swallowed and the in-memory graph could
    /// drift out of sync with SQLite without any host signal。
    /// Default nil preserves the M865/M869 silent-fail contract
    /// — hosts opt in to error visibility by passing a callback。
    private let onPersistError:
        (@Sendable (String, Error) -> Void)?
    private let cadence: BASCognitiveOSConvenienceCadence
    private let sessionID: String

    // MARK: - Rolling state

    private var iterationIndex: Int = 0
    private var currentState: BASUserState

    /// Chapter 三百八八 / M881 (P2.4 audit fix):high-water-mark
    /// timestamp of the most-recent event observed by
    /// `extractGraph()`。Pre-M881 the convenience helper had a
    /// hard cap at `cadence.graphExtractEventCap` total events,
    /// permanently disabling extraction past that mark for any
    /// host using the helper directly。Post-M881 each extract
    /// passes `since: hwm+1` to the M877 incremental extractor,
    /// bypassing the cap entirely (cap is now batch-size,not
    /// total-log-size)。
    private var lastGraphExtractHwm: Int64?

    // MARK: - Init

    /// Construct from bundle pieces。Pass nil for any primitive
    /// the caller does not want to feed。Empty (all-nil) is
    /// allowed — yields a no-op observer。
    ///
    /// Chapter 三百八二 / M869: `knowledgeGraphStorage` is the
    /// optional SQLite write-through companion (M866)。When set
    /// AND `knowledgeGraph` is also set,the convenience appends
    /// every graph node + edge through to SQLite after each
    /// graph extract。Hosts that don't pass the storage stay
    /// in-memory only (M865 contract preserved)。
    public init(
        eventLog: (any BASEventLogStorage)? = nil,
        userStateStore: (any BASUserStateStorage)? = nil,
        knowledgeGraph: BASKnowledgeGraph? = nil,
        knowledgeGraphStorage:
            BASSQLiteKnowledgeGraphStorage? = nil,
        sessionID: String = UUID().uuidString,
        cadence: BASCognitiveOSConvenienceCadence = .default,
        onPersistError:
            (@Sendable (String, Error) -> Void)? = nil
    ) {
        self.eventLog = eventLog
        self.userStateStore = userStateStore
        self.knowledgeGraph = knowledgeGraph
        self.knowledgeGraphStorage =
            knowledgeGraphStorage
        self.sessionID = sessionID
        self.cadence = cadence
        self.onPersistError = onPersistError
        self.currentState = .zero
    }

    // MARK: - Observe (the single entry point)

    /// Observe an event。Composes append + fold + extract at the
    /// configured cadence。Returns a typed result indicating
    /// which primitives fired this call。
    ///
    /// **Append**: every call (when `eventLog` non-nil)。
    /// **Fold**: every `cadence.stateFoldInterval` call,counting
    /// from index 0。First fold fires at iter index ==
    /// `stateFoldInterval`。
    /// **Extract**: every `cadence.graphExtractInterval` call,
    /// when `eventLog.totalCount <= graphExtractEventCap`。
    @discardableResult
    public func observe(
        event: BASEventLogEntry
    ) async -> BASCognitiveOSConvenienceResult {
        // 1-based index: first call is index 1,so cadence checks
        // fire predictably at multiples (100, 200, ... or
        // 1000, 2000, ...) — chapter 一百八十五 anti-magic-number
        // pin: cadence semantics matches the natural "every Nth
        // event" reading
        iterationIndex += 1
        let myIndex = iterationIndex

        // 1. Event log append
        var didAppendEvent = false
        if let log = eventLog {
            do {
                _ = try await log.append(event)
                didAppendEvent = true
            } catch {
                // Silent — observation primitives never disrupt
                // host turn loop on storage failure。Hosts that
                // need failure visibility can wrap this actor。
            }
        }

        // 2. State reducer fold (every Nth call,1-based)
        var didFoldState = false
        if myIndex % cadence.stateFoldInterval == 0
            && userStateStore != nil
        {
            didFoldState = await foldState(from: event)
        }

        // 3. Graph extract (every Mth call,1-based)
        var didExtractGraph = false
        if myIndex % cadence.graphExtractInterval == 0
            && knowledgeGraph != nil
            && eventLog != nil
        {
            didExtractGraph = await extractGraph()
        }

        return BASCognitiveOSConvenienceResult(
            eventAppended: didAppendEvent,
            stateFolded: didFoldState,
            graphExtracted: didExtractGraph,
            iterationIndex: myIndex)
    }

    // MARK: - Read-only stats

    /// Iteration count consumed by `observe(...)` calls so far。
    public var observedCount: Int {
        iterationIndex
    }

    /// Most-recent state vector (post-fold)。
    public var rollingState: BASUserState {
        currentState
    }

    // MARK: - Private helpers

    private func foldState(
        from event: BASEventLogEntry
    ) async -> Bool {
        guard let store = userStateStore else { return false }
        let newID = UUID().uuidString
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        // chapter 三百八一 / M868 upgrade: when a knowledge graph
        // is also wired into this convenience,fold via the M858
        // graph-aware reducer (which adds a complexityAddiction
        // bonus per delays-cycle on the event's project)。Hosts
        // that did NOT wire a graph fall back to the M842 base
        // reducer — preserves the M865 contract on graph-less
        // setups (zero behavior change pin)。
        let next: BASUserState
        if let graph = knowledgeGraph {
            next = await BASUserStateGraphAwareReducer.reduce(
                prior: currentState,
                event: event,
                graph: graph,
                newStateID: newID,
                generatedAtMs: nowMs)
        } else {
            next = BASUserStateReducer.reduce(
                prior: currentState,
                event: event,
                newStateID: newID,
                generatedAtMs: nowMs)
        }

        do {
            _ = try await store.append(
                next, sessionID: sessionID)
            currentState = next
            return true
        } catch {
            return false
        }
    }

    private func extractGraph() async -> Bool {
        guard let log = eventLog,
              let graph = knowledgeGraph
        else { return false }

        // M881 fix (P2.4 audit):pre-M881 the convenience helper
        // permanently disabled graph extraction once the event
        // log exceeded `graphExtractEventCap` (default 5000)。
        // This silently broke any host using the convenience
        // helper directly past 5000 events。SampleHost observer
        // got M877's incremental fix in chapter 三百八七,but
        // the substrate-side helper kept the cap → bifurcated
        // semantics。
        //
        // Post-M881:incremental extract (mirrors M877) — track
        // `lastGraphExtractHwm` and walk only events newer than
        // last extract。The cap on `cadence.graphExtractEventCap`
        // is now applied to the BATCH size rather than total log
        // size — defensive guard against catastrophic single-
        // batch growth (e.g.,per-extract interval mis-set so
        // large that a single extract walks millions of events)。
        let scanSince: Int64? =
            lastGraphExtractHwm.map { $0 + 1 }
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph,
            sinceTimestampMs: scanSince)

        // M881:advance high-water-mark for next call。Use
        // current wall-clock since events are timestamped at
        // append time。Bounded by `graphExtractInterval`,so
        // even if the next iter is a long Task.sleep away,the
        // hwm stays close to the extracted batch's tail。
        lastGraphExtractHwm = Int64(
            Date().timeIntervalSince1970 * 1000)

        // chapter 三百八二 / M869 write-through: when the host
        // wired `knowledgeGraphStorage`,append every node + edge
        // through to SQLite。M866's append APIs are idempotent on
        // duplicate IDs,so calling this on re-extraction is a
        // no-op on already-persisted rows。Failures are reported
        // via `onPersistError` (post-M872 deep review fix) but
        // never thrown — observation primitives never disrupt
        // the host turn loop。
        if let storage = knowledgeGraphStorage {
            await persistGraph(
                graph: graph, storage: storage)
        }

        return true
    }

    /// Walk the in-memory graph + write-through nodes + edges to
    /// the SQLite storage companion。Idempotent on already-
    /// persisted rows due to M866 append semantics。Errors are
    /// reported via the optional `onPersistError` callback (post-
    /// M872 deep review fix) but never thrown — observation
    /// primitives never disrupt the host turn loop。
    private func persistGraph(
        graph: BASKnowledgeGraph,
        storage: BASSQLiteKnowledgeGraphStorage
    ) async {
        let nodes = await graph.allNodes()
        for node in nodes {
            do {
                _ = try await storage.appendNode(node)
            } catch {
                onPersistError?(node.nodeID, error)
                // Continue — observation primitives never disrupt
                // host turn loop on storage failure
            }
        }
        let edges = await graph.allEdges()
        for edge in edges {
            do {
                _ = try await storage.appendEdge(edge)
            } catch {
                onPersistError?(edge.edgeID, error)
                // Continue — same contract as appendNode above
            }
        }
    }
}
