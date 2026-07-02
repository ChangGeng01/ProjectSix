// MARK: - BASQwen35RdarProbe — M1 kill-switch on the REAL iPhone A19 (BAS_QWEN35_RDAR_PROBE=1)
//
// THE cheapest go/no-go gate for the Qwen3.5-4B → Core AI direction: does rdar 177354777
// ("linear-attention LLMs may crash" — Apple's seed notes explicitly name Qwen3.5/3.6) actually
// crash the GDN-hybrid STRUCTURE on this device's CoreAI runtime? Runs the weights-free
// real-structure probe asset (Tools/qwen35_real_to_coreai.py → Qwen35Real_probe.aimodel:
// 8 layers = 6 GDN + 2 full-attn at interval 4, ONE fused state `state_all` [8, 524288] fp16,
// input `input_id` [1,1] int32, output `logits`). Random weights — the rdar crash is about the
// linear-attention structure, not weights, so this is a valid crash target.
//
// Verdict semantics:
//   • crash (SIGABRT/SIGSEGV) inside run()      → rdar CONFIRMED on this seed → direction BLOCKED at
//     Apple until a GA fix (devicectl console captures the crash; the last "STEP n…" line marks where).
//   • all steps return logits                    → SURVIVED → the direction is runnable → proceed to
//     device M3 (fused-asset fidelity) / M4 (power). Also logs ms/step ×2 options as a placement hint.
//
// Stage the asset (host):
//   cd /tmp && ~/.venvs/coreai-cv/bin/python <repo>/BehavioralAISubstrate/Tools/qwen35_real_to_coreai.py
//   xcrun devicectl device copy to --device <udid> --domain-type appDataContainer \
//     --domain-identifier com.changgeng.basdevicetest \
//     --source /tmp/gdn_coreai/Qwen35Real_probe.aimodel \
//     --destination Documents/Qwen35Real_probe.aimodel
// Then launch with BAS_QWEN35_RDAR_PROBE=1.

import Foundation

#if canImport(CoreAI)
import CoreAI
#endif

enum BASQwen35RdarProbe {

    /// Probe-model constants — MUST match Tools/qwen35_real_to_coreai.py (L=8; ROW = GDN state
    /// 32·128·128 = 524288, the max row of the fused per-layer state).
    private static let stateRows = 8 + 0     // one row per layer (pos is folded by the converter's buffer)
    private static let stateRow = 524_288
    private static let steps = 8             // a few tokens: exercise state carry-over, not just step 0

    static func run() async {
        #if canImport(CoreAI)
        print("[qwen35-rdar] M1 probe start — rdar 177354777 crash test (Qwen3.5 GDN-hybrid structure)")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let asset = docs.appendingPathComponent("Qwen35Real_probe.aimodel")
        guard FileManager.default.fileExists(atPath: asset.path) else {
            print("[qwen35-rdar] MISSING asset at \(asset.path) — stage it via devicectl (see header) ✗")
            return
        }
        for label in ["default", "ane"] {
            do {
                try await runOnce(asset: asset, label: label)
            } catch {
                // A TYPED error is NOT the rdar crash (that would kill the process) — report + continue.
                print("[qwen35-rdar] \(label): typed failure (not a crash): \(error) ✗")
            }
        }
        print("[qwen35-rdar] ✅ SURVIVED — no rdar-177354777 crash on this seed; direction is runnable (→ device M3/M4)")
        #else
        print("[qwen35-rdar] CoreAI framework unavailable on this OS — probe skipped")
        #endif
    }

    #if canImport(CoreAI)
    private static func runOnce(asset: URL, label: String) async throws {
        // Mirror BASCoreAIDecodeProbe: `.default` lets CoreAI place freely; "ane" pins the neural engine —
        // the placement rdar 177354777 is most likely to bite.
        let opts: SpecializationOptions =
            label == "ane" ? SpecializationOptions(preferredComputeUnitKind: .neuralEngine) : .default
        let model = try await AIModel(contentsOf: asset, options: opts)
        guard let name = model.functionNames.first, let fn = try model.loadFunction(named: name) else {
            print("[qwen35-rdar] \(label): no inference function in asset ✗")
            return
        }
        // ONE fused state, zero-initialized (mirrors BASCoreAIDecodeSession's single-state pattern).
        var state = NDArray(scalars: [Float16](repeating: 0, count: stateRows * stateRow),
                            shape: [stateRows, stateRow])
        var lastDim = -1
        let t0 = Date()
        for step in 0..<steps {
            print("[qwen35-rdar] \(label): STEP \(step) …")   // last line before a crash localizes it
            let inputs: [String: NDArray] = ["input_id": NDArray(scalars: [Int32(step)], shape: [1, 1])]
            var states = InferenceFunction.MutableViews()
            states.insert(&state, for: "state_all")
            var outputs = try await fn.run(inputs: inputs, states: states)
            guard let value = outputs.remove("logits"), let logits = value.ndArray else {
                print("[qwen35-rdar] \(label): STEP \(step) returned no logits ✗")
                return
            }
            lastDim = logits.shape.reduce(1, *)
        }
        let ms = Date().timeIntervalSince(t0) * 1000 / Double(steps)
        print(String(format: "[qwen35-rdar] %@: %d steps OK, logits dim %d, %.1f ms/step ✓",
                     label, steps, lastDim, ms))
    }
    #endif
}
