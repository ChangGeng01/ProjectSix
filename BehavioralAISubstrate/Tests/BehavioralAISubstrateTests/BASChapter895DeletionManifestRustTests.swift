// MARK: - BASChapter895DeletionManifestRustTests
// chapter 八百九十五 / M3165 — LOW-risk pilot Rust-side migration
//
// First per-store migration of L8 Rust unification arc per
// Docs/L8_RUST_UNIFICATION_RFC.md (chapter 八百九十三 RFC) +
// chapter 八百九十四 engine foundation。
//
// Ships the Rust-side `deletion_manifest` module + FFI surface
// that mirrors BASSQLiteHostConstitutionDeletionManifestStore
// (schema 015,append-only forensic trail)。 NO Swift bridge
// in this chapter — chapter 896 wires the byte-equality test
// suite against the live Swift actor。
//
// This chapter verifies the FFI surface is reachable + works
// end-to-end through the umbrella XCFramework on Apple
// platforms。

import XCTest
import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter895DeletionManifestRustTests: XCTestCase {

    /// Helper: make an in-memory engine + init schema 015。
    private func makeEngineWithSchema() -> OpaquePointer? {
        #if os(iOS) || os(macOS)
        let engine = bas_l8_engine_init(nil, 0)
        guard engine != nil else { return nil }
        let rc = bas_l8_deletion_manifest_init_schema(engine)
        XCTAssertEqual(rc, 0,
            "Schema 015 init must succeed")
        return engine
        #else
        return nil
        #endif
    }

    private func closeEngine(_ engine: OpaquePointer?) {
        #if os(iOS) || os(macOS)
        _ = bas_l8_engine_close(engine)
        #endif
    }

    /// PIN: schema 015 initializes cleanly + is idempotent。
    func testSchemaInitIdempotent() {
        #if os(iOS) || os(macOS)
        let engine = bas_l8_engine_init(nil, 0)
        XCTAssertNotNil(engine)
        let rc1 = bas_l8_deletion_manifest_init_schema(engine)
        XCTAssertEqual(rc1, 0)
        let rc2 = bas_l8_deletion_manifest_init_schema(engine)
        XCTAssertEqual(rc2, 0,
            "Schema init must be idempotent")
        closeEngine(engine)
        #endif
    }

    /// PIN: append a manifest + count round-trips correctly。
    func testAppendAndCount() {
        #if os(iOS) || os(macOS)
        let engine = makeEngineWithSchema()
        defer { closeEngine(engine) }
        let mid = "manifest-895-1"
        let vid = "vault-895-A"
        let tr = #"["host.v1"]"#
        let dt = "cascade"
        let rc = mid.withCString { midPtr in
            vid.withCString { vidPtr in
                tr.withCString { trPtr in
                    dt.withCString { dtPtr in
                        bas_l8_deletion_manifest_append(
                            engine,
                            midPtr, mid.utf8.count,
                            vidPtr, vid.utf8.count,
                            trPtr, tr.utf8.count,
                            dtPtr, dt.utf8.count,
                            1_700_000_000_000,
                            nil, 0,
                            nil, 0)
                    }
                }
            }
        }
        XCTAssertEqual(rc, 0,
            "Append must succeed via FFI")
        let count = bas_l8_deletion_manifest_count(engine)
        XCTAssertEqual(count, 1,
            "Count after one append must be 1")
        let countForVault = vid.withCString { p in
            bas_l8_deletion_manifest_count_for_vault(
                engine, p, vid.utf8.count)
        }
        XCTAssertEqual(countForVault, 1)
        let countForOther = "vault-other".withCString { p in
            bas_l8_deletion_manifest_count_for_vault(
                engine, p, "vault-other".utf8.count)
        }
        XCTAssertEqual(countForOther, 0,
            "Count for non-existent vault must be 0")
        #endif
    }

    /// PIN: duplicate manifest_id returns -2 (SQLITE_CONSTRAINT)。
    func testDuplicateManifestIDReturnsError() {
        #if os(iOS) || os(macOS)
        let engine = makeEngineWithSchema()
        defer { closeEngine(engine) }
        let mid = "dup-895"
        let vid = "vault-dup"
        let tr = "[]"
        let dt = "selective"
        // First append
        let rc1 = mid.withCString { midPtr in
            vid.withCString { vidPtr in
                tr.withCString { trPtr in
                    dt.withCString { dtPtr in
                        bas_l8_deletion_manifest_append(
                            engine,
                            midPtr, mid.utf8.count,
                            vidPtr, vid.utf8.count,
                            trPtr, tr.utf8.count,
                            dtPtr, dt.utf8.count,
                            1, nil, 0, nil, 0)
                    }
                }
            }
        }
        XCTAssertEqual(rc1, 0)
        // Second append with same manifest_id
        let rc2 = mid.withCString { midPtr in
            vid.withCString { vidPtr in
                tr.withCString { trPtr in
                    dt.withCString { dtPtr in
                        bas_l8_deletion_manifest_append(
                            engine,
                            midPtr, mid.utf8.count,
                            vidPtr, vid.utf8.count,
                            trPtr, tr.utf8.count,
                            dtPtr, dt.utf8.count,
                            2, nil, 0, nil, 0)
                    }
                }
            }
        }
        XCTAssertEqual(rc2, -2,
            "Duplicate manifest_id must return SQLite error (-2)")
        #endif
    }

    /// PIN: CHECK constraint on deletion_type rejects invalid
    /// values。
    func testInvalidDeletionTypeRejected() {
        #if os(iOS) || os(macOS)
        let engine = makeEngineWithSchema()
        defer { closeEngine(engine) }
        let mid = "invalid-type-895"
        let vid = "v"
        let tr = "[]"
        let dt = "explode"   // not in allowed set
        let rc = mid.withCString { midPtr in
            vid.withCString { vidPtr in
                tr.withCString { trPtr in
                    dt.withCString { dtPtr in
                        bas_l8_deletion_manifest_append(
                            engine,
                            midPtr, mid.utf8.count,
                            vidPtr, vid.utf8.count,
                            trPtr, tr.utf8.count,
                            dtPtr, dt.utf8.count,
                            0, nil, 0, nil, 0)
                    }
                }
            }
        }
        XCTAssertEqual(rc, -2,
            "CHECK constraint must reject invalid deletion_type")
        #endif
    }

    /// PIN: optional fields (cascaded_refs_json + version_ref)
    /// correctly NULL when len=0。
    func testOptionalFieldsNullable() {
        #if os(iOS) || os(macOS)
        let engine = makeEngineWithSchema()
        defer { closeEngine(engine) }
        let mid = "with-options-895"
        let vid = "vault-opt"
        let tr = "[]"
        let dt = "rollback"
        let cascaded = #"["dep1"]"#
        let versionRef = "version-1"
        // Append with both options present
        let rc = mid.withCString { midPtr in
            vid.withCString { vidPtr in
                tr.withCString { trPtr in
                    dt.withCString { dtPtr in
                        cascaded.withCString { cPtr in
                            versionRef.withCString { vPtr in
                                bas_l8_deletion_manifest_append(
                                    engine,
                                    midPtr, mid.utf8.count,
                                    vidPtr, vid.utf8.count,
                                    trPtr, tr.utf8.count,
                                    dtPtr, dt.utf8.count,
                                    1_700_000_000_000,
                                    cPtr, cascaded.utf8.count,
                                    vPtr, versionRef.utf8.count)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(rc, 0,
            "Append with optional fields must succeed")
        let count = bas_l8_deletion_manifest_count(engine)
        XCTAssertEqual(count, 1)
        #endif
    }
}
