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

/// B3 轨迹熵早退 — DEVICE A/B (the promotion gate). TEST_RUNNER_BAS_TRACE_AB=1.
///
/// Two regimes, production τ=300/window 8/min 24/reserve 32 (the _traceExitConfigFromEnv defaults):
///  • ENTROPY regime — 6 verifiable-answer reasoning prompts @ 384 cap, EXIT vs CTRL interleaved
///    (arm order alternates per prompt to cancel thermal drift). Verdict inputs: think-token cut,
///    total-token cut, decode time, ANSWER CORRECTNESS PARITY (quality must hold — the gate).
///  • BUDGET regime — 2 prompts @ 128 cap (the co-gate 96-tok artifact shape): the EXIT arm must
///    produce post-think answer text; the CTRL arm historically burns the whole cap thinking.
///
/// Honest-failure discipline: every row prints raw numbers; the assertions are deliberately weak
/// (plumbing-level) — the PROMOTION VERDICT is read from the printed table, not from XCTAssert.
final class BASTraceExitDeviceTests: XCTestCase {

    private struct Row: Sendable {
        let prompt: String
        let arm: String            // "exit" | "ctrl"
        let cap: Int
        let total: Int
        let think: Int             // tokens up to and including </think> (total if never closed)
        let seconds: Double
        let fired: String          // "entropy" | "budget" | "-"
        let correct: Bool
        let answerLen: Int         // decoded chars AFTER </think> (0 = no answer emerged)
    }

    private static let quiz: [(q: String, a: [String])] = [
        ("How many prime numbers are there between 10 and 50? Give the count.", ["11"]),
        ("A farmer has 17 sheep. All but 9 run away. How many sheep are left?", ["9"]),
        ("What is 23 multiplied by 17?", ["391"]),
        ("How many times does the letter r appear in the word strawberry?", ["3", "three"]),
        ("If today is Wednesday, what day of the week will it be 100 days from now?", ["friday"]),
        ("What is the sum of the first 10 positive integers?", ["55"]),
    ]
    private static let budgetQuiz: [(q: String, a: [String])] = [
        ("What is 15% of 240?", ["36"]),
        ("A train travels 60 km in 45 minutes. What is its speed in km/h? Think carefully.", ["80"]),
    ]

    func testTraceExitDeviceAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_TRACE_AB"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_TRACE_AB=1 (device; loads Qwen3.5-4B + MTP weights)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("MTP weights not staged at Documents/qwen35_mtp_folded.safetensors")
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })

        var rows: [Row] = []
        // ENTROPY regime @384: arm order alternates per prompt (thermal-drift cancellation).
        for (i, item) in Self.quiz.enumerated() {
            let order = i % 2 == 0 ? ["ctrl", "exit"] : ["exit", "ctrl"]
            for arm in order {
                rows.append(try await runOne(container: container, q: item.q, answers: item.a,
                                             arm: arm, cap: 384))
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                MLX.GPU.clearCache()
            }
        }
        // BUDGET regime @128 (the 96-tok artifact shape).
        for (i, item) in Self.budgetQuiz.enumerated() {
            let order = i % 2 == 0 ? ["ctrl", "exit"] : ["exit", "ctrl"]
            for arm in order {
                rows.append(try await runOne(container: container, q: item.q, answers: item.a,
                                             arm: arm, cap: 128))
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                MLX.GPU.clearCache()
            }
        }

        for r in rows {
            print(String(format: "[trace-ab] cap=%d arm=%@ total=%d think=%d t=%.1fs tok/s=%.1f fired=%@ correct=%@ ansLen=%d | %@",
                         r.cap, r.arm, r.total, r.think, r.seconds,
                         Double(r.total) / max(r.seconds, 0.001), r.fired,
                         r.correct ? "Y" : "N", r.answerLen, String(r.prompt.prefix(40))))
        }
        summarize(rows.filter { $0.total > 200 || $0.think > 120 }, label: "ENTROPY@384",
                  all: rows.filter { r in Self.quiz.contains { $0.q == r.prompt } })
        summarize([], label: "BUDGET@128",
                  all: rows.filter { r in Self.budgetQuiz.contains { $0.q == r.prompt } })
        XCTAssertFalse(rows.isEmpty)
        let exitFires = rows.filter { $0.arm == "exit" && $0.fired != "-" }.count
        print("[trace-ab] VERDICT-INPUT exit-arm fires: \(exitFires)/\(rows.count / 2)")

        // device-recon id12: compute the promotion verdict via the pure
        // BASTraceExitABVerdict (Mac-unit-tested) and ASSERT the documented
        // quality gate, instead of only printing the numbers. A trace-exit
        // that cut tokens by sacrificing correctness now REDS here.
        func samples(_ rs: [Row]) -> [BASTraceExitABVerdict.ArmSample] {
            rs.map { .init(think: $0.think, correct: $0.correct, answerLen: $0.answerLen) }
        }
        let entropyRows = rows.filter { r in Self.quiz.contains { $0.q == r.prompt } }
        let budgetRows = rows.filter { r in Self.budgetQuiz.contains { $0.q == r.prompt } }
        let verdict = BASTraceExitABVerdict.evaluate(
            entropyExit: samples(entropyRows.filter { $0.arm == "exit" }),
            entropyCtrl: samples(entropyRows.filter { $0.arm == "ctrl" }),
            budgetExit: samples(budgetRows.filter { $0.arm == "exit" }))
        print(String(format: "[trace-ab] VERDICT qualityHeld=%@ thinkCut=%.0f%% budgetAnswered=%@ promote=%@",
                     verdict.qualityHeld ? "Y" : "N", verdict.thinkCut * 100,
                     verdict.budgetAnswered ? "Y" : "N", verdict.promote ? "Y" : "N"))
        XCTAssertTrue(verdict.qualityHeld,
            "ENTROPY quality gate: trace-exit must not drop answer correctness below control")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }

    #if canImport(MLXLLM)
    private func summarize(_ _ignored: [Row], label: String, all: [Row]) {
        let ex = all.filter { $0.arm == "exit" }, ct = all.filter { $0.arm == "ctrl" }
        guard !ex.isEmpty, !ct.isEmpty else { return }
        func mean(_ xs: [Int]) -> Double { Double(xs.reduce(0, +)) / Double(xs.count) }
        let thinkCut = 1 - mean(ex.map(\.think)) / max(mean(ct.map(\.think)), 1)
        let totalCut = 1 - mean(ex.map(\.total)) / max(mean(ct.map(\.total)), 1)
        let sCut = 1 - ex.map(\.seconds).reduce(0, +) / max(ct.map(\.seconds).reduce(0, +), 0.001)
        print(String(format: "[trace-ab] %@ SUMMARY think-cut=%.0f%% total-cut=%.0f%% time-cut=%.0f%% quality exit=%d/%d ctrl=%d/%d answered exit=%d ctrl=%d",
                     label, thinkCut * 100, totalCut * 100, sCut * 100,
                     ex.filter(\.correct).count, ex.count, ct.filter(\.correct).count, ct.count,
                     ex.filter { $0.answerLen > 0 }.count, ct.filter { $0.answerLen > 0 }.count))
    }

    private func runOne(
        container: ModelContainer, q: String, answers: [String], arm: String, cap: Int
    ) async throws -> Row {
        let input = try await container.prepare(input: UserInput(chat: [.user(q)]))
        struct One: Sendable {
            let total: Int; let think: Int; let seconds: Double
            let fired: String; let text: String; let closeIdx: Int
        }
        let r: One = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else { throw BASQwen35MTPSpecDecoder.SpecError.notQwen35 }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
            let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
            var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
            let open = ctx.tokenizer.convertTokenToId("<think>") ?? 248068
            let close = ctx.tokenizer.convertTokenToId("</think>") ?? 248069
            let nl = ctx.tokenizer.encode(text: "\n").last ?? 198
            let nl2 = ctx.tokenizer.encode(text: "\n\n").last ?? 271
            let cfg: BASTraceExitConfig? = arm == "exit" ? BASTraceExitConfig(
                thinkOpenToken: open, thinkCloseToken: close,
                closeSequence: [nl, close, nl2], boundaryTokens: [nl, nl2]) : nil
            let promptIds = input.text.tokens.asArray(Int.self)
            let run = dec.generateSpecKFused(
                prompt: promptIds, maxTokens: cap, eosTokens: eos,
                k: MLXOrganAdapter.mtpProductionK, tCap: MLXOrganAdapter.mtpProductionTCap,
                adaptiveK: true, traceExit: cfg)
            let closeIdx = run.tokens.firstIndex(of: close) ?? -1
            return One(
                total: run.tokens.count,
                think: closeIdx >= 0 ? closeIdx + 1 : run.tokens.count,
                seconds: run.decodeSeconds,
                fired: run.traceExit?.reason.rawValue ?? "-",
                text: ctx.tokenizer.decode(tokenIds: run.tokens),
                closeIdx: closeIdx)
        }
        let answerText: String = {
            guard r.closeIdx >= 0, let range = r.text.range(of: "</think>") else { return "" }
            return String(r.text[range.upperBound...])
        }()
        let hay = (answerText.isEmpty ? "" : answerText).lowercased()
        let correct = answers.contains { hay.contains($0.lowercased()) }
        return Row(prompt: q, arm: arm, cap: cap, total: r.total, think: r.think, seconds: r.seconds,
                   fired: r.fired, correct: correct, answerLen: answerText.count)
    }
    #endif
}
