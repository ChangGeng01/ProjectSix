import XCTest
import MLX
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXLLM
#endif

/// 缝8 gates.
/// 8c (pure + env): under thermal throttle the B2 probe may only DOWNSHIFT — difficulty and
///    thermal never saw each other; a hard question under throttle got MORE budget exactly when
///    the device needed less. Run once plain and once under BAS_THERMAL_FORCE=1.
/// 8a/8b (model-gated BAS_SEAM8_TEST=1): eviction must not lose the victim's conversation on
///    either reclaim path (pending-spill live reclaim / disk restore), and the 2-slot decode
///    governor must cover the default-on capped-fused lane (peak concurrency ≤ 2).
final class BASSeam8Tests: XCTestCase {

    /// Synthetic probe: w=0 ⇒ p = sigmoid(b). b=-2 → p≈0.12 < hardBelow(0.35) ⇒ UPSHIFT intent.
    private func hardQuestionProbe() throws -> BASDifficultyProbe {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("seam8_probe_\(UUID().uuidString).json")
        let dim = 4
        let payload: [String: Any] = [
            "w": [Double](repeating: 0, count: dim), "b": -2.0,
            "mu": [Double](repeating: 0, count: dim), "sd": [Double](repeating: 1, count: dim),
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try BASDifficultyProbe(weightsURL: url)
    }

    func testProbeUpshiftsWhenCool() throws {
        guard ProcessInfo.processInfo.environment["BAS_THERMAL_FORCE"] != "1" else {
            throw XCTSkip("cool-path variant — run without BAS_THERMAL_FORCE")
        }
        let hook = try XCTUnwrap(
            MLXOrganAdapter._probeBudgetHook(hardQuestionProbe(), planned: 160))
        XCTAssertEqual(hook(MLXArray([Float](repeating: 0, count: 4))), 384,
                       "hard question while cool must upshift one tier")
    }

    func testProbeIsDownshiftOnlyUnderThermalForce() throws {
        guard ProcessInfo.processInfo.environment["BAS_THERMAL_FORCE"] == "1" else {
            throw XCTSkip("run under BAS_THERMAL_FORCE=1")
        }
        let hook = try XCTUnwrap(
            MLXOrganAdapter._probeBudgetHook(hardQuestionProbe(), planned: 160))
        XCTAssertEqual(hook(MLXArray([Float](repeating: 0, count: 4))), 160,
                       "under throttle the upshift must be suppressed (B2×thermal composition)")
    }

    func testEvictionKeepsConversationOnBothReclaimPaths() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SEAM8_TEST"] == "1" else {
            throw XCTSkip("set BAS_SEAM8_TEST=1 BAS_MAX_LIVE_SESSIONS=1 BAS_SESSION_CAPPED_FUSED=0 (heavy)")
        }
        #if canImport(MLXLLM)
        guard MLXOrganAdapter.maxLiveSessions == 1 else {
            throw XCTSkip("needs BAS_MAX_LIVE_SESSIONS=1 to force eviction")
        }
        guard !MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("needs BAS_SESSION_CAPPED_FUSED=0 — pooled seats are the eviction subjects")
        }
        #if os(iOS)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        #else
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        #endif
        try await adapter.loadModel()
        // UNCAPPED turns: this test forces the POOLED lane (capped-fused off ⇒ no B3), where a
        // tiny cap dies inside the think block — EOS-terminated turns keep the gate about
        // EVICTION, not budget policy.
        func turn(_ sid: String, _ text: String) async throws -> String {
            try await adapter.draft(BASOrganRequest(
                requestID: "s8-\(sid)-\(abs(text.hashValue))", role: .core,
                preset: .greedyDeterministic, instruction: text,
                maxOutputTokens: nil, sessionID: sid)).body
        }
        // Path 1 — IMMEDIATE reclaim: evict A (via B) and ask A again with no settle time; the
        // write is typically still in flight → the pending-spill live box must come back.
        _ = try await turn("seatA", "The codeword is GRANITE-7. Reply with just: OK.")
        _ = try await turn("seatB", "Reply with just: OK.")                 // evicts A (cap 1)
        let r1 = try await turn("seatA", "What is the codeword? Answer with just the codeword.")
        XCTAssertTrue(r1.localizedCaseInsensitiveContains("GRANITE"),
                      "immediate post-eviction recall lost the conversation: \(r1.prefix(120))")
        // Path 2 — SETTLED reclaim: evict A again, give the detached write time to land, then
        // ask A — the disk-restore path must carry the same conversation.
        _ = try await turn("seatB", "Reply with just: OK.")                 // evicts A again
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let r2 = try await turn("seatA", "What is the codeword? Answer with just the codeword.")
        XCTAssertTrue(r2.localizedCaseInsensitiveContains("GRANITE"),
                      "settled post-eviction recall lost the conversation: \(r2.prefix(120))")
        let stats = await adapter.sessionSpillStats()
        print("[seam8] spill stats spilled=\(stats.spilled) restored=\(stats.restored)")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }

    func testGovernorCoversCappedFusedLane() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SEAM8_TEST"] == "1" else {
            throw XCTSkip("set BAS_SEAM8_TEST=1 (heavy)")
        }
        #if canImport(MLXLLM)
        guard MLXOrganAdapter.sessionCappedFusedEnabled else {
            throw XCTSkip("needs the capped-fused lane armed (default-on)")
        }
        #if os(iOS)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        #else
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        #endif
        try await adapter.loadModel()
        // 4 concurrent capped session turns — pre-fix the fused lane never touched the governor,
        // so peak concurrency would track the task count; post-fix it is clamped at 2.
        await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0 ..< 4 {
                group.addTask {
                    _ = try await adapter.draft(BASOrganRequest(
                        requestID: "gov-\(i)", role: .core, preset: .greedyDeterministic,
                        instruction: "Reply with just: OK.", maxOutputTokens: 32,
                        sessionID: "gov-seat-\(i)"))
                }
            }
            try? await group.waitForAll()
        }
        let peak = await adapter.peakSessionDecodes
        XCTAssertGreaterThanOrEqual(peak, 1, "governor telemetry never armed — lane not covered")
        XCTAssertLessThanOrEqual(peak, MLXOrganAdapter.maxConcurrentSessionDecodes,
                                 "capped-fused turns exceeded the jetsam-margin decode cap")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }

    /// H4 设备认证腿(大审计梯次3 尾修):错峰突发——8 座位、到达间隔 0.4s,让新到者持续
    /// 与 release→resume 交接窗口在生产 decode 时标上赛跑(旧代码 Mac 压测峰值 14)。
    /// 门槛:peak ≤ cap 且 8 轮全部完成非空。
    func testH4_StaggeredBurstRespectsCap() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SEAM8_TEST"] == "1" else {
            throw XCTSkip("set BAS_SEAM8_TEST=1 (heavy)")
        }
        #if canImport(MLXLLM)
        #if os(iOS)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        #else
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        #endif
        try await adapter.loadModel()
        let bodies = await withTaskGroup(of: String.self, returning: [String].self) { group in
            for i in 0 ..< 8 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i) * 400_000_000)
                    let r = try? await adapter.draft(BASOrganRequest(
                        requestID: "h4-burst-\(i)", role: .core, preset: .greedyDeterministic,
                        instruction: "Reply with just: OK.", maxOutputTokens: 24,
                        sessionID: "h4-seat-\(i)"))
                    return r?.body ?? ""
                }
            }
            var out: [String] = []
            for await b in group { out.append(b) }
            return out
        }
        let peak = await adapter.peakSessionDecodes
        print("[h4-cert] peak=\(peak) completed=\(bodies.filter { !$0.isEmpty }.count)/8")
        XCTAssertEqual(bodies.filter { !$0.isEmpty }.count, 8, "错峰突发 8 轮必须全部完成")
        XCTAssertLessThanOrEqual(peak, MLXOrganAdapter.maxConcurrentSessionDecodes,
                                 "H4:错峰突发击穿 \(MLXOrganAdapter.maxConcurrentSessionDecodes)-slot 闸(peak=\(peak))")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
