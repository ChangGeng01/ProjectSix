import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// 缝2/缝3 pure gates (no model): spill filename isolation (SHA256 — the '#'→'_' sanitization
/// collided `a#scout` with `a_scout`), clear-reaches-disk (cleared sessions must NOT resurrect
/// from spill snapshots), clear-all wipes the disk tier.
final class BASSpillHygieneTests: XCTestCase {

    private func plant(_ key: String) -> URL {
        let url = MLXOrganAdapter._spillURL(forKey: key)
        try? Data("stale-kv".utf8).write(to: url)
        return url
    }

    func testSpillFilenamesAreCollisionFree() {
        let a = MLXOrganAdapter._spillURL(forKey: "a#scout")
        let b = MLXOrganAdapter._spillURL(forKey: "a_scout")
        XCTAssertNotEqual(a, b, "the sanitization collision is back")
        XCTAssertEqual(a, MLXOrganAdapter._spillURL(forKey: "a#scout"),
                       "spill filenames must be deterministic across calls")
        XCTAssertTrue(a.lastPathComponent.hasSuffix(".safetensors"))
    }

    func testClearSessionReachesDisk() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        let core = plant("victim#core")
        let scout = plant("victim#scout")
        let bystander = plant("survivor#core")
        defer { try? FileManager.default.removeItem(at: bystander) }
        await adapter.clearSession(sessionID: "victim")
        XCTAssertFalse(FileManager.default.fileExists(atPath: core.path),
                       "cleared core-seat snapshot survived — the session would resurrect")
        XCTAssertFalse(FileManager.default.fileExists(atPath: scout.path),
                       "cleared scout-seat snapshot survived")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bystander.path),
                      "clearSession must not touch other seats' snapshots")
    }

    func testClearAllSessionsWipesSpillDir() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        _ = plant("wipe-a#core")
        _ = plant("wipe-b#core")
        await adapter.clearAllSessions()
        let left = (try? FileManager.default.contentsOfDirectory(
            atPath: MLXOrganAdapter._spillDir().path)) ?? []
        XCTAssertTrue(left.isEmpty, "clear-all left spill snapshots on disk: \(left)")
    }
}
