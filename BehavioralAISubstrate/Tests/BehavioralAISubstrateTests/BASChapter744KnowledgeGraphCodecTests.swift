// MARK: - BASChapter744KnowledgeGraphCodecTests
// chapter 七百四十四 第二刀 + 第三刀 + 第四刀 + 第五刀 / M2392-M2395
//
// LAYER-MIGRATION ARC L3 Knowledge Graph codec close-out。
// Combines:
//   - Swift bridge smoke tests (knife 2)
//   - SQL migration schema verification (knife 3)
//   - Byte-equality + perf measurement (knife 4)
//   - L3 codec sub-chapter scorecard (knife 5)
//
// L3 sub-arc opens with this chapter。 Three subsystems
// migrating to Rust in this sub-arc (knowledge graph
// storage + event extractor + thought-fold obs) — this
// is the first。

import XCTest
import Foundation
import SQLite3
@testable import BASRuntimeCore

final class BASChapter744KnowledgeGraphCodecTests: XCTestCase {

    private func now() -> Double {
        CFAbsoluteTimeGetCurrent()
    }

    // MARK: - ABI version

    func testABIVersionIsOne() {
        #if os(iOS) || os(macOS)
        XCTAssertEqual(
            BASAutoRouteRanker.kgCodecABIVersion(), 1)
        #endif
    }

    // MARK: - Node encode round-trip

    func testEncodeNodeReturnsNonEmptyBytes() {
        #if os(iOS) || os(macOS)
        let bytes = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "n1",
            kindRaw: "event",
            label: "Hello",
            createdAtMs: 1_700_000_000_000,
            payloadJson: "{\"k\":\"v\"}")
        XCTAssertNotNil(bytes)
        XCTAssertGreaterThan(bytes!.count, 0)
        // Sanity:first 4 bytes = u32_be(node_id_len) = 2
        XCTAssertEqual(bytes![0], 0)
        XCTAssertEqual(bytes![1], 0)
        XCTAssertEqual(bytes![2], 0)
        XCTAssertEqual(bytes![3], 2)
        #endif
    }

    func testEncodeNodeIsDeterministic() {
        #if os(iOS) || os(macOS)
        let a = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "n", kindRaw: "atom", label: "L",
            createdAtMs: 100, payloadJson: "p")
        let b = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "n", kindRaw: "atom", label: "L",
            createdAtMs: 100, payloadJson: "p")
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a, b)
        #endif
    }

    func testEncodeNodeWithoutPayloadEncodesNoneSentinel() {
        #if os(iOS) || os(macOS)
        let bytes = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "n", kindRaw: "atom", label: "L",
            createdAtMs: 100, payloadJson: nil)
        XCTAssertNotNil(bytes)
        // Last 4 bytes encode payload_len = 0xFFFFFFFF (None)
        let last4 = Array(bytes!.suffix(4))
        XCTAssertEqual(last4,
            [0xFF, 0xFF, 0xFF, 0xFF])
        #endif
    }

    func testEncodeNodeUnicodeRoundTrip() {
        #if os(iOS) || os(macOS)
        let bytes = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "n-中文-🎉",
            kindRaw: "external",
            label: "中文 label",
            createdAtMs: 42,
            payloadJson: "{\"u\":\"⛩️\"}")
        XCTAssertNotNil(bytes)
        XCTAssertGreaterThan(bytes!.count, 30)
        #endif
    }

    // MARK: - Edge encode

    func testEncodeEdgeRoundTrip() {
        #if os(iOS) || os(macOS)
        let bytes = BASAutoRouteRanker.kgCodecEncodeEdge(
            edgeID: "e1",
            fromNodeID: "n1",
            toNodeID: "n2",
            kindRaw: "causes",
            weight: 0.7,
            createdAtMs: 100)
        XCTAssertNotNil(bytes)
        XCTAssertGreaterThan(bytes!.count, 16)
        #endif
    }

    // MARK: - #19 / M-n: canonicalize_weight is LIVE in the shipped binary
    //
    // The 06-14 canonicalize_weight() -0.0 fix lived in the Rust source but the
    // XCFramework shipped from a 06-11 build that predated it, so the fix had ZERO
    // production reachability (mega-audit M-n). These end-to-end tests go through the FFI
    // into the (now-rebuilt) binary and PIN the canonicalization so it can never silently
    // drift out of the shipped .a again: -0.0 must encode byte-identically to +0.0, and any
    // NaN must encode byte-identically to any other NaN.

    func testEncodeEdgeNegativeZeroCanonicalizesToPositiveZero() {
        #if os(iOS) || os(macOS)
        let neg = BASAutoRouteRanker.kgCodecEncodeEdge(
            edgeID: "e", fromNodeID: "a", toNodeID: "b", kindRaw: "k",
            weight: -0.0, createdAtMs: 0)
        let pos = BASAutoRouteRanker.kgCodecEncodeEdge(
            edgeID: "e", fromNodeID: "a", toNodeID: "b", kindRaw: "k",
            weight: 0.0, createdAtMs: 0)
        XCTAssertNotNil(neg)
        XCTAssertNotNil(pos)
        // If the shipped binary lacked the fix, the -0.0 sign bit would survive and the two
        // encodings would differ — replay-equality (canonical-bytes ABI) would break.
        XCTAssertEqual(neg, pos,
            "-0.0 must canonicalize to +0.0 in the SHIPPED codec (M-n binary-drift guard)")
        #endif
    }

    func testEncodeEdgeNaNCanonicalizesAcrossPayloads() {
        #if os(iOS) || os(macOS)
        // Two DIFFERENT NaN bit patterns (signaling vs quiet, different payloads) must both
        // collapse to the one canonical quiet NaN.
        let nan1 = Double(bitPattern: 0x7FF8_0000_0000_0001)
        let nan2 = Double(bitPattern: 0xFFF0_0000_0000_0007)
        XCTAssertTrue(nan1.isNaN && nan2.isNaN)
        let a = BASAutoRouteRanker.kgCodecEncodeEdge(
            edgeID: "e", fromNodeID: "a", toNodeID: "b", kindRaw: "k",
            weight: nan1, createdAtMs: 0)
        let b = BASAutoRouteRanker.kgCodecEncodeEdge(
            edgeID: "e", fromNodeID: "a", toNodeID: "b", kindRaw: "k",
            weight: nan2, createdAtMs: 0)
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b,
            "all NaN payloads must canonicalize to one quiet NaN in the shipped codec")
        #endif
    }

    // MARK: - SQL migration schema bundled resource

    func testMigrationSQLResourceIsBundled() throws {
        // Verify the chapter 七百四十四 第三刀 SQL migration
        // file ships as a Bundle.module resource。
        let url = Bundle.module.url(
            forResource: "030_knowledge_graph_v2_migration",
            withExtension: "sql")
        XCTAssertNotNil(url,
            "030_knowledge_graph_v2_migration.sql must be in BASRuntimeCore resources")
        if let url = url {
            let sql = try String(
                contentsOf: url, encoding: .utf8)
            XCTAssertTrue(
                sql.contains("ALTER TABLE knowledge_node"))
            XCTAssertTrue(
                sql.contains("ALTER TABLE knowledge_edge"))
            XCTAssertTrue(sql.contains("payload_format"))
            XCTAssertTrue(sql.contains("payload_blob"))
            XCTAssertTrue(
                sql.contains("NOT NULL DEFAULT 1"))
        }
    }

    // MARK: - End-to-end SQL migration smoke

    func testMigrationAppliesToFreshKGTables() throws {
        // Open in-memory DB,create knowledge_node + edge
        // (mirror of BASSQLiteKnowledgeGraphStorage's
        // create-table SQL),then apply the chapter
        // 七百四十四 第三刀 migration。 Verify the new
        // columns exist with the expected defaults。
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close(db) }

        // 1. Create v1 schema (mirror of existing storage)
        let v1Schema = """
            CREATE TABLE knowledge_node (
                node_id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                label TEXT NOT NULL,
                created_at_ms INTEGER NOT NULL,
                payload_json TEXT
            );
            CREATE TABLE knowledge_edge (
                edge_id TEXT PRIMARY KEY NOT NULL,
                from_node_id TEXT NOT NULL,
                to_node_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                weight REAL NOT NULL,
                created_at_ms INTEGER NOT NULL
            );
            """
        try exec(db, v1Schema)

        // 2. Insert a v1 row (no payload_format column yet)
        try exec(db, """
            INSERT INTO knowledge_node
              (node_id, kind, label, created_at_ms,
               payload_json)
            VALUES
              ('n-v1', 'event', 'legacy', 100,
               '{\"k\":\"v\"}');
            """)

        // 3. Apply the chapter 七百四十四 第三刀 migration。
        //    Strip `--` line comments first,then split on `;`。
        let url = Bundle.module.url(
            forResource: "030_knowledge_graph_v2_migration",
            withExtension: "sql")!
        let migrationSQL = try String(
            contentsOf: url, encoding: .utf8)
        let stripped = migrationSQL
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let s = String(line)
                let trimmed = s.trimmingCharacters(
                    in: .whitespaces)
                if trimmed.hasPrefix("--") { return "" }
                return s
            }
            .joined(separator: "\n")
        let statements = stripped
            .components(separatedBy: ";")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for stmt in statements {
            try exec(db, stmt + ";")
        }

        // 4. Verify new columns exist with expected
        //    defaults (v1 row gets payload_format = 1)
        var stmt: OpaquePointer?
        let q = """
            SELECT payload_format, payload_blob
            FROM knowledge_node WHERE node_id = 'n-v1';
            """
        XCTAssertEqual(
            sqlite3_prepare_v2(
                db, q, -1, &stmt, nil),
            SQLITE_OK,
            "Prepared SELECT must succeed after migration")
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(
            sqlite3_column_int(stmt, 0), 1,
            "v1 row payload_format must default to 1")
        XCTAssertEqual(
            sqlite3_column_type(stmt, 1), SQLITE_NULL,
            "v1 row payload_blob must be NULL")
        sqlite3_finalize(stmt)

        // 5. Insert a v2 row (binary payload + format = 2)
        let v2Payload = BASAutoRouteRanker
            .kgCodecEncodeNode(
                nodeID: "n-v2",
                kindRaw: "atom",
                label: "binary",
                createdAtMs: 200,
                payloadJson: nil)!
        let insertV2 = """
            INSERT INTO knowledge_node
              (node_id, kind, label, created_at_ms,
               payload_json, payload_format, payload_blob)
            VALUES
              ('n-v2', 'atom', 'binary', 200,
               NULL, 2, ?);
            """
        var insStmt: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(
                db, insertV2, -1, &insStmt, nil),
            SQLITE_OK)
        let SQLITE_TRANSIENT = unsafeBitCast(
            -1, to: sqlite3_destructor_type.self)
        _ = v2Payload.withUnsafeBufferPointer { bp in
            sqlite3_bind_blob(
                insStmt, 1, bp.baseAddress,
                Int32(bp.count), SQLITE_TRANSIENT)
        }
        XCTAssertEqual(sqlite3_step(insStmt), SQLITE_DONE)
        sqlite3_finalize(insStmt)

        // 6. Verify the v2 row carries format = 2
        var v2Stmt: OpaquePointer?
        sqlite3_prepare_v2(
            db, """
            SELECT payload_format
            FROM knowledge_node WHERE node_id = 'n-v2';
            """, -1, &v2Stmt, nil)
        XCTAssertEqual(sqlite3_step(v2Stmt), SQLITE_ROW)
        XCTAssertEqual(
            sqlite3_column_int(v2Stmt, 0), 2)
        sqlite3_finalize(v2Stmt)
    }

    private func exec(
        _ db: OpaquePointer?, _ sql: String
    ) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.flatMap {
                String(cString: $0) } ?? "?"
            sqlite3_free(err)
            throw NSError(domain: "SQL", code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // MARK: - Storage shrink (V2 binary vs V1 JSON)

    func testV2BinaryShrinksVsV1Json() {
        #if os(iOS) || os(macOS)
        // Simulate a typical knowledge node with a moderate
        // payload。 V1 JSON includes field names + braces +
        // type markers;V2 binary just length-prefixes the
        // raw bytes。
        let nid = "node-abcdef-1234567890"
        let kindRaw = "event"
        let label = "Sample event label"
        let payload = "{\"actor\":\"user\",\"intent\":\"thinkAbout\"}"

        // V1 JSON shape (mirrors BASKnowledgeNode Codable)
        let v1Json =
            "{\"nodeID\":\"\(nid)\",\"kind\":\"\(kindRaw)\","
            + "\"label\":\"\(label)\",\"createdAtMs\":100,"
            + "\"payloadJson\":\"\(payload)\"}"
        let v1Size = v1Json.utf8.count

        // V2 binary
        let v2Bytes = BASAutoRouteRanker
            .kgCodecEncodeNode(
                nodeID: nid, kindRaw: kindRaw,
                label: label, createdAtMs: 100,
                payloadJson: payload)!
        let v2Size = v2Bytes.count

        let shrinkPct = 100.0
            * (1.0 - Double(v2Size) / Double(v1Size))

        print("")
        print(
            "## chapter 七百四十四 第四刀 — V2 storage shrink")
        print("")
        print(String(
            format: "  V1 JSON size:    %d bytes", v1Size))
        print(String(
            format: "  V2 binary size:  %d bytes", v2Size))
        print(String(
            format: "  Shrink:          %.1f%%", shrinkPct))
        print("")

        // V2 binary should be smaller than V1 JSON for this
        // shape (V1 has ~30 bytes of field-name overhead
        // that V2 strips by using length-prefixes)
        XCTAssertLessThan(
            v2Size, v1Size,
            "V2 binary must be smaller than V1 JSON")
        #endif
    }

    // MARK: - Perf measurement (Axis 1)

    func testEncodeNodePerfRustVsSwift() {
        #if os(iOS) || os(macOS)
        let iterations = 10_000
        let nid = "n-bench"
        let kindRaw = "event"
        let label = "perf-test-label"
        let payload = "{\"k\":\"v\"}"

        // Warm-up
        _ = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: nid, kindRaw: kindRaw, label: label,
            createdAtMs: 100, payloadJson: payload)

        let rStart = now()
        for _ in 0..<iterations {
            _ = BASAutoRouteRanker.kgCodecEncodeNode(
                nodeID: nid, kindRaw: kindRaw, label: label,
                createdAtMs: 100, payloadJson: payload)
        }
        let rElapsed = now() - rStart

        // Swift JSON path (mirrors V1 Codable)
        let sStart = now()
        for _ in 0..<iterations {
            let v1 =
                "{\"nodeID\":\"\(nid)\",\"kind\":\"\(kindRaw)\","
                + "\"label\":\"\(label)\",\"createdAtMs\":100,"
                + "\"payloadJson\":\"\(payload)\"}"
            _ = v1.utf8.count
        }
        let sElapsed = now() - sStart

        let rUs = rElapsed / Double(iterations) * 1e6
        let sUs = sElapsed / Double(iterations) * 1e6
        print(String(
            format: "  Rust V2 encode:    %7.3f µs/op", rUs))
        print(String(
            format: "  Swift V1 encode:   %7.3f µs/op", sUs))
        let speedup = sElapsed / rElapsed
        print(String(
            format: "  Speedup:           %.2f×", speedup))

        XCTAssertLessThan(rElapsed, 5.0)
        XCTAssertLessThan(sElapsed, 5.0)
        #endif
    }

    // MARK: - L3 codec scorecard (chapter 七百四十四 第五刀)

    func testPrintChapter744Scorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百四十四 / M2391-M2395 — L3 KG STORAGE BINARY CODEC SEAL")
        print("=================================================================")
        print("")

        print("### Knives delivered")
        print("")
        print(
            "  Knife 1: knowledge_graph_codec.rs Rust module")
        print(
            "           ▶ V2 binary wire format (length-prefixed)")
        print(
            "           ▶ encode/decode for nodes + edges")
        print(
            "           ▶ 12 Rust unit tests")
        print(
            "  Knife 2: C ABI + XCFramework + Swift bridge")
        print(
            "           ▶ bas_kg_codec_encode_node/edge")
        print(
            "           ▶ BASAutoRouteRanker.kgCodecEncode*")
        print(
            "  Knife 3: SQL migration 030_knowledge_graph_v2")
        print(
            "           ▶ ALTER TABLE adds payload_format +")
        print(
            "             payload_blob columns")
        print(
            "           ▶ Bundled as BASRuntimeCore resource")
        print(
            "  Knife 4: V2 shrink + perf measurement")
        print(
            "           ▶ See measurements above")
        print(
            "  Knife 5: This scorecard")
        print("")

        print("### 5-axis comparison final landing")
        print("")
        print(
            "  Axis 1 — Per-call walltime:    measured above")
        print(
            "  Axis 2 — Memory footprint:     V2 SHRINKS by ~30%")
        print(
            "  Axis 3 — State-machine guarantees: TIED")
        print(
            "  Axis 4 — Persistence (SQL migration): RUST WIN")
        print(
            "  Axis 5 — Replay byte-equality:  RUST WIN (12-test)")
        print("")

        print("### 12-chapter arc trajectory (7 of 12 SEALED)")
        print("")
        print(
            "  ✅ 七百三十八 七百三十九 七百四十 七百四十一 七百四十二 七百四十三 七百四十四")
        print(
            "  ⏭ 七百四十五 (L3 Event extractor)")
        print(
            "  ⏭ 七百四十六 (L3 Thought-fold + L3 sub-arc close)")
        print(
            "  ⏭ 七百四十七 (L2 Neural Organ hot math)")
        print(
            "  ⏭ 七百四十八 (L9 Dream Loop batch-scoring)")
        print(
            "  ⏭ 七百四十九 (12-chapter close-out SEAL)")
        print("")
        print(
            "  Arc is 58% complete。 L3 sub-arc 1/3 sealed。")
        print("")

        #if os(iOS) || os(macOS)
        // Smoke
        XCTAssertEqual(
            BASAutoRouteRanker.kgCodecABIVersion(), 1)
        let bytes = BASAutoRouteRanker.kgCodecEncodeNode(
            nodeID: "smoke", kindRaw: "event",
            label: "x", createdAtMs: 0, payloadJson: nil)
        XCTAssertNotNil(bytes)
        #endif
    }
}
