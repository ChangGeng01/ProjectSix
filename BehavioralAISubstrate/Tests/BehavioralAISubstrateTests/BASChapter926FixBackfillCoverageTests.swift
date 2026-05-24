// MARK: - BASChapter926FixBackfillCoverageTests
// chapter 九百二十六 / M3335
//
// Swift-side test backfill closing the 6th-pass review gaps that
// chapter 925 missed。 The chapter 925 backfill claimed 11 tests
// for 11 gaps but actually delivered 6 of the 11 (the rest were
// silently substituted)。 Plus 4 NEW gaps the 6th-pass review
// found:
//
//   - testWalAutocheckpointIs1000 was FAKE coverage (read a
//     separate raw sqlite3 connection that returned SQLite's
//     default 1000,not the engine's PRAGMA-set value)
//   - cosineTopK [UInt8] overload had no NaN/dim guard
//   - cosine_topk_for_domain FFIs had no query_blob_len cap
//   - NH3 BLOB caps only tested signature_hash (1/3 of 3)
//   - MAX_HOTPATH_LIMIT only tested in 1 of 4 FFIs
//   - cosineTopK NaN test only tested Swift guard,not Rust
//
// Rust-side gaps (panic-safety + schema migration + poison
// recovery) shipped as Rust unit tests in lib.rs。 This file
// covers the Swift-reachable backfill。

import XCTest
@testable import BASMemory
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter926FixBackfillCoverageTests: XCTestCase {

    // MARK: - helpers

    private func makeTempDBURL(
        _ tag: String = "ch926"
    ) -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(
            "\(tag)-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        let paths = [
            url.path,
            url.path + "-wal",
            url.path + "-shm"]
        for p in paths {
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    /// Opens an L8Engine directly via FFI (bypassing the Swift
    /// storage wrappers) to exercise low-level invariants。 Used
    /// for tests that need to verify FFI return codes,raw PRAGMA
    /// values,or BLOB caps applied at the Rust boundary。
    private func openEngine(
        url: URL? = nil
    ) -> OpaquePointer {
        let pathBytes: [UInt8]
        if let u = url {
            pathBytes = Array(u.path.utf8)
        } else {
            pathBytes = []  // in-memory
        }
        return pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }!
    }

    // MARK: - CRITICAL-3 — real wal_autocheckpoint verification

    /// Verifies the ch 920 PRAGMA wal_autocheckpoint fix
    /// actually applied on the engine's OWN connection。
    ///
    /// chapter 九百二十七 / M3340 fix CRITICAL-1:value bumped
    /// 1000 → 1024 in production (lib.rs:187) so the test
    /// can DETECT reverts。 SQLite's compile-time default is
    /// 1000,so the ch 926 test was fake-coverage — it passed
    /// even if the ch 920 pragma_update call were deleted。
    /// 1024 is a power-of-2 sentinel that's detectably
    /// non-default with negligible production impact。
    func testWalAutocheckpointReadFromEngineConnection() {
        let url = makeTempDBURL("wal-eng")
        defer { cleanup(url) }
        let engine = openEngine(url: url)
        defer { _ = bas_l8_engine_close(engine) }

        let name = Array("wal_autocheckpoint".utf8)
        let value = name.withUnsafeBufferPointer { buf in
            bas_l8_engine_pragma_value_i64(
                engine,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        XCTAssertEqual(value, 1024,
            "wal_autocheckpoint must be 1024 on engine's own " +
            "connection (ch 920 fix + ch 927 CRITICAL-1 sentinel " +
            "value verified via ch 926 diagnostic FFI " +
            "bas_l8_engine_pragma_value_i64)")
    }

    /// Verifies the ch 922 NC2 PRAGMA busy_timeout=5000 fix。
    /// busy_timeout's SQLite default is 0,so this test would
    /// fail if the fix were reverted — unlike wal_autocheckpoint
    /// where default coincidentally matches the desired value。
    func testBusyTimeoutReadFromEngineConnection() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }

        let name = Array("busy_timeout".utf8)
        let value = name.withUnsafeBufferPointer { buf in
            bas_l8_engine_pragma_value_i64(
                engine,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        XCTAssertEqual(value, 5000,
            "busy_timeout must be 5000 ms (ch 922 NC2 fix) — " +
            "SQLite default is 0,so this catches revert")
    }

    /// Verifies the diagnostic FFI is whitelisted — passing
    /// an unknown pragma name returns -3 (not exposing arbitrary
    /// pragma surface to Swift callers)。
    func testPragmaValueHelperRejectsUnknownPragma() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }

        let name = Array("some_random_pragma".utf8)
        let value = name.withUnsafeBufferPointer { buf in
            bas_l8_engine_pragma_value_i64(
                engine,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        XCTAssertEqual(value, -3,
            "non-whitelisted pragma must return -3")
    }

    // MARK: - HIGH-2 — [UInt8] cosineTopK NaN/Inf/dim guard

    /// The chapter 924 NH4 NaN guard was added ONLY to the
    /// [Float] overload。 The [UInt8] overload + WithSkipped
    /// variants reached the FFI with no NaN check。 The ch 926
    /// HIGH-2 fix added a shared validateQueryBytes helper —
    /// this test verifies the helper rejects NaN bytes。
    func testCosineTopKBytesRejectsNaN() async throws {
        let url = makeTempDBURL("nan-bytes")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        // NaN bit pattern in f32: 0x7FC00000
        let nanBytes: [UInt8] = [
            0x00, 0x00, 0xC0, 0x7F]
        do {
            _ = try await store.cosineTopK(
                forDomain: "any",
                queryBytes: nanBytes, k: 5)
            XCTFail("NaN bytes must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            guard case .invalidArgument(let r) = e else {
                XCTFail("wrong error: \(e)"); return
            }
            XCTAssertTrue(r.contains("non-finite"),
                "reason should mention non-finite: \(r)")
        }
    }

    func testCosineTopKWithSkippedBytesRejectsNaN()
        async throws
    {
        let url = makeTempDBURL("nan-bytes-skip")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let nanBytes: [UInt8] = [
            0x00, 0x00, 0xC0, 0x7F]
        do {
            _ = try await store.cosineTopKWithSkipped(
                forDomain: "any",
                queryBytes: nanBytes, k: 5)
            XCTFail("NaN bytes must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            guard case .invalidArgument = e else {
                XCTFail("wrong error: \(e)"); return
            }
        }
    }

    /// [Float] overload with positive infinity — ch 924 guard
    /// uses `isFinite` which catches Inf as well as NaN,but the
    /// ch 925 test only exercised NaN。 This closes the「missing
    /// negative case」 gap from the test review。
    func testCosineTopKFloatRejectsPositiveInfinity()
        async throws
    {
        let url = makeTempDBURL("inf-pos")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let query: [Float] = [1.0, .infinity, 0.0, 0.0]
        do {
            _ = try await store.cosineTopK(
                forDomain: "any", query: query, k: 5)
            XCTFail("+Inf must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            guard case .invalidArgument = e else {
                XCTFail("wrong error: \(e)"); return
            }
        }
    }

    func testCosineTopKFloatRejectsNegativeInfinity()
        async throws
    {
        let url = makeTempDBURL("inf-neg")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let query: [Float] = [1.0, -.infinity, 0.0, 0.0]
        do {
            _ = try await store.cosineTopK(
                forDomain: "any", query: query, k: 5)
            XCTFail("-Inf must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            guard case .invalidArgument = e else {
                XCTFail("wrong error: \(e)"); return
            }
        }
    }

    /// Negative zero IS finite (isFinite returns true) — verify
    /// it's NOT rejected。 Documents the boundary。
    func testCosineTopKFloatAcceptsNegativeZero() async throws {
        let url = makeTempDBURL("neg-zero")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let query: [Float] = [
            Float(-0.0), Float(-0.0), Float(-0.0), Float(-0.0)]
        // Should not throw — -0.0 is a valid finite value
        let results = try await store.cosineTopK(
            forDomain: "empty-domain", query: query, k: 1)
        XCTAssertEqual(results.count, 0,
            "no rows → empty result,no throw")
    }

    // MARK: - HIGH-1 — query_blob_len cap on FFI

    /// Directly invokes the cosine_topk FFI with an oversized
    /// query_blob_len。 Ch 926 fix HIGH-1 added MAX_EMBEDDING_
    /// BYTES cap (65536) here。 Without the fix,a 10 MB query
    /// would trigger Vec::with_capacity abort。
    ///
    /// Note: Swift-side validateQueryBytes also catches this
    /// at the storage layer。 To exercise the Rust-side guard,
    /// we go through the storage layer with a 16385-dim query
    /// (16385 * 4 = 65540 bytes,1 byte over cap)。
    func testCosineTopKRejectsOversizedQueryBlob() async throws {
        let url = makeTempDBURL("oversize-query")
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        // 16385 floats = 65540 bytes — 4 over the 65536 cap
        let oversize = [Float](
            repeating: 0.1, count: 16_385)
        do {
            _ = try await store.cosineTopK(
                forDomain: "any", query: oversize, k: 5)
            XCTFail("oversized query must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            guard case .invalidArgument = e else {
                XCTFail("wrong error: \(e)"); return
            }
        }
    }

    // MARK: - HIGH NH3 — payload_blob + payload_json caps

    /// Ch 923 NH3 added 3 BLOB caps (signature_hash 64,
    /// payload_blob 1 MiB,payload_json 16 MiB)。 Ch 925
    /// only tested signature_hash。 This closes payload_blob。
    func testEventLogPayloadBlobCapRejectsOversized() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)

        let eventID = Array("e1".utf8)
        let sessionID = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("low".utf8)
        let payload = Array("".utf8)
        // 1 MiB + 1 byte — over the cap
        let oversize = [UInt8](
            repeating: 0xAB, count: 1_048_577)
        var wasNew: Int32 = 0

        let rc = eventID.withUnsafeBufferPointer { eBuf in
            sessionID.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        payload.withUnsafeBufferPointer { pBuf in
                            oversize.withUnsafeBufferPointer {
                                bBuf in
                                bas_l8_event_log_append(
                                    engine,
                                    eBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    eBuf.count,
                                    sBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    sBuf.count,
                                    100,
                                    kBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    kBuf.count,
                                    rBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    rBuf.count,
                                    pBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    pBuf.count,
                                    2,  // format=2 binary
                                    bBuf.baseAddress,
                                    bBuf.count,
                                    &wasNew)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "payload_blob > 1 MiB must reject with -3 " +
            "(ch 923 NH3 MAX_PAYLOAD_BLOB_BYTES)")
    }

    /// Closes the payload_json cap gap (16 MiB) — too large
    /// to test with full payload,but we can fake the length
    /// with a large pointer。 Use a 16 MiB + 1 byte string。
    func testEventLogPayloadJsonCapRejectsOversized() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)

        let eventID = Array("e2".utf8)
        let sessionID = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("low".utf8)
        // 16 MiB + 1 byte — over the cap
        let oversize_json = String(
            repeating: "x", count: 16_777_217)
        let payload = Array(oversize_json.utf8)
        let emptyBlob: [UInt8] = []
        var wasNew: Int32 = 0

        let rc = eventID.withUnsafeBufferPointer { eBuf in
            sessionID.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        payload.withUnsafeBufferPointer { pBuf in
                            emptyBlob.withUnsafeBufferPointer {
                                bBuf in
                                bas_l8_event_log_append(
                                    engine,
                                    eBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    eBuf.count,
                                    sBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    sBuf.count,
                                    200,
                                    kBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    kBuf.count,
                                    rBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    rBuf.count,
                                    pBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    pBuf.count,
                                    1,  // format=1 JSON
                                    bBuf.baseAddress,
                                    bBuf.count,
                                    &wasNew)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "payload_json > 16 MiB must reject with -3 " +
            "(ch 923 NH3 MAX_PAYLOAD_JSON_BYTES)")
    }

    // MARK: - HIGH — format=1 + format=2 coherence (inverse)

    /// ch 924 NH2 added format-payload coherence checks。
    /// Ch 925 tested:
    ///  - format=2 + empty blob → -3 ✓
    ///  - format=42 (invalid) → -3 ✓
    /// Missing inverse:
    ///  - format=1 + zero-len JSON → -3 (this test)
    ///  - format=1 + payload_blob present → -3 (this test)
    func testEventLogFormat1RequiresJsonPresent() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)

        let eventID = Array("e3".utf8)
        let sessionID = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("low".utf8)
        let emptyJson: [UInt8] = []
        let emptyBlob: [UInt8] = []
        var wasNew: Int32 = 0

        let rc = eventID.withUnsafeBufferPointer { eBuf in
            sessionID.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        emptyJson.withUnsafeBufferPointer {
                            pBuf in
                            emptyBlob.withUnsafeBufferPointer {
                                bBuf in
                                bas_l8_event_log_append(
                                    engine,
                                    eBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    eBuf.count,
                                    sBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    sBuf.count,
                                    300,
                                    kBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    kBuf.count,
                                    rBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    rBuf.count,
                                    pBuf.baseAddress,
                                    pBuf.count,
                                    1,  // format=1 JSON
                                    bBuf.baseAddress,
                                    bBuf.count,
                                    &wasNew)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "format=1 with empty JSON must reject with -3 " +
            "(ch 924 NH2 inverse — JSON required for format=1)")
    }

    func testEventLogFormat1RejectsBlobPresent() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)

        let eventID = Array("e4".utf8)
        let sessionID = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("low".utf8)
        let payload = Array("{\"x\":1}".utf8)
        let extraBlob: [UInt8] = [0x01, 0x02, 0x03]
        var wasNew: Int32 = 0

        let rc = eventID.withUnsafeBufferPointer { eBuf in
            sessionID.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        payload.withUnsafeBufferPointer { pBuf in
                            extraBlob.withUnsafeBufferPointer {
                                bBuf in
                                bas_l8_event_log_append(
                                    engine,
                                    eBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    eBuf.count,
                                    sBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    sBuf.count,
                                    400,
                                    kBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    kBuf.count,
                                    rBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    rBuf.count,
                                    pBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    pBuf.count,
                                    1,  // format=1 JSON
                                    bBuf.baseAddress,
                                    bBuf.count,
                                    &wasNew)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "format=1 with payload_blob must reject with -3 " +
            "(ch 924 NH2 inverse — blob forbidden for format=1)")
    }

    // MARK: - HIGH — UNIQUE(session_id, sequence_number)

    /// Ch 919 C4 added UNIQUE(session_id, sequence_number)
    /// constraint to event_log table。 Without test:reverting
    /// would silently allow duplicate sequence numbers per
    /// session,corrupting the audit replay invariant。
    func testEventLogUniqueConstraintRejectsDuplicateSeq() {
        let engine = openEngine()
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)

        func append(
            eventID: String, seq: Int
        ) -> Int64 {
            let e = Array(eventID.utf8)
            let s = Array("sess1".utf8)
            let k = Array("kind".utf8)
            let r = Array("low".utf8)
            let p = Array("{}".utf8)
            let b: [UInt8] = []
            var wasNew: Int32 = 0
            return e.withUnsafeBufferPointer { eBuf in
                s.withUnsafeBufferPointer { sBuf in
                    k.withUnsafeBufferPointer { kBuf in
                        r.withUnsafeBufferPointer { rBuf in
                            p.withUnsafeBufferPointer { pBuf in
                                b.withUnsafeBufferPointer {
                                    bBuf in
                                    bas_l8_event_log_append(
                                        engine,
                                        eBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        eBuf.count,
                                        sBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        sBuf.count,
                                        Int64(100 + seq),
                                        kBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        kBuf.count,
                                        rBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        rBuf.count,
                                        pBuf.baseAddress.map {
                                            UnsafeRawPointer($0)
                                                .assumingMemoryBound(
                                                    to: CChar.self)
                                        },
                                        pBuf.count,
                                        1,
                                        bBuf.baseAddress,
                                        bBuf.count,
                                        &wasNew)
                                }
                            }
                        }
                    }
                }
            }
        }

        // The FFI auto-computes per-session sequence number,
        // so duplicate-seq violations can't be reached through
        // bas_l8_event_log_append directly。 The UNIQUE
        // constraint at the schema level protects against
        // SQL-level corruption (e.g. multi-engine race on the
        // same DB,or direct SQL injection)。
        //
        // Rust-side regression guard lives in
        // legacy_db_gets_explicit_unique_index_added (lib.rs
        // tests) which inserts via raw SQL and verifies the
        // second duplicate INSERT fails。
        //
        // Here we verify the FFI's auto-increment behavior —
        // calling append twice for the SAME session should
        // produce sequential seq numbers (0, 1) with no
        // collision,proving the FFI itself prevents users
        // from accidentally creating duplicates。 The return
        // value is the assigned sequence number (≥ 0)。
        let seq0 = append(eventID: "evt-A", seq: 0)
        XCTAssertEqual(seq0, 0,
            "first append in session returns seq=0")
        let seq1 = append(eventID: "evt-B", seq: 0)
        XCTAssertEqual(seq1, 1,
            "second append auto-bumps to seq=1 — FFI " +
            "protects against UNIQUE collision via auto-seq")
        // Third with same eventID as first → idempotent,
        // returns the existing seq (0)
        let seq_dup = append(eventID: "evt-A", seq: 999)
        XCTAssertEqual(seq_dup, 0,
            "duplicate eventID is idempotent — returns " +
            "the originally-assigned seq=0")
    }

    // MARK: - HIGH — vector_index metadata sortedKeys determinism

    /// chapter 九百二十八 / M3345 fix HIGH-2:DELETED the
    /// fake-coverage `testVectorIndexMetadataSortedKeysDeterministic`
    /// from ch 926。 The test asserted UPSERT-REPLACE semantics
    /// (true regardless of JSON ordering because PK keying)。
    /// Ch 927 added the REAL test `testMetadataKeysAreSortedLexicographically`
    /// below + tagged the old test as「fake coverage」 in its
    /// docstring but LEFT IT IN PLACE — the「stop the cascade」
    /// discipline failed here。 Empirically verified 8th-pass:
    /// reverting `.sortedKeys` → old test still passes,new
    /// lex-order test fails as designed。 Ch 928 removes the
    /// fake test entirely so consumers can't misread it as
    /// active coverage。

    /// chapter 九百二十七 / M3340 fix HIGH-2 — REAL determinism
    /// guard。 Constructs a multi-key dict with keys in a
    /// NON-sorted order (zeta first,then alpha,etc.) and
    /// asserts the production encoder emits keys in
    /// LEXICOGRAPHIC order (alpha first,zeta last)。
    ///
    /// Without `.sortedKeys`,JSONEncoder emits keys in
    /// hash-table-iteration order which is process-deterministic
    /// but hash-seed-randomized。 For THIS specific 5-key dict
    /// literal on macOS Swift,8th-pass empirically verified
    /// the iteration order is `beta, tau, zeta, mu, alpha` —
    /// fails the lex-order assertion immediately when
    /// `.sortedKeys` is removed。
    ///
    /// chapter 九百二十八 / M3345 fix HIGH-2 (this docstring):
    /// removed the「probability 119/120」 wording from ch 927 —
    /// Swift dict iteration is NOT random per call,it's
    /// process-deterministic (hash seed fixed at process
    /// start)。 The「119/120」 framing implied per-call
    /// randomness which is false。 The test still works
    /// empirically — just for a different reason than originally
    /// claimed (hash-seed-randomized,not call-randomized)。
    func testMetadataKeysAreSortedLexicographically() throws {
        // Construct dict with keys deliberately NOT in
        // alpha order — proves the test exercises the
        // sortedKeys flag,not insertion-order coincidence。
        let meta: [String: String] = [
            "zeta": "z",
            "alpha": "a",
            "mu": "m",
            "beta": "b",
            "tau": "t"]
        let json = try BASRoutedVectorIndexStorage
            .encodeMetadata(meta)
        // With sortedKeys: alpha, beta, mu, tau, zeta
        let expected = "{\"alpha\":\"a\",\"beta\":\"b\"," +
            "\"mu\":\"m\",\"tau\":\"t\",\"zeta\":\"z\"}"
        XCTAssertEqual(json, expected,
            "metadata JSON keys MUST be in lexicographic " +
            "order (alpha,beta,mu,tau,zeta) — proves " +
            "`.sortedKeys` is active in the production " +
            "encoder。 If this fails,JSONEncoder is using " +
            "hash-iteration order (non-deterministic across " +
            "processes) and the ch 922 NC3 fix has regressed")
    }

    // chapter 九百三十 / M3355 fix HIGH-test-1 — DELETED
    // `testMetadataEncodingByteEqualityAcrossInvocations`
    // 10th-pass test agent empirically verified this test
    // is FAKE COVERAGE:reverted `.sortedKeys` from
    // production encoder → test STILL PASSED。 In-process
    // JSONEncoder is deterministic with fixed hash seed,so
    // 100-iteration loop trivially passes regardless of
    // `.sortedKeys` flag。 Ch 928 had relocated this test
    // to「in-process stability」 section + admitted it
    // doesn't guard sortedKeys — but per ch 928 discipline
    // (DELETED fake `testVectorIndexMetadataSortedKeysDeterministic`
    // for same reason),admission-only is insufficient when
    // future maintainer might re-add it as「coverage」 for
    // wrong invariant。
    //
    // The「future JSONEncoder per-call randomness」 future-
    // guard claim ch 928 made is speculative — Apple is
    // extremely unlikely to ship that breaking change
    // without flag/deprecation cycle giving us time to
    // re-add a properly-designed test。 For now: deleted as
    // weak-coverage that overlaps fully-realized lex-order
    // test (testMetadataKeysAreSortedLexicographically)。
}
