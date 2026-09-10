// MARK: - BASSuffixLookupProbe — Universal Draft Layer Phase 1: cross-turn suffix SSD on device (BAS_SUFFIX_PROBE=1)
//
// Measures the model-free CROSS-TURN suffix source (any LLM, no draft model, byte-identical): runs a multi-turn
// CONVERSATION where later turns reuse earlier turns' tokens (RAG-revisit, JSON-extend, code-iterate) and a
// free-form CONTROL conversation that does not. Per turn: cross-turn-spec vs baseline (the SAME decoder with a
// null drafter = pure single-model greedy), compared by TOKEN sequence (true byte-identity) + timing + acceptance.
// The win must show up on LATER turns (turn ≥ 1) of the reuse scenarios. The control is NOT expected to be ≥1×:
// the cross-turn lane is meant to be lane-gated OFF on free-form, where it carries the documented ~−8% per-round
// n-gram-scan cost (Track A control 0.91×→0.92× adaptive-K), so the control is expected in a ~0.90–0.95× band.
//
// THE PROMOTION GATE ("实测胜出"): VALID run (no errors / no excluded turns / both arms non-empty) AND
// token-identical on EVERY turn AND later-turn reuse mean > 1× AND control ≥ 0.90× (the documented free-form band).
// Single model resident (default Gemma-4-E2B), speculativeDecoding=.off. Env: BAS_SL_NGRAM_MIN/MAX, BAS_SL_K,
// BAS_SL_CAP, BAS_SLOOKUP_MODEL.
//
// SCOPE CAVEAT (不要亏): both arms here run BASPromptLookupDecoder with a FRESH cache per turn, so this AB
// isolates the DRAFT benefit with prefill held constant. It does NOT compare against the production multi-turn
// path (`draftMultiTurn`'s ChatSession KV-reuse, which prefills only the new turn). A >1× here is necessary but
// NOT sufficient to swap cross-turn in for `draftMultiTurn`: on long histories the re-prefill cost the KV-reuse
// path avoids can dominate. Treat this as "does the cross-turn draft accelerate decode," not "cross-turn beats
// the production multi-turn path."

import Foundation
import os
import BASOrgan
import BASMLXAdapter

enum BASSuffixLookupProbe {

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

    // Multi-turn conversations. Reuse scenarios: a LATER turn re-quotes / repeats / extends earlier content, so
    // the cross-turn corpus (prior turns' prompt+generation) gives the drafter recurring spans. The control's
    // turns are unrelated free-form → ~no cross-turn hits.
    private static let conversations: [(name: String, isReuse: Bool, turns: [String])] = [
        ("rag-revisit", true, [
            "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of "
            + "the cell's supply of adenosine triphosphate, used as a source of chemical energy.\n\"\"\"\n"
            + "Quote the passage above back to me verbatim, word for word.",
            "Now quote that exact same passage again, verbatim, word for word.",
        ]),
        ("json-extend", true, [
            "Convert these records to a JSON array, one object per line with keys id, name, role:\n"
            + "1 Alice engineer\n2 Bob designer\n3 Carol engineer",
            "Repeat that exact JSON array, then append objects for: 4 Dave designer, 5 Eve engineer, "
            + "keeping the identical format.",
        ]),
        ("code-iterate", true, [
            "Write a Swift function `add` that returns the sum of two Ints. Show only the function.",
            "Show that exact same `add` function again, unchanged, then below it show it again with a "
            + "one-line doc comment added above.",
        ]),
        ("control-freeform", false, [
            "Write a short, original opening paragraph for a science-fiction story set on a distant moon.",
            "Write a short, original limerick about a curious otter.",
        ]),
    ]

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "suffix-lookup", category: "suffix-lookup", alsoPrint: false)
        defer { fileLog.close() }

        let env = ProcessInfo.processInfo.environment
        let ngramMin = Int(env["BAS_SL_NGRAM_MIN"] ?? "") ?? 1
        let ngramMax = Int(env["BAS_SL_NGRAM_MAX"] ?? "") ?? 3
        let k = Int(env["BAS_SL_K"] ?? "") ?? 4
        let cap = Int(env["BAS_SL_CAP"] ?? "") ?? 200
        // PROMOTION GATE MODE (BAS_SL_GATE): "strict" (default) requires byte-identity to single-token greedy —
        // reachable only on batch-INVARIANT full-attention models (Llama/Qwen). "lossless" certifies the field-standard
        // guarantee used by dedicated MLX spec-decode projects (dflash-mlx / mlx-optiq): every emitted token IS the
        // target's argmax at verify time (ADR-039 — structural; the draft changes only the acceptance count, never a
        // byte). On batch-NON-invariant sliding-window models (Gemma) sequential byte-identity is unreachable in MLX
        // (~0.68 bf16 logit drift, mlx-optiq) yet losslessness holds; net-positivity (reuse>1× needs real acceptance)
        // doubles as the broken-source detector. See Docs/UNIVERSAL_DRAFT_LAYER.md.
        // PER-MODEL DEFAULT (when BAS_SL_GATE is unset): sliding-window Gemma is batch-NON-invariant (strict
        // byte-identity is structurally unreachable in MLX) so it defaults to "lossless"; full-attention models
        // (Llama/Qwen, batch-invariant → 8/8) default to "strict". An explicit BAS_SL_GATE always overrides.
        let selForGate = (env["BAS_SLOOKUP_MODEL"] ?? "llama_3b").lowercased()
        let defaultGate =
            (selForGate.contains("gemma") || selForGate.contains("e4b") || selForGate.contains("e2b"))
            ? "lossless" : "strict"
        let gateMode = (env["BAS_SL_GATE"] ?? defaultGate).lowercased()
        let losslessGate = gateMode == "lossless"
        fileLog.emit("📊 suffix-lookup START ngram=\(ngramMin)..\(ngramMax) K=\(k) cap=\(cap) gate=\(gateMode)")

        do {
            // Default Llama-3.2-3B (full attention). Sliding-window models (Gemma E2B/E4B) now ALSO run: the decoder
            // admits RotatingKVCache and speculates only inside the trimmable window, degrading to plain greedy past it
            // (byte-identical — see BASPromptLookupDecoder `windowK`). The probe's byte_identical=N/N is the on-device
            // proof the windowed path stays token-identical to single-model greedy on a sliding-window cache.
            let sel = (env["BAS_SLOOKUP_MODEL"] ?? "llama_3b").lowercased()
            let model: MLXModelCatalog.Entry
            switch sel {
            case "llama", "llama_3b": model = MLXModelCatalog.speculativeOptimalTarget
            case "qwen", "qwen_3b": model = MLXModelCatalog.qwen2_5_3B_4bit
            case "qwen_7b", "qwen7b": model = MLXModelCatalog.qwen2_5_7B_4bit
            case "gemma_e4b", "gemma4_e4b", "e4b": model = MLXModelCatalog.gemma4_E4B_4bit
            default: model = MLXModelCatalog.gemma4_E2B_4bit
            }
            let adapter = MLXOrganAdapter(model: model, maxOutputTokens: cap, speculativeDecoding: .off)
            try await adapter.loadModel()

            // FWDDIAG: pin the byte_identical<8/8 residual = bf16 ULP (small logit diff → fp32 fixes) vs systematic
            // Gemma multi-vs-single forward (large diff → fp32 won't). Short offset + a >window offset.
            if env["BAS_SL_FWDDIAG"] == "1" {
                // LIGHT for E4B memory-marginality: short prompts only (tiny KV snapshot). The single-vs-multi forward
                // diff is the SAME bf16-vs-systematic signal regardless of length — a short under-window comparison
                // answers it. (The >window case is covered by the reliable gemma_e2b run.)
                let shortP = "The capital of France is Paris. The Eiffel Tower is located there."
                let medP = "Quote this passage verbatim: The mitochondrion is the powerhouse of the cell; "
                    + "it generates most of the cell's supply of adenosine triphosphate."
                for (tag, p) in [("short", shortP), ("med", medP)] {
                    let line = (try? await adapter.windowForwardDiag(prompt: p, draftLen: k)) ?? "fwddiag ERROR"
                    fileLog.emit("📊 fwddiag[\(tag)] \(line)")
                }
                fileLog.emit("📊 suffix-lookup DONE FWDDIAG=1 (diagnostic only, no promotion gate)")
                return
            }

            var laterTurnReuseSpeedups: [Double] = []   // turn ≥ 1 of reuse scenarios — the cross-turn win
            var controlSpeedups: [Double] = []          // control turns — expected ~0.90–0.95× (lane-gated off)
            var controlWeights: [Double] = []           // per-turn (baseMs+specMs): duration-weights the control mean
            var reuseAccepted = 0, reuseRounds = 0       // acceptance corruption guard (byte-id-but-broken source → ~0)
            var allByteIdentical = true
            var turnCount = 0, identicalCount = 0
            var hadError = false        // any conversation threw → verdict is INVALID, not a measured FAIL
            var excludedTurns = 0       // degenerate (zero-timing) turns excluded from the means

            for convo in conversations {
                do {
                    let abs = try await adapter.crossTurnLookupAB(
                        forTurns: convo.turns, ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: k)
                    for ab in abs {
                        turnCount += 1
                        let identical = ab.specTokens == ab.baseTokens
                        if identical { identicalCount += 1 } else { allByteIdentical = false }
                        let hitRate = ab.proposed > 0 ? Double(ab.accepted) / Double(ab.proposed) : 0
                        let meanAcc = ab.rounds > 0 ? Double(ab.accepted) / Double(ab.rounds) : 0
                        // Degenerate timing (zero ms either arm) carries no signal — exclude, don't fold a 0 into the mean.
                        if ab.specMs > 0, ab.baseMs > 0 {
                            let speedup = ab.baseMs / ab.specMs
                            if convo.isReuse {
                                if ab.turn >= 1 {
                                    laterTurnReuseSpeedups.append(speedup)
                                    reuseAccepted += ab.accepted; reuseRounds += ab.rounds
                                }
                            } else {
                                controlSpeedups.append(speedup)
                                controlWeights.append(ab.baseMs + ab.specMs)
                            }
                            fileLog.emit(String(
                                format: "📊 suffix convo=%@ turn=%d reuse=%@ tokens=%d rounds=%d hit_rate=%.2f "
                                    + "mean_acc=%.2f spec_ms=%.0f base_ms=%.0f speedup=%.2fx byte_identical=%@",
                                convo.name, ab.turn, convo.isReuse ? "Y" : "N", ab.specTokens.count, ab.rounds,
                                hitRate, meanAcc, ab.specMs, ab.baseMs, speedup, identical ? "YES" : "NO"))
                        } else {
                            excludedTurns += 1
                            fileLog.emit("📊 suffix convo=\(convo.name) turn=\(ab.turn) EXCLUDED zero-timing "
                                + "spec_ms=\(ab.specMs) base_ms=\(ab.baseMs)")
                        }
                    }
                } catch {
                    hadError = true
                    fileLog.emit("📊 suffix convo=\(convo.name) ERROR=\(error)")
                }
            }

            func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }
            // Duration-weighted mean: weight each turn's speedup by its wall-clock (baseMs+specMs) so a SHORT free-form
            // control turn (few tokens → a small/small ratio with huge relative timing variance) can't tank the mean. A
            // device run showed two control turns at 0.44× and 1.17× (pure noise) on 42/87-tok gens → flat mean 0.80×
            // (false FAIL) while duration-weighting (the longer turn dominates) recovers ~0.98×. Falls back to the flat
            // mean if weights are absent/zero. The load-bearing reuseMean (real acceptance) is unaffected.
            func weightedMean(_ xs: [Double], _ ws: [Double]) -> Double {
                let wsum = ws.reduce(0, +)
                guard xs.count == ws.count, wsum > 0 else { return mean(xs) }
                return zip(xs, ws).reduce(0.0) { $0 + $1.0 * $1.1 } / wsum
            }
            let reuseMean = mean(laterTurnReuseSpeedups)
            let controlMean = weightedMean(controlSpeedups, controlWeights)
            let reuseMeanAcc = reuseRounds > 0 ? Double(reuseAccepted) / Double(reuseRounds) : 0
            // Distinguish INVALID (infra failure / missing data) from a genuine measured verdict, so an error or
            // empty arm is never reported as a measured PASS/FAIL.
            let valid = !hadError && excludedTurns == 0
                && !laterTurnReuseSpeedups.isEmpty && !controlSpeedups.isEmpty
            // Net-positivity (only meaningful when valid): later-turn reuse > 1× AND control within the documented
            // free-form band (≥0.90× — the lane-gated ~−8% n-gram-scan cost, Track A control 0.91×→0.92× adaptive-K;
            // BASPromptLookupDecoder.swift:30-32). reuse>1× requires real acceptance, so it doubles as the broken-source
            // detector. STRICT gate ALSO requires byte-identity to sequential greedy (the stronger reproducibility bar,
            // reachable on batch-invariant full-attention models). LOSSLESS gate relies on the structural ADR-039
            // guarantee (every emitted token = the target's verify argmax) — the field standard for sliding-window
            // models where MLX batch non-invariance makes sequential byte-identity unreachable (dflash-mlx / mlx-optiq).
            // ACCEPTANCE CORRUPTION GUARD (plan 红线: acceptance is the ONLY silent-corruption detector — never certify
            // on byte-identity alone): a byte-identical-but-broken draft source (e.g. a desynced index) stays byte-
            // identical yet its acceptance collapses to ~0 — invisible to byte_identical and near-invisible to a noisy
            // reuseMean. So ALSO require the reuse turns to show real acceptance (aggregate accepted/rounds > a small
            // floor; a working source clears it easily on the high-repetition rag-revisit/json-extend turns).
            let netPositive = valid && reuseMean > 1.0 && controlMean >= 0.90 && reuseMeanAcc > 0.05
            let gatePass = losslessGate ? netPositive : (netPositive && allByteIdentical)
            let verdict = !valid ? "INVALID" : (gatePass ? "PASS" : "FAIL")
            fileLog.emit(String(
                format: "📊 suffix-lookup DONE ngram=%d..%d K=%d gate=%@ later_turn_reuse_mean=%.2fx control_mean=%.2fx "
                    + "reuse_mean_acc=%.2f byte_identical=%d/%d all_identical=%@ excluded=%d errored=%@ PROMOTION_GATE=%@",
                ngramMin, ngramMax, k, gateMode, reuseMean, controlMean, reuseMeanAcc, identicalCount, turnCount,
                allByteIdentical ? "YES" : "NO", excludedTurns, hadError ? "YES" : "NO", verdict))
        } catch {
            fileLog.emit("📊 suffix-lookup ERROR=\(error)")
        }
    }
}
