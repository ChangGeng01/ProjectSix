import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// audit F6 (2026-07-12) — a removed atom's plaintext must not survive in the -wal file.
///
/// secure_delete=ON zeroes the freed MAIN-DB page, but under WAL the atom's original INSERT
/// frame (plaintext content) lives in the -wal file until a checkpoint truncates it.
/// remove(forID:) now runs a verified wal_checkpoint(TRUNCATE); this proves the sensitive
/// substring no longer appears in the on-disk -wal after a remove.
final class BASMemoryAtomSecureDeleteWALTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atom-wal-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    private func makeAtom(content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(), kind: .episodic, content: content, scope: .session,
            sensitivity: .high, tier: .warm, confidence: 0.7, sourceType: "test",
            governanceStatus: .governed, provenanceSummary: "test")
    }

    /// Bytes of the -wal sidecar (empty if truncated / absent).
    private func walBytes(_ u: URL) -> Data {
        (try? Data(contentsOf: URL(fileURLWithPath: u.path + "-wal"))) ?? Data()
    }

    func testRemovedAtomPlaintextIsGoneFromWAL() async throws {
        let u = tempURL(); defer { cleanup(u) }
        let secret = "SENSITIVE-PLAINTEXT-\(UUID().uuidString)"
        let secretData = Data(secret.utf8)

        let store = try BASSQLiteMemoryAtomStore(databaseURL: u)
        let atom = makeAtom(content: secret)
        try await store.admit(atom)

        // sanity: while present, the plaintext IS somewhere on disk (main or wal)
        let mainNow = (try? Data(contentsOf: u)) ?? Data()
        XCTAssertTrue(mainNow.range(of: secretData) != nil || walBytes(u).range(of: secretData) != nil,
            "precondition: the admitted plaintext is on disk before removal")

        _ = await store.remove(forID: atom.id.uuidString)

        // after remove: the WAL must be truncated → the plaintext frame is gone from -wal
        XCTAssertNil(walBytes(u).range(of: secretData),
            "removed atom plaintext must NOT survive in the -wal file (F6: verified TRUNCATE)")
    }

    // The helper's own contract: kill-switch is a no-op; a healthy DB truncates cleanly.
    func testCheckpointHelperIsNoOpWhenDisabled() {
        // (documentation-level) — with a nil db it must not throw
        XCTAssertNoThrow(try BASSQLiteSecureDelete.checkpointTruncateAfterSecureDelete(db: nil))
    }
}
