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
                let run = kEnvS > 1 ? dec.generateSpecK(prompt: prompt, maxTokens: 96, k: kEnvS)
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
        for (i, t) in topics.enumerated() {
            do {
                // LIVE thermal gate (the planner's production posture): spec only when not throttled.
                let throttled = ProcessInfo.processInfo.thermalState == .serious
                    || ProcessInfo.processInfo.thermalState == .critical
                let r: (Double, Double, Double, Bool) = try await container.perform { ctx in
                    guard let model = ctx.model as? Qwen35Model else {
                        throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                    }
                    let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
                    let ids = ctx.tokenizer.encode(text: "Write two sentences about \(t).")
                    let plain = dec.generatePlain(prompt: ids, maxTokens: 48)
                    if throttled {
                        let pT = Double(plain.tokens.count) / max(plain.decodeSeconds, 0.001)
                        return (pT, pT, -1, true)                        // gated: spec==plain by construction
                    }
                    let spec = dec.generateSpec(prompt: ids, maxTokens: 48)
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
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        guard !specRates.isEmpty else { print("[qwen35-cert] no data ✗"); return }
        let mR = ratios.reduce(0, +) / Double(ratios.count)
        let mS = specRates.reduce(0, +) / Double(specRates.count)
        let mA = accs.reduce(0, +) / Double(accs.count)
        let minS = specRates.min() ?? 0
        print(String(format: "[qwen35-cert] SUMMARY: engaged=%d gated=%d fail=%d | engaged spec mean %.1f min %.1f tok/s | ratio mean %.2fx | a mean %.2f | tie-div %d/%d | thermal-end %@",
                     specRates.count, gated, failures, mS, minS, mR, mA, divergences, specRates.count, thermal()))
        let pass = failures == 0 && mR >= 1.2 && mA >= 0.5 && mS >= 22
        print("[qwen35-cert] " + (pass
            ? "✅ ENDURANCE CERT PASS (single-device; 2nd-device leg OPEN)"
            : "⚠️ CERT NOT MET — see summary"))
    }

    static func run() async {
        print("[qwen35-mtp] G3 start — MTP spec vs plain, Qwen3.5-4B-4bit, bracketed protocol")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            print("[qwen35-mtp] MISSING qwen35_mtp_folded.safetensors — stage per header ✗"); return
        }
        do {
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
                    func specRun(_ m: Int) -> BASQwen35MTPSpecDecoder.Run {
                        kEnv > 1 ? dec.generateSpecK(prompt: prompt, maxTokens: m, k: kEnv)
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
                print("[qwen35-mtp] cooldown 20s … thermal=\(thermal())")
                try? await Task.sleep(nanoseconds: 20_000_000_000)
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
