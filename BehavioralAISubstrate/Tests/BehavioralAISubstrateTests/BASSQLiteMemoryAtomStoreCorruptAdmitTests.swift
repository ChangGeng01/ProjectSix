import XCTest
import Foundation
import SQLite3
@testable import BASMemory

/// audit memory-a F7 — BASSQLiteMemoryAtomStore.admit() computed `existed` via `(try? fetchAtom) != nil`,
/// so a decode-corrupt EXISTING row read as "did not exist": admit reported wasNew=true for a row it
/// actually overwrote AND masked the corruption. admit already throws, so it now surfaces the error.
#if os(iOS) || os(macOS)
final class BASSQLiteMemoryAtomStoreCorruptAdmitTests: XCTestCase {

    private func url() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atoms-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    private func atom(_ id: UUID) -> BASGovernedMemory {
        BASGovernedMemory(id: id, kind: .semantic, content: "c", scope: .user,
                          sensitivity: .low, tier: .warm, confidence: 0.7,
                          sourceType: "t", governanceStatus: .governed, provenanceSummary: "p")
    }

    func testAdmitSurfacesCorruptExistingRowInsteadOfSwallowing() async throws {
        let u = url(); defer { cleanup(u) }
        let store = try BASSQLiteMemoryAtomStore(databaseURL: u)
        let id = UUID()
        _ = try await store.admit(atom(id))   // creates the table + row + user_version

        // Corrupt the existing row's payload_json via a second connection (a DATA-page update, so it
        // is visible to the store's connection on its next read — unlike schema-page corruption).
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        let sql = "UPDATE memory_atoms SET payload_json='{ not valid json' WHERE atom_id='\(id.uuidString)';"
        XCTAssertEqual(sqlite3_exec(raw, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close_v2(raw)

        // Re-admit the same id: admit's existence check decodes the now-corrupt payload_json and must
        // THROW — not `try?`-swallow it and wrongly report wasNew=true.
        do {
            _ = try await store.admit(atom(id))
            XCTFail("admit must surface a corrupt existing-row decode error, not swallow it")
        } catch {
            // expected: fetchAtom's decode error propagates
        }
    }
}
#endif
