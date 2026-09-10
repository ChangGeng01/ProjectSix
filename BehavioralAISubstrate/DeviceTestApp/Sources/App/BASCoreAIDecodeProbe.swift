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

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

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
    private static func mark(_ fileLog: ProbeFileLog, _ s: String) {
        print(s)
        fflush(stdout)
        fileLog.emit(s)
    }

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "coreai-decode", category: "coreai-decode", alsoPrint: false)
        defer { fileLog.close() }
        mark(fileLog, String(format: "📊 coreai-decode START footprint0=%.0fMB (beat: MLX 3B=38.3 tok/s; cap 3248MB)", footprintMB()))
        #if canImport(CoreAI)
        if #available(iOS 27, macOS 27, *) {
            // Each backend can FAIL INDEPENDENTLY and some failures are uncatchable (aned OOM / GPU compile →
            // std::bad_alloc → SIGABRT, killing the app past Swift try/catch). So units are run in
            // BAS_COREAI_UNITS order (default "cpu,gpu") — isolate a backend (e.g. "ane") so an earlier crash
            // can't pre-empt it. The 1B fp16 OOM-crashes aned; int8 (1.24 GB) is the ANE candidate.
            let env = ProcessInfo.processInfo.environment
            let split = (env["BAS_COREAI_SPLIT"] ?? "0") == "1"   // layer-split: N chunk .aimodels (BAS_COREAI_SPLIT_DIR/LAYERS)
            let mamba = (env["BAS_COREAI_MAMBA"] ?? "0") == "1"   // Mamba-2 (Llamba-1B): 2 fused states, NO rope/onehot/bias
            let units = (env["BAS_COREAI_UNITS"] ?? "cpu,gpu")
                .split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            for u in units {
                let opts: SpecializationOptions?
                switch u {
                case "cpu": opts = .cpuOnly
                case "gpu": opts = SpecializationOptions(preferredComputeUnitKind: .gpu)
                case "ane": opts = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
                default: mark(fileLog, "📊 coreai-decode unknown unit \(u)"); opts = nil
                }
                guard let options = opts else { continue }
                let label = (u == "cpu") ? "cpuOnly" : u
                if mamba { await measureMamba(label: label, options: options, fileLog: fileLog) }
                else if split { await measureSplit(label: label, options: options, fileLog: fileLog) }
                else { await measure(label: label, options: options, fileLog: fileLog) }
            }
            mark(fileLog, "📊 coreai-decode DONE — read: tok/s vs 38.3 (gate b); peak_MB vs 3248 (gate c); per-unit = placement (gate d).")
        } else {
            mark(fileLog, "📊 coreai-decode SKIP — needs iOS 27 / macOS 27")
        }
        #else
        mark(fileLog, "📊 coreai-decode SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }

    #if canImport(CoreAI)
    @available(iOS 27, macOS 27, *)
    private static func measure(label: String, options: SpecializationOptions, fileLog: ProbeFileLog) async {
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

    /// Mamba-2 (Llamba-1B): the decisive "does a 16-layer recurrent-state model clear the per-asset ANE
    /// LAYER-COUNT ceiling that blocked the 16-layer transformer?" probe. NO RoPE/onehot/bias inputs, NO
    /// KV window — just two fused recurrent states (conv_all/ssm_all), positionless `step(token:)`. Stage
    /// only the .aimodel (BAS_COREAI_ASSET, default Llamba1B_fp16.aimodel); state shapes via
    /// BAS_COREAI_MAMBA_CONV / BAS_COREAI_MAMBA_SSM (defaults match the converter: [16,6144,4] / [16,32,64,64]).
    @available(iOS 27, macOS 27, *)
    private static func measureMamba(label: String, options: SpecializationOptions, fileLog: ProbeFileLog) async {
        let env = ProcessInfo.processInfo.environment
        let assetName = env["BAS_COREAI_ASSET"] ?? "Llamba1B_fp16.aimodel"
        let convShape = (env["BAS_COREAI_MAMBA_CONV"] ?? "16,6144,4").split(separator: ",").compactMap { Int($0) }
        let ssmShape = (env["BAS_COREAI_MAMBA_SSM"] ?? "16,32,64,64").split(separator: ",").compactMap { Int($0) }
        guard convShape.count == 3, ssmShape.count == 4, let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            mark(fileLog, "📊 coreai-decode mamba/\(label) ERROR=bad-shapes-or-no-docs"); return
        }
        let asset = docs.appendingPathComponent(assetName)
        guard FileManager.default.fileExists(atPath: asset.path) else {
            mark(fileLog, "📊 coreai-decode mamba/\(label) ERROR=\(assetName) missing — stage it into Documents"); return
        }
        let mBefore = footprintMB()
        mark(fileLog, String(format: "📊 coreai-decode mamba/%@ loading %@ conv%@ ssm%@… footprint=%.0fMB",
                             label, assetName, "\(convShape)", "\(ssmShape)", mBefore))
        do {
            let session = try await BASCoreAIMambaSession(
                assetURL: asset, convShape: convShape, ssmShape: ssmShape, options: options)
            let mLoaded = footprintMB()
            mark(fileLog, String(format: "📊 coreai-decode mamba/%@ loaded footprint=%.0fMB (Δ%.0fMB)", label, mLoaded, mLoaded - mBefore))
            var tok = 1
            for _ in 0..<8 { tok = try await session.step(token: max(0, tok)) }   // warmup (state accumulates)
            let steps = 128
            let t0 = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<steps { tok = try await session.step(token: max(0, tok)) }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            let peak = footprintMB()
            let msPerTok = elapsedMs / Double(steps)
            let tps = msPerTok > 0 ? 1000.0 / msPerTok : -1
            mark(fileLog, String(format:
                "📊 coreai-decode mamba/%@ ms/tok=%.3f tok/s=%.2f load_MB=%.1f peak_MB=%.1f (MLX 3B=38.3 tok/s, cap 3248MB) lastTok=%d",
                label, msPerTok, tps, mLoaded - mBefore, peak, tok))
        } catch {
            mark(fileLog, "📊 coreai-decode mamba/\(label) ERROR=\(error)")
        }
    }

    /// Layer-split: drive N chunk `.aimodel`s (BAS_COREAI_SPLIT_DIR, default LlamaDraft1B_split88; BAS_COREAI_SPLIT_LAYERS,
    /// default "8,8") via BASCoreAILayerSplitSession. Same decode-timing harness as `measure`.
    @available(iOS 27, macOS 27, *)
    private static func measureSplit(label: String, options: SpecializationOptions, fileLog: ProbeFileLog) async {
        let env = ProcessInfo.processInfo.environment
        let assetName = env["BAS_COREAI_SPLIT_ASSET"] ?? "LlamaDraft1B_mfn88.aimodel"   // ONE multi-function asset
        let layers = (env["BAS_COREAI_SPLIT_LAYERS"] ?? "8,8").split(separator: ",").compactMap { Int($0) }
        let nKV = Int(env["BAS_COREAI_NKV"] ?? "") ?? 8
        let headDim = Int(env["BAS_COREAI_HEADDIM"] ?? "") ?? 64
        let maxSeq = Int(env["BAS_COREAI_MAXSEQ"] ?? "") ?? 512
        guard !layers.isEmpty, let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            mark(fileLog, "📊 coreai-decode split/\(label) ERROR=bad-config-or-no-docs"); return
        }
        let assetURL = docs.appendingPathComponent(assetName)
        guard FileManager.default.fileExists(atPath: assetURL.path) else {
            mark(fileLog, "📊 coreai-decode split/\(label) ERROR=\(assetName) missing"); return
        }
        let cosURL = docs.appendingPathComponent("rope_cos_h\(headDim).bin")
        let sinURL = docs.appendingPathComponent("rope_sin_h\(headDim).bin")
        let tableBytes = maxSeq * headDim * MemoryLayout<Float>.size
        for url in [cosURL, sinURL] where !FileManager.default.fileExists(atPath: url.path) {
            try? Data(count: tableBytes).write(to: url)
        }
        let mBefore = footprintMB()
        mark(fileLog, String(format: "📊 coreai-decode split/%@ loading %d chunks %@… footprint=%.0fMB", label, layers.count, "\(layers)", mBefore))
        do {
            let session = try await BASCoreAILayerSplitSession(
                assetURL: assetURL, chunkLayers: layers,
                ropeCosURL: cosURL, ropeSinURL: sinURL, nKV: nKV, headDim: headDim, maxSeq: maxSeq, options: options)
            let mLoaded = footprintMB()
            mark(fileLog, String(format: "📊 coreai-decode split/%@ loaded footprint=%.0fMB (Δ%.0fMB)", label, mLoaded, mLoaded - mBefore))
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
                "📊 coreai-decode split/%@ ms/tok=%.3f tok/s=%.2f load_MB=%.1f peak_MB=%.1f (MLX 3B=38.3 tok/s, cap 3248MB) lastTok=%d",
                label, msPerTok, tps, mLoaded - mBefore, peak, tok))
        } catch {
            mark(fileLog, "📊 coreai-decode split/\(label) ERROR=\(error)")
        }
    }
    #endif
}
