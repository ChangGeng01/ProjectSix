// MARK: - BASKnowledgeGraphEventExtractor — chapter 三百七十 / M857
//
// Phase P2 G9 part 2: typed extractor that walks the M841 event
// log and populates a M856 knowledge graph using deterministic
// heuristics。Closes the data-flow loop between event log + graph
// — the M856 graph is now AUTO-POPULATABLE from existing event
// stream,no manual node/edge construction required for hosts。
//
// ## Why this exists
//
// M841 (chapter 三百五四) shipped the event log。
// M856 (chapter 三百六九) shipped the knowledge graph + cycle
// detection。M856 is currently EMPTY at runtime — hosts must
// manually construct nodes / edges to populate it。
//
// M857 ships the bridge: a deterministic extractor that walks
// event log entries through typed heuristics + produces nodes
// + edges that the graph can ingest。Hosts call:
//
//     let result = await BASKnowledgeGraphEventExtractor
//         .extract(
//             from: eventLog,
//             sessionID: "ssn-1",
//             into: graph)
//     // result.addedNodes + result.addedEdges populated
//
// ## Heuristics (chapter 一百八十五 anti-magic-number — pinned)
//
//   1. **Each event → event node** (kind=.event,nodeID=eventID)
//   2. **project tag → project node** (kind=.project)
//   3. **Event with project → mentions edge** (event → project)
//   4. **Sequential events sharing project → causes edge**
//      (earlier event → later event,within same session)
//   5. **`skip:*` action on tagged event → delays edge**
//      (event → project)
//   6. **`permit:block` or `permit:replace` → contradicts edge**
//      (event → project)
//
// **Determinism**: same event sequence + same prior graph state
// → same result。Required for replay correctness (G1 replay
// runner)。Heuristic 4 specifically uses event sequence number
// for ordering。
//
// ## Doctrine pins held
//
//   - All BASKnowledgeGraph + BASEventLog pins apply
//   - 不变量 #1 / #2 / #3 全保 — extractor is pure transformation
//   - 红线 7 hint-only — extracted graph is observation-class
//   - chapter 二百一一 single-source-of-truth — ONE extractor
//     namespace,heuristic configuration via typed parameters
//   - chapter 一百八十五 anti-magic-number — heuristic
//     coefficients (edge weights,project-tag thresholds) named
//     typed constants
//   - ADR-014 OPT-IN → PROD — extractor is opt-in;hosts that
//     don't call it have empty graphs (zero behavior change)

import Foundation

// MARK: - Extraction result

/// Typed result from one extraction run。
public struct BASKnowledgeGraphEventExtractionResult:
    Equatable, Sendable
{
    /// Count of new nodes inserted into the graph (excluding
    /// those already present)。
    public let addedNodeCount: Int

    /// Count of new edges inserted into the graph。
    public let addedEdgeCount: Int

    /// Count of events skipped (no project tag,or already
    /// represented in graph)。
    public let skippedEventCount: Int

    /// Total events read from the source。
    public let totalEventsRead: Int

    /// Reason codes for audit emission。Caller appends to the
    /// host's audit ledger。
    public let reasonCodes: [String]

    public init(
        addedNodeCount: Int,
        addedEdgeCount: Int,
        skippedEventCount: Int,
        totalEventsRead: Int,
        reasonCodes: [String]
    ) {
        self.addedNodeCount = addedNodeCount
        self.addedEdgeCount = addedEdgeCount
        self.skippedEventCount = skippedEventCount
        self.totalEventsRead = totalEventsRead
        self.reasonCodes = reasonCodes
    }
}

// MARK: - Extractor namespace

/// Pure-orchestration extractor。Stateless;reads from event log,
/// writes to graph,returns typed result。
public enum BASKnowledgeGraphEventExtractor {

    // MARK: - Heuristic constants (chapter 一百八十五)

    /// Edge weight for `mentions` edges (event → project)。Low
    /// because mentions are weak associations。
    public static let mentionsEdgeWeight: Double = 0.3

    /// Edge weight for `causes` edges (sequential events on
    /// same project)。Medium。
    public static let sequentialCausesEdgeWeight: Double = 0.5

    /// Edge weight for `delays` edges (skip:* actions)。High。
    /// Strong signal for user-vision §10 complexity-addiction
    /// loop detection。
    public static let delaysEdgeWeight: Double = 0.7

    /// Edge weight for `contradicts` edges (permit:block /
    /// permit:replace actions)。High。
    public static let contradictsEdgeWeight: Double = 0.8

    /// Reason-code prefix。Mirrors existing prefixes (mesh-coreml,
    /// constitution, rag) per chapter 二百一一 grep doctrine。
    public static let reasonCodePrefix: String =
        "knowledge-graph-extract"

    // MARK: - Heuristic 7 (M860): closing-edge synthesis

    /// Default minimum delays-edge count per project to trigger
    /// heuristic 7 closing-edge synthesis。Below this,extractor
    /// does NOT synthesize the project → causes → first-event
    /// edge (callers can still wire it manually if they want)。
    /// Chapter 一百八十五 anti-magic-number — pinned typed
    /// constant。
    public static let closingEdgeDelaysThreshold: Int = 2

    /// Edge weight for synthesized closing edges (heuristic 7)。
    /// Lower than direct causes edges because the closing edge
    /// is INFERRED,not directly observed in event actions。
    public static let closingEdgeWeight: Double = 0.4

    /// Reason code emitted when heuristic 7 fires (audit anchor)。
    public static let closingEdgeAnchorCode: String =
        "knowledge-graph-extract:heuristic-7:closing-edge-synthesized"

    /// Chapter 三百九〇 / M888:event log kind / source / action
    /// constants for the cycle-detection feedback event。When
    /// `feedbackLog` is supplied to `extract(...)` the extractor
    /// emits a synthetic event for each H7 closing edge,making
    /// detected complexity-addiction cycles first-class citizens
    /// of the event log。Future replays + extractions then see
    /// the cycle as part of session history。
    public static let cycleFeedbackEventSource: String =
        "knowledge-graph-extract:cycle-feedback"
    public static let cycleFeedbackActionPrefix: String =
        "cycle-detected:project:"

    // MARK: - Extract

    /// Walk a session's event log + populate the graph using
    /// typed heuristics。
    ///
    /// **Idempotent**: re-running with same event sequence +
    /// same graph produces no NEW nodes/edges (existing nodes
    /// are .upsert-ed,duplicate edges are caught + skipped)。
    ///
    /// - Parameters:
    ///   - eventLog: source event log conformer
    ///   - sessionID: session to extract events from
    ///   - graph: target graph to populate
    ///   - closingEdgeThreshold: heuristic 7 trigger — minimum
    ///     delays-edge count per project to synthesize the
    ///     closing causes edge。Default
    ///     `closingEdgeDelaysThreshold` (2)。Pass 0 to disable
    ///     heuristic 7 entirely。
    ///   - sinceTimestampMs: chapter 三百八七 / M877 incremental
    ///     mode。When non-nil,extractor reads only events with
    ///     `timestampMs >= since` AND filters to the supplied
    ///     `sessionID`。Closes the long-run cap problem
    ///     (M862 observer's 5000-event extractEventCap means
    ///     hosts running > 1h see ZERO graph updates after the
    ///     first 5 extracts)。Caller tracks the high-water-mark
    ///     across calls;default nil preserves M857 full-walk
    ///     semantics for back-compat。
    ///   - feedbackLog: chapter 三百九〇 / M888 cycle-feedback
    ///     mode。When non-nil,extractor writes a typed synthetic
    ///     `internalSignal` event back to this log for each H7
    ///     closing edge synthesized this run。The synthetic event
    ///     uses a stable eventID derived from the closing edge
    ///     ID,so re-extraction is idempotent (event log's
    ///     duplicate-detection returns wasNew=false)。Default
    ///     nil preserves M860 semantics (no feedback)。Pass the
    ///     same log used as `eventLog` to enable closed-loop
    ///     cognitive OS feedback。
    /// - Returns: typed result bundle
    public static func extract(
        from eventLog: any BASEventLogStorage,
        sessionID: String,
        into graph: BASKnowledgeGraph,
        closingEdgeThreshold: Int =
            BASKnowledgeGraphEventExtractor
                .closingEdgeDelaysThreshold,
        sinceTimestampMs: Int64? = nil,
        feedbackLog: (any BASEventLogStorage)? = nil
    ) async -> BASKnowledgeGraphEventExtractionResult {
        let events: [BASEventLogEntry]
        if let since = sinceTimestampMs {
            // M877 incremental path: timestamp-bounded scan
            // then session filter。Storage protocol's
            // `events(sinceTimestampMs:limit:)` returns
            // ALL sessions matching the timestamp range,so
            // we filter session-side in-memory。Hosts that
            // want SQL-level WHERE filtering can extend the
            // protocol with a typed scoped-since method
            // when needed (chapter 二百一一 — extend the
            // existing protocol rather than fork)。
            let unfiltered = await eventLog.events(
                sinceTimestampMs: since,
                limit: Int.max)
            events = unfiltered.filter {
                $0.sessionID == sessionID
            }
        } else {
            events = await eventLog.events(
                forSession: sessionID)
        }
        var addedNodes = 0
        var addedEdges = 0
        var skippedEvents = 0
        var reasonCodes: [String] = [
            "\(reasonCodePrefix):session:\(sessionID)",
            "\(reasonCodePrefix):events-read:\(events.count)"
        ]

        // Track project nodes we've seen this run for
        // sequential-causes detection
        var projectToLastEventID: [String: String] = [:]
        // Track project nodes we've ensured exist
        var ensuredProjects: Set<String> = []

        // Heuristic 7 (M860): track FIRST event per project
        // + count of delays edges per project for closing-edge
        // synthesis。
        var projectToFirstEventID: [String: String] = [:]
        var projectToDelaysCount: [String: Int] = [:]
        var closingEdgesSynthesized = 0

        for event in events {
            // Heuristic 1: each event → event node
            let eventNode = BASKnowledgeNode(
                nodeID: event.eventID,
                kind: .event,
                label: "\(event.kind.rawValue)" +
                    (event.intent.map { ":\($0)" } ?? ""),
                createdAtMs: event.timestampMs)
            do {
                try await graph.insert(node: eventNode)
                addedNodes += 1
            } catch BASKnowledgeGraphError
                .duplicateNodeID
            {
                // Already present — upsert to refresh metadata
                await graph.upsert(node: eventNode)
            } catch {
                skippedEvents += 1
                continue
            }

            // Heuristics 2-6 require project tag
            guard let project = event.project,
                  !project.isEmpty
            else {
                continue
            }

            // Heuristic 2: project tag → project node
            let projectNodeID = "project:\(project)"
            if !ensuredProjects.contains(projectNodeID) {
                let projectNode = BASKnowledgeNode(
                    nodeID: projectNodeID,
                    kind: .project,
                    label: project,
                    createdAtMs: event.timestampMs)
                do {
                    try await graph.insert(node: projectNode)
                    addedNodes += 1
                } catch BASKnowledgeGraphError
                    .duplicateNodeID
                {
                    // Already present — that's fine
                } catch {
                    // Other errors — ensuredProjects guard
                    // prevents repeat attempts;skip + continue
                }
                ensuredProjects.insert(projectNodeID)
            }

            // Heuristic 7 prep: record FIRST event per project
            // (for synthesizing closing causes edge from project
            // back to first event when delays threshold trips)
            if projectToFirstEventID[project] == nil {
                projectToFirstEventID[project] = event.eventID
            }

            // Heuristic 3: event → mentions → project
            let mentionsEdgeID =
                "mentions:\(event.eventID)→\(projectNodeID)"
            let mentionsEdge = BASKnowledgeEdge(
                edgeID: mentionsEdgeID,
                fromNodeID: event.eventID,
                toNodeID: projectNodeID,
                kind: .mentions,
                weight: mentionsEdgeWeight,
                createdAtMs: event.timestampMs)
            do {
                try await graph.insert(edge: mentionsEdge)
                addedEdges += 1
            } catch BASKnowledgeGraphError
                .duplicateEdgeID
            {
                // Re-extraction; idempotent skip
            } catch {
                continue
            }

            // Heuristic 4: sequential events on same project →
            // causes edge from earlier to later
            if let priorEventID =
                projectToLastEventID[project]
            {
                let causesEdgeID =
                    "causes:\(priorEventID)→\(event.eventID)"
                let causesEdge = BASKnowledgeEdge(
                    edgeID: causesEdgeID,
                    fromNodeID: priorEventID,
                    toNodeID: event.eventID,
                    kind: .causes,
                    weight: sequentialCausesEdgeWeight,
                    createdAtMs: event.timestampMs)
                do {
                    try await graph.insert(edge: causesEdge)
                    addedEdges += 1
                } catch BASKnowledgeGraphError
                    .duplicateEdgeID
                {
                    // Re-extraction; idempotent
                } catch {
                    // Defensive — endpoints exist by construction
                }
            }
            projectToLastEventID[project] = event.eventID

            // Heuristic 5: skip:* actions → event → delays
            //              → project
            for action in event.actions
                where action.hasPrefix("skip:")
            {
                let delaysEdgeID =
                    "delays:\(event.eventID)→\(projectNodeID)"
                let delaysEdge = BASKnowledgeEdge(
                    edgeID: delaysEdgeID,
                    fromNodeID: event.eventID,
                    toNodeID: projectNodeID,
                    kind: .delays,
                    weight: delaysEdgeWeight,
                    createdAtMs: event.timestampMs)
                do {
                    try await graph.insert(edge: delaysEdge)
                    addedEdges += 1
                    // Heuristic 7 prep: track delays count
                    // for closing-edge synthesis
                    projectToDelaysCount[
                        project, default: 0] += 1
                    break  // one delays edge per event,not
                           // per skip-action
                } catch BASKnowledgeGraphError
                    .duplicateEdgeID
                {
                    // Idempotent retry — still count toward
                    // threshold so re-extraction is consistent
                    projectToDelaysCount[
                        project, default: 0] += 1
                    break
                } catch {
                    break
                }
            }

            // Heuristic 6: permit:block / permit:replace →
            // event → contradicts → project
            for action in event.actions where
                action == "permit:block"
                || action == "permit:replace"
            {
                let contradictsEdgeID =
                    "contradicts:\(event.eventID)→\(projectNodeID)"
                let contradictsEdge = BASKnowledgeEdge(
                    edgeID: contradictsEdgeID,
                    fromNodeID: event.eventID,
                    toNodeID: projectNodeID,
                    kind: .contradicts,
                    weight: contradictsEdgeWeight,
                    createdAtMs: event.timestampMs)
                do {
                    try await graph.insert(
                        edge: contradictsEdge)
                    addedEdges += 1
                    break
                } catch BASKnowledgeGraphError
                    .duplicateEdgeID
                {
                    break
                } catch {
                    break
                }
            }
        }

        // Heuristic 7 (M860): synthesize closing causes edge
        // from project node → first event when delays-edge
        // count exceeds threshold。This is the "loop closer" —
        // turns a partial chain (events → delays → project)
        // into a full cycle (events → delays → project →
        // causes → first event) so the M856 cycle detector
        // can find user-vision §10 'complexity addiction loop'
        // without manual edge wiring。
        //
        // Pass `closingEdgeThreshold = 0` to disable this
        // heuristic entirely (conservative replay mode)。
        if closingEdgeThreshold > 0 {
            for (project, delaysCount)
                in projectToDelaysCount
            where delaysCount >= closingEdgeThreshold
            {
                guard let firstEventID =
                    projectToFirstEventID[project]
                else { continue }
                let projectNodeID = "project:\(project)"
                let closingEdgeID =
                    "h7-closing:\(projectNodeID)→\(firstEventID)"
                let closingEdge = BASKnowledgeEdge(
                    edgeID: closingEdgeID,
                    fromNodeID: projectNodeID,
                    toNodeID: firstEventID,
                    kind: .causes,
                    weight: closingEdgeWeight,
                    createdAtMs: events.last?.timestampMs ?? 0)
                do {
                    try await graph.insert(edge: closingEdge)
                    addedEdges += 1
                    closingEdgesSynthesized += 1
                } catch BASKnowledgeGraphError
                    .duplicateEdgeID
                {
                    // Re-extraction; idempotent skip
                } catch {
                    // Defensive — endpoints exist by
                    // construction (project + firstEvent
                    // both inserted earlier in this run)
                }

                // M888 cycle-detection-as-event:emit a typed
                // synthetic `internalSignal` event so the
                // detected cycle becomes a first-class citizen
                // of the event log。
                //
                // M890 fix:timestamp = events.last.timestampMs
                // + 1 so the cycle event lands inside next
                // extract's `since: hwm+1` scan window。
                //
                // M892 fix (post-deep-audit v3):eventID is now
                // `cycle:<sessionID>:project:<name>` — ONE per
                // session per project,not per closing-edge-ID。
                // Pre-M892 the ID was `cycle:<closingEdgeID>`
                // which embedded `firstEventID`。On incremental
                // extracts the `projectToFirstEventID` map is
                // local-per-extract,so each new scan window
                // captured a DIFFERENT first-event,producing a
                // DIFFERENT closing-edge-ID → DIFFERENT cycle-
                // eventID → idempotent check passed → unbounded
                // cycle event accumulation on long sessions
                // (potentially 360k cycle events over a 100h
                // run with 1000-event extract intervals)。
                //
                // Post-M892:same project in same session always
                // gets the same cycle-eventID,so re-detection
                // is a no-op append (wasNew=false)。The graph
                // edge itself still uses closing-edge-ID with
                // firstEvent (preserves graph topology accuracy);
                // only the LOG event signal is collapsed to one
                // per project per session。
                if let feedback = feedbackLog {
                    let cycleEventID =
                        "cycle:\(sessionID):project:\(project)"
                    let baseTimestamp =
                        events.last?.timestampMs ?? 0
                    let cycleEvent = BASEventLogEntry(
                        eventID: cycleEventID,
                        timestampMs: baseTimestamp + 1,
                        kind: .internalSignal,
                        sessionID: sessionID,
                        sequenceNumber: 0,
                        source:
                            cycleFeedbackEventSource,
                        project: project,
                        actions: [
                            "\(cycleFeedbackActionPrefix)" +
                                project,
                        ],
                        confidence: closingEdgeWeight)
                    do {
                        _ = try await feedback.append(
                            cycleEvent)
                    } catch {
                        // Silent — observation primitives
                        // never disrupt the host turn loop
                    }
                }
            }
        }

        reasonCodes.append(
            "\(reasonCodePrefix):nodes-added:\(addedNodes)")
        reasonCodes.append(
            "\(reasonCodePrefix):edges-added:\(addedEdges)")
        if skippedEvents > 0 {
            reasonCodes.append(
                "\(reasonCodePrefix):events-skipped:" +
                "\(skippedEvents)")
        }
        if closingEdgesSynthesized > 0 {
            reasonCodes.append(
                "\(reasonCodePrefix):heuristic-7:" +
                "closing-edges-synthesized:" +
                "\(closingEdgesSynthesized)")
            reasonCodes.append(closingEdgeAnchorCode)
        }

        return BASKnowledgeGraphEventExtractionResult(
            addedNodeCount: addedNodes,
            addedEdgeCount: addedEdges,
            skippedEventCount: skippedEvents,
            totalEventsRead: events.count,
            reasonCodes: reasonCodes)
    }
}
