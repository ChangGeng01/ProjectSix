// MARK: - BASChapter894L8EngineFoundationTests
// chapter 八百九十四 / M3160 — L8 Rust unification arc start
//
// First implementation chapter per Docs/L8_RUST_UNIFICATION_RFC.md
// (chapter 八百九十三 RFC)。 Ships the bas-l8-engine crate skeleton +
// rusqlite link + ABI version + open/close lifecycle。 NO actor
// migration in this chapter — just verifies the foundation is
// reachable from Swift via the XCFramework。
//
// Subsequent chapters (八百九十五+) migrate individual Swift SQLite
// actors to use this engine via per-store FFI surfaces。

import XCTest
import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter894L8EngineFoundationTests: XCTestCase {

    /// PIN: bas-l8-engine is bundled into the umbrella XCFramework
    /// (force_link bumped crate count 22 → 23)。
    func testBundleCrateCountBumpedFor894() {
        #if os(iOS) || os(macOS)
        // chapter 七百五十七 「>= count」 floor pattern: future
        // chapters can ADD crates,but must not DROP this 23
        // baseline。
        let count = bas_substrate_bundle_crate_count()
        XCTAssertGreaterThanOrEqual(count, 23,
            "Chapter 894 bumped bundle crate count to ≥ 23 " +
            "(added bas-l8-engine for L8 Rust unification)")
        #endif
    }

    /// PIN: bas_l8_engine_abi_version returns 1 (chapter 894
    /// initial ABI)。 Subsequent ABI changes must bump this。
    func testL8EngineAbiVersionPinned() {
        #if os(iOS) || os(macOS)
        let v = bas_l8_engine_abi_version()
        XCTAssertEqual(v, 1,
            "Chapter 894 ships L8 engine ABI v1 — if " +
            "this changes,bump version + update Swift " +
            "cross-check pin")
        #endif
    }

    /// PIN: in-memory engine init + close succeeds via the
    /// XCFramework-shipped FFI。 Smoke test that the rusqlite
    /// link works through the umbrella into the .a。
    func testInMemoryEngineInitAndCloseSucceeds() {
        #if os(iOS) || os(macOS)
        // null path + 0 len → in-memory engine
        let engine = bas_l8_engine_init(nil, 0)
        XCTAssertNotNil(engine,
            "In-memory L8 engine init must succeed")
        let rc = bas_l8_engine_close(engine)
        XCTAssertEqual(rc, 0,
            "L8 engine close must return 0 on success")
        #endif
    }

    /// PIN: on-disk engine init at a temp path succeeds + the
    /// SQLite file is created。 Verifies bundled SQLite is wired
    /// + can open a file。
    func testOnDiskEngineInitCreatesFile() throws {
        #if os(iOS) || os(macOS)
        let tmpDir = FileManager.default.temporaryDirectory
        let dbPath = tmpDir.appendingPathComponent(
            "l8-engine-test-\(UUID().uuidString).db")
        defer {
            try? FileManager.default.removeItem(at: dbPath)
        }
        let pathStr = dbPath.path
        let pathBytes = Array(pathStr.utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        XCTAssertNotNil(engine,
            "On-disk L8 engine init must succeed at " +
            pathStr)
        // SQLite file should exist post-init (WAL mode also
        // creates -wal + -shm sidecar files,but the main .db
        // is what we check here)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: pathStr),
            "SQLite DB file must be created by engine init")
        let rc = bas_l8_engine_close(engine)
        XCTAssertEqual(rc, 0)
        #endif
    }

    /// PIN: db_path probe returns the path the engine was
    /// opened at。 Used by future audit trail wiring。
    func testDbPathRoundTripsThroughFFI() {
        #if os(iOS) || os(macOS)
        let engine = bas_l8_engine_init(nil, 0)
        XCTAssertNotNil(engine)
        defer { _ = bas_l8_engine_close(engine) }
        // Probe required size
        let needed = bas_l8_engine_db_path(engine, nil, 0)
        XCTAssertEqual(needed, Int32(":memory:".count),
            "In-memory engine db_path is ':memory:'")
        // Allocate + fetch
        var buf = [UInt8](
            repeating: 0, count: Int(needed))
        let written = buf.withUnsafeMutableBufferPointer { p in
            bas_l8_engine_db_path(
                engine, p.baseAddress, p.count)
        }
        XCTAssertEqual(written, needed)
        let str = String(bytes: buf, encoding: .utf8)
        XCTAssertEqual(str, ":memory:")
        #endif
    }

    /// PIN: close on null returns -1 (treat as already-closed,
    /// not an error)。
    func testCloseOnNullReturnsMinusOne() {
        #if os(iOS) || os(macOS)
        let rc = bas_l8_engine_close(nil)
        XCTAssertEqual(rc, -1,
            "Close on null pointer returns -1 (idempotent)")
        #endif
    }

    /// PIN: multiple engines are independent (test isolation
    /// per RFC open question 1)。
    func testMultipleEnginesAreIndependent() {
        #if os(iOS) || os(macOS)
        let e1 = bas_l8_engine_init(nil, 0)
        let e2 = bas_l8_engine_init(nil, 0)
        XCTAssertNotNil(e1)
        XCTAssertNotNil(e2)
        // Compare opaque pointer values directly。
        let p1 = UInt(bitPattern: e1)
        let p2 = UInt(bitPattern: e2)
        XCTAssertNotEqual(p1, p2,
            "Each init must return a distinct opaque handle")
        _ = bas_l8_engine_close(e1)
        _ = bas_l8_engine_close(e2)
        #endif
    }
}
