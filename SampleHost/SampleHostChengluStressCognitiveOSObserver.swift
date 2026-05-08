// MARK: - SampleHostChengluStressCognitiveOSObserver
//                                       — chapter 三百七五 / M862
//
// A3 SampleHost integration: opt-in observer that wires the M859
// cognitive OS bundle into the chenglu stress runner。Default
// behavior is no-op (zero-stat, zero-side-effect) so that hosts
// not opting in see the original M826 / M837 stress runner
// contract preserved。
//
// ## What this ships
//
// A typed Sendable observer that:
//   - Constructs the cognitive OS bundle via M859 builder
//   - Appends one event-log entry per stress iter (G1)
//   - Folds state via M842 reducer every 100 iter (G2)
//   - Extracts knowledge graph from event log every 1000 iter
//     (G9 / M857 + M860 heuristic 7)
//   - Surfaces stats: event count / state count / graph nodes /
//     graph edges
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — observer is observation only,
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — appending events / states / graph is HINT;
//   the chenglu mesh sweep is the live decision path
// - 单提交口 (L11/L14) 不变 — observer never bypasses gate
// - chapter 三百三九 (M826) — original stress runner contract
//   preserved (default options → observer is no-op)
// - chapter 三百四七 (M834) — bundle held by observer for
//   lifetime;destructure-and-drop avoided
// - chapter 一百八十五 anti-magic-number — reducer / extractor
//   intervals are named typed constants
// - ADR-014 OPT-IN → PROD — default `.allDisabled` produces
//   zero behavior change

import Foundation
import BASHostKit

// MARK: - Observer

/// Opt-in observer that wraps the M859 cognitive OS bundle for
/// the chenglu stress runner。`disabled` static factory returns
/// an observer that performs zero work + reports zero stats
/// (preserves chapter 三百三九 stress runner contract)。
@MainActor
final class SampleHostChengluStressCognitiveOSObserver {

    // MARK: - Doctrine constants (chapter 一百八十五)

    enum Constants {
        /// State reducer fold interval in iterations。
        static let stateFoldInterval: Int = 100

        /// Knowledge graph extraction interval in iterations。
        static let graphExtractInterval: Int = 1_000

        /// Maximum events extractor walks per call。Beyond this,
        /// extraction skips the sweep this turn (defensive cap
        /// for long-running 8h stress where event log grows to
        /// millions)。
        static let extractEventCap: Int = 5_000

        /// Chapter 三百八七 / M875 evolution:project names that
        /// observed events cycle through。4 names → events on the
        /// same project repeat every 4 iters,which gives the M857
        /// extractor enough recurring project signal to fire H2
        /// sequential-causes + H7 closing-edge synthesis。Pre-M875
        /// events had no project field → 0 graph edges across
        /// 2.1M iPhone iters。
        static let projectNames: [String] = [
            "alpha", "beta", "gamma", "delta",
        ]

        /// Chapter 三百九〇 / M887 evolution:thermal pressure
        /// re-sample interval (iters)。ProcessInfo.thermalState
        /// is a coarse OS signal that doesn't change per-iter,
        /// so we re-read every N iters to amortize syscall cost。
        /// 100 iter ≈ once per ~700ms at 147 iter/s thermal-hot
        /// case observed on iPhone 17e。
        static let thermalReadInterval: Int = 100

        /// Chapter 三百九九 / M905:slowdown multiplier applied to
        /// `graphExtractInterval` when `.slowOnHot` thermal
        /// sensitivity is active AND cached risk band is
        /// `.medium` (=`.serious`) or `.high` (=`.critical`)。
        /// Default 4 matches M900 substrate primitive default。
        /// At 1000 iter normal interval × 4 multiplier = 4000
        /// iter slowed interval under thermal load,giving
        /// ANE / CPU back to the chenglu mesh path during the
        /// 98%-`.serious` thermal envelope the 10h run revealed。
        static let thermalSlowdownMultiplier: Int = 4
    }

    // MARK: - State

    /// Underlying bundle (nil when disabled)。
    private let bundle: BASCognitiveOSBundle?

    /// Session ID used for event log + graph extraction。
    /// Generated at observer construction so all events for one
    /// stress run share the same session。
    private let sessionID: String

    /// In-memory rolling state vector folded every 100 iter。
    /// Persisted via `userStateStore` if present。
    private var currentState: BASUserState

    /// Most-recent stats observed (refreshed by `refreshStats`)。
    private(set) var eventCount: Int = 0
    private(set) var stateCount: Int = 0
    private(set) var graphNodeCount: Int = 0
    private(set) var graphEdgeCount: Int = 0

    /// Chapter 三百八八 / M883 (P2.3 audit fix):counter of
    /// failed graph SQLite write-through attempts。Pre-M883 the
    /// `try?` swallow in `extractGraph()` made the JSON / UI
    /// report 331,947 graph nodes while disk had 0 — the
    /// "looks-good-in-memory,silent-on-disk" bug the audit
    /// flagged。Post-M883 hosts read this counter (surfaced via
    /// the @Published stress runner field) to see whether
    /// SQLite mutation actually succeeded。
    private(set) var graphPersistFailures: Int = 0

    /// Chapter 三百八七 / M877: high-water-mark timestamp of the
    /// most-recent event observed by `extractGraph()`。Nil before
    /// the first extract;subsequent extracts pass `since: hwm+1`
    /// to the M877 incremental extractor so each call walks only
    /// the new events since the last extract,bypassing the
    /// pre-M877 5000-event cap that silently disabled long-run
    /// graph signal。
    private var lastExtractHighWaterMs: Int64?

    /// M886 fix (post-deep-review):highest event.timestampMs
    /// seen by `observeIteration(...)` so far。Used as the hwm
    /// advance target after each extract instead of wall-clock,
    /// which is incomparable with synthetic / replayed event
    /// timestamps。
    private var maxObservedEventTimestampMs: Int64 = 0

    /// Chapter 三百九八 / M899 perf fix:track count of
    /// already-persisted nodes/edges so write-through walks only
    /// NEW elements,not all。Pre-M899 the observer's
    /// `extractGraph()` walked `graph.allNodes()` (full array,
    /// e.g. 5M nodes after a 10h run) on EVERY extract,calling
    /// idempotent append per element → O(N) SQLite queries per
    /// extract → ~5M queries / 7s extract interval → backpressure
    /// → throughput collapse around the 1-hour mark。Post-M899
    /// each extract walks only `graph.nodeCount -
    /// lastPersistedNodeCount` new elements (the suffix of the
    /// sorted-by-createdAtMs allNodes array)。Bounded per-extract
    /// work,O(1) amortized per added node。
    private var lastPersistedNodeCount: Int = 0
    private var lastPersistedEdgeCount: Int = 0

    /// Chapter 三百九〇 / M887:cached thermal state,re-read
    /// every `Constants.thermalReadInterval` iters。Maps to
    /// `BASEventLogRiskBand` so events carry real-world thermal
    /// pressure signal,not just hardcoded `succeeded → low /
    /// failed → medium`。20-min iPhone run showed thermal envelope
    /// drops throughput 1109 → 147 iter/s but observer events
    /// reported `riskBand: low` throughout — substrate had no
    /// surface for thermal pressure。M887 closes that gap。
    private var cachedThermalRiskBand:
        BASEventLogRiskBand = .low

    /// Chapter 三百九九 / M905:thermal sensitivity policy。
    /// Default `.ignoreThermal` preserves M826 / M887 contract
    /// (zero behavior change for hosts that don't opt in)。Hosts
    /// running 1h+ stress should pass `.slowOnHot` so graph
    /// extraction backs off when the iPhone hits `.serious`
    /// thermal — 10h run showed device spent 98.13% there but
    /// the observer kept extracting at full cadence anyway,
    /// burning ANE cycles that the chenglu mesh needed。
    private let thermalSensitivity:
        BASCognitiveOSThermalSensitivity

    /// Chapter 三百九九 / M905:test-injection seam mirroring the
    /// M900 substrate primitive's `thermalSampler` closure。
    /// Default reads `ProcessInfo.processInfo.thermalState` via
    /// `Self.thermalRiskBand()`。Tests inject a closure to pin
    /// thermal state for deterministic verification of the
    /// `.slowOnHot` / `.skipOnCritical` decision paths without
    /// requiring real device thermal pressure。
    private let thermalRiskBandSampler:
        @MainActor () -> BASEventLogRiskBand

    /// Chapter 三百九九 / M905 telemetry — extracts SKIPPED by
    /// thermal-sensitivity gating。Hosts surface this via the
    /// runner UI / JSON so the `.slowOnHot` policy effect is
    /// observable in 1h+ runs。
    private(set) var thermalSkippedExtracts: Int = 0

    /// Chapter 三百九九 / M905 telemetry — extracts that fired on
    /// the SLOWED cadence (every interval × multiplier iters)
    /// when `.slowOnHot` was active and thermal was hot。
    private(set) var thermalSlowedExtracts: Int = 0

    /// True when bundle has at least one populated primitive。
    var isEnabled: Bool {
        bundle?.isEmpty == false
    }

    /// Chapter 三百九九 / M901:expose the cached thermal risk
    /// band so the runner can capture it in the per-minute time
    /// series。Read-only — observer is the sole owner of the
    /// underlying state。Returns `.low` when M887 sampling has
    /// not yet fired (initial state)。
    var currentThermalRiskBand: BASEventLogRiskBand {
        cachedThermalRiskBand
    }

    // MARK: - Init

    /// Construct from M859 options。Throws on SQLite open / schema
    /// errors。Pass `.allDisabled` for the no-op observer
    /// (preserves M826 / M837 stress runner contract)。
    ///
    /// Chapter 三百九九 / M905:`thermalSensitivity` defaults to
    /// `.ignoreThermal` — back-compat with all M826-M899 hosts。
    /// 1h+ stress runs should pass `.slowOnHot` so graph
    /// extraction backs off under the `.serious` thermal envelope
    /// the 10h iPhone run revealed (98% of events were there)。
    /// `thermalRiskBandSampler` is a test-injection seam — leave
    /// as default in production code。
    init(
        options: BASCognitiveOSBundleOptions,
        sessionID: String = UUID().uuidString,
        thermalSensitivity:
            BASCognitiveOSThermalSensitivity = .ignoreThermal,
        thermalRiskBandSampler: (
            @MainActor () -> BASEventLogRiskBand)? = nil
    ) throws {
        if options == .allDisabled {
            self.bundle = nil
        } else {
            self.bundle = try BASCognitiveOSBuilder
                .build(options: options)
        }
        self.sessionID = sessionID
        self.currentState = .zero
        self.thermalSensitivity = thermalSensitivity
        self.thermalRiskBandSampler =
            thermalRiskBandSampler ?? {
                Self.thermalRiskBand()
            }
    }

    /// No-op convenience for callers that want the default
    /// observer without throwing。
    static func disabled() -> SampleHostChengluStressCognitiveOSObserver {
        // .allDisabled never throws,but make this resilient
        // against future builder changes by force-trying then
        // falling through to the empty bundle path
        do {
            return try SampleHostChengluStressCognitiveOSObserver(
                options: .allDisabled)
        } catch {
            // Should never happen — `.allDisabled` short-circuits
            // before any I/O,so build cannot throw。Defensive
            // pin: return an observer whose bundle is nil。
            return SampleHostChengluStressCognitiveOSObserver
                .unsafeNoOp()
        }
    }

    /// Private no-throw fallback constructor。Used only by
    /// `disabled()` defensive path。Bundle is nil → `isEnabled`
    /// is false → all observe methods are no-op。
    private static func unsafeNoOp()
        -> SampleHostChengluStressCognitiveOSObserver
    {
        SampleHostChengluStressCognitiveOSObserver(noOp: ())
    }

    private init(noOp _: Void) {
        self.bundle = nil
        self.sessionID = "noop"
        self.currentState = .zero
        self.thermalSensitivity = .ignoreThermal
        self.thermalRiskBandSampler = {
            Self.thermalRiskBand()
        }
    }

    // MARK: - Observe (per-iter / per-N-iter)

    /// Append one event for this iter。No-op when event log is
    /// not in the bundle。Does NOT throw — failures count
    /// silently against the runner's failure tally to avoid
    /// disrupting the stress loop on transient SQLite contention。
    ///
    /// Chapter 三百八七 / M875 evolution:event metadata enriched
    /// based on iPhone 1h-run findings。Pre-M875 events had no
    /// `project` + only `chenglu:sweep:ok/fail` actions,which
    /// matched ZERO graph extractor heuristics → 0 graph edges
    /// after 2.1M events on real device。Post-M875 events cycle
    /// through 4 named projects + emit varied actions
    /// (`delays:`,`dispatch:`,`permit:replace`) so heuristics
    /// 1-7 produce meaningful nodes + edges。
    func observeIteration(
        index: Int,
        latencyMs: Double,
        succeeded: Bool
    ) async {
        guard let log = bundle?.eventLog else { return }

        // M887:re-sample thermal state every N iters (cheap to
        // call,but not free)。Maps OS thermal pressure into the
        // typed `BASEventLogRiskBand` so events carry the
        // real-world signal that 20-min iPhone runs surfaced
        // (throughput 1109 → 147 iter/s under thermal envelope
        // but observer events all reported `riskBand: low`
        // pre-M887)。
        // M905 (chapter 三百九九):sample via the injected closure
        // so tests can pin thermal state without device pressure。
        // Default closure reads `Self.thermalRiskBand()`,
        // preserving M887 production semantics。
        if index % Constants.thermalReadInterval == 0 {
            cachedThermalRiskBand =
                thermalRiskBandSampler()
        }

        // M875: cycle through project names so H3 (mentions) +
        // H4 (sequential causes) + H7 (closing edges) fire
        let project = Constants.projectNames[
            index % Constants.projectNames.count]

        // M880 fix (P1.2 audit) — action labels MUST match
        // substrate consumer patterns, not invent suffixes。
        //
        // Two distinct consumers:
        //   1. BASKnowledgeGraphEventExtractor (graph edges):
        //      - H5 delays edge:`action.hasPrefix("skip:")`
        //      - H6 contradicts edge:`action == "permit:block"`
        //        OR `action == "permit:replace"` (EXACT)
        //      - H3/H2 mentions/causes:fire on `event.project`,
        //        no matching action needed
        //   2. BASUserStateReducer (agentRouteHistory):
        //      - `action.hasPrefix("dispatch:")` → suffix
        //        prepended to state.agentRouteHistory
        //
        // Pre-M880:emitted `delays:<project>` /
        // `permit:replace:<project>` → BOTH invalid for graph
        // heuristics (had project suffix breaking exact match,
        // wrong prefix for delays)。Post-M880 actions exercise
        // BOTH consumers correctly。
        //
        // M886 deep-review note:`dispatch:` is NOT dead code —
        // it feeds state.agentRouteHistory via M842 reducer
        // (BASUserStateReducer.swift:149),not the graph
        // extractor。This is intentional dual-purpose:graph
        // edges via skip:/permit:* + state route history via
        // dispatch: + project context via event.project。
        let actions: [String]
        if succeeded {
            switch index % 7 {
            case 0:
                // Feeds M842 reducer's agentRouteHistory
                actions = ["dispatch:\(project)"]
            case 1, 2:
                // mentions edges fire from event.project alone
                // (no matching action prefix needed)
                actions = ["chenglu:sweep:ok"]
            default:
                actions = ["chenglu:sweep:ok"]
            }
        } else {
            switch index % 5 {
            case 0:
                // skip: prefix → H5 delays edge
                actions = ["skip:thermal-pressure"]
            case 1:
                // EXACT permit:replace → H6 contradicts edge
                actions = ["permit:replace"]
            case 2:
                // EXACT permit:block → H6 contradicts edge
                actions = ["permit:block"]
            default:
                actions = ["chenglu:sweep:fail",
                          "skip:overload"]
            }
        }

        let entry = BASEventLogEntry(
            eventID: UUID().uuidString,
            timestampMs: Int64(
                Date().timeIntervalSince1970 * 1000),
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,  // storage assigns
            source: "samplehost.chenglu-stress",
            turnRef: "iter-\(index)",
            // M887:risk band combines failure signal + thermal
            // pressure。Failure overrides thermal (worst-case
            // wins);on success,thermal state passes through。
            riskBand: succeeded
                ? cachedThermalRiskBand
                : .medium,
            project: project,
            actions: actions,
            confidence: succeeded ? 1.0 : 0.0,
            payloadJson: makePayload(
                latencyMs: latencyMs))
        do {
            _ = try await log.append(entry)
        } catch {
            // Silent — see method contract above。Counter still
            // monotonic via local `eventCount` increment below。
        }
        eventCount += 1

        // M886 fix:track max event timestamp for event-clock hwm
        if entry.timestampMs > maxObservedEventTimestampMs {
            maxObservedEventTimestampMs = entry.timestampMs
        }

        // Per-100-iter state reducer fold (M842)
        if index > 0
            && index % Constants.stateFoldInterval == 0
        {
            await foldState(from: entry)
        }

        // Per-1000-iter graph extract (M857 + M860),M905
        // thermal-aware gating layered on top:
        //   - `.ignoreThermal`:fire on every interval boundary
        //     (M826/M887 contract preserved)
        //   - `.slowOnHot`:when cached riskBand is `.medium` or
        //     `.high`,only fire when index ALSO matches the
        //     slowed cadence (interval × thermalSlowdownMultiplier)
        //   - `.skipOnCritical`:when cached riskBand is `.high`,
        //     skip extraction entirely (state fold continues)
        if index > 0
            && index % Constants.graphExtractInterval == 0
        {
            if shouldExtractUnderThermalPolicy(
                atIndex: index)
            {
                await extractGraph()
            } else {
                thermalSkippedExtracts += 1
            }
        }
    }

    /// M905 typed predicate gating extractGraph based on the
    /// configured thermal sensitivity + the M887 cached risk band。
    /// Mirrors `BASCognitiveOSConvenience.shouldExtractUnderThermal`
    /// (chapter 三百九九 substrate primitive)— see that doc for
    /// the full sensitivity matrix。
    private func shouldExtractUnderThermalPolicy(
        atIndex index: Int
    ) -> Bool {
        switch thermalSensitivity {
        case .ignoreThermal:
            return true
        case .slowOnHot:
            switch cachedThermalRiskBand {
            case .medium, .high:
                let slowedInterval =
                    Constants.graphExtractInterval
                    * Constants.thermalSlowdownMultiplier
                if index % slowedInterval == 0 {
                    thermalSlowedExtracts += 1
                    return true
                } else {
                    return false
                }
            case .low, .unknown:
                return true
            }
        case .skipOnCritical:
            switch cachedThermalRiskBand {
            case .high:
                return false
            case .low, .medium, .unknown:
                return true
            }
        }
    }

    /// Fold the most-recent event into the rolling state vector。
    /// Persists to user state store if present。
    private func foldState(
        from event: BASEventLogEntry
    ) async {
        guard let store = bundle?.userStateStore else { return }

        let newID = UUID().uuidString
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        let next = BASUserStateReducer.reduce(
            prior: currentState,
            event: event,
            newStateID: newID,
            generatedAtMs: nowMs)

        do {
            _ = try await store.append(
                next, sessionID: sessionID)
            currentState = next
            stateCount += 1
        } catch {
            // Silent per observer contract。
        }
    }

    /// Extract knowledge graph nodes + edges from the event log。
    ///
    /// Chapter 三百八七 / M877 evolution:uses incremental mode
    /// (`sinceTimestampMs`) so each call walks only events newer
    /// than the previous high-water-mark。Pre-M877 the M862
    /// observer used a 5000-event cap that silently disabled
    /// graph extraction after the first hour of any sustained
    /// run。Post-M877 the cap is unnecessary — incremental walks
    /// are bounded by the per-extract event count
    /// (`graphExtractInterval`),not the total log size。
    private func extractGraph() async {
        guard let log = bundle?.eventLog,
              let graph = bundle?.knowledgeGraph
        else { return }

        // M877 incremental scan: walk only events appended since
        // last extract。`since` is exclusive in spirit (strictly-
        // greater) but the storage filter is `>=`,so we add 1ms
        // to skip the boundary event already processed last call。
        let scanSince: Int64? =
            lastExtractHighWaterMs.map { $0 + 1 }

        // M886 fix v2:use event-clock,not wall-clock,for the
        // hwm advance target。`maxObservedEventTimestampMs`
        // tracks the highest timestamp from events that ENTERED
        // the observer (via `observeIteration` calling the log's
        // append),so it correctly bounds "what's been processed"
        // even when events use synthetic / replayed timestamps。
        //
        // M888 (chapter 三百九〇):pass the same log as
        // `feedbackLog` so detected cycles become first-class
        // events。Idempotent eventIDs ensure no duplicates。
        let preExtractHwm = maxObservedEventTimestampMs
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph,
            sinceTimestampMs: scanSince,
            feedbackLog: log)
        lastExtractHighWaterMs = preExtractHwm

        // M879 + M899 graph SQLite write-through。M879 added the
        // basic write-through;M899 added delta-only walk so a
        // 10h run doesn't collapse on backpressure。
        //
        // Pre-M899 every extract walked ALL graph.allNodes() →
        // O(total-graph-size) SQLite queries per extract → at
        // 5M+ nodes after several hours,each extract took
        // longer than the extract cadence → unbounded queue
        // growth + throughput collapse。
        //
        // Post-M899:track `lastPersistedNodeCount` +
        // `lastPersistedEdgeCount`。Walk only the SUFFIX of
        // allNodes/allEdges that's been added since last
        // persist (sorted by createdAtMs ASC,so suffix = newest
        // N items)。Bounded per-extract work proportional to
        // graphExtractInterval (1000 events ≈ 1000-2000 new
        // graph elements at most),not total graph size。
        //
        // M866 append APIs are still idempotent,so even if the
        // count tracking drifts (e.g. on observer restart),the
        // worst case is replaying same nodes which become
        // wasNew=false no-ops。Counter is rebuildable from
        // storage.nodeCount on cold start。
        //
        // M883 persist-failure counter still active — exposed via
        // `graphPersistFailures` for hosts that need disk-write
        // visibility。
        if let storage = bundle?.knowledgeGraphStorage {
            let currentNodeCount = await graph.nodeCount
            if currentNodeCount > lastPersistedNodeCount {
                let allNodes = await graph.allNodes()
                let newCount =
                    currentNodeCount - lastPersistedNodeCount
                let newNodes = allNodes.suffix(newCount)
                for node in newNodes {
                    do {
                        _ = try await storage.appendNode(node)
                    } catch {
                        graphPersistFailures += 1
                    }
                }
                lastPersistedNodeCount = currentNodeCount
            }
            let currentEdgeCount = await graph.edgeCount
            if currentEdgeCount > lastPersistedEdgeCount {
                let allEdges = await graph.allEdges()
                let newCount =
                    currentEdgeCount - lastPersistedEdgeCount
                let newEdges = allEdges.suffix(newCount)
                for edge in newEdges {
                    do {
                        _ = try await storage.appendEdge(edge)
                    } catch {
                        graphPersistFailures += 1
                    }
                }
                lastPersistedEdgeCount = currentEdgeCount
            }
        }

        graphNodeCount = await graph.nodeCount
        graphEdgeCount = await graph.edgeCount
    }

    /// Refresh stats from underlying storage。Called at end of
    /// run for the final UI update。
    func refreshStats() async {
        if let log = bundle?.eventLog {
            eventCount = await log.totalCount
        }
        if let store = bundle?.userStateStore {
            stateCount = await store.totalCount
        }
        if let graph = bundle?.knowledgeGraph {
            graphNodeCount = await graph.nodeCount
            graphEdgeCount = await graph.edgeCount
        }
    }

    // MARK: - Helpers

    private func makePayload(latencyMs: Double) -> String? {
        // Compact JSON — UI doesn't read this,but training
        // pipelines (G8) do
        let formatted = String(
            format: "{\"latencyMs\":%.3f}", latencyMs)
        return formatted
    }

    /// Chapter 三百九〇 / M887:read OS thermal pressure +
    /// map to typed `BASEventLogRiskBand`。`ProcessInfo.thermalState`
    /// is platform-portable (iOS / macOS) and updates as the OS
    /// detects sustained workload causing chip heating。Mapping:
    ///   .nominal   → .low
    ///   .fair      → .low
    ///   .serious   → .medium
    ///   .critical  → .high
    /// `@unknown default` falls through to `.unknown` per Swift
    /// 6 exhaustiveness handling — defensive against future Apple
    /// thermal-state additions。
    private static func thermalRiskBand()
        -> BASEventLogRiskBand
    {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal, .fair:
            return .low
        case .serious:
            return .medium
        case .critical:
            return .high
        @unknown default:
            return .unknown
        }
    }
}
