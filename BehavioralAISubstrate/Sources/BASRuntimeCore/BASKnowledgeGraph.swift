// MARK: - BASKnowledgeGraph — chapter 三百六九 / M856
//
// Phase P2 G9: typed knowledge-graph + causal-graph primitives。
// Closes G9 from chapter 三百五三 / M840 Cognitive OS roadmap by
// shipping the foundational graph data structure that hosts +
// future P2 work consume to:
//   - Detect causal cycles (user vision §10 "焦虑→加技术→做不完
//     →焦虑" complexity-addiction loop)
//   - Expose project / memory relationships to L9 (multi-path)
//     and L10 (arbitration) actors (M855 just shipped)
//   - Feed structured world-model state to future P2 G8 Mamba
//     SSM (event log → reducer → state vector → graph traversal)
//
// ## What this ships
//
//   - `BASKnowledgeNodeKind` typed enum (event / atom / project /
//     goal / state / external — extensible)
//   - `BASKnowledgeEdgeKind` typed enum (causes / delays /
//     replaces / contradicts / supports / mentions)
//   - `BASKnowledgeNode` typed value (Codable + Sendable)
//   - `BASKnowledgeEdge` typed value (Codable + Sendable)
//   - `BASKnowledgeGraph` actor (insert / query / walk / cycle
//     detection)
//
// ## Why in BASRuntimeCore
//
// Knowledge graph types must be visible to:
//   - BASMemory (atom store nodes)
//   - BASEventLog already in BASRuntimeCore (event nodes)
//   - BASUserStateReducer (consumes via reducer composition)
//   - Future BASHostKit consumers
//
// BASRuntimeCore is the right home — same module as BASEventLog
// + BASUserState + BAS14LayerMeshMap。No external import deps
// (Foundation only)。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — graph is pure data structure,
//     no permit/verdict mutation,no runtime weight feed
//   - 红线 7 hint-only — graph traversal results are observation/
//     hint material consumed by L9/L10/L14 actors
//   - 单提交口 (L11/L14) 不变 — graph feeds the gate as INPUT,
//     never bypasses
//   - chapter 二百一一 single-source-of-truth — ONE graph type,
//     ONE actor primitive
//   - chapter 一百八十五 anti-magic-number — edge type raw values
//     + default visit limits named typed constants
//   - chapter 一百二 五级删除 doctrine — `removeNode(...)` issues
//     real DELETE (cascades to incident edges);no tombstone
//   - ADR-014 OPT-IN → PROD — graph is opt-in;hosts that don't
//     construct it use existing tier-prefix retrieval / M850
//     vector RAG retrieval (no behavior change)

import Foundation

// MARK: - Node kind

/// Typed taxonomy of graph node kinds。Extensible via String
/// raw value (chapter 八十七 raw value stability — bumping
/// requires audit migration)。
public enum BASKnowledgeNodeKind: String, Codable, Equatable,
    Sendable, CaseIterable
{
    /// Event log entry (M841 BASEventLogEntry)
    case event
    /// Memory atom (M735 BASGovernedMemory / BASMemoryAtom)
    case atom
    /// Project / task name (eg. "chenglu-cognitive-os-roadmap")
    case project
    /// Goal node (eg. "ship-P1-foundation")
    case goal
    /// User state snapshot (M842 BASUserState)
    case state
    /// External context (eg. URL, document, tool)
    case external
}

// MARK: - Edge kind

/// Typed edge taxonomy。Mirrors user vision §10 causal-graph
/// edge types (causes / delays / replaces / contradicts /
/// supports / mentions)。
public enum BASKnowledgeEdgeKind: String, Codable, Equatable,
    Sendable, CaseIterable
{
    /// A → causes → B。User said X,X led to Y。
    case causes
    /// A → delays → B。User worked on X,delayed Y。
    case delays
    /// A → replaces → B。User pivoted from X to Y。
    case replaces
    /// A → contradicts → B。User asserted X,then asserted not-X。
    case contradicts
    /// A → supports → B。X provides evidence for Y。
    case supports
    /// A → mentions → B。X references Y (weak association)。
    case mentions
}

// MARK: - Node

/// Typed graph node。`payloadJson` is a free-form Codable
/// extension surface for kind-specific metadata。
public struct BASKnowledgeNode: Codable, Equatable, Sendable {
    /// Stable unique identifier。Caller-determined;graph
    /// rejects duplicates。
    public let nodeID: String

    /// Typed node kind per `BASKnowledgeNodeKind` taxonomy。
    public let kind: BASKnowledgeNodeKind

    /// Display label (whitespace-trimmed)。
    public let label: String

    /// Wall-clock ms when this node was created。
    public let createdAtMs: Int64

    /// Free-form JSON-encoded extension payload (Codable
    /// kind-specific metadata)。
    public let payloadJson: String?

    public init(
        nodeID: String,
        kind: BASKnowledgeNodeKind,
        label: String,
        createdAtMs: Int64,
        payloadJson: String? = nil
    ) {
        self.nodeID = nodeID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.kind = kind
        self.label = label.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.createdAtMs = createdAtMs
        self.payloadJson = payloadJson
    }
}

// MARK: - Edge

/// Typed graph edge。Directed:`fromNodeID` → `toNodeID`。
public struct BASKnowledgeEdge: Codable, Equatable, Sendable {
    /// Stable unique identifier。
    public let edgeID: String

    /// Source node ID。
    public let fromNodeID: String

    /// Destination node ID。
    public let toNodeID: String

    /// Typed edge kind per `BASKnowledgeEdgeKind` taxonomy。
    public let kind: BASKnowledgeEdgeKind

    /// Edge weight in `[0, 1]`。Higher = stronger relationship。
    /// Used by traversal scoring + cycle-strength filters。
    public let weight: Double

    /// Wall-clock ms when this edge was created。
    public let createdAtMs: Int64

    public init(
        edgeID: String,
        fromNodeID: String,
        toNodeID: String,
        kind: BASKnowledgeEdgeKind,
        weight: Double = 0.5,
        createdAtMs: Int64
    ) {
        self.edgeID = edgeID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.fromNodeID = fromNodeID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.toNodeID = toNodeID.trimmingCharacters(
            in: .whitespacesAndNewlines)
        self.kind = kind
        // Clamp weight to [0, 1]
        self.weight = max(0, min(1, weight))
        self.createdAtMs = createdAtMs
    }
}

// MARK: - Errors

public enum BASKnowledgeGraphError: Error, Equatable, Sendable {
    case duplicateNodeID(String)
    case duplicateEdgeID(String)
    case nodeNotFound(String)
}

// MARK: - Cycle result

/// Typed result of cycle detection — a sequence of nodeIDs
/// forming a directed cycle。
public struct BASKnowledgeCycle: Equatable, Sendable {
    /// Ordered list of nodeIDs forming the cycle。Length ≥ 2;
    /// the cycle closes from `nodeIDs.last` back to
    /// `nodeIDs.first`。
    public let nodeIDs: [String]

    /// The edge kinds traversed in cycle order (parallel to
    /// `nodeIDs`)。Length == nodeIDs.count (last entry is the
    /// closing edge from last back to first)。
    public let edgeKinds: [BASKnowledgeEdgeKind]

    public init(
        nodeIDs: [String],
        edgeKinds: [BASKnowledgeEdgeKind]
    ) {
        self.nodeIDs = nodeIDs
        self.edgeKinds = edgeKinds
    }

    /// Cycle length (== nodeIDs.count)。
    public var length: Int { nodeIDs.count }

    /// Convenience: does this cycle include any edges of the
    /// given kind? Used by user-vision §10 detection ("does
    /// this cycle include `delays` edges?")。
    public func containsEdgeKind(
        _ kind: BASKnowledgeEdgeKind
    ) -> Bool {
        edgeKinds.contains(kind)
    }
}

// MARK: - Knowledge graph actor

/// Actor-isolated knowledge graph storage + traversal。
///
/// **Storage**: in-memory dict-of-dicts (nodeID → node;
/// nodeID → outgoing edges)。SQLite persistence ships in a
/// future chapter when corpus size requires it (per M840 §3.4
/// "iPhone-scale corpus < 10K nodes" doctrine — in-memory is
/// sufficient for personal cognitive OS scale)。
///
/// **Thread safety**: actor-isolated;all mutating operations
/// + reads are serialized through actor isolation。
public actor BASKnowledgeGraph {

    /// Maximum cycle length the cycle detector enumerates per
    /// start node (chapter 一百八十五 anti-magic-number — pinned
    /// to prevent runaway DFS on densely-connected graphs)。
    public static let defaultMaxCycleLength: Int = 8

    /// Maximum total cycles returned per detect call。
    public static let defaultMaxCyclesReturned: Int = 32

    private var nodes: [String: BASKnowledgeNode] = [:]
    private var outgoingEdges: [String: [BASKnowledgeEdge]] = [:]
    private var edgeIDIndex: Set<String> = []

    public init() {}

    // MARK: - Insert / remove

    /// Insert a new node。Throws on duplicate nodeID。
    public func insert(
        node: BASKnowledgeNode
    ) throws {
        guard nodes[node.nodeID] == nil else {
            throw BASKnowledgeGraphError.duplicateNodeID(
                node.nodeID)
        }
        nodes[node.nodeID] = node
    }

    /// Insert / replace a node by ID (idempotent)。
    public func upsert(
        node: BASKnowledgeNode
    ) {
        nodes[node.nodeID] = node
    }

    /// Insert a new edge。Throws on duplicate edgeID,or if
    /// either endpoint is missing。
    public func insert(
        edge: BASKnowledgeEdge
    ) throws {
        guard edgeIDIndex.contains(edge.edgeID) == false else {
            throw BASKnowledgeGraphError.duplicateEdgeID(
                edge.edgeID)
        }
        guard nodes[edge.fromNodeID] != nil else {
            throw BASKnowledgeGraphError.nodeNotFound(
                edge.fromNodeID)
        }
        guard nodes[edge.toNodeID] != nil else {
            throw BASKnowledgeGraphError.nodeNotFound(
                edge.toNodeID)
        }
        edgeIDIndex.insert(edge.edgeID)
        outgoingEdges[edge.fromNodeID, default: []]
            .append(edge)
    }

    /// Remove a node by ID。Cascades to all incident edges
    /// (incoming + outgoing — chapter 一百二 五级删除 doctrine:
    /// real DELETE,no tombstone)。Returns true if removed,
    /// false if absent。
    @discardableResult
    public func remove(nodeID: String) -> Bool {
        guard nodes.removeValue(forKey: nodeID) != nil
        else { return false }
        // Drop outgoing edges from this node
        if let outgoing = outgoingEdges
            .removeValue(forKey: nodeID)
        {
            for edge in outgoing {
                edgeIDIndex.remove(edge.edgeID)
            }
        }
        // Drop incoming edges (scan + filter)
        for (sourceID, edges) in outgoingEdges {
            let filtered = edges.filter { edge in
                if edge.toNodeID == nodeID {
                    edgeIDIndex.remove(edge.edgeID)
                    return false
                }
                return true
            }
            outgoingEdges[sourceID] = filtered
        }
        return true
    }

    // MARK: - Query

    public func node(forID id: String) -> BASKnowledgeNode? {
        nodes[id]
    }

    /// Outgoing edges from a node。Returns empty array if
    /// node has no outgoing edges or doesn't exist。
    public func outgoing(
        from nodeID: String
    ) -> [BASKnowledgeEdge] {
        outgoingEdges[nodeID] ?? []
    }

    public var nodeCount: Int { nodes.count }

    public var edgeCount: Int { edgeIDIndex.count }

    // MARK: - Cycle detection

    /// Detect directed cycles in the graph。Returns up to
    /// `maxCycles` cycles,each up to `maxLength` nodes long。
    ///
    /// **Algorithm**: bounded DFS from each node,tracking
    /// visited path,recording cycles when re-encountering the
    /// start node。NOT a full Tarjan SCC algorithm — this is
    /// sufficient for personal-cognitive-OS scale (< 10K nodes)
    /// + bounded depth (defaultMaxCycleLength = 8) per chapter
    /// 一百八十五 anti-magic-number doctrine。
    ///
    /// **Use case** (user vision §10): detect "焦虑→加技术→
    /// 做不完→焦虑" complexity-addiction loop。Caller filters
    /// returned cycles by edge kinds (eg. cycles containing at
    /// least one `delays` edge are interesting)。
    ///
    /// - Parameters:
    ///   - maxLength: max cycle length to enumerate (default 8)
    ///   - maxCycles: max cycles to return (default 32)
    ///   - filter: optional predicate to filter cycles before
    ///     returning。Default returns all detected。
    /// - Returns: typed cycles in detection order (deduplicated
    ///   by canonical rotation — same cycle from different
    ///   start points returned only once)
    public func detectCycles(
        maxLength: Int = defaultMaxCycleLength,
        maxCycles: Int = defaultMaxCyclesReturned,
        filter: ((BASKnowledgeCycle) -> Bool)? = nil
    ) -> [BASKnowledgeCycle] {
        guard maxLength >= 2, maxCycles > 0 else {
            return []
        }
        var cycles: [BASKnowledgeCycle] = []
        var seenCanonicalKeys: Set<String> = []
        for startNodeID in nodes.keys.sorted() {
            if cycles.count >= maxCycles { break }
            walkForCycles(
                start: startNodeID,
                current: startNodeID,
                path: [startNodeID],
                edgeKinds: [],
                maxLength: maxLength,
                maxCycles: maxCycles,
                cycles: &cycles,
                seenCanonicalKeys: &seenCanonicalKeys,
                filter: filter)
        }
        return cycles
    }

    private func walkForCycles(
        start: String,
        current: String,
        path: [String],
        edgeKinds: [BASKnowledgeEdgeKind],
        maxLength: Int,
        maxCycles: Int,
        cycles: inout [BASKnowledgeCycle],
        seenCanonicalKeys: inout Set<String>,
        filter: ((BASKnowledgeCycle) -> Bool)?
    ) {
        guard cycles.count < maxCycles else { return }
        guard path.count <= maxLength else { return }
        for edge in outgoingEdges[current] ?? [] {
            if edge.toNodeID == start && path.count >= 2 {
                // Cycle closes at start
                let cycle = BASKnowledgeCycle(
                    nodeIDs: path,
                    edgeKinds: edgeKinds + [edge.kind])
                let canonicalKey = canonicalCycleKey(cycle)
                if !seenCanonicalKeys.contains(canonicalKey) {
                    seenCanonicalKeys.insert(canonicalKey)
                    if filter?(cycle) ?? true {
                        cycles.append(cycle)
                        if cycles.count >= maxCycles {
                            return
                        }
                    }
                }
                continue
            }
            // Skip if this would re-visit a non-start node
            // (we want simple cycles only)
            if path.contains(edge.toNodeID) { continue }
            walkForCycles(
                start: start,
                current: edge.toNodeID,
                path: path + [edge.toNodeID],
                edgeKinds: edgeKinds + [edge.kind],
                maxLength: maxLength,
                maxCycles: maxCycles,
                cycles: &cycles,
                seenCanonicalKeys: &seenCanonicalKeys,
                filter: filter)
        }
    }

    /// Canonical key for cycle dedup: rotate so the
    /// lexicographically-smallest nodeID is first,then join
    /// nodeIDs + edgeKinds together so cycles with same node
    /// sequence but different edge kinds are kept distinct
    /// (eg. when two parallel edges connect the same pair with
    /// different kinds — both cycles are interesting separately
    /// for filtering by edge kind)。
    private func canonicalCycleKey(
        _ cycle: BASKnowledgeCycle
    ) -> String {
        guard !cycle.nodeIDs.isEmpty else { return "" }
        // Find min nodeID + its index
        var minIndex = 0
        for (idx, id) in cycle.nodeIDs.enumerated() {
            if id < cycle.nodeIDs[minIndex] {
                minIndex = idx
            }
        }
        // Rotate nodes AND edge kinds together (same offset
        // because both arrays are parallel by construction:
        // nodeIDs[i] → edgeKinds[i] points to nodeIDs[i+1])
        let rotatedNodes =
            Array(cycle.nodeIDs[minIndex...])
            + Array(cycle.nodeIDs[..<minIndex])
        let rotatedKinds: [BASKnowledgeEdgeKind]
        if cycle.edgeKinds.count == cycle.nodeIDs.count {
            rotatedKinds =
                Array(cycle.edgeKinds[minIndex...])
                + Array(cycle.edgeKinds[..<minIndex])
        } else {
            rotatedKinds = cycle.edgeKinds
        }
        let nodePart = rotatedNodes.joined(separator: "→")
        let kindPart = rotatedKinds
            .map { $0.rawValue }
            .joined(separator: "|")
        return "\(nodePart)::\(kindPart)"
    }
}
