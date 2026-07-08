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
import UIKit
import BASMLXAdapter   // MLX GPU arm (M4)
import BASOrgan

#if canImport(CoreAI)
import CoreAI
#endif

enum BASQwen35RdarProbe {

    /// Probe-model constants — defaults match Tools/qwen35_real_to_coreai.py (L=8; ROW = GDN state
    /// 32·128·128 = 524288). Overridable via env so the SAME probe can run the 11MB toy-hybrid asset
    /// (BAS_RDAR_ASSET=Qwen35Hybrid_probe BAS_RDAR_STATE_ROW=16384) to split STRUCTURE-crash vs MEMORY-death.
    private static var assetName: String {
        ProcessInfo.processInfo.environment["BAS_RDAR_ASSET"] ?? "Qwen35Real_probe"
    }
    private static var stateRows: Int {
        Int(ProcessInfo.processInfo.environment["BAS_RDAR_STATE_ROWS"] ?? "") ?? 8
    }
    private static var stateRow: Int {
        Int(ProcessInfo.processInfo.environment["BAS_RDAR_STATE_ROW"] ?? "") ?? 524_288
    }
    private static let steps = 8             // a few tokens: exercise state carry-over, not just step 0
    /// Input contract override: unset = token model ("input_id" [1,1] int32). BAS_RDAR_INPUT_DIM=2560 = the
    /// real fused assets' hidden contract ("x" [1,dim] fp16) — enough for a load+step smoke (zeros in).
    private static var inputDim: Int? {
        Int(ProcessInfo.processInfo.environment["BAS_RDAR_INPUT_DIM"] ?? "")
    }

    static func run() async {
        #if canImport(CoreAI)
        guard #available(iOS 27, macOS 27, *) else {
            print("[qwen35-rdar] iOS 27 required for CoreAI — probe skipped")
            return
        }
        if let arm = ProcessInfo.processInfo.environment["BAS_RDAR_M4"] {
            await runM4(arm: arm)
            return
        }
        if ProcessInfo.processInfo.environment["BAS_RDAR_CHAIN"] == "1" {
            await runChainFidelity()
            return
        }
        print("[qwen35-rdar] M1 probe start — rdar 177354777 crash test (asset=\(assetName), state [\(stateRows), \(stateRow)])")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let asset = docs.appendingPathComponent("\(assetName).aimodel")
        guard FileManager.default.fileExists(atPath: asset.path) else {
            print("[qwen35-rdar] MISSING asset at \(asset.path) — stage it via devicectl (see header) ✗")
            return
        }
        var completed = 0
        for label in ["default", "ane"] {
            do {
                if try await runOnce(asset: asset, label: label) { completed += 1 }
            } catch {
                // A TYPED error is NOT the rdar crash (that would kill the process) — report + continue.
                print("[qwen35-rdar] \(label): typed failure (not a crash): \(error) ✗")
            }
        }
        // audit M-i/M1 — "no crash" alone is NOT "runnable". The green banner
        // used to fire even when BOTH placements failed (typed error / no
        // output): a loaded gun reporting a hit it never fired. Require ≥1
        // genuine completion before claiming the direction is demonstrated.
        if completed > 0 {
            print("[qwen35-rdar] ✅ SURVIVED — no rdar-177354777 crash AND \(completed)/2 placement(s) ran to completion; direction is runnable (→ device M3/M4)")
        } else {
            print("[qwen35-rdar] ⚠️ no rdar-177354777 crash, but EVERY placement failed (typed error / no output) — direction NOT demonstrated ✗")
        }
        #else
        print("[qwen35-rdar] CoreAI framework unavailable on this OS — probe skipped")
        #endif
    }

    #if canImport(CoreAI)


    // MARK: - M4 — sustained ENERGY per token (BAS_RDAR_M4=ane|mlx, BAS_M4_MINUTES, default 12)
    //
    // The bet's payoff question: watts (proxied by battery %/1k-tokens at 1% granularity over ~12 min) for the
    // CoreAI/ANE chain vs the MLX/GPU baseline, plus the thermal trajectory. MEASUREMENT PROTOCOL: launch via
    // devicectl (cable), then UNPLUG within ~15s (charging invalidates battery delta — the log marks plugged
    // samples), keep the screen ON (idle timer is disabled here); results persist to Documents/qwen35-m4-<arm>-*.log
    // (ProbeFileLog) — replug afterwards and pull via devicectl copy from.
    @available(iOS 27, macOS 27, *)
    private static func runM4(arm: String) async {
        let minutes = Double(ProcessInfo.processInfo.environment["BAS_M4_MINUTES"] ?? "") ?? 12
        let log = ProbeFileLog(filePrefix: "qwen35-m4-\(arm)", category: "qwen35m4", alsoFlush: true)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        func battery() -> Double { Double(UIDevice.current.batteryLevel) * 100 }
        func plugged() -> Bool { UIDevice.current.batteryState != .unplugged }
        func thermal() -> String {
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: return "nominal"; case .fair: return "fair"
            case .serious: return "serious"; case .critical: return "critical"
            @unknown default: return "?" }
        }
        log.emit("[m4-\(arm)] start minutes=\(minutes) battery=\(battery())% plugged=\(plugged()) thermal=\(thermal())")
        // WAIT-FOR-UNPLUG (≤5 min), called AFTER the arm's model load/download so the window is pure decode.
        // Also warns on the 100% top-buffer plateau (iOS holds "100%" for ~10-20 min after unplug — a 0% delta
        // starting at 100% is NOT a real zero).
        func waitUnplug() async {
            if plugged() {
                log.emit("[m4-\(arm)] ⏳ models ready — waiting for UNPLUG (up to 300s), pull the cable now")
                let waitEnd = Date().addingTimeInterval(300)
                while plugged() && Date() < waitEnd {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            log.emit("[m4-\(arm)] " + (plugged() ? "still plugged — measuring anyway (⚠️invalid)"
                                                  : "unplugged ✓ — starting the \(Int(minutes))-min window"))
            if !plugged() && battery() >= 99.5 {
                burning = true
                deadline = Date().addingTimeInterval(20 * 60)   // burn-in cap
                log.emit("[m4-\(arm)] 🔥 battery at 100% plateau — PRE-BURN (uncounted) until the reading dips <99.5%")
            }
        }
        var deadline = Date().addingTimeInterval(minutes * 60)
        var tokens = 0
        var lastSample = Date()
        var bStart: Double = -1     // set at first UNPLUGGED sample (charging start invalidates)
        // 100%-plateau BURN-IN: while unplugged at ≥99.5%, decode WITHOUT counting until the reading first dips
        // (iOS holds "100%" ~10-20 min after unplug) — then zero the counters and restart the window. Immune to
        // launch timing AND the top-buffer.
        var burning = false
        func sampleIfDue() {
            guard Date().timeIntervalSince(lastSample) >= 30 else { return }
            lastSample = Date()
            if burning && !plugged() && battery() < 99.5 {
                burning = false
                tokens = 0
                bStart = battery()
                deadline = Date().addingTimeInterval(minutes * 60)
                log.emit("[m4-\(arm)] 🔥 burn-in complete (battery \(battery())%) — window RESTARTED")
            }
            if bStart < 0 && !plugged() && !burning { bStart = battery() }
            log.emit("[m4-\(arm)] t=\(Int(Date().timeIntervalSince(deadline) + minutes * 60))s tokens=\(tokens) battery=\(battery())% plugged=\(plugged()) thermal=\(thermal()) \(burning ? "(burn-in)" : "")")
        }
        if arm == "ane" {
            // ALL-RESIDENT 4-stage chain (this is also the residency experiment: 4 assets ≈4.2GB int8 → relies on
            // CoreAI weight mmap; a jetsam here is itself a finding, logged by the last emitted line).
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let stages: [(String, Int, Bool)] = [("Qwen35fused_asset1_L0-11_int8", 13, true),
                                                 ("Qwen35fused_asset2_L12-23_int8", 13, true),
                                                 ("Qwen35fused_asset3body_int8", 9, true),
                                                 ("Qwen35fused_head_only_int8", 1, false)]
            guard let raw = try? Data(contentsOf: docs.appendingPathComponent("qwen35_embeds32.bin")) else {
                log.emit("[m4-ane] MISSING embeds ✗"); log.close(); return
            }
            let dim = 2560, T = raw.count / (2560 * 2)
            let embeds: [[Float16]] = raw.withUnsafeBytes { buf in
                let p = buf.bindMemory(to: Float16.self)
                return (0..<T).map { t in Array(p[(t * dim)..<((t + 1) * dim)]) }
            }
            var fns: [InferenceFunction] = []
            var states: [NDArray] = []
            for (name, rows, ane) in stages {
                do {
                    let m = try await AIModel(
                        contentsOf: docs.appendingPathComponent("\(name).aimodel"),
                        options: ane ? SpecializationOptions(preferredComputeUnitKind: .neuralEngine) : .default)
                    guard let fn = try m.loadFunction(named: m.functionNames.first ?? "main") else {
                        log.emit("[m4-ane] \(name): no fn ✗"); log.close(); return
                    }
                    fns.append(fn)
                    states.append(NDArray(scalars: [Float16](repeating: 0, count: rows * 548_864), shape: [rows, 548_864]))
                    log.emit("[m4-ane] resident: \(name)")
                } catch { log.emit("[m4-ane] \(name) LOAD FAILED \(error) ✗"); log.close(); return }
            }
            log.emit("[m4-ane] all 4 resident — residency experiment PASSED load; looping")
            await waitUnplug()
            deadline = Date().addingTimeInterval(minutes * 60)
            var x = embeds[0]
            while Date() < deadline {
                do {
                    var h = x
                    for k in 0..<fns.count {
                        let inp = NDArray(scalars: h, shape: [1, h.count])
                        var views = InferenceFunction.MutableViews()
                        views.insert(&states[k], for: "state_all")
                        var out = try await fns[k].run(inputs: ["x": inp], states: views)
                        guard let v = out.remove("out"), let nd = v.ndArray else {
                            log.emit("[m4-ane] no out ✗"); log.close(); return
                        }
                        if k < fns.count - 1 {
                            var vec = [Float16](repeating: 0, count: nd.shape.reduce(1, *))
                            nd.view(as: Float16.self).withUnsafePointer { p, _, _ in
                                for i in 0..<vec.count { vec[i] = p[i] }
                            }
                            h = vec
                        }
                    }
                    tokens += 1
                    x = embeds[tokens % T]
                } catch { log.emit("[m4-ane] step failed \(error) ✗"); break }
                sampleIfDue()
            }
        } else {
            // MLX GPU arm — the production baseline (Qwen3.5-4B-4bit, GDN-safe streamDraft loop).
            let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
            do { try await organ.loadModel() } catch {
                log.emit("[m4-mlx] loadModel FAILED \(error) ✗ (first run needs the on-device model download)"); log.close(); return
            }
            log.emit("[m4-mlx] model loaded; looping")
            await waitUnplug()
            deadline = Date().addingTimeInterval(minutes * 60)
            var i = 0
            while Date() < deadline {
                let req = BASOrganRequest(requestID: "m4-\(i)", role: .core, preset: .core,
                                          instruction: "Write a short paragraph about topic \(i).", context: [])
                var body = ""
                do { for try await c in organ.streamDraft(req) { body = c.cumulativeBody; sampleIfDue() } }
                catch { log.emit("[m4-mlx] gen failed \(error) ✗"); break }
                tokens += await organ.tokenCount(of: body)
                i += 1
                sampleIfDue()
            }
        }
        let bEnd = battery()
        let used = bStart >= 0 ? bStart - bEnd : -1
        let per1k = tokens > 0 && used >= 0 ? used * 1000 / Double(tokens) : -1
        log.emit(String(format: "[m4-%@] DONE tokens=%d batteryStart(unplugged)=%.0f%% end=%.0f%% used=%.1f%% → %.2f%%/1k-tok thermal=%@ plugged=%@",
                        arm, tokens, bStart, bEnd, used, per1k, thermal(), plugged() ? "true(⚠️invalid)" : "false"))
        log.close()
    }

    // MARK: - M3-device — 3-asset chain fidelity (BAS_RDAR_CHAIN=1)
    //
    // Sequential-residency (all 3 assets = 4.21GB > the ~3.2GB jetsam cap, so ONE asset resident at a time):
    // asset1 runs all T steps carrying its fused state (saving hidden outs), releases; asset2 consumes them;
    // asset3 emits the final-step logits → print top-5 ids/values for host comparison vs the MLX golden
    // (expected [693, 3086, 198, 62, 16] — 693/3086 are an fp16 TIE). Inputs = Documents/qwen35_embeds32.bin
    // (T=32 × 2560 fp16, the REAL embedded golden tokens dumped on the host).
    @available(iOS 27, macOS 27, *)
    private static func runChainFidelity() async {
        print("[qwen35-chain] M3-device start — 3-asset chain fidelity (sequential residency, ANE-pinned)")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let embURL = docs.appendingPathComponent("qwen35_embeds32.bin")
        guard let raw = try? Data(contentsOf: embURL) else {
            print("[qwen35-chain] MISSING qwen35_embeds32.bin ✗"); return
        }
        let dim = 2560
        let T = raw.count / (dim * 2)
        var inputs: [[Float16]] = raw.withUnsafeBytes { buf in
            let p = buf.bindMemory(to: Float16.self)
            return (0..<T).map { t in Array(p[(t * dim)..<((t + 1) * dim)]) }
        }
        print("[qwen35-chain] inputs: T=\(T) dim=\(dim)")
        // Head split (ANE InvalidWidth: vocab 248320 > ANE max tensor width) — the body stages pin the ANE,
        // the head-only stage loads with .default (GPU) placement. head's state is a dummy [1, ROW].
        let chain: [(name: String, rows: Int, ane: Bool)] = [
            ("Qwen35fused_asset1_L0-11_int8", 13, true),
            ("Qwen35fused_asset2_L12-23_int8", 13, true),
            ("Qwen35fused_asset3body_int8", 9, true),
            ("Qwen35fused_head_only_int8", 1, false),
        ]
        var finalLogits: [Float16] = []
        for (idx, stage) in chain.enumerated() {
            let url = docs.appendingPathComponent("\(stage.name).aimodel")
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("[qwen35-chain] MISSING \(stage.name) ✗"); return
            }
            do {
                let t0 = Date()
                let model = try await AIModel(
                    contentsOf: url,
                    options: stage.ane
                        ? SpecializationOptions(preferredComputeUnitKind: .neuralEngine) : .default)
                guard let fname = model.functionNames.first, let fn = try model.loadFunction(named: fname) else {
                    print("[qwen35-chain] \(stage.name): no function ✗"); return
                }
                print("[qwen35-chain] stage \(idx + 1)/\(chain.count) \(stage.name) loaded in \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
                var state = NDArray(scalars: [Float16](repeating: 0, count: stage.rows * stateRow),
                                    shape: [stage.rows, stateRow])
                var outs: [[Float16]] = []
                let t1 = Date()
                for t in 0..<T {
                    let x = NDArray(scalars: inputs[t], shape: [1, dim])
                    var views = InferenceFunction.MutableViews()
                    views.insert(&state, for: "state_all")
                    var outputs = try await fn.run(inputs: ["x": x], states: views)
                    guard let value = outputs.remove("out"), let nd = value.ndArray else {
                        print("[qwen35-chain] \(stage.name): step \(t) no output ✗"); return
                    }
                    var vec = [Float16](repeating: 0, count: nd.shape.reduce(1, *))
                    nd.view(as: Float16.self).withUnsafePointer { p, _, _ in
                        for i in 0..<vec.count { vec[i] = p[i] }
                    }
                    if idx < chain.count - 1 { outs.append(vec) } else if t == T - 1 { finalLogits = vec }
                }
                let ms = Date().timeIntervalSince(t1) * 1000 / Double(T)
                print(String(format: "[qwen35-chain] stage %d done: %d steps, %.1f ms/step", idx + 1, T, ms))
                if idx < chain.count - 1 { inputs = outs }
            } catch {
                print("[qwen35-chain] \(stage.name): FAILED \(error) ✗"); return
            }
            // model/fn go out of scope here → released before the next stage loads (sequential residency)
        }
        guard !finalLogits.isEmpty else { print("[qwen35-chain] no final logits ✗"); return }
        var top: [(Int, Float)] = []
        for (i, v) in finalLogits.enumerated() {
            let f = Float(v)
            if top.count < 5 { top.append((i, f)); top.sort { $0.1 > $1.1 } }
            else if f > top[4].1 { top[4] = (i, f); top.sort { $0.1 > $1.1 } }
        }
        let ids = top.map { $0.0 }
        print("[qwen35-chain] FINAL top5 ids=\(ids) logits=\(top.map { $0.1 })")
        print("[qwen35-chain] expected (MLX golden) ≈ [693, 3086, 198, 62, 16] (693/3086 fp16-tied)")
        let expect: Set<Int> = [693, 3086, 198, 62, 16]
        let overlap = expect.intersection(ids).count
        print("[qwen35-chain] " + (overlap >= 4
            ? "✅ M3-DEVICE PASS — on-device 3-asset chain matches the MLX golden (top-5 overlap \(overlap)/5)"
            : "⚠️ M3-DEVICE DIVERGES — top-5 overlap \(overlap)/5"))
    }

    @available(iOS 27, macOS 27, *)
    /// audit M-i/M1 — returns TRUE only when a placement actually ran all
    /// steps to completion. The two ✗ early-returns and any thrown error
    /// return/propagate false so the caller's SURVIVED banner can't claim
    /// "direction is runnable" when every placement failed.
    private static func runOnce(asset: URL, label: String) async throws -> Bool {
        // Mirror BASCoreAIDecodeProbe: `.default` lets CoreAI place freely; "ane" pins the neural engine —
        // the placement rdar 177354777 is most likely to bite.
        let opts: SpecializationOptions =
            label == "ane" ? SpecializationOptions(preferredComputeUnitKind: .neuralEngine) : .default
        let model = try await AIModel(contentsOf: asset, options: opts)
        guard let name = model.functionNames.first, let fn = try model.loadFunction(named: name) else {
            print("[qwen35-rdar] \(label): no inference function in asset ✗")
            return false
        }
        // ONE fused state, zero-initialized (mirrors BASCoreAIDecodeSession's single-state pattern).
        var state = NDArray(scalars: [Float16](repeating: 0, count: stateRows * stateRow),
                            shape: [stateRows, stateRow])
        var lastDim = -1
        let t0 = Date()
        for step in 0..<steps {
            print("[qwen35-rdar] \(label): STEP \(step) …")   // last line before a crash localizes it
            let inputs: [String: NDArray]
            if let d = inputDim {
                inputs = ["x": NDArray(scalars: [Float16](repeating: 0, count: d), shape: [1, d])]
            } else {
                inputs = ["input_id": NDArray(scalars: [Int32(step)], shape: [1, 1])]
            }
            var states = InferenceFunction.MutableViews()
            states.insert(&state, for: "state_all")
            var outputs = try await fn.run(inputs: inputs, states: states)
            guard let value = outputs.remove(inputDim == nil ? "logits" : "out"), let logits = value.ndArray else {
                print("[qwen35-rdar] \(label): STEP \(step) returned no output ✗")
                return false
            }
            lastDim = logits.shape.reduce(1, *)
        }
        let ms = Date().timeIntervalSince(t0) * 1000 / Double(steps)
        print(String(format: "[qwen35-rdar] %@: %d steps OK, logits dim %d, %.1f ms/step ✓",
                     label, steps, lastDim, ms))
        return true
    }
    #endif
}
