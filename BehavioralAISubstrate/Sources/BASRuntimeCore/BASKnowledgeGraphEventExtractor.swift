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
    /// - Returns: typed result bundle
    public static func extract(
        from eventLog: any BASEventLogStorage,
        sessionID: String,
        into graph: BASKnowledgeGraph
    ) async -> BASKnowledgeGraphEventExtractionResult {
        let events = await eventLog.events(
            forSession: sessionID)
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
                    break  // one delays edge per event,not
                           // per skip-action
                } catch BASKnowledgeGraphError
                    .duplicateEdgeID
                {
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

        reasonCodes.append(
            "\(reasonCodePrefix):nodes-added:\(addedNodes)")
        reasonCodes.append(
            "\(reasonCodePrefix):edges-added:\(addedEdges)")
        if skippedEvents > 0 {
            reasonCodes.append(
                "\(reasonCodePrefix):events-skipped:" +
                "\(skippedEvents)")
        }

        return BASKnowledgeGraphEventExtractionResult(
            addedNodeCount: addedNodes,
            addedEdgeCount: addedEdges,
            skippedEventCount: skippedEvents,
            totalEventsRead: events.count,
            reasonCodes: reasonCodes)
    }
}
