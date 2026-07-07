import XCTest
import MLX
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// R2-C 设备采集(RSI 章程第五部分,协议冻结于采集前)——B2 探针语料全量设备重采。
/// 题面 = v2 重生成(20260704/7 + 20260705/7)∪ R2 新题(20260707/30 + 20260708/30)
/// = 1,231 题;TEST_RUNNER_BAS_R2_HALF=0|1 偶/奇下标分两机;解码 = 生产形状
/// (k=3, tCap=生产常数, adaptiveK, B3 武装, cap 224);输出 Documents/b2_r2_features_<half>.jsonl。
final class BASB2R2CollectDeviceTests: XCTestCase {

    func testCollectR2Half() async throws {
        guard let halfStr = ProcessInfo.processInfo.environment["BAS_R2_HALF"],
              let half = Int(halfStr), half == 0 || half == 1 else {
            throw XCTSkip("set TEST_RUNNER_BAS_R2_HALF=0|1 (device, ~615 gens ≈ 1.5-2h)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: localDir.path),
              FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("model/MTP weights not staged in Documents")
        }
        // 冻结题面:v2 重生成 ∪ R2 新题,稳定顺序,偶/奇下标分机。
        let all = BASDifficultyProbeCollectTests.makeQuestions(seed: 20260704, perCell: 7)
            + BASDifficultyProbeCollectTests.makeBroadQuestions(seed: 20260705, perCell: 7)
            + BASDifficultyProbeCollectTests.makeQuestions(seed: 20260707, perCell: 30)
            + BASDifficultyProbeCollectTests.makeBroadQuestions(seed: 20260708, perCell: 30)
        let mine = all.enumerated().filter { $0.offset % 2 == half }.map(\.element)
        print("[r2-collect] half=\(half) questions=\(mine.count)/\(all.count)")

        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let outURL = docs.appendingPathComponent("b2_r2_features_\(half).jsonl")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        let fh = try XCTUnwrap(FileHandle(forWritingAtPath: outURL.path))
        defer { try? fh.close() }

        var done = 0, correct = 0
        for item in mine {
            let input = try await container.prepare(input: UserInput(chat: [.user(item.q)]))
            struct S: Sendable { let h: [Float]; let qlen: Int; let text: String }
            let s: S = try await container.perform(nonSendable: input) { ctx, input in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let ids = input.text.tokens.asArray(Int.self)
                let cache = qwen.newCache(parameters: nil)
                let h0 = qwen.hiddenStatesWithCache(
                    MLXArray(ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                let h = h0[0, h0.dim(1) - 1].asType(.float32).asArray(Float.self)
                let open = ctx.tokenizer.convertTokenToId("<think>") ?? 248068
                let close = ctx.tokenizer.convertTokenToId("</think>") ?? 248069
                let nl = ctx.tokenizer.encode(text: "\n").last ?? 198
                let nl2 = ctx.tokenizer.encode(text: "\n\n").last ?? 271
                let cfg = BASTraceExitConfig(
                    thinkOpenToken: open, thinkCloseToken: close,
                    closeSequence: [nl, close, nl2], boundaryTokens: [nl, nl2])
                // 生产形状:tCap = 生产常数(iOS 5——qmv 悬崖之下;Mac 版收集用 12 是 Mac 常数)
                let run = dec.generateSpecKFused(
                    prompt: ids, maxTokens: 224, eosTokens: eos, k: 3,
                    tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true, traceExit: cfg)
                return S(h: h, qlen: ids.count, text: ctx.tokenizer.decode(tokenIds: run.tokens))
            }
            let answerText = s.text.range(of: "</think>").map { String(s.text[$0.upperBound...]) } ?? s.text
            let ok = answerText.range(of: "\\b\(item.ans)\\b", options: .regularExpression) != nil
            if ok { correct += 1 }
            done += 1
            let rec: [String: Any] = [
                "family": item.family, "band": item.band, "qlen": s.qlen,
                "label": ok ? 1 : 0, "q": item.q, "ans": item.ans,
                "h": s.h.map { Double($0) },
            ]
            fh.write(try JSONSerialization.data(withJSONObject: rec))
            fh.write("\n".data(using: .utf8)!)
            if done % 25 == 0 {
                print("[r2-collect] \(done)/\(mine.count) acc=\(String(format: "%.2f", Double(correct) / Double(done))) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
                MLX.GPU.clearCache()
            }
        }
        print("[r2-collect] DONE half=\(half) n=\(done) acc=\(String(format: "%.3f", Double(correct) / Double(done))) → \(outURL.path)")
        XCTAssertEqual(done, mine.count)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
