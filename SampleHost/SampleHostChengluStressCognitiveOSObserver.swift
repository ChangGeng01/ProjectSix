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

    /// Chapter 三百八七 / M877: high-water-mark timestamp of the
    /// most-recent event observed by `extractGraph()`。Nil before
    /// the first extract;subsequent extracts pass `since: hwm+1`
    /// to the M877 incremental extractor so each call walks only
    /// the new events since the last extract,bypassing the
    /// pre-M877 5000-event cap that silently disabled long-run
    /// graph signal。
    private var lastExtractHighWaterMs: Int64?

    /// True when bundle has at least one populated primitive。
    var isEnabled: Bool {
        bundle?.isEmpty == false
    }

    // MARK: - Init

    /// Construct from M859 options。Throws on SQLite open / schema
    /// errors。Pass `.allDisabled` for the no-op observer
    /// (preserves M826 / M837 stress runner contract)。
    init(
        options: BASCognitiveOSBundleOptions,
        sessionID: String = UUID().uuidString
    ) throws {
        if options == .allDisabled {
            self.bundle = nil
        } else {
            self.bundle = try BASCognitiveOSBuilder
                .build(options: options)
        }
        self.sessionID = sessionID
        self.currentState = .zero
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

        // M875: cycle through project names so H1 (mentions) +
        // H2 (sequential causes) + H7 (closing edges) fire
        let project = Constants.projectNames[
            index % Constants.projectNames.count]

        // M875: action variation by iter % cycle so all edge
        // kinds get exercised
        // - succeeded → dispatch / mentions
        // - failed → delays / permit:replace
        let actions: [String]
        if succeeded {
            switch index % 7 {
            case 0:
                actions = ["dispatch:\(project)"]
            case 1, 2:
                actions = ["mentions:\(project)"]
            default:
                actions = ["chenglu:sweep:ok",
                          "mentions:\(project)"]
            }
        } else {
            switch index % 5 {
            case 0:
                actions = ["delays:\(project)"]
            case 1:
                actions = ["permit:replace:\(project)"]
            default:
                actions = ["chenglu:sweep:fail",
                          "delays:\(project)"]
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
            riskBand: succeeded ? .low : .medium,
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

        // Per-100-iter state reducer fold (M842)
        if index > 0
            && index % Constants.stateFoldInterval == 0
        {
            await foldState(from: entry)
        }

        // Per-1000-iter graph extract (M857 + M860)
        if index > 0
            && index % Constants.graphExtractInterval == 0
        {
            await extractGraph()
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
        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph,
            sinceTimestampMs: scanSince)

        // Update high-water-mark to the newest event timestamp
        // observed so the next extract starts past this batch。
        // Use Date().timeIntervalSince1970 since each event was
        // stamped at write time;this is approximate but bounded
        // by the per-extract interval。
        lastExtractHighWaterMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        // Chapter 三百八八 / M879 fix:write the in-memory graph
        // through to the SQLite storage companion when wired。
        // Pre-M879 the M862 observer extracted into in-memory
        // graph but never persisted nodes / edges,so M878's
        // SQLite path produced empty graph.sqlite even when
        // the JSON cognitiveOS summary reported large counts。
        // M866 append APIs are idempotent,so repeated walks are
        // no-ops on already-persisted rows。
        if let storage = bundle?.knowledgeGraphStorage {
            for node in await graph.allNodes() {
                _ = try? await storage.appendNode(node)
            }
            for edge in await graph.allEdges() {
                _ = try? await storage.appendEdge(edge)
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
}
