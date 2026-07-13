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


    // ── B2 tail-closure: BROAD-DOMAIN families (non-arithmetic, still VERIFIABLE) ──
    // The v1 probe trained on 7 math/counting families only; these 4 probe whether it
    // generalizes: factual recall, reading extraction, alphabetical ordering, string reversal.
    private static let capitals: [[(String, String)]] = [
        [("France", "Paris"), ("Japan", "Tokyo"), ("Italy", "Rome"), ("Spain", "Madrid"),
         ("Germany", "Berlin"), ("England", "London"), ("Russia", "Moscow"), ("China", "Beijing")],
        [("Norway", "Oslo"), ("Kenya", "Nairobi"), ("Thailand", "Bangkok"), ("Peru", "Lima"),
         ("Portugal", "Lisbon"), ("Austria", "Vienna"), ("Cuba", "Havana"), ("Greece", "Athens")],
        [("Bhutan", "Thimphu"), ("Suriname", "Paramaribo"), ("Burkina Faso", "Ouagadougou"),
         ("Kyrgyzstan", "Bishkek"), ("Eritrea", "Asmara"), ("Vanuatu", "Port Vila"),
         ("Lesotho", "Maseru"), ("Moldova", "Chisinau")],
    ]
    private static let readColors = ["red", "green", "blue", "yellow", "black", "white", "silver", "purple"]
    private static let readItems = ["book", "cup", "key", "coin", "pen", "map", "bell", "comb"]
    private static let readPlaces = ["shelf", "drawer", "table", "basket", "windowsill", "cupboard", "bench", "tray"]
    private static let alphaPools: [[[String]]] = [
        [["apple", "mango", "zebra", "kite", "orange"], ["banana", "tiger", "cloud", "wolf", "grape"],
         ["desk", "river", "yarn", "hill", "plum"]],
        [["stone", "star", "sting", "stew", "stack"], ["brick", "brave", "bloom", "batch", "burn"],
         ["crane", "cliff", "chess", "count", "cycle"]],
        [["bring", "brink", "brisk", "bride", "bright"], ["stack", "stall", "stamp", "stark", "stab"],
         ["chart", "charm", "chase", "champ", "chalk"]],
    ]
    private static let reverseWords: [[String]] = [
        ["lamp", "frog", "mint", "dusk", "coal", "vine", "peak"],
        ["blanket", "harvest", "lantern", "monster", "gravity", "postage", "whisper"],
        ["motorcycle", "watermelon", "toothbrush", "coordinate", "lighthouse", "brainstorm", "spreadsheet"],
    ]
    static func makeBroadQuestions(seed: UInt64, perCell: Int) -> [(q: String, ans: String, family: String, band: Int)] {
        var r = LCG(state: seed)
        var out: [(String, String, String, Int)] = []
        for band in 0 ..< 3 {
            for _ in 0 ..< perCell {
                // recall — capitals, band = obscurity tier
                let (country, capital) = capitals[band][r.next(capitals[band].count)]
                out.append(("What is the capital city of \(country)? Answer with just the city name.",
                            capital, "recall", band))
                // reading — extract one placed fact among 2/5/8 distractor facts
                let nFacts = [2, 5, 8][band]
                var pairs: [(String, String, String)] = []
                var used = Set<Int>()
                while pairs.count < nFacts {
                    let ci = r.next(readColors.count), ii = r.next(readItems.count)
                    guard used.insert(ci * 100 + ii).inserted else { continue }
                    pairs.append((readColors[ci], readItems[ii], readPlaces[r.next(readPlaces.count)]))
                }
                let passage = pairs.map { "The \($0.0) \($0.1) is on the \($0.2)." }.joined(separator: " ")
                let pick = pairs[r.next(pairs.count)]
                out.append(("\(passage) Where is the \(pick.0) \(pick.1)? Answer with one word.",
                            pick.2, "reading", band))
                // alpha — first-alphabetically among 3, band = shared-prefix depth
                let pool = alphaPools[band][r.next(alphaPools[band].count)]
                var trio = Set<String>()
                while trio.count < 3 { trio.insert(pool[r.next(pool.count)]) }
                let items = Array(trio)
                out.append(("Which of these words comes first alphabetically: \(items.joined(separator: ", "))? Answer with the word.",
                            items.min()!, "alpha", band))
                // reverse — spell backwards, band = word length tier
                let word = reverseWords[band][r.next(reverseWords[band].count)]
                out.append(("Spell the word \"\(word)\" backwards. Answer with the reversed letters only, no separators.",
                            String(word.reversed()), "reverse", band))
            }
        }
        return out
    }

    // ── R4 新题库(RSI 章程第六部分,2026-07-07 冻结)——alpha 主战场 + 次级域 ──
    private static let r4Band0Words = [
        "anchor", "breeze", "copper", "dolphin", "ember", "falcon", "garnet", "harbor",
        "island", "jungle", "kettle", "lantern", "meadow", "nectar", "orbit", "pebble",
        "quartz", "ribbon", "saddle", "timber", "umbrella", "velvet", "walnut", "xenon",
        "yonder", "zephyr",
    ]
    private static let r4Band1Pools = [
        ["magnet", "meadow", "mirror", "morsel", "muffin", "mantle", "mellow"],
        ["damsel", "deputy", "dinghy", "donkey", "dampen", "dexter", "dimple"],
        ["hammer", "hedges", "hollow", "hazel", "hinge", "hoist", "humble"],
        ["padded", "pencil", "pillow", "pocket", "puddle", "parcel", "pigeon"],
        ["rabbit", "reason", "ripple", "rocket", "rustic", "raven", "riddle"],
        ["sample", "settle", "signal", "sorrow", "supper", "saloon", "sizzle"],
        ["tackle", "temper", "tinder", "topple", "tunnel", "tailor", "tissue"],
        ["wander", "weasel", "wicker", "wobble", "warden", "walrus", "willow"],
    ]
    private static let r4Band2Clusters = [
        ["grain", "grand", "grant", "grasp", "grass", "grave", "gravel"],
        ["plane", "plank", "plant", "plate", "plaza", "place", "plaid"],
        ["crest", "crews", "creed", "creek", "creep", "cream", "crease"],
        ["shine", "shift", "shirt", "shiver", "shield", "shimmer", "shin"],
        ["trace", "track", "trade", "trail", "train", "trait", "tram"],
        ["frost", "front", "frown", "froze", "frozen", "frock", "frolic"],
        ["click", "climb", "cling", "clinic", "clip", "clique", "clinch"],
        ["spray", "spread", "spring", "sprint", "sprout", "spruce", "sprig"],
        ["thread", "threat", "thrift", "throne", "throat", "throb", "thrive"],
        ["bland", "blank", "blast", "blaze", "blade", "blame", "blare"],
    ]
    private static let r4ReverseWords: [[String]] = [
        ["quartz", "anchor", "breeze", "saddle", "walnut", "velvet"],
        ["avocado", "biscuit", "caravan", "dungeon", "epsilon", "flamingo"],
        ["chandelier", "grasshopper", "thermometer", "periscope", "binoculars", "peninsula"],
    ]
    private static let r4Elements: [[(String, String)]] = [
        [("oxygen", "O"), ("hydrogen", "H"), ("carbon", "C"), ("nitrogen", "N"),
         ("helium", "He"), ("neon", "Ne"), ("zinc", "Zn"), ("calcium", "Ca")],
        [("sodium", "Na"), ("iron", "Fe"), ("copper", "Cu"), ("silver", "Ag"),
         ("gold", "Au"), ("magnesium", "Mg"), ("aluminium", "Al"), ("silicon", "Si")],
        [("lead", "Pb"), ("mercury", "Hg"), ("tin", "Sn"), ("potassium", "K"),
         ("tungsten", "W"), ("antimony", "Sb"), ("bismuth", "Bi"), ("manganese", "Mn")],
    ]

    /// R4v2 math 守卫(批判 CRITICAL-1:原 105 槽经双集排除只活 38——speed/percent/
    /// letters/primes 空间饱和)。只用 mul/gcd/weekday 且参数域外扩(与语料draw不相交
    /// 的区间),仿真预验存活。种子 20260719。
    static func makeR4MathGuard(seed: UInt64) -> [(q: String, ans: String, family: String, band: Int)] {
        var r = LCG(state: seed)
        var out: [(String, String, String, Int)] = []
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        for band in 0 ..< 3 {
            for _ in 0 ..< 30 {
                // mul:外扩区间(千位段,语料为 2-3 位段)
                let (a, b): (Int, Int) = band == 0 ? (1000 + r.next(9000), 2 + r.next(8))
                    : band == 1 ? (1000 + r.next(9000), 10 + r.next(90))
                    : (1000 + r.next(9000), 100 + r.next(900))
                out.append(("What is \(a) multiplied by \(b)?", "\(a * b)", "mul", band))
                // gcd:外扩基数(语料 g∈{6,12,18};此处 {21,24,27})
                let g = [21, 24, 27][band]
                let (m1, m2) = (2 + r.next(8 + band * 12), 3 + r.next(8 + band * 12))
                out.append(("What is the greatest common divisor of \(g * m1) and \(g * m2)?",
                            "\(gcd(g * m1, g * m2))", "gcd", band))
                // weekday:外扩位移(语料 ≤400;此处 500-999)
                let d = r.next(7)
                let shift = 500 + r.next(500)
                out.append(("If today is \(weekdays[d]), what day of the week will it be \(shift) days from now?",
                            weekdays[(d + shift) % 7], "weekday", band))
            }
        }
        return out
    }

    static func makeR4Questions(seed: UInt64) -> [(q: String, ans: String, family: String, band: Int)] {
        var r = LCG(state: seed)
        var out: [(String, String, String, Int)] = []
        // R4v2(起飞前批判 HIGH-2a):全 band 统一 k=4——"选项数"曾是裸露的 band 标记,
        // 会把 band 可分性混进"路由能力";难度只由前缀深度承载。band 槽位 80/100/150
        // (HIGH-4:band2 C(7,4)=35×10=350 唯一空间,150 槽喂足负例)。
        let perBand = [80, 100, 150]
        for band in 0 ..< 3 {
            for _ in 0 ..< perBand[band] {
                let pool: [String]
                let k = 4
                switch band {
                case 0: pool = r4Band0Words
                case 1: pool = r4Band1Pools[r.next(r4Band1Pools.count)]
                default: pool = r4Band2Clusters[r.next(r4Band2Clusters.count)]
                }
                var pick = Set<String>()
                while pick.count < k { pick.insert(pool[r.next(pool.count)]) }
                // 确定性洗牌:先 sorted() 定基序(消 Set 进程随机序——审计抓过的同款坑),
                // 再 LCG Fisher-Yates(随机比较器非严格弱序,禁用)。
                var items = pick.sorted()
                for i in stride(from: items.count - 1, to: 0, by: -1) {
                    items.swapAt(i, r.next(i + 1))
                }
                out.append(("Which of these words comes first alphabetically: \(items.joined(separator: ", "))? Answer with the word.",
                            items.min()!, "alpha", band))
            }
        }
        // reverse ~45(新词,band=词长)
        for band in 0 ..< 3 {
            for _ in 0 ..< 15 {
                let w = r4ReverseWords[band][r.next(r4ReverseWords[band].count)]
                out.append(("Spell the word \"\(w)\" backwards. Answer with the reversed letters only, no separators.",
                            String(w.reversed()), "reverse", band))
            }
        }
        // elements ~45(新模板次级域,band=生僻度)
        for band in 0 ..< 3 {
            for _ in 0 ..< 15 {
                let (name, sym) = r4Elements[band][r.next(r4Elements[band].count)]
                out.append(("What is the chemical symbol for \(name)? Answer with just the symbol.",
                            sym, "elements", band))
            }
        }
        return out
    }

    func testCollectProbeFeatures() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PROBE_COLLECT"] == "1" else {
            throw XCTSkip("set BAS_PROBE_COLLECT=1 (Mac, heavy — ~300 generations on Qwen3.5-4B)")
        }
        try await collect(questions: Self.makeQuestions(seed: 20260704, perCell: 7),
                          defaultOut: "/tmp/gdn_coreai/probe_features.jsonl")
    }

    /// B2 tail-closure: same pipeline over the 4 broad-domain families (84 questions) —
    /// the v1-probe generalization set (evaluated by Tools/eval_probe_ood.py).
    func testCollectBroadProbeFeatures() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PROBE_BROAD"] == "1" else {
            throw XCTSkip("set BAS_PROBE_BROAD=1 (Mac, heavy — 84 generations on Qwen3.5-4B)")
        }
        try await collect(questions: Self.makeBroadQuestions(seed: 20260705, perCell: 7),
                          defaultOut: "/tmp/gdn_coreai/probe_features_broad.jsonl")
    }

    private func collect(
        questions: [(q: String, ans: String, family: String, band: Int)], defaultOut: String
    ) async throws {
        #if canImport(MLXLLM)
        let outPath = ProcessInfo.processInfo.environment["BAS_PROBE_OUT"] ?? defaultOut
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
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
                MLX.Memory.clearCache()
            }
        }
        print("[probe-collect] DONE n=\(done) acc=\(String(format: "%.3f", Double(correct) / Double(done))) → \(outPath)")
        XCTAssertEqual(done, questions.count, "collection incomplete")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
