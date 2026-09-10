import XCTest
import BASOrgan
import BASRuntimeCore
@testable import BASMLXAdapter

/// audit M-h dream-loop — the H7 clear-epoch guard on warm-seat snapshots. A
/// snapshot write that LANDS AFTER a clearSession/clearAllSessions must be
/// SUPPRESSED (its file removed), else the just-cleared conversation KV
/// resurrects on disk and reloads on the next turn (the 缝2 leak). The guard
/// already existed inline; extracting `_snapshotSeat(key:write:)` makes it
/// exercisable with a fake writer — no Qwen3.5-4B model load.
final class BASSnapshotClearRaceTests: XCTestCase {

    private func url(forKey key: String) -> URL {
        MLXOrganAdapter._spillURL(forKey: key)
    }

    /// clearSession during the write ⇒ epoch bumps ⇒ the post-write guard
    /// deletes the resurrecting file.
    func testSnapshotSuppressesWriteLandingAfterClearSession() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        let sid = "victim-\(UUID().uuidString)"
        let key = "\(sid)#\(BASOrganRole.core.rawValue)"
        let u = url(forKey: key)
        defer { try? FileManager.default.removeItem(at: u) }

        let counted = await adapter._snapshotSeat(key: key) {
            // The RACE: the clear lands first (bumps the clear epoch), THEN the
            // snapshot write completes — the exact "write lands after clear" window.
            await adapter.clearSession(sessionID: sid)
            try? Data("resurrect-kv".utf8).write(to: u)
            return u
        }

        XCTAssertFalse(counted,
            "a write that lands after clearSession must not count the seat")
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.path),
            "the post-clear write must be SUPPRESSED — else the cleared conversation "
            + "resurrects on disk on the next turn (缝2 dream-loop leak)")
    }

    /// clearAllSessions during the write ⇒ clearAllEpoch bumps ⇒ same suppression.
    func testSnapshotSuppressesWriteLandingAfterClearAll() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        let key = "victim-\(UUID().uuidString)#\(BASOrganRole.core.rawValue)"
        let u = url(forKey: key)
        defer { try? FileManager.default.removeItem(at: u) }

        let counted = await adapter._snapshotSeat(key: key) {
            await adapter.clearAllSessions()
            try? Data("resurrect-kv".utf8).write(to: u)
            return u
        }

        XCTAssertFalse(counted, "clearAllSessions during the write must not count the seat")
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.path),
            "clearAllSessions must also suppress the resurrecting write")
    }

    /// A write that FAILS (nil) never counts and leaves nothing behind.
    func testFailedWriteDoesNotCount() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        let key = "novictim-\(UUID().uuidString)#\(BASOrganRole.core.rawValue)"
        let counted = await adapter._snapshotSeat(key: key) { nil }
        XCTAssertFalse(counted, "a failed persist (nil url) never counts")
    }
}
