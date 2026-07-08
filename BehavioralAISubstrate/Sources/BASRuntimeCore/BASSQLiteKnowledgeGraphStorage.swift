// MARK: - BASSQLiteKnowledgeGraphStorage — chapter 三百七九 / M866
//
// G9 第三刀: closes the M856 deferred persistence work。M856 doc
// noted "in-memory only;persistence ships in a future chapter
// when corpus size requires it"。M866 fills that gap with an
// optional SQLite-backed storage for `BASKnowledgeGraph` nodes +
// edges,mirroring the M735 / M841 / M849 / M863 SQLite idiom。
//
// ## Why this exists
//
// Pre-M866 hosts that wanted to retain their knowledge graph
// across sessions had to:
//   1. Use `BASKnowledgeGraphEventExtractor.extract(...)` from
//      the persisted event log (M841) every session,then
//   2. Re-run all heuristics (M860) every time they wanted the
//      graph populated
//
// That works for small event logs but burns CPU on warm starts
// for long-running personal cognitive OS sessions。M866 adds a
// "warm cache" layer:nodes + edges write-through to SQLite,then
// `preload(into: graph)` rehydrates the in-memory actor at
// session start。
//
// ## Mirrors `BASSQLiteVectorIndexStorage` (chapter 三百六二 / M849)
//
// Same idiom:
//   - `actor` for serialized access
//   - `import SQLite3` system framework
//   - `OpaquePointer` db handle owned by actor
//   - WAL journal mode + transient destructor + typed StorageError
//   - `appendNode(_:)` / `appendEdge(_:)` write methods
//   - `allNodes()` / `allEdges()` bulk read for preload
//   - `preload(into: graph)` async helper that bulk-rehydrates
//     the in-memory actor
//
// ## Schema (version 1)
//
//   CREATE TABLE knowledge_node (
//     node_id TEXT PRIMARY KEY NOT NULL,
//     kind TEXT NOT NULL,
//     label TEXT NOT NULL,
//     created_at_ms INTEGER NOT NULL,
//     payload_json TEXT
//   );
//   CREATE INDEX knowledge_node_kind_idx ON knowledge_node(kind);
//   CREATE INDEX knowledge_node_created_idx
//     ON knowledge_node(created_at_ms);
//
//   CREATE TABLE knowledge_edge (
//     edge_id TEXT PRIMARY KEY NOT NULL,
//     from_node_id TEXT NOT NULL,
//     to_node_id TEXT NOT NULL,
//     kind TEXT NOT NULL,
//     weight REAL NOT NULL,
//     created_at_ms INTEGER NOT NULL
//   );
//   CREATE INDEX knowledge_edge_from_idx
//     ON knowledge_edge(from_node_id);
//   CREATE INDEX knowledge_edge_to_idx
//     ON knowledge_edge(to_node_id);
//   CREATE INDEX knowledge_edge_kind_idx ON knowledge_edge(kind);
//
// ## Doctrine pins held
//
// All from BASKnowledgeGraph.swift apply。Additionally:
//   - chapter 二百四十八 (M735) — SQLite idiom mirrored
//   - chapter 一百九十一 (M91) — integrity > availability
//   - chapter 一百二 五级删除 — `removeNode/removeEdge` issues real
//     DELETE (caller-driven,mirrors graph actor semantics)

import Foundation
import SQLite3

/// SQLite-backed write-through storage for `BASKnowledgeGraph`。
/// Companion to the in-memory `BASKnowledgeGraph` actor — hosts
/// that want persistence wire BOTH and write through to storage
/// when they mutate the graph,then call `preload(into:)` at
/// session start to rehydrate from disk。
public actor BASSQLiteKnowledgeGraphStorage {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(id: String, message: String)
        case decodeFailed(id: String, message: String)
        case corruptedRow(id: String, reason: String)
        /// M884 (P3.6 audit fix):edge insert attempted with
        /// `from_node_id` OR `to_node_id` not present in the
        /// `knowledge_node` table。Pre-M884 the storage allowed
        /// dangling edges,which preload then silently dropped
        /// (in-memory `BASKnowledgeGraph.insert(edge:)` requires
        /// both endpoints exist) → storage.edgeCount diverged
        /// from in-memory edgeCount post-preload。
        case danglingEdgeEndpoint(
            edgeID: String,
            missingNodeID: String)
    }

    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    public let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Lifecycle

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(
            databaseURL.path, &handle, flags, nil)
        guard openRC == SQLITE_OK, let handle else {
            let message = handle.flatMap { db -> String? in
                String(cString: sqlite3_errmsg(db))
            } ?? "sqlite3_open_v2 rc=\(openRC)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw StorageError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle

        // audit M-c (损坏=空): surface a structurally-corrupt store at OPEN instead of letting the
        // reads' `(try? fetchAll) ?? []` mistake corruption for empty. Default-on, fail-closed.
        try BASSQLiteIntegrity.assertOK(db: handle, store: "knowledge-graph")

        try Self.runExec(
            db: handle, sql: "PRAGMA journal_mode=WAL;")
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete default-on (kill-switch BAS_SECURE_DELETE=0).
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: sdSQL)
        }
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        // M891 fix:tighter auto-checkpoint (200 pages ≈ 800KB)
        // bounds WAL growth on long-running stress runs。
        try Self.runExec(
            db: handle,
            sql: "PRAGMA wal_autocheckpoint=200;")

        // M882 fix (P2.5 audit):read user_version FIRST before
        // overwriting it。Pre-M882 the unconditional `PRAGMA
        // user_version=N` overwrote any existing value,silently
        // upgrading old databases (or downgrading future ones)
        // and making `verifySchemaVersion` a no-op since it ran
        // AFTER the overwrite。Post-M882:
        //   existing == 0 → fresh DB,set to current schema
        //   existing == current → accept (no-op write)
        //   existing != current → throw schemaVersionMismatch
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)
    }

    /// M882 helper:read `PRAGMA user_version` without setting
    /// it。Returns 0 for a freshly-created SQLite file。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "PRAGMA user_version;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Node CRUD

    /// Idempotent on duplicate nodeID — returns false if already
    /// stored,true if newly inserted。
    @discardableResult
    public func appendNode(
        _ node: BASKnowledgeNode
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        if try Self.fetchNode(
            db: db, nodeID: node.nodeID) != nil
        {
            return false
        }
        try Self.insertNode(db: db, node: node)
        return true
    }

    /// Upsert a node — if exists,replace;if not,insert。
    public func upsertNode(
        _ node: BASKnowledgeNode
    ) async throws {
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        try Self.upsertNode(db: db, node: node)
    }

    /// Fetch a node by ID。
    public func node(
        forID nodeID: String
    ) async -> BASKnowledgeNode? {
        guard let db else { return nil }
        return (try? Self.fetchNode(
            db: db, nodeID: nodeID)) ?? nil
    }

    /// Bulk-fetch all nodes ordered by createdAtMs ASC for
    /// stable preload sequence。
    public func allNodes() async -> [BASKnowledgeNode] {
        guard let db else { return [] }
        return (try? Self.fetchAllNodes(db: db)) ?? []
    }

    /// Remove a node + all incident edges。Returns true if a
    /// row was deleted。Mirrors graph actor semantics —
    /// `BASKnowledgeGraph.remove(nodeID:)` cascades incident
    /// edges,so this storage method does the same。
    ///
    /// Uses a prepared statement for the cascade DELETE rather
    /// than inline string interpolation。Per chapter 二百四十八
    /// M735 SQLite idiom — every external string flows through
    /// a parameter bind,never through string interpolation。
    @discardableResult
    public func removeNode(
        _ nodeID: String
    ) async throws -> Bool {
        guard let db else { return false }
        // Delete incident edges first (referential consistency)
        try Self.deleteIncidentEdges(db: db, nodeID: nodeID)
        return try Self.deleteNode(db: db, nodeID: nodeID)
    }

    /// Cascade-DELETE every edge incident to `nodeID` (either
    /// `from_node_id` OR `to_node_id`)。Prepared statement
    /// forecloses any SQL injection surface — caller-supplied
    /// nodeID flows through `bindText` only。
    fileprivate static func deleteIncidentEdges(
        db: OpaquePointer,
        nodeID: String
    ) throws {
        let sql = """
            DELETE FROM knowledge_edge
            WHERE from_node_id = ? OR to_node_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, nodeID)
        bindText(stmt, 2, nodeID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    public var nodeCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(
                db: db, table: "knowledge_node")) ?? 0
        }
    }

    // MARK: - Edge CRUD

    /// Idempotent on duplicate edgeID。
    ///
    /// M884 (P3.6 audit fix):validates both endpoints exist in
    /// `knowledge_node` before insert。Pre-M884 dangling edges
    /// could persist (no FK constraint),then silently drop on
    /// preload because in-memory `BASKnowledgeGraph.insert(edge:)`
    /// throws `nodeNotFound` for unknown endpoints。Post-M884 the
    /// storage rejects dangling edges with a typed error,keeping
    /// storage + in-memory edgeCount consistent。
    @discardableResult
    public func appendEdge(
        _ edge: BASKnowledgeEdge
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        if try Self.fetchEdge(
            db: db, edgeID: edge.edgeID) != nil
        {
            return false
        }
        // M884 endpoint validation:both ends must exist as
        // nodes。Use fetchNode (already-implemented) for the
        // existence check rather than COUNT(*) to keep the
        // pattern consistent with M866's idiom。
        if try Self.fetchNode(
            db: db, nodeID: edge.fromNodeID) == nil
        {
            throw StorageError.danglingEdgeEndpoint(
                edgeID: edge.edgeID,
                missingNodeID: edge.fromNodeID)
        }
        if try Self.fetchNode(
            db: db, nodeID: edge.toNodeID) == nil
        {
            throw StorageError.danglingEdgeEndpoint(
                edgeID: edge.edgeID,
                missingNodeID: edge.toNodeID)
        }
        try Self.insertEdge(db: db, edge: edge)
        return true
    }

    /// Bulk-fetch all edges ordered by createdAtMs ASC。
    public func allEdges() async -> [BASKnowledgeEdge] {
        guard let db else { return [] }
        return (try? Self.fetchAllEdges(db: db)) ?? []
    }

    @discardableResult
    public func removeEdge(
        _ edgeID: String
    ) async throws -> Bool {
        guard let db else { return false }
        return try Self.deleteEdge(db: db, edgeID: edgeID)
    }

    public var edgeCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(
                db: db, table: "knowledge_edge")) ?? 0
        }
    }

    // MARK: - Preload helper

    /// Preload all persisted nodes + edges into an in-memory
    /// `BASKnowledgeGraph`。Use at session start to restore the
    /// graph from disk。
    ///
    /// Returns `(nodesLoaded, edgesLoaded)`。Corrupt rows are
    /// individually-skipped (logged via callbacks) rather than
    /// failing the whole preload — chapter 一百九十一 integrity
    /// pin applies row-by-row。
    public func preload(
        into graph: BASKnowledgeGraph,
        onCorruptNode:
            (@Sendable (String, Error) -> Void)? = nil,
        onCorruptEdge:
            (@Sendable (String, Error) -> Void)? = nil
    ) async -> (
        nodesLoaded: Int, edgesLoaded: Int)
    {
        let nodes = await allNodes()
        var nodesLoaded = 0
        for node in nodes {
            // upsert doesn't throw — node insertion is
            // idempotent by design (overwrites by nodeID)。
            // The onCorruptNode callback is reserved for future
            // schema-version-mismatch decoder paths。
            _ = onCorruptNode
            await graph.upsert(node: node)
            nodesLoaded += 1
        }

        let edges = await allEdges()
        var edgesLoaded = 0
        for edge in edges {
            do {
                try await graph.insert(edge: edge)
                edgesLoaded += 1
            } catch {
                onCorruptEdge?(edge.edgeID, error)
            }
        }
        return (nodesLoaded, edgesLoaded)
    }

    // MARK: - Schema setup

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS knowledge_node (
                node_id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                label TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                payload_json TEXT
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                knowledge_node_kind_idx
                ON knowledge_node(kind);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                knowledge_node_created_idx
                ON knowledge_node(created_at_ms);
            """)

        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS knowledge_edge (
                edge_id TEXT PRIMARY KEY NOT NULL,
                from_node_id TEXT NOT NULL,
                to_node_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                weight REAL NOT NULL,
                created_at_ms INTEGER NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                knowledge_edge_from_idx
                ON knowledge_edge(from_node_id);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                knowledge_edge_to_idx
                ON knowledge_edge(to_node_id);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                knowledge_edge_kind_idx
                ON knowledge_edge(kind);
            """)
    }

    fileprivate static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let sql = "PRAGMA user_version;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let found = Int(sqlite3_column_int64(stmt, 0))
        guard found == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: found, expected: schemaVersion)
        }
    }

    // MARK: - Node CRUD primitives

    fileprivate static func insertNode(
        db: OpaquePointer,
        node: BASKnowledgeNode
    ) throws {
        let sql = """
            INSERT INTO knowledge_node (
                node_id, kind, label,
                created_at_ms, payload_json
            ) VALUES (?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, node.nodeID)
        bindText(stmt, 2, node.kind.rawValue)
        bindText(stmt, 3, node.label)
        sqlite3_bind_int64(stmt, 4, node.createdAtMs)
        if let payload = node.payloadJson {
            bindText(stmt, 5, payload)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func upsertNode(
        db: OpaquePointer,
        node: BASKnowledgeNode
    ) throws {
        // SQLite UPSERT (ON CONFLICT) — atomic insert-or-replace
        let sql = """
            INSERT INTO knowledge_node (
                node_id, kind, label,
                created_at_ms, payload_json
            ) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(node_id) DO UPDATE SET
                kind = excluded.kind,
                label = excluded.label,
                created_at_ms = excluded.created_at_ms,
                payload_json = excluded.payload_json
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, node.nodeID)
        bindText(stmt, 2, node.kind.rawValue)
        bindText(stmt, 3, node.label)
        sqlite3_bind_int64(stmt, 4, node.createdAtMs)
        if let payload = node.payloadJson {
            bindText(stmt, 5, payload)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchNode(
        db: OpaquePointer,
        nodeID: String
    ) throws -> BASKnowledgeNode? {
        let sql = """
            SELECT node_id, kind, label,
                   created_at_ms, payload_json
            FROM knowledge_node
            WHERE node_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, nodeID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return try buildNode(stmt: stmt)
    }

    fileprivate static func fetchAllNodes(
        db: OpaquePointer
    ) throws -> [BASKnowledgeNode] {
        let sql = """
            SELECT node_id, kind, label,
                   created_at_ms, payload_json
            FROM knowledge_node
            ORDER BY created_at_ms ASC, node_id ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var out: [BASKnowledgeNode] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            // M891 fix (post-deep-audit):per-row corruption
            // tolerance — pre-M891 a single bad node row threw
            // out of fetchAllNodes,then `try?` in `allNodes()`
            // swallowed the throw + returned `[]` → preload
            // silently lost ALL nodes,not just the corrupt one。
            // Post-M891 the bad row is skipped + good rows
            // are preserved per chapter 一百九十一 row-by-row
            // integrity doctrine。
            do {
                out.append(try buildNode(stmt: stmt))
            } catch {
                // Skip corrupt row;continue with remaining。
                // Caller can detect via storage.nodeCount vs
                // returned-array count if needed。
            }
        }
        return out
    }

    fileprivate static func deleteNode(
        db: OpaquePointer,
        nodeID: String
    ) throws -> Bool {
        let sql = """
            DELETE FROM knowledge_node WHERE node_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, nodeID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return sqlite3_changes(db) > 0
    }

    private static func buildNode(
        stmt: OpaquePointer
    ) throws -> BASKnowledgeNode {
        let id = readText(stmt, 0)
        let kindRaw = readText(stmt, 1)
        guard let kind = BASKnowledgeNodeKind(
            rawValue: kindRaw)
        else {
            throw StorageError.corruptedRow(
                id: id,
                reason: "unknown kind: \(kindRaw)")
        }
        let label = readText(stmt, 2)
        let createdAtMs = sqlite3_column_int64(stmt, 3)
        let payload: String?
        if sqlite3_column_type(stmt, 4) == SQLITE_NULL {
            payload = nil
        } else {
            payload = readText(stmt, 4)
        }
        return BASKnowledgeNode(
            nodeID: id,
            kind: kind,
            label: label,
            createdAtMs: createdAtMs,
            payloadJson: payload)
    }

    // MARK: - Edge CRUD primitives

    fileprivate static func insertEdge(
        db: OpaquePointer,
        edge: BASKnowledgeEdge
    ) throws {
        let sql = """
            INSERT INTO knowledge_edge (
                edge_id, from_node_id, to_node_id,
                kind, weight, created_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, edge.edgeID)
        bindText(stmt, 2, edge.fromNodeID)
        bindText(stmt, 3, edge.toNodeID)
        bindText(stmt, 4, edge.kind.rawValue)
        sqlite3_bind_double(stmt, 5, edge.weight)
        sqlite3_bind_int64(stmt, 6, edge.createdAtMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchEdge(
        db: OpaquePointer,
        edgeID: String
    ) throws -> BASKnowledgeEdge? {
        let sql = """
            SELECT edge_id, from_node_id, to_node_id,
                   kind, weight, created_at_ms
            FROM knowledge_edge
            WHERE edge_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, edgeID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return try buildEdge(stmt: stmt)
    }

    fileprivate static func fetchAllEdges(
        db: OpaquePointer
    ) throws -> [BASKnowledgeEdge] {
        let sql = """
            SELECT edge_id, from_node_id, to_node_id,
                   kind, weight, created_at_ms
            FROM knowledge_edge
            ORDER BY created_at_ms ASC, edge_id ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var out: [BASKnowledgeEdge] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            // M891 fix:per-row corruption tolerance (same as
            // fetchAllNodes — see that comment for rationale)。
            do {
                out.append(try buildEdge(stmt: stmt))
            } catch {
                // Skip corrupt row;continue with remaining。
            }
        }
        return out
    }

    fileprivate static func deleteEdge(
        db: OpaquePointer,
        edgeID: String
    ) throws -> Bool {
        let sql = """
            DELETE FROM knowledge_edge WHERE edge_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, edgeID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return sqlite3_changes(db) > 0
    }

    private static func buildEdge(
        stmt: OpaquePointer
    ) throws -> BASKnowledgeEdge {
        let id = readText(stmt, 0)
        let from = readText(stmt, 1)
        let to = readText(stmt, 2)
        let kindRaw = readText(stmt, 3)
        guard let kind = BASKnowledgeEdgeKind(
            rawValue: kindRaw)
        else {
            throw StorageError.corruptedRow(
                id: id,
                reason: "unknown edge kind: \(kindRaw)")
        }
        let weight = sqlite3_column_double(stmt, 4)
        let createdAtMs = sqlite3_column_int64(stmt, 5)
        return BASKnowledgeEdge(
            edgeID: id,
            fromNodeID: from,
            toNodeID: to,
            kind: kind,
            weight: weight,
            createdAtMs: createdAtMs)
    }

    // MARK: - Utility

    fileprivate static func countAll(
        db: OpaquePointer,
        table: String
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM \(table)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    fileprivate static func runExec(
        db: OpaquePointer,
        sql: String
    ) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let message = errMsg.flatMap { ptr -> String in
                let s = String(cString: ptr)
                sqlite3_free(ptr)
                return s
            } ?? "sqlite3_exec rc=\(rc)"
            throw StorageError.prepareFailed(
                sql: sql, message: message)
        }
    }

    fileprivate static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    fileprivate static func bindText(
        _ stmt: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    fileprivate static func readText(
        _ stmt: OpaquePointer,
        _ index: Int32
    ) -> String {
        guard let cstr = sqlite3_column_text(stmt, index)
        else { return "" }
        return String(cString: cstr)
    }

    // (`escape` helper removed — `deleteIncidentEdges` now uses
    // a prepared statement,so no inline string interpolation
    // path remains in this file。chapter 二百四十八 M735 idiom
    // upheld:every external string flows through bindText)
}
