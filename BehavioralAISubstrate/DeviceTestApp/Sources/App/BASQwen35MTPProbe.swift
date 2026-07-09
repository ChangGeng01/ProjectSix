// MARK: - BASQwen35MTPProbe — G3: the ≥20 tok/s verdict on the iPhone (BAS_QWEN35_MTP_PROBE=1)
//
// Device A/B for the MTP speculative lane (BASQwen35MTPSpecDecoder) vs plain greedy on the MAIN model
// (Qwen3.5-4B-4bit). Protocol inherits the mined decode wisdom (Docs/MTP_LANDING_CHECKLIST.md):
//   • warmup both paths (JIT), then BRACKET: plain-pre → spec → plain-post, ≥20 s cooldown between arms
//     (thermal drift ±44-78% has invalidated unbracketed sweeps before — the win only counts beyond the band).
//   • decode-only timing, N tokens/arm, greedy-identity asserted (spec stream == plain stream), acceptance `a`
//     reported alongside (byte-identity alone can mask a broken drafter: identical bytes + a→0).
//   • thermal state + phys_footprint logged per arm (jetsam line ~3248 MB).
// Stage first (host):
//   xcrun devicectl device copy to --device <udid> --domain-type appDataContainer \
//     --domain-identifier com.changgeng.basdevicetest \
//     --source /tmp/gdn_coreai/qwen35_mtp_folded.safetensors --destination Documents/qwen35_mtp_folded.safetensors
// VERDICT: PASS = spec tok/s ≥ 20 AND spec > plain-mean beyond the drift band AND identity AND a > 0.3.

import Foundation
import MLX
import MLXHuggingFace
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
import BASMLXAdapter
import BASOrgan

enum BASQwen35MTPProbe {

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    private static func thermal() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"; case .fair: return "fair"
        case .serious: return "serious"; case .critical: return "critical"
        @unknown default: return "?" }
    }

    struct Arm: Sendable {
        let name: String
        let tokens: [Int]
        let seconds: Double
        let accepted: Int
        let iterations: Int
        var tokPerSec: Double { Double(tokens.count) / max(seconds, 0.001) }
    }

    /// SUSTAINED smoke (BAS_MTP_SUSTAIN_MIN=10): repeated spec generations (96 tok each, fresh state — the
    /// production turn shape, also inside the maxSeq cap) for N minutes; per-gen tok/s + thermal + footprint;
    /// verdict = mean over the window + first-vs-last-quartile degradation (thermal drift is the known enemy:
    /// past sustained runs drifted +44-78%).
    static func runSustained(minutes: Double, container: ModelContainer, wURL: URL) async throws {
        let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
        let deadline = Date().addingTimeInterval(minutes * 60)
        var rates: [Double] = []
        var accs: [Double] = []
        var gen = 0
        while Date() < deadline {
            let r: (Double, Double) = try await container.perform { ctx in
                guard let model = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
                let kEnvS = Int(ProcessInfo.processInfo.environment["BAS_MTP_K"] ?? "") ?? 1
                let kFusedS = Int(ProcessInfo.processInfo.environment["BAS_MTP_FUSED_K"] ?? "") ?? 0
                let tCapS = Int(ProcessInfo.processInfo.environment["BAS_MTP_TCAP"] ?? "") ?? 5
                // PRODUCTION MIRROR: adaptive K + thermal tier (nominal EMA{1-3} / fair K=1), as shipped.
                let run = kFusedS >= 1 ? dec.generateSpecKFused(prompt: prompt, maxTokens: 96, k: kFusedS,
                                                                tCap: tCapS, adaptiveK: true)
                    : kEnvS > 1 ? dec.generateSpecK(prompt: prompt, maxTokens: 96, k: kEnvS)
                                : dec.generateSpec(prompt: prompt, maxTokens: 96)
                let a = run.iterations > 0 ? Double(run.accepted) / Double(run.iterations) : 0
                return (Double(run.tokens.count) / max(run.decodeSeconds, 0.001), a)
            }
            gen += 1
            rates.append(r.0); accs.append(r.1)
            print(String(format: "[qwen35-sustain] gen %02d: %.1f tok/s a=%.2f thermal=%@ footprint=%dMB",
                         gen, r.0, r.1, thermal(), Int(footprintMB())))
        }
        guard rates.count >= 4 else { print("[qwen35-sustain] too few gens ✗"); return }
        let mean = rates.reduce(0, +) / Double(rates.count)
        let q = rates.count / 4
        let first = rates.prefix(q).reduce(0, +) / Double(q)
        let last = rates.suffix(q).reduce(0, +) / Double(q)
        let minR = rates.min() ?? 0
        let aMean = accs.reduce(0, +) / Double(accs.count)
        print(String(format: "[qwen35-sustain] SUMMARY: %d gens | mean %.1f | min %.1f | firstQ %.1f → lastQ %.1f (%+.0f%%) | a-mean %.2f | thermal-end %@",
                     rates.count, mean, minR, first, last, (last - first) / first * 100, aMean, thermal()))
        print("[qwen35-sustain] " + (mean >= 30 && last >= 28
            ? "✅ SUSTAINED ≥30 (mean) with lastQ ≥28"
            : mean >= 25 ? "✅ sustained ≥25 — thermal tax visible, cold 30 confirmed separately"
                         : "⚠️ sustained degradation below 25 — thermal wall"))
    }

    /// SHIP-CERT endurance (BAS_MTP_CERT=1): 50 diverse tokenized prompts × (plain 48 + spec 48), turn-paced
    /// (2s gaps = realistic cooling windows), per-prompt lossless telemetry + timing + thermal; aggregate verdict
    /// per the greedy-spec cert precedent (single-device run — the 2-device requirement is noted as open).
    static func runCert(container: ModelContainer, wURL: URL) async throws {
        let topics = ["the ocean", "photosynthesis", "a small village", "gravity", "friendship", "volcanoes",
                      "chess", "the moon", "bread baking", "electricity", "a rainy day", "whales", "honesty",
                      "deserts", "music theory", "bicycles", "the seasons", "memory", "rivers", "telescopes",
                      "courage", "spiders", "clocks", "islands", "language", "maps", "gardens", "thunder",
                      "libraries", "glaciers", "patience", "bridges", "the stars", "salt", "forests", "trains",
                      "kindness", "caves", "lighthouses", "clouds", "iron", "bees", "harbors", "mirrors",
                      "wind", "paper", "mountains", "lanterns", "tides", "roots"]
        var ratios: [Double] = []
        var specRates: [Double] = []
        var accs: [Double] = []
        var divergences = 0
        var failures = 0
        var gated = 0
        // ONE decoder for the whole cert (production mirror: MTPDecoderBox caches it across turns; the
        // adaptive-K EMA persists). The old per-prompt re-init also re-quantized ~300MB × 50 — pure heat:
        // take-2's 43/50 thermal-gated turns were substantially self-inflicted.
        // @unchecked box (the production MTPDecoderBox pattern): the decoder crosses the actor boundary
        // ONLY as an opaque handle — every USE stays inside container.perform (single-actor execution).
        struct CertBox: @unchecked Sendable { let dec: BASQwen35MTPSpecDecoder }
        let certBox: CertBox? = try? await container.perform { ctx in
            guard let model = ctx.model as? Qwen35Model else { throw BASQwen35MTPSpecDecoder.SpecError.notQwen35 }
            return CertBox(dec: try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL))
        }
        guard let certBox else { print("[qwen35-cert] decoder init failed ✗"); return }
        // Warm BOTH decode paths before turn 1 (Metal JIT) — take-4's turn-1 spec read 0.97× purely from
        // first-use kernel compilation (the bracket mode always warmed; the cert didn't).
        _ = try? await container.perform { [certBox] _ in
            _ = certBox.dec.generatePlain(prompt: [100, 200, 300], maxTokens: 8)
            _ = certBox.dec.generateSpecKFused(prompt: [100, 200, 300], maxTokens: 8, k: 3, tCap: 5, adaptiveK: true)
            return 0
        }
        for (i, t) in topics.enumerated() {
            do {
                // LIVE thermal gate (the planner's production posture): spec only when not throttled.
                let throttled = ProcessInfo.processInfo.thermalState == .serious
                    || ProcessInfo.processInfo.thermalState == .critical
                let r: (Double, Double, Double, Bool) = try await container.perform { [certBox] ctx in
                    let dec = certBox.dec
                    let ids = ctx.tokenizer.encode(text: "Write two sentences about \(t).")
                    let plain = dec.generatePlain(prompt: ids, maxTokens: 48)
                    if throttled {
                        let pT = Double(plain.tokens.count) / max(plain.decodeSeconds, 0.001)
                        return (pT, pT, -1, true)                        // gated: spec==plain by construction
                    }
                    // PRODUCTION MIRROR: the adapter's .mtpSpec lane = fused ADAPTIVE-K ≤3 / tCap5.
                    let spec = dec.generateSpecKFused(prompt: ids, maxTokens: 48, k: 3, tCap: 5, adaptiveK: true)
                    let a = spec.iterations > 0 ? Double(spec.accepted) / Double(spec.iterations) : 0
                    let pT = Double(plain.tokens.count) / max(plain.decodeSeconds, 0.001)
                    let sT = Double(spec.tokens.count) / max(spec.decodeSeconds, 0.001)
                    return (pT, sT, a, spec.tokens == plain.tokens)
                }
                if r.2 < 0 {
                    gated += 1
                    print(String(format: "[qwen35-cert] %02d/50 %@: plain %.1f [thermal-GATED → plain] thermal=%@",
                                 i + 1, t, r.0, thermal()))
                } else {
                    ratios.append(r.1 / r.0); specRates.append(r.1); accs.append(r.2)
                    if !r.3 { divergences += 1 }
                    print(String(format: "[qwen35-cert] %02d/50 %@: plain %.1f | spec %.1f (%.2fx) a=%.2f%@ thermal=%@",
                                 i + 1, t, r.0, r.1, r.1 / r.0, r.2, r.3 ? "" : " [tie-div]", thermal()))
                }
            } catch {
                failures += 1
                print("[qwen35-cert] \(i + 1)/50 \(t): FAILED \(error)")
            }
            // Sync spin, NOT Task.sleep — devicectl-launched runs freeze at idle awaits (2026-07-03 gotcha);
            // 2s of one e-core keeps the turn pacing without the suspension point.
            let gapEnd = Date().addingTimeInterval(2)
            var spinX = 1.0
            while Date() < gapEnd { spinX = sin(spinX) + 1.000001 }
            if spinX == .infinity { print("") }
        }
        guard !specRates.isEmpty else { print("[qwen35-cert] no data ✗"); return }
        let mR = ratios.reduce(0, +) / Double(ratios.count)
        let mS = specRates.reduce(0, +) / Double(specRates.count)
        let mA = accs.reduce(0, +) / Double(accs.count)
        let minS = specRates.min() ?? 0
        print(String(format: "[qwen35-cert] SUMMARY: engaged=%d gated=%d fail=%d | engaged spec mean %.1f min %.1f tok/s | ratio mean %.2fx | a mean %.2f | tie-div %d/%d | thermal-end %@",
                     specRates.count, gated, failures, mS, minS, mR, mA, divergences, specRates.count, thermal()))
        // Gates for the ADAPTIVE lane: the RATIO is the certification (≥1.15, matching the K=1 cert bar
        // within noise); `a` reverts to collapse detection (prose regime folds a/iter ∈ [0.4, 1.0]).
        let pass = failures == 0 && mR >= 1.15 && mA >= 0.4 && mS >= 22
        print("[qwen35-cert] " + (pass
            ? "✅ ENDURANCE CERT PASS (single-device; 2nd-device leg OPEN)"
            : "⚠️ CERT NOT MET — see summary"))
    }

    /// DEFAULT-ON on-device verification (BAS_MTP_DEFAULTON=1): behavioral triple —
    /// A) ZERO-CONFIG adapter: draft() (which THREW nonTrimmableCache on Qwen3.5 before the lane) must now
    ///    succeed via .mtpSpec, faster than the streaming baseline;
    /// B) kill-switch adapter: the same draft() must revert to the legacy throw (proving A's success came from
    ///    the MTP lane, not some other change);
    /// C) streamDraft baseline for the ratio.
    static func runDefaultOnVerify() async throws {
        print("[mtp-defaulton] A) zero-config adapter (no URL, no flags)")
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        print("[mtp-defaulton] resolved weights: \(organ.mtpResolvedWeightsURL()?.lastPathComponent ?? "NIL ✗")")
        // GREEDY preset (temp 0) — the lane's doctrine scope: byte-safe speculation only for already-greedy
        // requests (same boundary as the certified 1.46× greedy draft lane; .core@0.7 correctly stays plain).
        let req = BASOrganRequest(requestID: "don", role: .core, preset: .greedyDeterministic,
                                  instruction: "Reply with one short sentence about lighthouses.", context: [])
        var t0 = Date()
        var plainBody = ""
        for try await c in organ.streamDraft(req) { plainBody = c.cumulativeBody }
        let plainSec = Date().timeIntervalSince(t0)
        print(String(format: "[mtp-defaulton] C) streaming baseline: %.1fs (%d chars)", plainSec, plainBody.count))
        t0 = Date()
        do {
            let d = try await organ.draft(req)
            let specSec = Date().timeIntervalSince(t0)
            print(String(format: "[mtp-defaulton] A) draft() via .mtpSpec: %.1fs (%d chars) = %.2fx vs streaming ✓",
                         specSec, d.body.count, plainSec / specSec))
        } catch {
            print("[mtp-defaulton] A) draft() FAILED: \(error) ✗ (default-ON not effective)")
            return
        }
        // B) kill-switch: verify at the RESOLUTION level WITHOUT loading a second 2.3GB model copy (two
        // containers = ~4.6GB > jetsam line — the first version of this arm got the app killed). The
        // nil-resolution → capabilities-false → planner-plain chain is pinned by the Mac unit tests.
        let legacy = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit, mtpSpecEnabled: false)
        let off = legacy.mtpResolvedWeightsURL() == nil
        print("[mtp-defaulton] B) kill-switch resolution nil: \(off ? "✓ (lane never offered)" : "✗ UNEXPECTED")")
        print("[mtp-defaulton] " + (off ? "✅ DEFAULT-ON VERIFIED ON DEVICE" : "⚠️ kill-switch broken"))
    }

    /// SPEC-SAMPLING device A/B at the PRODUCTION preset (.core, temp 0.7): per-token rates over 3 prompts
    /// (sampling is stochastic → compare tok/s, not total seconds). Distribution-losslessness is unit-proven
    /// (TV<0.007); this verifies device ENGAGEMENT + SPEED + acceptance at real presets.
    static func runSamplingVerify() async throws {
        print("[mtp-sampling] step1: adapter init")
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)   // default-ON
        print("[mtp-sampling] step2: loadModel…")
        try await organ.loadModel()
        print("[mtp-sampling] step3: loaded, footprint=\(Int(footprintMB()))MB")
        // Fairness (first-run lesson): cap BOTH arms at 256 tokens — uncapped, stochastic lengths diverged
        // 354 vs 1024 tok, confounding tok/s with KV-growth + thermal drift. Cooldowns between arms/topics
        // (bracket-protocol discipline); thermal printed per ARM, not per topic.
        //
        // MIXED-REGIME final verification (post 0.60 break-even floor): 2 short-prose topics (device a≈0.34-0.47
        // sub-break-even → the floor should GATE turns 2+ to plain — which exercises the `_chatSessionPlainDraft`
        // fallback, the exact path that crashed pre-fix) then 2 essay topics (length-matched a=0.62-0.68 → 1.05×;
        // if reached while gated they demonstrate STICKINESS: a frozen + ratio≈1.0 + no crash).
        // Read per-topic `a=`: rising ⇒ sampling engaged; frozen ⇒ gated (plain fallback ran).
        let topics = [("lighthouses", false), ("glaciers", false), ("market squares", true), ("mountain passes", true)]
        var plainRates: [Double] = []
        var specRates: [Double] = []
        for (t, essay) in topics {
            let req = BASOrganRequest(requestID: "s-\(t)", role: .core, preset: .core,
                                      instruction: essay ? "Write a detailed 500-word essay about \(t)."
                                                         : "Describe \(t) in two sentences.", context: [],
                                      maxOutputTokens: 256)
            print("[mtp-sampling] step4: streamDraft \(t)… thermal=\(thermal())")
            var t0 = Date()
            var plainBody = ""
            for try await c in organ.streamDraft(req) { plainBody = c.cumulativeBody }
            let pSec = Date().timeIntervalSince(t0)
            let pTok = await organ.tokenCount(of: plainBody)
            await idleGuardedSleep(seconds: 30)   // audit M-i MED-2: lock-screen freeze guard (BAS_COOLDOWN_SPIN=1)
            print("[mtp-sampling] step5: draft() \(t)… thermal=\(thermal())")
            t0 = Date()
            let d = try await organ.draft(req)                                 // planner → .mtpSpecSampling
            let sSec = Date().timeIntervalSince(t0)
            let sTok = await organ.tokenCount(of: d.body)
            let pR = Double(pTok) / max(pSec, 0.001), sR = Double(sTok) / max(sSec, 0.001)
            plainRates.append(pR); specRates.append(sR)
            let a = await organ.mtpSamplingProfilerStat().map { String(format: "%.2f", $0.emaHitRate) } ?? "n/a"
            print(String(format: "[mtp-sampling] %@: plain %.1f tok/s (%d tok) | spec-sampling %.1f tok/s (%d tok) = %.2fx a=%@ thermal=%@",
                         t, pR, pTok, sR, sTok, sR / pR, a, thermal()))
            await idleGuardedSleep(seconds: 30)   // audit M-i MED-2: lock-screen freeze guard (BAS_COOLDOWN_SPIN=1)
        }
        let n = Double(plainRates.count)
        let mP = plainRates.reduce(0, +) / n, mS = specRates.reduce(0, +) / n
        print(String(format: "[mtp-sampling] SUMMARY: plain %.1f | spec-sampling %.1f tok/s = %.2fx @ core(0.7)", mP, mS, mS / mP))
        print("[mtp-sampling] " + (mS / mP >= 1.15
            ? "✅ SAMPLING LANE WINS at the production preset"
            : mS / mP >= 0.95 ? "≈ parity — engagement verified, speed marginal" : "⚠️ net loss at 0.7 — gate it"))
    }

    /// Bump on every deployed change — printed at start so a stale binary (the take-3 VOID incident:
    /// BUILD FAILED + old app relaunched) is visible in the FIRST log line.
    static let buildTag = "2026-07-04a-unified-mtp"

    /// Sleep-mechanism forensics (BAS_MTP_SLEEPTEST=1): the Task.sleep freeze gotcha — which async wait
    /// primitives actually resume in a devicectl-launched app? Each gets 3s; a mechanism that hasn't
    /// reported within 12s is FROZEN (the watchdog prints survivors; run with --console).
    static func runSleepTest() async {
        print("[sleeptest] start thermal=\(thermal())")
        let t0 = Date()
        func stamp(_ name: String) { print(String(format: "[sleeptest] %@ RESUMED at +%.1fs", name, Date().timeIntervalSince(t0))); fflush(stdout) }
        Task.detached {                                   // watchdog: pure spin, no async wait
            var x = 1.0
            while Date().timeIntervalSince(t0) < 12 { x = sin(x) + 1.000001 }
            print("[sleeptest] watchdog: 12s elapsed (spin) — anything unreported above is FROZEN x=\(x > 0)")
            fflush(stdout)
        }
        Task.detached { try? await Task.sleep(nanoseconds: 3_000_000_000); stamp("Task.sleep") }
        Task.detached {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { c.resume() }
            }
            stamp("GCD.asyncAfter")
        }
        Task.detached {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().async { Thread.sleep(forTimeInterval: 3); c.resume() }
            }
            stamp("Thread.sleep(GCD)")
        }
        // give everything 15s of wall clock (spin — this function must not itself rely on a sleep)
        var y = 1.0
        while Date().timeIntervalSince(t0) < 15 { y = sin(y) + 1.000001 }
        print("[sleeptest] done y=\(y > 0)")
    }

    static func run() async {
        setvbuf(stdout, nil, _IOLBF, 0)      // line-buffer: devicectl console pipes are block-buffered —
                                             // mid-run prints were invisible during hang forensics
        print("[qwen35-mtp] G3 start — MTP spec vs plain, Qwen3.5-4B-4bit, bracketed protocol [\(buildTag)]")
        if ProcessInfo.processInfo.environment["BAS_MTP_SLEEPTEST"] == "1" {
            await runSleepTest()
            return
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            print("[qwen35-mtp] MISSING qwen35_mtp_folded.safetensors — stage per header ✗"); return
        }
        do {
            if ProcessInfo.processInfo.environment["BAS_MTP_SAMPLEON"] == "1" {
                try await runSamplingVerify()               // has its own adapter/container — no probe container
                return
            }
            // Local staged dir preferred (the ship form); HF-cache id as fallback (M4-arm precedent).
            // (sustained-mode dispatch happens after load below)
            let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
            let configuration: ModelConfiguration
            if FileManager.default.fileExists(atPath: localDir.path) {
                configuration = ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"])
            } else {
                configuration = ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: ["<|im_end|>"])
            }
            let t0 = Date()
            let container = try await #huggingFaceLoadModelContainer(
                configuration: configuration, progressHandler: { _ in })
            print("[qwen35-mtp] model loaded in \(Int(Date().timeIntervalSince(t0)))s footprint=\(Int(footprintMB()))MB")
            if let m = Double(ProcessInfo.processInfo.environment["BAS_MTP_SUSTAIN_MIN"] ?? "") {
                try await runSustained(minutes: m, container: container, wURL: wURL)
                return
            }
            if ProcessInfo.processInfo.environment["BAS_MTP_DEFAULTON"] == "1" {
                try await runDefaultOnVerify()
                return
            }
            if ProcessInfo.processInfo.environment["BAS_MTP_CERT"] == "1" {
                try await runCert(container: container, wURL: wURL)
                return
            }

            let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
            let n = 64
            func runArm(_ name: String, spec: Bool) async throws -> Arm {
                try await container.perform { ctx -> Arm in
                    guard let model = ctx.model as? Qwen35Model else {
                        throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                    }
                    let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
                    let kEnv = Int(ProcessInfo.processInfo.environment["BAS_MTP_K"] ?? "") ?? 1
                    let kFused = Int(ProcessInfo.processInfo.environment["BAS_MTP_FUSED_K"] ?? "") ?? 0
                    let fp16S = ProcessInfo.processInfo.environment["BAS_MTP_FUSED_FP16"] == "1"
                    let tCap = Int(ProcessInfo.processInfo.environment["BAS_MTP_TCAP"] ?? "") ?? 5
                    func specRun(_ m: Int) -> BASQwen35MTPSpecDecoder.Run {
                        kFused >= 1 ? dec.generateSpecKFused(prompt: prompt, maxTokens: m, k: kFused,
                                                             fp32Scores: !fp16S, tCap: tCap)
                            : kEnv > 1 ? dec.generateSpecK(prompt: prompt, maxTokens: m, k: kEnv)
                                       : dec.generateSpec(prompt: prompt, maxTokens: m)
                    }
                    _ = spec ? specRun(8)
                             : dec.generatePlain(prompt: prompt, maxTokens: 8)      // warmup (JIT both paths)
                    let r = spec ? specRun(n)
                                 : dec.generatePlain(prompt: prompt, maxTokens: n)
                    return Arm(name: name, tokens: r.tokens, seconds: r.decodeSeconds,
                               accepted: r.accepted, iterations: r.iterations)
                }
            }
            func report(_ a: Arm) {
                let acc = a.iterations > 0 && a.accepted > 0
                    ? String(format: " a=%.2f", Double(a.accepted) / Double(a.iterations)) : ""
                print(String(format: "[qwen35-mtp] %@: %.1f tok/s (%d tok in %.1fs)%@ thermal=%@ footprint=%dMB",
                             a.name, a.tokPerSec, a.tokens.count, a.seconds, acc, thermal(), Int(footprintMB())))
            }
            func cooldown() async {
                if ProcessInfo.processInfo.environment["BAS_MTP_NOCOOL"] == "1" {
                    print("[qwen35-mtp] cooldown SKIPPED (BAS_MTP_NOCOOL) thermal=\(thermal())")
                    return
                }
                print("[qwen35-mtp] cooldown 20s … thermal=\(thermal())")
                // LOCKED-PHONE suspension guard (forensics 2026-07-03): a devicectl-launched app whose
                // screen locks gets suspended at its first fully-idle await — three K-sweeps froze at THIS
                // sleep while every GPU-busy phase ran full speed. A live utility-QoS spinner keeps one
                // e-core runnable so the process never goes idle and the sleep's timer actually fires;
                // the GPU (the thing the cooldown exists to cool) still rests.
                let spinner = Task.detached(priority: .utility) {
                    var x = 1.0
                    while !Task.isCancelled { x = sin(x) + 1.000001 }
                    if x == .infinity { print("") }        // unreachable; defeats spin elision
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                spinner.cancel()
            }

            let pre = try await runArm("plain-pre", spec: false); report(pre)
            await cooldown()
            let spec = try await runArm("spec", spec: true); report(spec)
            await cooldown()
            let post = try await runArm("plain-post", spec: false); report(post)

            // ---- verdict (checklist gate) ----
            let plainMean = (pre.tokPerSec + post.tokPerSec) / 2
            let band = abs(pre.tokPerSec - post.tokPerSec) / plainMean
            let ratio = spec.tokPerSec / plainMean
            let a = spec.iterations > 0 ? Double(spec.accepted) / Double(spec.iterations) : 0
            var firstDiv = -1
            for i in 0 ..< min(spec.tokens.count, pre.tokens.count) where spec.tokens[i] != pre.tokens[i] {
                firstDiv = i; break
            }
            print(String(format: "[qwen35-mtp] VERDICT: plain-mean %.1f tok/s (drift band ±%.0f%%) | spec %.1f tok/s = %.2fx | a=%.2f | serial-div@%d (ADR-039 lossless)",
                         plainMean, band * 100, spec.tokPerSec, ratio, a, firstDiv))
            let pass20 = spec.tokPerSec >= 20 && ratio > 1 + band && a > 0.7
            let pass30 = spec.tokPerSec >= 30 && ratio > 1 + band && a > 0.7
            print("[qwen35-mtp] " + (pass30
                ? "✅✅ 30 tok/s TARGET MET"
                : pass20 ? "✅ ≥20 holds — 30 gap = \(String(format: "%.1f", 30 - spec.tokPerSec)) tok/s"
                         : "⚠️ below 20 — regression, investigate"))
        } catch {
            print("[qwen35-mtp] FAILED: \(error) ✗")
        }
    }
}
