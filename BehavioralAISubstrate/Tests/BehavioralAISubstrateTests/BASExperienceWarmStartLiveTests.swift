import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// P0 Mac 实弹门(BAS_EXP_LIVE=1 + BAS_PROFILER_PERSIST=1):双 adapter 实例模拟跨进程——
/// 实例 A 跑真 eager 轮 → force flush;新实例 B 仅 ensure-load 即温启动(profiler 非冷 +
/// chainEmaL 恢复)。设备温启动税 A/B 是单独的验收(预注册),本门只验机制端到端。
final class BASExperienceWarmStartLiveTests: XCTestCase {
    func testCrossInstanceWarmStart() async throws {
        guard ProcessInfo.processInfo.environment["BAS_EXP_LIVE"] == "1" else {
            throw XCTSkip("set BAS_EXP_LIVE=1 BAS_PROFILER_PERSIST=1 (loads the 4B twice, Mac)")
        }
        guard MLXOrganAdapter._profilerPersistEnabled else {
            throw XCTSkip("also requires BAS_PROFILER_PERSIST=1")
        }
        #if canImport(MLXLLM)
        let a = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await a.loadModel()
        let req = BASOrganRequest(requestID: "exp-live", role: .core, preset: .core,
                                  instruction: "List three prime numbers.", context: [])
        _ = try await a.draft(req)
        _ = try await a.draft(req)
        await a._persistExperienceIfDue(force: true)
        try await Task.sleep(nanoseconds: 1_500_000_000)   // fire-and-forget write settles
        let url = a._experienceFileURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "快照必须落盘: \(url.path)")

        let b = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        await b._ensureExperienceLoaded()
        let cells = await b.draftProfiler.exportCells()
        let ema = await b.restoredChainEmaL
        print("[exp-live] restored cells=\(cells.count) chainEmaL=\(ema.map { String(format: "%.2f", $0) } ?? "nil")")
        XCTAssertFalse(cells.isEmpty, "新实例必须温启动(profiler 非冷)")
        XCTAssertNotNil(ema, "chainEmaL 必须恢复(fused 轮已跑过)")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
