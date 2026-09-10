// MARK: - BASSpecAcceptanceProbe — Gate 2: GPU same-vocab draft free-form α (BAS_SPEC_ALPHA=1)
//
// Decode-accel cascade Gate 2 (Gate 1 ANE-overlap FAILED: ρ=0.86 contention). Question: does a draft MODEL help
// FREE-FORM at all on the GPU (no ANE overlap needed — both models on GPU, like the shipped 1.46× greedy-spec
// sibling)? Measures teacher-forced acceptance α of Llama-3.2-1B (DRAFT, same vocab) vs Llama-3.2-3B (TARGET):
//   a = accepted/round on FREE-FORM. With both on GPU there's no f→0 overlap, so the honest net ≈ (1+a·K)/(1+f·K);
//   but `a` itself is the gate — a<0.5 means no draft beats the free-form wall (→ Gate 3 bandwidth); a≥0.5 means a
//   GPU draft is worth routing onto free-form lanes.
//
// Method: target greedy → reference T; draft teacher-forced over prompt+T (ONE forward) → per-position argmax
// agreement; BASAcceptanceBlockReducer → a. No rewind shim, no ANE. Echo-heavy workloads are the sanity floor (a
// same-vocab 1B should ace verbatim repeats). Launch BAS_ENDURANCE_AUTOSTART=1 BAS_SPEC_ALPHA=1. Needs both MLX
// models loadable on device (the 3B is the spec target; the 1B is the certified spec sibling). Env: BAS_SPEC_ALPHA_K,
// BAS_SPEC_ALPHA_MAXTOK. Output: Documents/spec-alpha-<stamp>.log.

import Foundation
import BASOrgan
import BASMLXAdapter

enum BASSpecAcceptanceProbe {

    /// (name, class, prompt). `echo` = output recapitulates the prompt (the draft should ace these — harness sanity).
    /// `free` = genuinely generative (the real test of whether a small draft tracks the 3B on novel content).
    private static let workloads: [(name: String, klass: String, prompt: String)] = [
        ("rag-quote", "echo",
         "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of the "
         + "cell's supply of adenosine triphosphate.\n\"\"\"\nQuote the passage above back to me verbatim."),
        ("json", "echo",
         "Convert these records to a JSON array, one object per line with keys id, name:\n1 Alice\n2 Bob\n3 Carol"),
        ("code", "echo",
         "Repeat this Swift function exactly, then repeat it again unchanged:\n"
         + "func add(_ a: Int, _ b: Int) -> Int { return a + b }"),
        ("qa", "free",
         "Explain in a few sentences why the sky appears blue during the day."),
        ("reasoning", "free",
         "A train travels at 60 miles per hour for 2.5 hours. How far does it travel? "
         + "Show your reasoning step by step."),
        ("summarize", "free",
         "Summarize the following in two sentences:\nThe Industrial Revolution was a period of major "
         + "industrialization and innovation during the late 1700s and early 1800s. It began in Britain and spread "
         + "to other parts of the world, transforming economies from agrarian to manufacturing-based."),
        ("creative", "free",
         "Write a short, original opening paragraph for a science-fiction story set on a distant moon."),
    ]

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "spec-alpha", category: "spec-alpha", alsoPrint: false)
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let K = Int(env["BAS_SPEC_ALPHA_K"] ?? "") ?? 4
        let maxTok = Int(env["BAS_SPEC_ALPHA_MAXTOK"] ?? "") ?? 160
        fileLog.emit("📊 spec-alpha START — Gate 2: GPU same-vocab draft (Llama-1B) free-form α vs 3B target, K=\(K) maxTok=\(maxTok)")
        do {
            let target = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget, maxOutputTokens: maxTok, speculativeDecoding: .off)
            try await target.loadModel()
            fileLog.emit("📊 spec-alpha target(Llama-3.2-3B) loaded")

            let draft = MLXOrganAdapter(
                model: MLXModelCatalog.llama3_2_1B_4bit, maxOutputTokens: maxTok, speculativeDecoding: .off)
            try await draft.loadModel()
            fileLog.emit("📊 spec-alpha draft(Llama-3.2-1B) loaded")

            var freeA: [Double] = []
            var echoA: [Double] = []
            for w in workloads {
                let req = BASOrganRequest(
                    requestID: "alpha-\(w.name)", role: .core,
                    preset: .greedyDeterministic, instruction: w.prompt, context: [])
                do {
                    let ref = try await target.greedyReferenceTokens(for: req)
                    let agreement = try await draft.teacherForcedAgreement(
                        promptTokens: ref.promptTokens, referenceTokens: ref.tokens)
                    let r = BASAcceptanceBlockReducer.reduce(agreement: agreement, k: K)
                    let perTok = agreement.isEmpty ? 0
                        : Double(agreement.filter { $0 }.count) / Double(agreement.count)
                    if w.klass == "free" { freeA.append(r.meanAcceptedPerRound) }
                    else { echoA.append(r.meanAcceptedPerRound) }
                    fileLog.emit(String(format:
                        "📊 spec-alpha workload=%@ class=%@ n=%d a=%.2f tpr=%.2f per_token_agree=%.2f",
                        w.name, w.klass, ref.tokens.count, r.meanAcceptedPerRound, r.tokensPerRound, perTok))
                } catch {
                    fileLog.emit("📊 spec-alpha workload=\(w.name) ERROR=\(error)")
                }
            }
            let meanFree = freeA.isEmpty ? 0 : freeA.reduce(0, +) / Double(freeA.count)
            let meanEcho = echoA.isEmpty ? 0 : echoA.reduce(0, +) / Double(echoA.count)
            let verdict = meanFree >= 1.0 ? "BUILD-route-GPU-sibling-onto-free-form"
                        : (meanFree >= 0.5 ? "MARGINAL" : "FAIL-go-Gate3-bandwidth")
            fileLog.emit(String(format:
                "📊 spec-alpha DONE free_a_mean=%.2f echo_a_mean=%.2f K=%d verdict=%@ "
                + "(gate: free a≥1 build, 0.5–1 marginal, <0.5 → Gate 3)",
                meanFree, meanEcho, K, verdict))
        } catch {
            fileLog.emit("📊 spec-alpha ERROR=\(error)")
        }
    }
}
