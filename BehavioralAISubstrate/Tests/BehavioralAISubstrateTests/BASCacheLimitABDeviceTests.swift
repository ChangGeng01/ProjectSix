import XCTest
import BASOrgan
import MLX
@testable import BASHostKit
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif
#if canImport(Darwin)
import Darwin
#endif

/// cacheLimit {256,512,768,∞} A/B 战役 (Docs/CACHELIMIT_AB_2026-07-07.md,预注册先于测量)。
/// 512 default 是纯 E2B 搬运(ADR-038),Qwen3.5-4B 生产车道上零受控测量——本 harness 补上。
/// 设计:同机同会话交错、镜像块序消热漂(每臂跨块平均位置全等 4.5);每臂块
/// set→clearCache→resetPeak→1 热身+6 计入;fidelity anchor(cap 结构性 byte-equal ⇒
/// 任何输出分歧 = harness bug)为硬断言;∞ 臂预注册安全中止(cache>2GiB / iOS avail<600MB)。
/// 判决从日志读(预注册判据 1-7),Mac 干跑只验仪器不出速度证据。
final class BASCacheLimitABDeviceTests: XCTestCase {

    func testCacheLimitSweep() async throws {
        guard ProcessInfo.processInfo.environment["BAS_CACHELIMIT_AB"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_CACHELIMIT_AB=1 (device ~12min / Mac ~6min sweep)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #if os(iOS)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        guard FileManager.default.fileExists(atPath: localDir.path),
              FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("Qwen3.5-4B-4bit / MTP weights not staged in Documents")
        }
        let config = ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"])
        #else
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("MTP weights missing at /tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        }
        let config = ModelConfiguration(
            id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: ["<|im_end|>"])
        #endif

        let mib = 1024 * 1024
        // 在位值加载(生产同构),臂内再切换。
        MLX.GPU.set(cacheLimit: 512 * mib)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: config, progressHandler: { _ in })

        // 与 sustained 探针同题(可比性)。
        let prompts = [
            "Describe a quiet morning in a mountain village.",
            "Explain what a tide pool is to a curious child.",
            "Write a short paragraph about why libraries matter.",
        ]
        var inputs: [[Int]] = []
        for q in prompts {
            let inp = try await container.prepare(input: UserInput(chat: [.user(q)]))
            let ids: [Int] = try await container.perform(nonSendable: inp) { _, inp in
                inp.text.tokens.asArray(Int.self)
            }
            inputs.append(ids)
        }
        let inputsFixed = inputs

        struct Row: Sendable {
            let block: Int; let arm: String; let gen: Int; let prompt: Int
            let tokens: Int; let seconds: Double
            let accepted: Int; let iters: Int; let thermal: Int
            let activeMB: Int; let cacheMB: Int; let peakMB: Int
            let tokHash: Int; let measured: Bool
        }
        struct S: Sendable { let rows: [Row]; let aborted: [String] }

        let armsForward: [(tag: String, bytes: Int)] = [
            ("256", 256 * mib), ("512", 512 * mib), ("768", 768 * mib), ("inf", Int.max),
        ]
        let blocks: [[(tag: String, bytes: Int)]] = [armsForward, armsForward.reversed()]
        let gensPerArm = 7   // gen0 = 热身不计入,gen1-6 计入
        let abortCacheBytes = 2048 * mib
        let abortAvailBytes = 600 * mib

        let s: S = try await container.perform { ctx -> S in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
            let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
            var rows: [Row] = []
            var aborted: [String] = []
            for (bi, block) in blocks.enumerated() {
                for arm in block {
                    MLX.GPU.set(cacheLimit: arm.bytes)
                    MLX.GPU.clearCache()
                    MLX.GPU.resetPeakMemory()
                    var armAborted = false
                    for g in 0..<gensPerArm {
                        let p = g % inputsFixed.count
                        let g0 = Date()
                        // adaptiveK:false(确定性探针纪律):EMA 轨迹→K 序列→批形状→
                        // fp16 近平局 argmax 翻转(Gate-b 流伪影)会破 fidelity anchor;
                        // 固定 K 消掉该噪声源,cap 效应(回收 churn)与 K 策略一阶无关。
                        let run = dec.generateSpecKFused(
                            prompt: inputsFixed[p], maxTokens: 192, eosTokens: eos,
                            k: MLXOrganAdapter.mtpProductionK,
                            tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: false)
                        let dt = Date().timeIntervalSince(g0)
                        let snap = MLX.GPU.snapshot()
                        rows.append(Row(
                            block: bi, arm: arm.tag, gen: g, prompt: p,
                            tokens: run.tokens.count, seconds: run.decodeSeconds > 0 ? run.decodeSeconds : dt,
                            accepted: run.accepted, iters: run.iterations,
                            thermal: ProcessInfo.processInfo.thermalState.rawValue,
                            activeMB: snap.activeMemory / (1024 * 1024),
                            cacheMB: snap.cacheMemory / (1024 * 1024),
                            peakMB: snap.peakMemory / (1024 * 1024),
                            tokHash: run.tokens.hashValue, measured: g > 0))
                        // 预注册判据 2:∞ 臂(及任何臂)安全中止。
                        if snap.cacheMemory > abortCacheBytes {
                            print("[climit] ABORT arm=\(arm.tag) b=\(bi) UNBOUNDED-GROWTH cache=\(snap.cacheMemory / (1024 * 1024))MB")
                            armAborted = true
                        }
                        #if os(iOS)
                        if os_proc_available_memory() < abortAvailBytes {
                            print("[climit] ABORT arm=\(arm.tag) b=\(bi) LOW-AVAIL DNF")
                            armAborted = true
                        }
                        #endif
                        if armAborted { break }
                        usleep(1_000_000)
                    }
                    if armAborted { aborted.append("b\(bi)/\(arm.tag)") }
                    usleep(5_000_000)
                }
            }
            return S(rows: rows, aborted: aborted)
        }

        // ── 逐行 ──────────────────────────────────────────────────────────────
        for r in s.rows {
            let tps = Double(r.tokens) / max(r.seconds, 0.001)
            print(String(
                format: "[climit] b=%d arm=%@ g=%d p=%d tok=%d tok/s=%.1f acc/it=%.2f thermal=%d active=%dMB cache=%dMB peak=%dMB%@",
                r.block, r.arm, r.gen, r.prompt, r.tokens, tps,
                r.iters > 0 ? Double(r.accepted) / Double(r.iters) : 0,
                r.thermal, r.activeMB, r.cacheMB, r.peakMB, r.measured ? "" : " (warmup)"))
        }

        // ── 判据 1:fidelity anchor(硬断言)─────────────────────────────────
        var fidelityMismatches = 0
        for p in 0..<inputsFixed.count {
            let hashes = Set(s.rows.filter { $0.prompt == p }.map { $0.tokHash })
            if hashes.count > 1 {
                fidelityMismatches += 1
                print("[climit] FIDELITY-FAIL prompt=\(p) distinct=\(hashes.count)")
            }
        }
        print("[climit] FIDELITY \(fidelityMismatches == 0 ? "OK" : "FAIL") across \(s.rows.count) rows")

        // ── 判据 3/4:每臂 pooled + 每块 + 池平台 ────────────────────────────
        for arm in armsForward.map(\.tag) {
            let m = s.rows.filter { $0.arm == arm && $0.measured }
            guard !m.isEmpty else { continue }
            let pooled = Double(m.reduce(0) { $0 + $1.tokens }) / m.reduce(0) { $0 + $1.seconds }
            var perBlock: [String] = []
            for bi in 0...1 {
                let b = m.filter { $0.block == bi }
                if !b.isEmpty {
                    let t = Double(b.reduce(0) { $0 + $1.tokens }) / b.reduce(0) { $0 + $1.seconds }
                    perBlock.append(String(format: "b%d=%.1f(th%d-%d)", bi, t,
                                           b.map(\.thermal).min() ?? 0, b.map(\.thermal).max() ?? 0))
                }
            }
            let plateau = s.rows.filter { $0.arm == arm }.map(\.cacheMB).max() ?? 0
            let peak = s.rows.filter { $0.arm == arm }.map(\.peakMB).max() ?? 0
            print(String(format: "[climit] SUMMARY arm=%@ pooled=%.1f tok/s %@ cache_plateau=%dMB peak=%dMB",
                         arm, pooled, perBlock.joined(separator: " "), plateau, peak))
        }
        if !s.aborted.isEmpty { print("[climit] ABORTED arms: \(s.aborted.joined(separator: ","))") }

        XCTAssertFalse(s.rows.isEmpty)
        XCTAssertEqual(fidelityMismatches, 0,
                       "cap 结构性 byte-equal ⇒ 输出分歧 = harness bug,判决无效(预注册判据 1)")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
