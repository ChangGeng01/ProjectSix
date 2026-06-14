// MARK: - BASCoreAIDecodeProbe — Track E on the REAL iPhone A19 (BAS_COREAI_DECODE_PROBE=1)
//
// THE decisive Phase-0 gate for Saguaro-on-CoreAI: does the iOS-27 **CoreAI** stateful decode
// (BASCoreAIDecodeSession over LlamaDraft1B_fp16.aimodel) run on the A19, and at what tok/s vs the
// MLX 3B baseline (38.3 tok/s)? Throughput / memory / placement are FIDELITY-INDEPENDENT (a
// same-shape model measures identically), so this runs on the throughput-first artifact regardless
// of the known coreai_torch-0.4.0 attention-value matmul bug.
//
// Measures, for SpecializationOptions `.default` (CoreAI auto-picks ANE/GPU) and `.cpuOnly`:
//   • steady-state ms/token over ~128 decode step()s (warmup excluded) → tok/s vs 38.3
//   • load delta + peak phys_footprint (vs the 3248 MB jetsam cap)
//   • placement proxy: default-vs-cpuOnly tok/s ratio (>>1 ⇒ accelerators carry the decode)
//
// Stage ONLY the .aimodel (RoPE tables are written in-app as the right-sized buffers — for a
// throughput probe the RoPE VALUES are irrelevant; timing is identical):
//   xcrun devicectl device copy to --device <udid> --domain-type appDataContainer \
//     --domain-identifier com.changgeng.basdevicetest \
//     --source /tmp/draft_coreai/LlamaDraft1B_fp16.aimodel \
//     --destination Documents/LlamaDraft1B_fp16.aimodel
// Then launch with BAS_COREAI_DECODE_PROBE=1.

import Foundation
import os
import BASAppleAdapters   // BASCoreAIDecodeSession (the stateful CoreAI decode driver)

#if canImport(CoreAI)
import CoreAI
#endif

enum BASCoreAIDecodeProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "coreai-decode")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("coreai-decode-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASCoreAIDecodeProbe.log.info("\(line, privacy: .public)")
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

    /// print() → process stdout (captured reliably by `devicectl … --console`, and SURVIVES a crash,
    /// unlike buffered os_log) + the FileLog.
    private static func mark(_ fileLog: FileLog, _ s: String) {
        print(s)
        fflush(stdout)
        fileLog.emit(s)
    }

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        mark(fileLog, String(format: "📊 coreai-decode START footprint0=%.0fMB (beat: MLX 3B=38.3 tok/s; cap 3248MB)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            // .default / .neuralEngine OOM-CRASH the aned ANE compiler on the 2.3 GB fp16 1B (uncatchable
            // std::bad_alloc → SIGABRT — matches the prior Core ML "fp16 ANE size-rejected" finding). So
            // measure GPU + CPU on fp16; ANE is gated behind BAS_COREAI_TRY_ANE=1 (for a future int8 artifact).
            await measure(label: "cpuOnly", options: .cpuOnly, fileLog: fileLog)
            await measure(label: "gpu", options: SpecializationOptions(preferredComputeUnitKind: .gpu), fileLog: fileLog)
            if (ProcessInfo.processInfo.environment["BAS_COREAI_TRY_ANE"] ?? "0") == "1" {
                await measure(label: "ane", options: SpecializationOptions(preferredComputeUnitKind: .neuralEngine), fileLog: fileLog)
            } else {
                mark(fileLog, "📊 coreai-decode ane SKIPPED (fp16 1B OOM-crashes aned; needs int8 + BAS_COREAI_TRY_ANE=1)")
            }
            mark(fileLog, "📊 coreai-decode DONE — read: tok/s vs 38.3 (gate b); peak_MB vs 3248 (gate c); gpu/cpu ratio = placement (gate d).")
        } else {
            mark(fileLog, "📊 coreai-decode SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark(fileLog, "📊 coreai-decode SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }

    #if canImport(CoreAI)
    @available(iOS 27, macOS 27, *)
    private static func measure(label: String, options: SpecializationOptions, fileLog: FileLog) async {
        let env = ProcessInfo.processInfo.environment
        let assetName = env["BAS_COREAI_ASSET"] ?? "LlamaDraft1B_fp16.aimodel"
        let nLayers = Int(env["BAS_COREAI_LAYERS"] ?? "") ?? 16
        let nKV = Int(env["BAS_COREAI_NKV"] ?? "") ?? 8
        let headDim = Int(env["BAS_COREAI_HEADDIM"] ?? "") ?? 64
        let maxSeq = Int(env["BAS_COREAI_MAXSEQ"] ?? "") ?? 512
        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            mark(fileLog, "📊 coreai-decode \(label) ERROR=no-documents-dir"); return
        }
        let asset = docs.appendingPathComponent(assetName)
        guard FileManager.default.fileExists(atPath: asset.path) else {
            fileLog.emit("📊 coreai-decode \(label) ERROR=LlamaDraft1B_fp16.aimodel missing — stage it into Documents")
            return
        }
        // RoPE tables: write right-sized zero buffers if absent (values irrelevant to timing).
        let cosURL = docs.appendingPathComponent("rope_cos_h\(headDim).bin")
        let sinURL = docs.appendingPathComponent("rope_sin_h\(headDim).bin")
        let tableBytes = maxSeq * headDim * MemoryLayout<Float>.size
        for url in [cosURL, sinURL] where !FileManager.default.fileExists(atPath: url.path) {
            try? Data(count: tableBytes).write(to: url)
        }

        let mBefore = footprintMB()
        mark(fileLog, String(format: "📊 coreai-decode %@ loading… footprint=%.0fMB", label, mBefore))
        do {
            let session = try await BASCoreAIDecodeSession(
                assetURL: asset, ropeCosURL: cosURL, ropeSinURL: sinURL,
                nLayers: nLayers, nKV: nKV, headDim: headDim, maxSeq: maxSeq, options: options)
            let mLoaded = footprintMB()
            mark(fileLog, String(format: "📊 coreai-decode %@ loaded footprint=%.0fMB (Δ%.0fMB)", label, mLoaded, mLoaded - mBefore))

            // Pure decode step loop from pos 0 (KV accumulates). Token values are irrelevant to timing.
            var pos = 0
            var tok = 1
            for _ in 0..<8 { tok = try await session.step(token: tok, pos: pos); pos += 1 }   // warmup
            let steps = 128
            let t0 = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<steps { tok = try await session.step(token: max(0, tok), pos: pos); pos += 1 }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            let peak = footprintMB()
            let msPerTok = elapsedMs / Double(steps)
            let tps = msPerTok > 0 ? 1000.0 / msPerTok : -1
            mark(fileLog, String(format:
                "📊 coreai-decode %@ ms/tok=%.3f tok/s=%.2f load_MB=%.1f peak_MB=%.1f (MLX 3B=38.3 tok/s, cap 3248MB) lastTok=%d",
                label, msPerTok, tps, mLoaded - mBefore, peak, tok))
        } catch {
            mark(fileLog, "📊 coreai-decode \(label) ERROR=\(error)")
        }
    }
    #endif
}
