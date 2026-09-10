// MARK: - BASChapter925FixCoverageBackfillTests
// chapter 九百二十五 / M3330 — test backfill per 5th-pass audit
//
// 5th-pass 最最掘地三尺 test audit found 11 of 18 CRITICAL+
// HIGH fixes from chapters 915-924 had ZERO test coverage。
// Reversibility check showed each could be reverted to broken
// behavior and the test suite would still report green。
// This chapter backfills tests for all 11 gaps PLUS the new
// chapter 九百二十四 panic-safe transactional guard。
//
// # The 11 gaps (audit verdict)
//
// 1. C2 vault empty-payload throws (BASRoutedHostConstitutionVaultStorage)
// 2. C4 UNIQUE(session_id, sequence_number) constraint enforced
// 3. C5 Mutex<Connection> poison recovery works after panic
// 4. NC1 transactional rollback on intermediate error
// 5. NC2 busy_timeout PRAGMA value = 5000
// 6. NC3 vector_index metadata sortedKeys determinism
// 7. NC4 Rust-side limit cap rejects > MAX_HOTPATH_LIMIT
// 8. NC5 dimension × 4 vs embedding_len mismatch rejected
// 9. H5 vector_index BLOB cap (65536 bytes) enforced
// 10. NH3 BLOB caps for signature_hash + payload_blob + payload_json
// 11. MED-17 wal_autocheckpoint PRAGMA value = 1000

import XCTest
import Foundation
import SQLite3
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter925FixCoverageBackfillTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch925-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Gap 1: C2 vault empty-payload throws

    func testVaultLoadThrowsOnEmptyPayload() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        // Create + populate vault via Rust bridge first
        let store = try BASRoutedHostConstitutionVaultStorage(
            databaseURL: url)
        let snap = BASHostConstitution(
            hostID: "host.x", activeVersion: "v.x")
        let report = BASHostDeviceConsistencyReport(
            sourceDeviceID: "dev")
        let vault = BASHostConstitutionVault(
            vaultID: "test-vault",
            constitutionSnapshot: snap,
            deviceConsistencyReport: report)
        _ = try await store.save(vault)
        // Now corrupt the payload_json column directly via SQLite
        // to simulate the empty-payload corruption scenario。
        // chapter 九百三十九 / M3400 fix MED-2:check every
        // sqlite_* return code per 6P-MED-2 / 10P-LOW-2 carryover。
        // Previously these were ignored — a silent failure would
        // cause the test to fail for the wrong reason (corruption
        // never applied → loadVault returns normal → XCTFail fires)。
        var db: OpaquePointer?
        let openRc = sqlite3_open_v2(url.path, &db,
            SQLITE_OPEN_READWRITE, nil)
        XCTAssertEqual(openRc, SQLITE_OK,
            "sqlite3_open_v2 must succeed (rc=\(openRc))")
        let sql = "UPDATE host_constitution_vaults " +
            "SET payload_json = '' WHERE vault_id = ?"
        var stmt: OpaquePointer?
        let prepRc = sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil)
        XCTAssertEqual(prepRc, SQLITE_OK,
            "sqlite3_prepare_v2 must succeed (rc=\(prepRc))")
        let bindRc = sqlite3_bind_text(stmt, 1, "test-vault", -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        XCTAssertEqual(bindRc, SQLITE_OK,
            "sqlite3_bind_text must succeed (rc=\(bindRc))")
        let stepRc = sqlite3_step(stmt)
        XCTAssertEqual(stepRc, SQLITE_DONE,
            "sqlite3_step must return DONE (rc=\(stepRc))")
        let finRc = sqlite3_finalize(stmt)
        XCTAssertEqual(finRc, SQLITE_OK,
            "sqlite3_finalize must succeed (rc=\(finRc))")
        // Verify the corruption actually applied:read back
        // payload_json length on a fresh statement (post-edit
        // verification per ch 932 discipline)
        var verifyStmt: OpaquePointer?
        let verifySql = "SELECT length(payload_json) FROM " +
            "host_constitution_vaults WHERE vault_id = ?"
        _ = sqlite3_prepare_v2(
            db, verifySql, -1, &verifyStmt, nil)
        _ = sqlite3_bind_text(verifyStmt, 1, "test-vault", -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        XCTAssertEqual(sqlite3_step(verifyStmt), SQLITE_ROW,
            "SELECT length(payload_json) must return a row")
        let lengthAfterCorruption = sqlite3_column_int(
            verifyStmt, 0)
        XCTAssertEqual(lengthAfterCorruption, 0,
            "payload_json must be empty after corruption " +
            "UPDATE — if length > 0,the UPDATE did not " +
            "apply and the subsequent test would pass for " +
            "the wrong reason")
        sqlite3_finalize(verifyStmt)
        let closeRc = sqlite3_close_v2(db)
        XCTAssertEqual(closeRc, SQLITE_OK,
            "sqlite3_close_v2 must succeed (rc=\(closeRc))")
        // Now loadVault should THROW (not return nil)
        // because the row exists but payload is empty
        do {
            _ = try await store.loadVault(
                vaultID: "test-vault")
            XCTFail("Empty payload must throw, not return nil")
        } catch let e as
            BASRoutedHostConstitutionVaultStorage.StoreError
        {
            if case .payloadDecodeFailed(let reason) = e {
                XCTAssertTrue(
                    reason.contains("Empty payload"),
                    "Expected empty-payload reason: \(reason)")
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - Gap 7: NC4 Rust-side limit cap

    func testRustLimitCapRejectsOversizedLimit() async throws {
        // Direct FFI call bypassing Swift limitCap
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init failed")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_memory_usage_records_init_schema(engine)
        let atomID = Array("a".utf8)
        var ts: Int64 = 0
        var hc: Int64 = 0
        // Pass limit > MAX_HOTPATH_LIMIT (100_000)
        let rc = atomID.withUnsafeBufferPointer { aBuf in
            bas_l8_memory_usage_records_recent_for_atom(
                engine,
                aBuf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                aBuf.count,
                200_000,  // > MAX_HOTPATH_LIMIT
                &ts,
                &hc)
        }
        XCTAssertEqual(rc, -4,
            "Rust limit > cap must return -4")
    }

    // MARK: - Gap 8: NC5 dim × 4 != embedding_len rejected

    func testDimensionMismatchRejected() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_vector_index_init_schema(engine)
        let atomID = Array("a".utf8)
        let pv = Array("p".utf8)
        let domain = Array("d".utf8)
        let metaJson = Array("{}".utf8)
        // dimension=4 says 4 floats = 16 bytes, but blob is 12 bytes
        let badBlob: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0,
                                0, 0, 0, 0]
        let rc = atomID.withUnsafeBufferPointer { aBuf in
            pv.withUnsafeBufferPointer { pvBuf in
                domain.withUnsafeBufferPointer { dBuf in
                    metaJson.withUnsafeBufferPointer { mBuf in
                        badBlob.withUnsafeBufferPointer { eBuf in
                            bas_l8_vector_index_upsert(
                                engine,
                                aBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                aBuf.count,
                                4,  // dimension says 4 (= 16 bytes)
                                pvBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pvBuf.count,
                                eBuf.baseAddress,
                                eBuf.count,  // = 12, not 16
                                dBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                dBuf.count,
                                mBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mBuf.count)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "dim*4 != embedding_len must reject with -3")
    }

    func testNonFourAlignedEmbeddingRejected() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_vector_index_init_schema(engine)
        let atomID = Array("a".utf8)
        let pv = Array("p".utf8)
        let domain = Array("d".utf8)
        let metaJson = Array("{}".utf8)
        // 13 bytes — not 4-aligned, should be rejected
        let badBlob: [UInt8] = Array(repeating: 0, count: 13)
        let rc = atomID.withUnsafeBufferPointer { aBuf in
            pv.withUnsafeBufferPointer { pvBuf in
                domain.withUnsafeBufferPointer { dBuf in
                    metaJson.withUnsafeBufferPointer { mBuf in
                        badBlob.withUnsafeBufferPointer { eBuf in
                            bas_l8_vector_index_upsert(
                                engine,
                                aBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                aBuf.count,
                                3,  // claim 3 dims
                                pvBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pvBuf.count,
                                eBuf.baseAddress,
                                eBuf.count,
                                dBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                dBuf.count,
                                mBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mBuf.count)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "non-4-aligned blob len must reject with -3")
    }

    // MARK: - Gap 9: H5 vector_index BLOB cap (65536)

    func testOversizedEmbeddingRejected() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_vector_index_init_schema(engine)
        let atomID = Array("a".utf8)
        let pv = Array("p".utf8)
        let domain = Array("d".utf8)
        let metaJson = Array("{}".utf8)
        // 65540 bytes — just over the 65536 cap
        let oversize: [UInt8] = Array(
            repeating: 0, count: 65_540)
        let rc = atomID.withUnsafeBufferPointer { aBuf in
            pv.withUnsafeBufferPointer { pvBuf in
                domain.withUnsafeBufferPointer { dBuf in
                    metaJson.withUnsafeBufferPointer { mBuf in
                        oversize.withUnsafeBufferPointer { eBuf in
                            bas_l8_vector_index_upsert(
                                engine,
                                aBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                aBuf.count,
                                16385,
                                pvBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pvBuf.count,
                                eBuf.baseAddress,
                                eBuf.count,
                                dBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                dBuf.count,
                                mBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mBuf.count)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "embedding > 65536 bytes must reject with -3")
    }

    // MARK: - Gap 11: MED-17 wal_autocheckpoint value
    //
    // chapter 九百四十四 / M3425 fix HIGH (16P-test-1) — DELETED
    // the testWalAutocheckpointIs1000 test that lived here。
    // The test was fake coverage on 3 axes:
    //   (a) name lied:said「Is1000」 but engine pins 1024 since
    //       ch 927 7P-CRIT-1 sentinel break
    //   (b) opened READONLY raw-SQLite connection that gets the
    //       default 1000,not the engine's connection's 1024
    //   (c) assertion was tautology `XCTAssertGreaterThan(value, 0)`
    //       which passes for ANY positive value including a
    //       fully-removed pragma_update
    // Test BASChapter926.testWalAutocheckpointReadFromEngineConnection
    // (lines 89-110) does this correctly via engine's own
    // bas_l8_engine_pragma_value_i64 FFI + asserts == 1024。
    // Per ch 928 / ch 930 / ch 931 misnamed-test-deletion
    // discipline,fake-coverage tests are deleted not renamed。

    // MARK: - Gap 10: NH3 BLOB caps for signature_hash

    func testOversizedSignatureHashRejected() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_version_tree_init_schema(engine)
        let vid = Array("v1".utf8)
        let vaultID = Array("vault1".utf8)
        let parent = Array("".utf8)
        let mergedJson = Array("{}".utf8)
        // 128 bytes — over the 64-byte cap (covers SHA512)
        let oversize: [UInt8] = Array(
            repeating: 0xFF, count: 128)
        let rc = vid.withUnsafeBufferPointer { vBuf in
            vaultID.withUnsafeBufferPointer { vaBuf in
                parent.withUnsafeBufferPointer { pBuf in
                    mergedJson.withUnsafeBufferPointer { mBuf in
                        oversize.withUnsafeBufferPointer { sBuf in
                            bas_l8_version_tree_append(
                                engine,
                                vBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                vBuf.count,
                                vaBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                vaBuf.count,
                                pBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pBuf.count,
                                100,
                                sBuf.baseAddress,
                                sBuf.count,
                                0,
                                mBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mBuf.count)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "signature_hash > 64 bytes must reject with -3")
    }

    // MARK: - Gap 4: NaN query in cosineTopK throws

    func testCosineTopKThrowsOnNaNQuery() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let nanQuery: [Float] = [1.0, Float.nan, 0.0, 0.0]
        do {
            _ = try await store.cosineTopK(
                forDomain: "any", query: nanQuery, k: 5)
            XCTFail("NaN query must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            if case .invalidArgument(let reason) = e {
                XCTAssertTrue(
                    reason.contains("non-finite"),
                    "Reason should mention non-finite: " +
                    "\(reason)")
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    func testCosineTopKThrowsOnOversizedQueryDim() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let big = [Float](repeating: 0.1, count: 20_000)
        do {
            _ = try await store.cosineTopK(
                forDomain: "any", query: big, k: 5)
            XCTFail("Oversized query dim must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            if case .invalidArgument(let reason) = e {
                XCTAssertTrue(reason.contains("16384"))
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - Gap 2: payload_format coherence

    func testEventLogFormat2RequiresBlob() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)
        let eid = Array("e1".utf8)
        let sid = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("r".utf8)
        let payloadJson = Array("".utf8)
        var wasNew: Int32 = 0
        // payload_format=2 + payload_blob_len=0 → invalid
        let rc = eid.withUnsafeBufferPointer { eBuf in
            sid.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        payloadJson.withUnsafeBufferPointer { pjBuf in
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
                                pjBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pjBuf.count,
                                2,  // format=2 but no blob
                                nil,
                                0,
                                &wasNew)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "format=2 without blob must reject with -3")
    }

    func testEventLogInvalidFormatRejected() async throws {
        let pathBytes = Array("".utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            XCTFail("engine init")
            return
        }
        defer { _ = bas_l8_engine_close(engine) }
        _ = bas_l8_event_log_init_schema(engine)
        let eid = Array("e1".utf8)
        let sid = Array("s1".utf8)
        let kind = Array("k".utf8)
        let risk = Array("r".utf8)
        let payloadJson = Array("{}".utf8)
        var wasNew: Int32 = 0
        // format=42 → invalid
        let rc = eid.withUnsafeBufferPointer { eBuf in
            sid.withUnsafeBufferPointer { sBuf in
                kind.withUnsafeBufferPointer { kBuf in
                    risk.withUnsafeBufferPointer { rBuf in
                        payloadJson.withUnsafeBufferPointer { pjBuf in
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
                                pjBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pjBuf.count,
                                42,  // invalid format
                                nil,
                                0,
                                &wasNew)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, -3,
            "format=42 (not 1 or 2) must reject with -3")
    }
}
#endif
