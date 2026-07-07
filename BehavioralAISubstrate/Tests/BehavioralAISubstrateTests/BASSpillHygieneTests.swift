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

// ── 大审计梯次3 接线 gates(H5 单写者 / H7 clear-epoch,2026-07-07)──────────────

extension BASSpillHygieneTests {

    /// H7:clear 后的 epoch 必须领先——snapshot/fused writeback 用它判"写期间是否被 clear"。
    func testH7_ClearBumpsEpoch() async {
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        let e0 = await adapter._clearEpoch("victim#core")
        await adapter.clearSession(sessionID: "victim")
        let e1 = await adapter._clearEpoch("victim#core")
        XCTAssertGreaterThan(e1, e0, "clearSession 必须提升该 key 的 clear epoch")
        // clearAll 覆盖任意 key(不枚举)。
        let f0 = await adapter._clearEpoch("any#core")
        await adapter.clearAllSessions()
        let f1 = await adapter._clearEpoch("any#core")
        XCTAssertGreaterThan(f1, f0, "clearAllSessions 必须提升所有 key 的 epoch")
    }

    /// H6 门:opt-in env 默认关(字节等价直调),设了才启用——纯静态断言,无模型。
    func testH6_GateOptInDefaultOff() {
        // 未设 BAS_SESSION_GATE ⇒ 默认关(本测试进程未设)。
        if ProcessInfo.processInfo.environment["BAS_SESSION_GATE"] == "1" {
            XCTAssertTrue(MLXOrganAdapter._perKeySessionGateEnabled)
        } else {
            XCTAssertFalse(MLXOrganAdapter._perKeySessionGateEnabled,
                           "H6 门必须默认关——默认路径字节等价")
        }
    }
}
