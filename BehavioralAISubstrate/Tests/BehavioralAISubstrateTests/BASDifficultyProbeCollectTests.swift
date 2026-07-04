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

/// B2 探针路由器 — TRAINING-DATA COLLECTION (BAS_PROBE_COLLECT=1, Mac, ~30 min, heavy).
///
/// The pre-generation difficulty probe (2602.09924 AUC 0.931 / DiffAdapt ICLR-26) needs
/// (last-prompt-token hidden state, first-attempt pass/fail) pairs from OUR 4B. This harness
/// generates ~300 programmatic VERIFIABLE questions (7 families × 3 difficulty bands, seeded),
/// runs the production fused lane with the B3 trace-exit armed (answers guaranteed within cap),
/// judges correctness deterministically, and dumps JSONL: {family, band, qlen, label, h[4096]}.
///
/// Scope honesty: v1 domain = verifiable math/factual — the probe learned here routes THIS class;
/// broader production traffic needs its own calibration pass (recorded as the follow-up).
final class BASDifficultyProbeCollectTests: XCTestCase {

    // Deterministic LCG (no system RNG — reproducible dataset across runs).
    private struct LCG {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private static func isPrime(_ n: Int) -> Bool {
        if n < 2 { return false }
        if n < 4 { return true }
        if n % 2 == 0 { return false }
        var i = 3
        while i * i <= n {
            if n % i == 0 { return false }
            i += 2
        }
        return true
    }

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let words = [
        "strawberry", "committee", "bookkeeper", "mississippi", "encyclopedia", "parallelogram",
        "onomatopoeia", "dependability", "carpetbagger", "hippopotamus", "grasshopper", "lollipop",
    ]

    static func makeQuestions(seed: UInt64, perCell: Int) -> [(q: String, ans: String, family: String, band: Int)] {
        var r = LCG(state: seed)
        var out: [(String, String, String, Int)] = []
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        for band in 0 ..< 3 {
            for _ in 0 ..< perCell {
                // mul — bands: 2d×1d / 2d×2d / 3d×3d
                let (a, b): (Int, Int) = band == 0 ? (10 + r.next(90), 2 + r.next(8))
                    : band == 1 ? (10 + r.next(90), 10 + r.next(90))
                    : (100 + r.next(900), 100 + r.next(900))
                out.append(("What is \(a) multiplied by \(b)?", "\(a * b)", "mul", band))
                // primes — range width 10 / 30 / 60
                let lo = 10 + r.next(60)
                let w = band == 0 ? 10 : band == 1 ? 30 : 60
                let cnt = (lo ... lo + w).filter { isPrime($0) }.count
                out.append(("How many prime numbers are there between \(lo) and \(lo + w), inclusive? Give the count.",
                            "\(cnt)", "primes", band))
                // weekday — shift 3-9 / 20-60 / 100-400
                let d = r.next(7)
                let shift = band == 0 ? 3 + r.next(7) : band == 1 ? 20 + r.next(41) : 100 + r.next(301)
                out.append(("If today is \(weekdays[d]), what day of the week will it be \(shift) days from now?",
                            weekdays[(d + shift) % 7], "weekday", band))
                // letters — the tokenizer-hostile family (band by word length tier)
                let word = words[r.next(words.count)]
                let letter = Array(word)[r.next(word.count)]
                let lcnt = word.filter { $0 == letter }.count
                out.append(("How many times does the letter \(letter) appear in the word \(word)?",
                            "\(lcnt)", "letters", band))
                // percent — integer results, growing awkwardness
                let pct = [10, 25, 50][r.next(3)] + (band == 2 ? 5 : 0)   // band2: 15/30/55
                let base = (4 + r.next(20)) * 20
                out.append(("What is \(pct)% of \(base)?", "\(pct * base / 100)", "percent", band))
                // gcd — small / medium / large
                let g = [6, 12, 18][band]
                let (m1, m2) = (2 + r.next(8 + band * 12), 3 + r.next(8 + band * 12))
                out.append(("What is the greatest common divisor of \(g * m1) and \(g * m2)?",
                            "\(gcd(g * m1, g * m2))", "gcd", band))
                // speed — integer km/h
                let sp = 20 + 10 * r.next(band == 0 ? 4 : 10)
                let mins = [30, 45, 90][band]
                out.append(("A vehicle travels \(sp * mins / 60) km in \(mins) minutes. What is its speed in km/h?",
                            "\(sp)", "speed", band))
            }
        }
        return out
    }

    func testCollectProbeFeatures() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PROBE_COLLECT"] == "1" else {
            throw XCTSkip("set BAS_PROBE_COLLECT=1 (Mac, heavy — ~300 generations on Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        let outPath = ProcessInfo.processInfo.environment["BAS_PROBE_OUT"]
            ?? "/tmp/gdn_coreai/probe_features.jsonl"
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let questions = Self.makeQuestions(seed: 20260704, perCell: 7)   // 3 bands × 7 × 7 fam = 147×... = 441? (7 fam × 3 × 7 = 147)
        FileManager.default.createFile(atPath: outPath, contents: nil)
        let fh = try XCTUnwrap(FileHandle(forWritingAtPath: outPath))
        defer { try? fh.close() }

        var done = 0, correct = 0
        for item in questions {
            let input = try await container.prepare(input: UserInput(chat: [.user(item.q)]))
            struct S: Sendable { let h: [Float]; let qlen: Int; let text: String; let closeIdx: Bool }
            let s: S = try await container.perform(nonSendable: input) { ctx, input in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let ids = input.text.tokens.asArray(Int.self)
                // FEATURE: last-prompt-token hidden state from a dedicated prefill (the probe's
                // production home is the fused lane's own h0 — same tensor, shared KV there).
                let cache = qwen.newCache(parameters: nil)
                let h0 = qwen.hiddenStatesWithCache(
                    MLXArray(ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                let h = h0[0, h0.dim(1) - 1].asType(.float32).asArray(Float.self)
                // LABEL: production-shape generation (B3 armed ⇒ the answer text exists in-cap).
                let open = ctx.tokenizer.convertTokenToId("<think>") ?? 248068
                let close = ctx.tokenizer.convertTokenToId("</think>") ?? 248069
                let nl = ctx.tokenizer.encode(text: "\n").last ?? 198
                let nl2 = ctx.tokenizer.encode(text: "\n\n").last ?? 271
                let cfg = BASTraceExitConfig(
                    thinkOpenToken: open, thinkCloseToken: close,
                    closeSequence: [nl, close, nl2], boundaryTokens: [nl, nl2])
                let run = dec.generateSpecKFused(
                    prompt: ids, maxTokens: 224, eosTokens: eos, k: 3, tCap: 12,
                    adaptiveK: true, traceExit: cfg)
                let text = ctx.tokenizer.decode(tokenIds: run.tokens)
                return S(h: h, qlen: ids.count, text: text,
                         closeIdx: run.tokens.contains(close))
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
            let data = try JSONSerialization.data(withJSONObject: rec)
            fh.write(data)
            fh.write("\n".data(using: .utf8)!)
            if done % 20 == 0 {
                print("[probe-collect] \(done)/\(questions.count) running_acc=\(String(format: "%.2f", Double(correct) / Double(done)))")
                MLX.GPU.clearCache()
            }
        }
        print("[probe-collect] DONE n=\(done) acc=\(String(format: "%.3f", Double(correct) / Double(done))) → \(outPath)")
        XCTAssertGreaterThan(done, 100)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
