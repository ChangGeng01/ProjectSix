// MARK: - BASSpecSpeedupProbe — Gate 2b: end-to-end free-form tok/s, draft-spec vs plain (BAS_SPEC_SPEEDUP=1)
//
// Gate 2 proved the draft's ACCEPTANCE is high on free-form (a=2.28). This closes the α→speedup gap: the NET speedup
// is (1+a·K)/(1+f·K) — it needs the GPU draft cost f. Measure it directly, end-to-end, on ONE loaded adapter
// (Llama-3.2-3B target + Llama-3.2-1B draft) by toggling the kill-switch:
//   • plain  = decodePlannerAutoSelect OFF → `_plainDraft` (production plain, no draft).
//   • spec   = decodePlannerAutoSelect ON  → planner → `.draftModelSpec` → `_draftSpeculative` (1B drafts, 3B verifies).
// speedup = spec_tok/s ÷ plain_tok/s on FREE-FORM. >1 ⇒ deploying the 1B draft genuinely speeds up free-form decode.
//
// Both lanes JIT distinct kernels (BAS loop vs vendor spec generate), so a warmup pass precedes timing. Launch
// BAS_ENDURANCE_AUTOSTART=1 BAS_SPEC_SPEEDUP=1. Needs the 3B + 1B both loadable (the certified spec pair). Env:
// BAS_SPEC_SPEEDUP_K, BAS_SPEC_SPEEDUP_MAXTOK. Output: Documents/spec-speedup-<stamp>.log.

import Foundation
import BASOrgan
import BASMLXAdapter

enum BASSpecSpeedupProbe {

    private static let workloads: [(name: String, klass: String, prompt: String)] = [
        ("rag-quote", "echo",
         "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of the "
         + "cell's supply of adenosine triphosphate.\n\"\"\"\nQuote the passage above back to me verbatim."),
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
        let fileLog = ProbeFileLog(filePrefix: "spec-speedup", category: "spec-speedup", alsoPrint: false)
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let K = Int(env["BAS_SPEC_SPEEDUP_K"] ?? "") ?? 4
        let maxTok = Int(env["BAS_SPEC_SPEEDUP_MAXTOK"] ?? "") ?? 128
        fileLog.emit("📊 spec-speedup START — Gate 2b: draft-spec(1B+3B) vs plain free-form tok/s, K=\(K) maxTok=\(maxTok)")
        do {
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget,
                maxOutputTokens: maxTok,
                draftModel: MLXModelCatalog.llama3_2_1B_4bit,
                speculativeDecoding: .greedy,
                numDraftTokens: K)
            try await adapter.loadModel()
            let specActive = await adapter.isSpeculationActive
            fileLog.emit("📊 spec-speedup loaded specActive=\(specActive)")
            guard specActive else {
                fileLog.emit("📊 spec-speedup ERROR=draft-not-loaded — spec lane inactive (fit budget? staging?)"); return
            }

            // Estimated-token rate; both lanes share the same char-based estimator so the speedup ratio is fair.
            func timed(_ req: BASOrganRequest) async throws -> (tps: Double, ms: Double, toks: Int) {
                let t0 = DispatchTime.now().uptimeNanoseconds
                let d = try await adapter.draft(req)
                let ms = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
                let toks = d.outputTokensEstimated
                return (ms > 0 ? Double(toks) * 1000.0 / ms : 0, ms, toks)
            }

            // WARMUP both distinct JIT kernel paths (BAS plain loop vs vendor spec generate) so timing is warm.
            let warm = BASOrganRequest(
                requestID: "spd-warm", role: .core, preset: .greedyDeterministic, instruction: "Hello.", context: [])
            await adapter.setDecodePlannerAutoSelect(false); _ = try? await adapter.draft(warm)
            await adapter.setDecodePlannerAutoSelect(true);  _ = try? await adapter.draft(warm)
            fileLog.emit("📊 spec-speedup warmup done")

            var freeSpeedups: [Double] = []
            for w in workloads {
                let req = BASOrganRequest(
                    requestID: "spd-\(w.name)", role: .core,
                    preset: .greedyDeterministic, instruction: w.prompt, context: [])
                do {
                    await adapter.setDecodePlannerAutoSelect(false)   // plain (no draft)
                    let plain = try await timed(req)
                    await adapter.setDecodePlannerAutoSelect(true)    // draft-model spec
                    let spec = try await timed(req)
                    let speedup = plain.tps > 0 ? spec.tps / plain.tps : 0
                    if w.klass == "free" { freeSpeedups.append(speedup) }
                    fileLog.emit(String(format:
                        "📊 spec-speedup workload=%@ class=%@ plain_tps=%.1f spec_tps=%.1f speedup=%.2fx "
                        + "plain_ms=%.0f spec_ms=%.0f plain_tok=%d spec_tok=%d",
                        w.name, w.klass, plain.tps, spec.tps, speedup, plain.ms, spec.ms, plain.toks, spec.toks))
                } catch {
                    fileLog.emit("📊 spec-speedup workload=\(w.name) ERROR=\(error)")
                }
            }
            let meanFree = freeSpeedups.isEmpty ? 0 : freeSpeedups.reduce(0, +) / Double(freeSpeedups.count)
            fileLog.emit(String(format:
                "📊 spec-speedup DONE free_speedup_mean=%.2fx K=%d (>1 ⇒ the 1B draft speeds up free-form end-to-end)",
                meanFree, K))
        } catch {
            fileLog.emit("📊 spec-speedup ERROR=\(error)")
        }
    }
}
