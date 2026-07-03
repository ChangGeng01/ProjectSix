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

    static func run() async {
        print("[qwen35-mtp] G3 start — MTP spec vs plain, Qwen3.5-4B-4bit, bracketed protocol")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            print("[qwen35-mtp] MISSING qwen35_mtp_folded.safetensors — stage per header ✗"); return
        }
        do {
            // Local staged dir preferred (the ship form); HF-cache id as fallback (M4-arm precedent).
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

            let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
            let n = 64
            func runArm(_ name: String, spec: Bool) async throws -> Arm {
                try await container.perform { ctx -> Arm in
                    guard let model = ctx.model as? Qwen35Model else {
                        throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                    }
                    let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
                    _ = spec ? dec.generateSpec(prompt: prompt, maxTokens: 8)
                             : dec.generatePlain(prompt: prompt, maxTokens: 8)      // warmup (JIT both paths)
                    let r = spec ? dec.generateSpec(prompt: prompt, maxTokens: n)
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
            let identical = spec.tokens == pre.tokens
            print(String(format: "[qwen35-mtp] VERDICT: plain-mean %.1f tok/s (drift band ±%.0f%%) | spec %.1f tok/s = %.2fx | a=%.2f | identity %@",
                         plainMean, band * 100, spec.tokPerSec, ratio, a, identical ? "OK" : "✗"))
            let pass = spec.tokPerSec >= 20 && ratio > 1 + band && identical && a > 0.3
            print("[qwen35-mtp] " + (pass
                ? "✅ G3 PASS — Qwen3.5-4B ≥20 tok/s on device with the MTP lane"
                : "⚠️ G3 NOT MET — see arms above (target 20; win must exceed the drift band; identity+a required)"))
        } catch {
            print("[qwen35-mtp] FAILED: \(error) ✗")
        }
    }
}
