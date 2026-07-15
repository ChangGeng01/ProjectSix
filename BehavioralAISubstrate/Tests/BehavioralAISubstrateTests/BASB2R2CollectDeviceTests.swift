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
        // R2-C 修订二:BAS_R2_EXTRA=1 ⇒ 扩展批(仅 math 生成器,种子 20260710——
        // broad 族按构造饱和已枯竭;796<1000 触发线的补齐批)。
        let extraRaw = ProcessInfo.processInfo.environment["BAS_R2_EXTRA"]
        let extra = extraRaw == "1" || extraRaw == "2" || extraRaw == "3" || extraRaw == "4"
        // EXTRA=1 种子 20260710;EXTRA=2 = 修订二再批(20260711);
        // EXTRA=3 = R3 全新 heldout(broad 20260713/40 + math 20260714/10,确认性检验)。
        // EXTRA=4 = R4 新题库真确认(alpha 主战场 20260717 + math 守卫 20260716)。
        let all = extraRaw == "4"
            ? BASDifficultyProbeCollectTests.makeR4Questions(seed: 20260717)
                + BASDifficultyProbeCollectTests.makeR4MathGuard(seed: 20260719)
            : extraRaw == "3"
            ? BASDifficultyProbeCollectTests.makeBroadQuestions(seed: 20260713, perCell: 40)
                + BASDifficultyProbeCollectTests.makeQuestions(seed: 20260714, perCell: 10)
            : extra
            ? BASDifficultyProbeCollectTests.makeQuestions(
                seed: extraRaw == "2" ? 20260711 : 20260710, perCell: 20)
            : BASDifficultyProbeCollectTests.makeQuestions(seed: 20260704, perCell: 7)
                + BASDifficultyProbeCollectTests.makeBroadQuestions(seed: 20260705, perCell: 7)
                + BASDifficultyProbeCollectTests.makeQuestions(seed: 20260707, perCell: 30)
                + BASDifficultyProbeCollectTests.makeBroadQuestions(seed: 20260708, perCell: 30)
        let mine = all.enumerated().filter { $0.offset % 2 == half }.map(\.element)
        print("[r2-collect] half=\(half) questions=\(mine.count)/\(all.count)")

        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let outURL = docs.appendingPathComponent(
            extraRaw == "4" ? "b2_r4_fresh_\(half).jsonl"
                : extraRaw == "3" ? "b2_r3_fresh_\(half).jsonl"
                : extraRaw == "2" ? "b2_r2_features_extra2_\(half).jsonl"
                : extra ? "b2_r2_features_extra_\(half).jsonl"
                : "b2_r2_features_\(half).jsonl")
        // 可续采(崩溃后 xcodebuild 自动重试从破坏性变无害):已有行按题文跳过,APPEND 永不截断。
        var doneQs = Set<String>()
        if let data = try? Data(contentsOf: outURL), let text = String(data: data, encoding: .utf8) {
            for line in text.split(separator: "\n") where !line.isEmpty {
                if let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                   let q = obj["q"] as? String { doneQs.insert(q) }
            }
        }
        if !FileManager.default.fileExists(atPath: outURL.path) {
            FileManager.default.createFile(atPath: outURL.path, contents: nil)
        }
        // H2 修:轮内按 q 去重(生成器池小必撞;重复槽位曾白烧算力+断言假红)。
        var seenQ = Set<String>()
        let todo = mine.filter { seenQ.insert($0.q).inserted && !doneQs.contains($0.q) }
        print("[r2-collect] resume: already=\(doneQs.count) todo=\(todo.count)")
        let fh = try XCTUnwrap(FileHandle(forWritingAtPath: outURL.path))
        // R4v2(批判 MED-7):续采先截断到最后一个换行——jetsam 落在行中间时,残行会
        // 与新行黏连成永久损毁行;截断后 doneQs 解析与追加两侧都干净。
        if let data = try? Data(contentsOf: outURL), !data.isEmpty {
            if let lastNL = data.lastIndex(of: UInt8(ascii: "\n")) {
                try fh.truncate(atOffset: UInt64(lastNL + 1))
            } else {
                try fh.truncate(atOffset: 0)
            }
        }
        try fh.seekToEnd()
        defer { try? fh.close() }

        // 预 tokenize(避免 perform 内 async;sustained 式单 perform 单解码器——
        // 崩因修复:v1 每题一次 perform + 每题重建解码器(每次重量化 MTP 头)= jetsam churn)。
        var tokenized: [[Int]] = []
        for item in todo {
            let input = try await container.prepare(input: UserInput(chat: [.user(item.q)]))
            let ids: [Int] = try await container.perform(nonSendable: input) { _, input in
                input.text.tokens.asArray(Int.self)
            }
            tokenized.append(ids)
        }
        let todoFixed = todo
        let tokFixed = tokenized
        struct Row: Sendable { let h: [Float]; let qlen: Int; let text: String; let idx: Int }
        struct Batch: Sendable { let rows: [Row] }
        var written = doneQs.count
        var correct = 0
        // 分段 perform(每段 25 题):段间回到 actor 落盘+清缓存,段内单解码器复用。
        var cursor = 0
        while cursor < todoFixed.count {
            let lo = cursor, hi = min(cursor + 25, todoFixed.count)
            cursor = hi
            let batch: Batch = try await container.perform { ctx -> Batch in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let open = ctx.tokenizer.convertTokenToId("<think>") ?? 248068
                let close = ctx.tokenizer.convertTokenToId("</think>") ?? 248069
                let nl = ctx.tokenizer.encode(text: "\n").last ?? 198
                let nl2 = ctx.tokenizer.encode(text: "\n\n").last ?? 271
                let cfg = BASTraceExitConfig(
                    thinkOpenToken: open, thinkCloseToken: close,
                    closeSequence: [nl, close, nl2], boundaryTokens: [nl, nl2])
                var rows: [Row] = []
                for i in lo ..< hi {
                    let ids = tokFixed[i]
                    let cache = qwen.newCache(parameters: nil)
                    let h0 = qwen.hiddenStatesWithCache(
                        MLXArray(ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                    let h = h0[0, h0.dim(1) - 1].asType(.float32).asArray(Float.self)
                    let run = dec.generateSpecKFused(
                        prompt: ids, maxTokens: 224, eosTokens: eos, k: 3,
                        tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true, traceExit: cfg)
                    rows.append(Row(h: h, qlen: ids.count,
                                    text: ctx.tokenizer.decode(tokenIds: run.tokens), idx: i))
                }
                return Batch(rows: rows)
            }
            for row in batch.rows {
                let item = todoFixed[row.idx]
                let answerText = row.text.range(of: "</think>").map { String(row.text[$0.upperBound...]) } ?? row.text
                // R4v2(批判 MED-8):alpha 判分取答案末行——五选难题下模型枚举比较选项,
                // 全文匹配把"出现在枚举里"误判为对,虚高正例抽干负例。其余族保持全文匹配
                // (与 R2/R3 仪器可比性),差异入册。
                let scoreText: Substring
                if item.family == "alpha" {
                    scoreText = answerText.split(separator: "\n").last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? Substring(answerText)
                } else {
                    scoreText = Substring(answerText)
                }
                let ok = scoreText.range(of: "\\b\(item.ans)\\b", options: .regularExpression) != nil
                if ok { correct += 1 }
                written += 1
                let rec: [String: Any] = [
                    "family": item.family, "band": item.band, "qlen": row.qlen,
                    "label": ok ? 1 : 0, "q": item.q, "ans": item.ans,
                    "h": row.h.map { Double($0) },
                ]
                var line = try JSONSerialization.data(withJSONObject: rec)
                line.append(0x0A)
                fh.write(line)   // R4v2(MED-7):单次原子性更好的整行写
            }
            MLX.Memory.clearCache()
            print("[r2-collect] \(written)/\(mine.count) batch_acc=\(String(format: "%.2f", Double(correct) / Double(cursor))) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
        }
        let done = written - doneQs.count
        print("[r2-collect] DONE half=\(half) new=\(done) total=\(written)/\(mine.count) → \(outURL.path)")
        // 生成器内部有重复题(broad 饱和)——集齐 = 唯一题全收,非槽位数。
        XCTAssertEqual(written, Set(mine.map(\.q)).count, "含续采在内必须集齐本半全部唯一题")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
