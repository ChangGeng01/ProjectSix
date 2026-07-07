import XCTest
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// P0 设备验收 v2(预注册修订,RSI 章程):经验持久化机制在设备上以【真学习值】往返。
/// v1 教训(诚实入册):会话轮 preset .core 是 temp>0 ⇒ 选举走 pooled 采样车道(capped-fused
/// 为 greedy-only)⇒ 无 profiler fold 无 MTP box ⇒ 空快照;且 30s 间隔热混杂。v2 改 EAGER
/// draft() 轮(mtpSpec 族 eager 车道:折 profiler + 养 chainEmaL),判据改为热免疫的行为门:
/// 温臂 warm-start 行 cells>0 且 chainEmaL 非空(= 真学习值跨进程往返);tok/s 只随 thermal
/// 共测【报告】不判决(跨 run 热基线不可判——本战役自己的方法教训)。学习税值留给后续
/// 同热窗测量;若温启动无可测收益 ⇒ 诚实负面照记(P0 的价值=记忆基座本身,先决条件)。
final class BASExperienceWarmTaxDeviceTests: XCTestCase {
    func testSessionWarmStartTax() async throws {
        guard ProcessInfo.processInfo.environment["BAS_EXP_TAX"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_EXP_TAX=1 TEST_RUNNER_BAS_PROFILER_PERSIST=1; run TWICE (cold then warm)")
        }
        guard MLXOrganAdapter._profilerPersistEnabled else {
            throw XCTSkip("also set TEST_RUNNER_BAS_PROFILER_PERSIST=1")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #if os(iOS)
        let entry = MLXModelCatalog.qwen3_5_4B_4bit_local   // Documents-staged (no on-device HF pull)
        #else
        let entry = MLXModelCatalog.qwen3_5_4B_4bit
        #endif
        let organ = MLXOrganAdapter(model: entry)
        try await organ.loadModel()
        await organ._ensureExperienceLoaded()
        // 臂判定自愈:v1 失败跑留下的空快照 = 重播种(COLD),载入 cells 非空才是 WARM。
        let isWarm = await !organ.draftProfiler.exportCells().isEmpty
        print("[exp-tax] arm=\(isWarm ? "WARM" : "COLD")")
        if isWarm {
            // ── 行为硬门(热免疫):真学习值必须跨进程往返 ──────────────────
            let cells = await organ.draftProfiler.exportCells()
            let ema = await organ.restoredChainEmaL
            XCTAssertFalse(cells.isEmpty, "温臂必须恢复非空 profiler(v1 空快照教训)")
            XCTAssertNotNil(ema, "温臂必须恢复 chainEmaL")
            for c in cells {
                print("[exp-tax] restored cell \(c.sourceID)|\(c.purpose) accepted=\(String(format: "%.2f", c.stat.emaAccepted)) hit=\(String(format: "%.2f", c.stat.emaHitRate)) n=\(c.stat.observations)")
            }
        }
        let prompts = [
            "Summarize why unit tests matter, in two sentences.",
            "Name three sorting algorithms and their complexity.",
            "Explain what a mutex protects against, briefly.",
            "Give two reasons to prefer immutable data.",
            "What is a race condition? Two sentences.",
            "Describe binary search in plain words.",
        ]
        for (i, q) in prompts.enumerated() {
            // EAGER 车道(无 sessionID):planner 路由 mtpSpec 族 ⇒ 折 profiler + 养 chainEmaL。
            let req = BASOrganRequest(requestID: "tax-\(i)", role: .core, preset: .core,
                                      instruction: q, context: [], maxOutputTokens: 192)
            let t0 = Date()
            let draft = try await organ.draft(req, purpose: .factual)   // greedy fused ⇒ chainEmaL 真演化
            let dt = Date().timeIntervalSince(t0)
            print(String(format: "[exp-tax] turn=%d wall_s=%.2f body_chars=%d thermal=%d",
                         i, dt, draft.body.count, ProcessInfo.processInfo.thermalState.rawValue))
        }
        await organ._persistExperienceIfDue(force: true)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: organ._experienceFileURL().path))
        let savedCells = await organ.draftProfiler.exportCells()
        print("[exp-tax] persisted cells=\(savedCells.count) chainEmaL=\((await organ.restoredChainEmaL).map { String(format: "%.2f", $0) } ?? "nil")")
        XCTAssertFalse(savedCells.isEmpty, "eager 轮后 profiler 必须非空(播种有效性)")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
