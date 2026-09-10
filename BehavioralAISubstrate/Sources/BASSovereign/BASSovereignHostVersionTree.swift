import Foundation

/// Host version tree — the "which host profile did we come from,
/// and which ones could we go back to" index used by the sovereign
/// rollback path.
///
/// ## Why this exists
///
/// `SnapshotAnchor` names a `hostVersionRef`, but before this tree
/// existed the ref was an opaque string. Nobody could answer:
///
/// - "Is host version X reachable by rollback from host version Y?"
/// - "Show me the diff path between Y and Z."
/// - "What's the latest host version that is NOT marked bad?"
///
/// The sovereign kernel needs all three to execute `.rollback` and
/// `.deadStop` verdicts deterministically. This tree is the answer.
///
/// ## Shape
///
/// The tree is a forward-only DAG (every node has at most one
/// parent; children form the tree). Each node carries:
///
/// - `versionID`: stable identifier (the ref used in anchors)
/// - `parentID`: the version this was derived from, nil for genesis
/// - `diffSummary`: human-readable short description of what changed
/// - `isKnownGood`: a node can be marked bad after the fact, e.g.
///   when a verdict rolls back through it; rollback target selection
///   skips bad nodes.
/// - `recordedAt`: registration timestamp
///
/// Operations are append-only: versions are registered, never
/// deleted. Marking bad is a state transition, not a removal.
public actor BASSovereignHostVersionTree {
    public enum TreeError:
        Error, Equatable, Sendable, Codable
    {
        case unknownVersion(id: String)
        case parentUnknown(parent: String, child: String)
        case parentSelfReference(id: String)
        case duplicateVersion(id: String)
        case cycle(at: String)
    }

    public struct Node: Sendable, Equatable, Codable {
        public let versionID: String
        public let parentID: String?
        public let diffSummary: String
        public var isKnownGood: Bool
        public var badReason: String?
        public let recordedAt: Date

        public init(
            versionID: String,
            parentID: String?,
            diffSummary: String,
            isKnownGood: Bool = true,
            badReason: String? = nil,
            recordedAt: Date
        ) {
            self.versionID = versionID
            self.parentID = parentID
            self.diffSummary = diffSummary
            self.isKnownGood = isKnownGood
            self.badReason = badReason
            self.recordedAt = recordedAt
        }
    }

    /// Path result from `lineage(from:to:)`. `commonAncestor` is the
    /// lowest version present on both ancestor chains; `up` is the
    /// path from `from` up to the common ancestor (exclusive); `down`
    /// is the path from the common ancestor (exclusive) down to `to`.
    public struct LineagePath:
        Sendable, Equatable, Codable
    {
        public let from: String
        public let to: String
        public let commonAncestor: String?
        public let up: [String]
        public let down: [String]
    }

    private var nodes: [String: Node] = [:]
    /// Parent-id → child ids, for descendant traversal.
    private var childIndex: [String: [String]] = [:]
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: - Registration

    public func registerGenesis(
        versionID: String,
        diffSummary: String = "genesis"
    ) throws {
        if nodes[versionID] != nil {
            throw TreeError.duplicateVersion(id: versionID)
        }
        nodes[versionID] = Node(
            versionID: versionID,
            parentID: nil,
            diffSummary: diffSummary,
            recordedAt: now())
    }

    public func registerVersion(
        versionID: String,
        parentID: String,
        diffSummary: String
    ) throws {
        if versionID == parentID {
            throw TreeError.parentSelfReference(id: versionID)
        }
        if nodes[versionID] != nil {
            throw TreeError.duplicateVersion(id: versionID)
        }
        guard nodes[parentID] != nil else {
            throw TreeError.parentUnknown(
                parent: parentID, child: versionID)
        }
        nodes[versionID] = Node(
            versionID: versionID,
            parentID: parentID,
            diffSummary: diffSummary,
            recordedAt: now())
        childIndex[parentID, default: []].append(versionID)
    }

    public func markBad(versionID: String, reason: String) throws {
        guard var node = nodes[versionID] else {
            throw TreeError.unknownVersion(id: versionID)
        }
        node.isKnownGood = false
        node.badReason = reason
        nodes[versionID] = node
    }

    public func markGood(versionID: String) throws {
        guard var node = nodes[versionID] else {
            throw TreeError.unknownVersion(id: versionID)
        }
        node.isKnownGood = true
        node.badReason = nil
        nodes[versionID] = node
    }

    // MARK: - Navigation

    public func node(_ versionID: String) -> Node? {
        nodes[versionID]
    }

    public func parent(of versionID: String) throws -> Node? {
        guard let n = nodes[versionID] else {
            throw TreeError.unknownVersion(id: versionID)
        }
        if let pid = n.parentID { return nodes[pid] }
        return nil
    }

    public func children(of versionID: String) throws -> [Node] {
        guard nodes[versionID] != nil else {
            throw TreeError.unknownVersion(id: versionID)
        }
        return (childIndex[versionID] ?? []).compactMap { nodes[$0] }
    }

    /// Walk parent links from `versionID` up to the root. Guarded
    /// against cycles (which can't happen if registration was well-
    /// formed, but we still check — the registry is append-only but
    /// nothing stops a caller from recording a duplicate id in a
    /// different instance).
    public func ancestors(of versionID: String) throws -> [Node] {
        guard nodes[versionID] != nil else {
            throw TreeError.unknownVersion(id: versionID)
        }
        var out: [Node] = []
        var seen: Set<String> = [versionID]
        var current = nodes[versionID]?.parentID
        while let pid = current {
            if seen.contains(pid) {
                throw TreeError.cycle(at: pid)
            }
            seen.insert(pid)
            guard let pn = nodes[pid] else {
                throw TreeError.parentUnknown(
                    parent: pid, child: versionID)
            }
            out.append(pn)
            current = pn.parentID
        }
        return out
    }

    /// All nodes reachable by walking `childIndex` from `versionID`
    /// (depth-first).
    public func descendants(of versionID: String) throws -> [Node] {
        guard nodes[versionID] != nil else {
            throw TreeError.unknownVersion(id: versionID)
        }
        var out: [Node] = []
        var stack = childIndex[versionID] ?? []
        while let next = stack.popLast() {
            guard let n = nodes[next] else { continue }
            out.append(n)
            stack.append(contentsOf: childIndex[next] ?? [])
        }
        return out
    }

    /// Lowest-common-ancestor-based path between two versions.
    /// Returns the ids on the "up" leg (from `from` to LCA, exclusive
    /// of LCA) and the "down" leg (from LCA to `to`, exclusive of LCA).
    /// Both nodes must be registered; they don't have to share a
    /// common ancestor — if they're in disjoint trees, LCA is nil and
    /// `up`/`down` are each full climbs to their respective roots.
    public func lineage(from: String, to: String) throws -> LineagePath {
        guard nodes[from] != nil else {
            throw TreeError.unknownVersion(id: from)
        }
        guard nodes[to] != nil else {
            throw TreeError.unknownVersion(id: to)
        }
        let fromAncestors =
            try [from] + ancestors(of: from).map(\.versionID)
        let toAncestors =
            try [to] + ancestors(of: to).map(\.versionID)
        let fromSet = Set(fromAncestors)
        let lca = toAncestors.first(where: { fromSet.contains($0) })

        let upLeg: [String] = {
            guard let lca else { return fromAncestors }
            var out: [String] = []
            for v in fromAncestors {
                if v == lca { break }
                out.append(v)
            }
            return out
        }()
        let downLeg: [String] = {
            guard let lca else { return toAncestors.reversed() }
            var out: [String] = []
            for v in toAncestors {
                if v == lca { break }
                out.append(v)
            }
            return out.reversed()
        }()
        return LineagePath(
            from: from,
            to: to,
            commonAncestor: lca,
            up: upLeg,
            down: downLeg)
    }

    // MARK: - Rollback target selection

    /// Latest-known-good ancestor of `versionID`.
    ///
    /// - When `includingSelf == true` (default): if `versionID`
    ///   itself is known good it is returned; otherwise the
    ///   closest good ancestor is returned.
    /// - When `includingSelf == false`: self is skipped; only
    ///   strictly-upward ancestors are considered. This is the
    ///   mode the rollback coordinator uses — rolling back to
    ///   "self" is a contradiction.
    ///
    /// Returns nil if no good target exists under the chosen mode.
    public func latestKnownGoodAncestor(
        of versionID: String,
        includingSelf: Bool = true
    ) throws -> Node? {
        guard let start = nodes[versionID] else {
            throw TreeError.unknownVersion(id: versionID)
        }
        if includingSelf, start.isKnownGood { return start }
        for ancestor in try ancestors(of: versionID) {
            if ancestor.isKnownGood { return ancestor }
        }
        return nil
    }

    // MARK: - Diagnostics

    public func allVersions() -> [Node] {
        nodes.values.sorted { $0.recordedAt < $1.recordedAt }
    }

    public func versionCount() -> Int { nodes.count }
}
