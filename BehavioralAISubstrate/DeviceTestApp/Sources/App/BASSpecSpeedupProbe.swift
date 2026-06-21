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

            // REAL-token rate (audit fix): the two lanes emit different-length bodies via different forward paths, so
            // the prior chars/4 `outputTokensEstimated` was biased differently per lane. Use the actual tokenizer count.
            func timed(_ req: BASOrganRequest) async throws -> (tps: Double, ms: Double, toks: Int) {
                let t0 = DispatchTime.now().uptimeNanoseconds
                let d = try await adapter.draft(req)
                let ms = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
                let toks = await adapter.tokenCount(of: d.body)   // real tokenizer count, not chars/4
                return (ms > 0 ? Double(toks) * 1000.0 / ms : 0, ms, toks)
            }

            // WARMUP both distinct JIT kernel paths (BAS plain loop vs vendor spec generate) so timing is warm.
            let warm = BASOrganRequest(
                requestID: "spd-warm", role: .core, preset: .greedyDeterministic, instruction: "Hello.", context: [])
            await adapter.setDecodePlannerAutoSelect(false); _ = try? await adapter.draft(warm)
            await adapter.setDecodePlannerAutoSelect(true);  _ = try? await adapter.draft(warm)
            fileLog.emit("📊 spec-speedup warmup done")

            // T4 (gap-audit): THERMAL-BRACKET each workload — plain-pre / spec / plain-post with cooldowns, and
            // refuse a speedup that falls inside the plain-to-plain drift band (mirrors BASQuantABProbe's discipline).
            // The original plain-then-spec single-shot gave spec a hot-SECOND bias on a +77-112%-drift device and ran
            // the free-form workloads last (hottest) — so the 0.88× "NET LOSS" that set minDraftModelAccepted=2.7 was
            // confounded. This bracket makes each workload self-thermal-controlled; the per-workload drift is reported.
            func cooldown() async { try? await Task.sleep(nanoseconds: 6_000_000_000) }
            func ts() -> String {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal: return "nominal"; case .fair: return "fair"
                case .serious: return "serious"; case .critical: return "critical"; @unknown default: return "?"
                }
            }
            var freeSpeedups: [Double] = []
            for w in workloads {
                let req = BASOrganRequest(
                    requestID: "spd-\(w.name)", role: .core,
                    preset: .greedyDeterministic, instruction: w.prompt, context: [])
                do {
                    await adapter.setDecodePlannerAutoSelect(false)   // plain-pre
                    let plainPre = try await timed(req); await cooldown()
                    await adapter.setDecodePlannerAutoSelect(true)    // draft-model spec (sandwiched)
                    let spec = try await timed(req); await cooldown()
                    await adapter.setDecodePlannerAutoSelect(false)   // plain-post (the drift probe)
                    let plainPost = try await timed(req); await cooldown()
                    let bracketMs = (plainPre.ms + plainPost.ms) / 2
                    let driftBand = abs(plainPost.ms - plainPre.ms)
                    let driftPct = plainPre.ms > 0 ? (plainPost.ms - plainPre.ms) / plainPre.ms * 100 : 0
                    let speedup = spec.ms > 0 ? bracketMs / spec.ms : 0     // ms: lower = faster
                    let win = spec.ms > 0 && spec.ms < (bracketMs - driftBand)
                    let verdict = win ? "SPEC-WIN" : "WITHIN-DRIFT"
                    if w.klass == "free" { freeSpeedups.append(speedup) }
                    fileLog.emit(String(format:
                        "📊 spec-speedup workload=%@ class=%@ plain_bracket_ms=%.0f spec_ms=%.0f drift_pct=%+.1f%% "
                        + "speedup=%.2fx verdict=%@ thermal=%@ (bracketed; drift-honest)",
                        w.name, w.klass, bracketMs, spec.ms, driftPct, speedup, verdict, ts()))
                } catch {
                    fileLog.emit("📊 spec-speedup workload=\(w.name) ERROR=\(error)")
                }
            }
            let meanFree = freeSpeedups.isEmpty ? 0 : freeSpeedups.reduce(0, +) / Double(freeSpeedups.count)
            fileLog.emit(String(format:
                "📊 spec-speedup DONE free_speedup_mean=%.2fx K=%d thermal=%@ (bracketed plain/spec/plain, drift-refused; "
                + ">1 ⇒ the 1B draft speeds up free-form end-to-end. Recompute minDraftModelAccepted from drift-honest rows)",
                meanFree, K, ts()))
        } catch {
            fileLog.emit("📊 spec-speedup ERROR=\(error)")
        }
    }
}
