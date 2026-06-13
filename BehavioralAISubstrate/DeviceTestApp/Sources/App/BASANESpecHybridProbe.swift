// MARK: - BASANESpecHybridProbe — Track B2: the end-to-end ANE-draft ∥ MLX-verify hybrid (BAS_ANE_SPEC_PROBE=1)
//
// The "last big piece": a Core ML int8 Llama-3.2-1B draft (65% A19-ANE) proposes K tokens; the MLX target
// verifies all K in ONE forward (greedy argmax); accept the longest matching prefix — TOKEN-identical to
// target-only greedy (ADR-039). Certifying config (fits the iPhone-Air cap): a 1B MLX target + the 1B int8 draft
// (~2.7 GB). Byte-identity is target-size-independent, so 1B+1B fully certifies the mechanism; the 3B target is
// memory-gated (2969+1200 > 3376 cap) and deferred.
//
// The silent-corruption gate: a broken draft RESYNC stays byte-identical but collapses acceptance to ~0. So the
// load-bearing number is mean_acc (accepted/round) — on this same-family config it must be substantial (>~1).
//
// Stage first: LlamaDraft1B_int8.mlpackage + rope_cos_f32.bin + rope_sin_f32.bin into Documents. Env:
// BAS_SPEC_K, BAS_SPEC_MAX_DECODE, BAS_SPEC_DRAFT_UNITS (all|ane|gpu).

import Foundation
import os
import CoreML
import BASOrgan
import BASMLXAdapter

enum BASANESpecHybridProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "ane-spec")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("ane-spec-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASANESpecHybridProbe.log.info("\(line, privacy: .public)")
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

    private static let workloads: [(name: String, prompt: String)] = [
        ("rag-quote",
         "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of "
         + "the cell's supply of adenosine triphosphate.\n\"\"\"\nQuote the passage above back verbatim."),
        ("code-repeat",
         "Repeat this Swift function exactly, then again unchanged:\nfunc add(_ a: Int, _ b: Int) -> Int { a + b }"),
        ("control-freeform",
         "Write a short original opening paragraph for a science-fiction story set on a distant moon."),
    ]

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let k = Int(env["BAS_SPEC_K"] ?? "") ?? 4
        let cap = Int(env["BAS_SPEC_MAX_DECODE"] ?? "") ?? 128
        let unitsStr = env["BAS_SPEC_DRAFT_UNITS"] ?? "all"
        // Target: 1b (certifies the mechanism; draft not cheaper → no speedup) vs 3b (the WIN case — the 1B int8
        // draft replaces expensive 3B forwards). int8 draft mmaps to ~30MB resident, so 3B+draft fits the cap.
        let targetStr = env["BAS_SPEC_TARGET"] ?? "1b"
        let target = targetStr == "3b" ? MLXModelCatalog.llama3_2_3B_4bit : MLXModelCatalog.llama3_2_1B_4bit

        guard #available(iOS 18.0, *) else {
            fileLog.emit("📊 ane-spec SKIPPED — needs iOS 18 (MLState)"); return
        }
        let units: MLComputeUnits = unitsStr == "ane" ? .cpuAndNeuralEngine : (unitsStr == "gpu" ? .cpuAndGPU : .all)
        fileLog.emit("📊 ane-spec START target=\(target.providerID) draft=int8 K=\(k) cap=\(cap) units=\(unitsStr) "
            + String(format: "footprint0=%.0fMB", footprintMB()))

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fileLog.emit("📊 ane-spec ERROR=no-documents"); return
        }
        let modelURL = docs.appendingPathComponent("LlamaDraft1B_int8.mlpackage")
        let cosURL = docs.appendingPathComponent("rope_cos_f32.bin")
        let sinURL = docs.appendingPathComponent("rope_sin_f32.bin")
        for u in [modelURL, cosURL, sinURL] where !FileManager.default.fileExists(atPath: u.path) {
            fileLog.emit("📊 ane-spec ERROR=missing \(u.lastPathComponent) — stage it into Documents"); return
        }

        do {
            let adapter = MLXOrganAdapter(
                model: target, maxOutputTokens: cap, speculativeDecoding: .off)
            try await adapter.loadModel()
            fileLog.emit(String(format: "📊 ane-spec target loaded footprint=%.0fMB", footprintMB()))

            let draft = try BASCoreMLDraftSession(
                modelURL: modelURL, ropeCosURL: cosURL, ropeSinURL: sinURL, computeUnits: units)
            fileLog.emit(String(format: "📊 ane-spec draft loaded footprint=%.0fMB (peak resident with both)", footprintMB()))

            var speedups: [Double] = []
            var allIdentical = true
            var idCount = 0

            for w in workloads {
                let request = BASOrganRequest(
                    requestID: "spec-\(w.name)", role: .core,
                    preset: .greedyDeterministic, instruction: w.prompt, context: [])
                do {
                    let ab = try await adapter.coreMLDraftAB(for: request, draft: draft, numDraftTokens: k)
                    let identical = ab.specTokens == ab.baseTokens
                    if identical { idCount += 1 } else { allIdentical = false }
                    let speedup = ab.specMs > 0 ? ab.baseMs / ab.specMs : 0
                    let hitRate = ab.proposed > 0 ? Double(ab.accepted) / Double(ab.proposed) : 0
                    let meanAcc = ab.rounds > 0 ? Double(ab.accepted) / Double(ab.rounds) : 0
                    speedups.append(speedup)
                    fileLog.emit(String(
                        format: "📊 ane-spec workload=%@ tokens=%d rounds=%d hit_rate=%.2f mean_acc=%.2f "
                            + "spec_ms=%.0f base_ms=%.0f speedup=%.2fx token_identical=%@",
                        w.name, ab.specTokens.count, ab.rounds, hitRate, meanAcc,
                        ab.specMs, ab.baseMs, speedup, identical ? "YES" : "NO"))
                } catch {
                    fileLog.emit("📊 ane-spec workload=\(w.name) ERROR=\(error)")
                }
            }

            let mean = speedups.isEmpty ? 0 : speedups.reduce(0, +) / Double(speedups.count)
            fileLog.emit(String(
                format: "📊 ane-spec DONE K=%d mean_speedup=%.2fx token_identical=%d/%d all_identical=%@ "
                    + "peak=%.0fMB", k, mean, idCount, workloads.count,
                allIdentical ? "YES" : "NO", footprintMB()))
        } catch {
            fileLog.emit("📊 ane-spec ERROR=\(error)")
        }
    }
}
