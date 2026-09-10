import XCTest
import Foundation
import SQLite3
@testable import BASRuntimeCore

/// audit runtimecore-b MED-3 — BASSQLiteEvalRunStorage's reads (run / latestRun / runs / report /
/// reportsForCandidate / counts) used `(try? fetch) ?? nil/[]/0`, so a BUSY or corrupt DB read
/// returned empty indistinguishably from "no runs recorded" (silent fail-open). Only the KG store's
/// half of the finding landed earlier (9ddad0695); this store was untouched. The reads now route a
/// swallowed error to onSilentFailure, and the *OrThrow siblings surface it. Ports the same
/// three-piece set (onSilentFailure hook + *OrThrow sibling + busy_timeout=5000).
#if os(iOS) || os(macOS)
final class BASEvalRunCorruptSurfacingTests: XCTestCase {

    private func url(_ n: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("evalrun-\(UUID().uuidString)-\(n)")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s)) }
    }
    private func run(_ id: String) -> BASEvalRun {
        BASEvalRun(runID: id, timestampMs: 1_700_000_000_000, metrics: [.accuracy: 0.9],
                   buildChapter: "M863", hostFingerprint: "fp", sampleCount: 100)
    }
    private final class Box: @unchecked Sendable {
        let lock = NSLock(); var fired = 0
        func bump() { lock.lock(); fired += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return fired }
    }

    func testHealthyReadNeitherThrowsNorFires() async throws {
        let u = url("healthy"); defer { cleanup(u) }
        let store = try BASSQLiteEvalRunStorage(databaseURL: u)
        _ = try await store.append(run("r1"))
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.runOrThrow(forID: "r1")
        let viaDefault = await store.run(forID: "r1")
        XCTAssertEqual(viaThrow?.runID, "r1")
        XCTAssertEqual(viaDefault?.runID, "r1")
        XCTAssertEqual(box.count, 0, "a healthy read must not fire the hook")
    }

    func testGenuineMissingRunStaysNilNotCorrupt() async throws {
        let u = url("empty"); defer { cleanup(u) }
        let store = try BASSQLiteEvalRunStorage(databaseURL: u)
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }
        let viaThrow = try await store.runOrThrow(forID: "nope")
        let viaDefault = await store.run(forID: "nope")
        XCTAssertNil(viaThrow)
        XCTAssertNil(viaDefault)
        XCTAssertEqual(box.count, 0, "a genuinely-absent run is NOT corruption")
    }

    /// The reversal-red teeth: DROP the table via a second connection so the store's next read
    /// prepare fails deterministically (SQLITE_SCHEMA → no-such-table). The non-throwing read must
    /// fire the hook (not silently return nil), and the *OrThrow sibling must throw.
    /// Reverting the fix to `(try? fetchRun) ?? nil` makes `box.count == 0` here ⇒ red.
    func testCorruptReadFiresHookAndOrThrowSurfaces() async throws {
        let u = url("corrupt"); defer { cleanup(u) }
        let store = try BASSQLiteEvalRunStorage(databaseURL: u)
        _ = try await store.append(run("r1"))
        let box = Box()
        await store.setOnSilentFailure { _ in box.bump() }

        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        _ = sqlite3_exec(raw, "DROP TABLE eval_run;", nil, nil, nil)
        sqlite3_close_v2(raw)

        let viaDefault = await store.run(forID: "r1")
        XCTAssertNil(viaDefault, "the fail-open path still returns nil…")
        XCTAssertGreaterThan(box.count, 0, "…but it must ALSO surface the error via onSilentFailure")

        do {
            _ = try await store.runOrThrow(forID: "r1")
            XCTFail("runOrThrow must surface the busy/corrupt read error, not return nil")
        } catch { /* expected */ }
    }
}
#endif
