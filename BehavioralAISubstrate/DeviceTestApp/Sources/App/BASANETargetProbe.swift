// MARK: - BASANETargetProbe — Phase 0 GATE: does a Core ML Llama-3.2-3B TARGET decode ≥ 38.3 tok/s on the A19?
//
// The decisive bet behind the Core ML backend rewrite. The MLX 3B-4bit baseline is 38.3 tok/s / 2969 MB on the
// A19; the B2 int8 1B Core ML draft was already ~31 tok/s (slower per token), so a 3B (bigger) is at real risk.
// This probe drives the staged stateful 3B (int4 or int8) via BASCoreMLDraftSession (headDim 128, h128 RoPE
// tables) and measures: (a) decode ms/token (steady state, warmup excluded) → tok/s vs 38.3; (b) peak footprint
// vs the 3248 MB usable cap; (c) MLComputePlan placement (ANE op fraction; no error -14). GO/NO-GO → Docs.
//
// Stage first: LlamaTarget3B_int4.mlpackage / _int8.mlpackage + rope_cos_f32_h128.bin + rope_sin_f32_h128.bin into
// Documents. Env: BAS_TARGET_QUANT (int4|int8, default int4), BAS_TARGET_UNITS (all|ane|gpu, default all),
// BAS_TARGET_DECODE (steady-state token count, default 128).

import Foundation
import os
import CoreML
import BASMLXAdapter

enum BASANETargetProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "ane-target")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("ane-target-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASANETargetProbe.log.info("\(line, privacy: .public)")
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }
        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

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

    // MARK: - MLComputePlan placement histogram (input-agnostic)

    @available(iOS 17.4, *)
    private static func plan(_ url: URL, units: MLComputeUnits, label: String, fileLog: FileLog) async {
        do {
            let compiled = try await MLModel.compileModel(at: url)
            let cfg = MLModelConfiguration(); cfg.computeUnits = units
            let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: cfg)
            var hist: [String: Int] = [:]; var total = 0; var capable = 0
            if case .program(let prog) = plan.modelStructure {
                for (_, fn) in prog.functions { walk(fn.block, plan, &hist, &total, &capable) }
            }
            let parts = hist.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            fileLog.emit("📊 ane-target plan \(label) ops=\(total) \(parts) ane_capable=\(capable)")
        } catch {
            fileLog.emit("📊 ane-target plan \(label) error=\(error)")
        }
    }

    @available(iOS 17.4, *)
    private static func walk(_ b: MLModelStructure.Program.Block, _ p: MLComputePlan,
                             _ h: inout [String: Int], _ t: inout Int, _ cap: inout Int) {
        for op in b.operations {
            if let u = p.deviceUsage(for: op) {
                h[dev(u.preferred), default: 0] += 1; t += 1
                if u.supported.contains(where: { if case .neuralEngine = $0 { return true }; return false }) { cap += 1 }
            }
            for n in op.blocks { walk(n, p, &h, &t, &cap) }
        }
    }

    @available(iOS 17.4, *)
    private static func dev(_ d: MLComputeDevice?) -> String {
        switch d { case .neuralEngine: return "ane"; case .gpu: return "gpu"; case .cpu: return "cpu"; default: return "?" }
    }

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let quant = env["BAS_TARGET_QUANT"] ?? "int4"
        let unitsStr = env["BAS_TARGET_UNITS"] ?? "all"
        let decodeN = Int(env["BAS_TARGET_DECODE"] ?? "") ?? 128
        let units: MLComputeUnits = unitsStr == "ane" ? .cpuAndNeuralEngine
            : (unitsStr == "gpu" ? .cpuAndGPU : .all)

        guard #available(iOS 18.0, *) else { fileLog.emit("📊 ane-target SKIPPED — needs iOS 18"); return }
        fileLog.emit("📊 ane-target START quant=\(quant) units=\(unitsStr) decodeN=\(decodeN) "
            + String(format: "footprint0=%.0fMB (baseline to beat: MLX 3B = 38.3 tok/s, 2969MB; cap 3248MB)", footprintMB()))

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fileLog.emit("📊 ane-target ERROR=no-documents"); return
        }
        let modelURL = docs.appendingPathComponent("LlamaTarget3B_\(quant).mlpackage")
        let cosURL = docs.appendingPathComponent("rope_cos_f32_h128.bin")
        let sinURL = docs.appendingPathComponent("rope_sin_f32_h128.bin")
        for u in [modelURL, cosURL, sinURL] where !FileManager.default.fileExists(atPath: u.path) {
            fileLog.emit("📊 ane-target ERROR=missing \(u.lastPathComponent) — stage it into Documents"); return
        }

        // (d) Placement — input-agnostic, across compute-unit options.
        if #available(iOS 17.4, *) {
            await plan(modelURL, units: .all, label: "\(quant)/all", fileLog: fileLog)
            await plan(modelURL, units: .cpuAndNeuralEngine, label: "\(quant)/cpuAndANE", fileLog: fileLog)
        }

        do {
            let session = try BASCoreMLDraftSession(
                modelURL: modelURL, ropeCosURL: cosURL, ropeSinURL: sinURL,
                maxSeq: 512, headDim: 128, computeUnits: units)
            fileLog.emit(String(format: "📊 ane-target loaded footprint=%.0fMB", footprintMB()))

            // Prefill a short fixed prompt, then decode `decodeN` tokens autoregressively (argmax feedback).
            let prompt = [128000, 9906, 11, 1268, 656, 499, 990, 30, 358, 2846, 264, 4221, 1646, 13]  // arbitrary valid ids
            try session.prefill(prompt)
            var tok = prompt.last ?? 1
            var pos = session.draftPos
            // Warmup (8 steps, excluded from timing).
            for _ in 0..<8 where pos < 500 { tok = try session.step(token: tok, pos: pos); pos += 1 }
            let warmFootprint = footprintMB()

            let s = DispatchTime.now().uptimeNanoseconds
            var n = 0
            while n < decodeN && pos < 500 { tok = try session.step(token: tok, pos: pos); pos += 1; n += 1 }
            let ms = Double(DispatchTime.now().uptimeNanoseconds &- s) / 1_000_000
            let msPerTok = n > 0 ? ms / Double(n) : 0
            let tokPerSec = msPerTok > 0 ? 1000.0 / msPerTok : 0
            let peak = footprintMB()
            let throughputGO = tokPerSec >= 38.3 ? "YES" : "NO"
            let memGO = peak < 3248 ? "YES" : "NO"
            fileLog.emit(String(
                format: "📊 ane-target DONE quant=%@ units=%@ decoded=%d ms_per_tok=%.2f tok_per_sec=%.1f "
                    + "peak_mb=%.0f warm_mb=%.0f throughput_GO(>=38.3)=%@ mem_GO(<3248)=%@",
                quant, unitsStr, n, msPerTok, tokPerSec, peak, warmFootprint, throughputGO, memGO))
        } catch {
            fileLog.emit("📊 ane-target ERROR=\(error)")
        }
    }
}
