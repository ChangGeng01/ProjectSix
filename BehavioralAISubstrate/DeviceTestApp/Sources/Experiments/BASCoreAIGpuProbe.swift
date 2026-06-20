// MARK: - BASCoreAIGpuProbe — "does CoreAI's GPU path (A19 Neural Accelerators) beat MLX?" (BAS_COREAI_GPU_PROBE=1)
//
// THE kernel-layer datum for the universal-decode收口 (Docs/COREAI_IOS27_REFERENCE.md + litert-onphone-reality):
// the universal on-device speedup is BANDWIDTH (read bytes faster), and the question is whether CoreAI's GPU path —
// which rides the A19 GPU's matmul "Neural Accelerators" — decodes a real-size model FASTER than BAS's MLX-Metal,
// which (hypothesis) does not target that HW. If yes, BAS gets an Apple-NATIVE kernel-accel lane (no Google .litertlm
// dependency, no per-arch verify-signature gates).
//
// WHY a random-weight stub is rigorous here: on-device decode tok/s depends ONLY on the matmul SHAPES
// (layers/hidden/heads/vocab), never on weight VALUES. A correctly-SHAPED Llama-3.2-1B int8 .aimodel measures
// CoreAI-GPU's real 1B decode speed while sidestepping every fidelity gotcha (those affect output, not speed).
//
// THE COMPARISON IS NOT BYTE-MATCHED: CoreAI ships int8 (~1.2 GB; fp16 SIGABRTs the .gpu loader at 2.3 GB), MLX runs
// int4 (~0.7 GB). So CoreAI reads ~1.7× the bytes/token. If CoreAI-GPU tok/s still ≈ MLX-int4 tok/s, the CoreAI
// kernel is ~1.7× more efficient PER BYTE (a strong Neural-Accelerator win). Report the ratio WITH this caveat.
//
// Env: BAS_COREAI_GPU_PROBE=1 (+ BAS_ENDURANCE_AUTOSTART=1). Knobs: BAS_CAI_ASSET / BAS_CAI_LAYERS / BAS_CAI_NKV /
// BAS_CAI_HEADDIM / BAS_CAI_MAXSEQ / BAS_CAI_STEPS / BAS_CAI_UNIT (gpu|ane|cpu, default gpu). Default-OFF.

import Foundation
import os
import BASOrgan
import BASMLXAdapter
#if canImport(CoreAI)
import CoreAI            // SpecializationOptions, ComputeUnitKind {.cpu,.gpu,.neuralEngine}
import BASAppleAdapters  // BASCoreAIDecodeSession
#endif

enum BASCoreAIGpuProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "coreai-gpu")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("coreai-gpu-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASCoreAIGpuProbe.log.info("\(line, privacy: .public)")
            print(line); fflush(stdout)   // survives where os_log is lost; lets --console read it live
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }
        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        #if canImport(CoreAI)
        guard #available(iOS 27, macOS 27, *) else {
            fileLog.emit("📊 coreai-gpu SKIP — needs iOS 27 / macOS 27"); return
        }
        let assetName = env["BAS_CAI_ASSET"] ?? "llama1b_v128k_int8.aimodel"
        let nLayers = Int(env["BAS_CAI_LAYERS"] ?? "") ?? 16
        let nKV = Int(env["BAS_CAI_NKV"] ?? "") ?? 8
        let headDim = Int(env["BAS_CAI_HEADDIM"] ?? "") ?? 64
        let maxSeq = Int(env["BAS_CAI_MAXSEQ"] ?? "") ?? 512
        let steps = Int(env["BAS_CAI_STEPS"] ?? "") ?? 32
        let unitStr = (env["BAS_CAI_UNIT"] ?? "gpu").lowercased()
        let (unit, unitLabel): (ComputeUnitKind, String) = {
            switch unitStr {
            case "ane", "neuralengine": return (.neuralEngine, "neuralEngine")
            case "cpu": return (.cpu, "cpu")
            default: return (.gpu, "gpu")
            }
        }()
        fileLog.emit("📊 coreai-gpu START asset=\(assetName) unit=\(unitLabel) layers=\(nLayers) nKV=\(nKV) "
            + "headDim=\(headDim) maxSeq=\(maxSeq) steps=\(steps)")

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fileLog.emit("📊 coreai-gpu ERROR=no Documents dir"); return
        }
        let asset = docs.appendingPathComponent(assetName)
        guard FileManager.default.fileExists(atPath: asset.path) else {
            fileLog.emit("📊 coreai-gpu ERROR=\(assetName) missing — stage it (devicectl copy to Documents/)"); return
        }
        // Zero RoPE tables — values are irrelevant to a SPEED measurement (only shapes matter).
        let cosURL = docs.appendingPathComponent("rope_cos_h\(headDim).bin")
        let sinURL = docs.appendingPathComponent("rope_sin_h\(headDim).bin")
        let tableBytes = maxSeq * headDim * MemoryLayout<Float>.size
        for url in [cosURL, sinURL] where !FileManager.default.fileExists(atPath: url.path) {
            try? Data(count: tableBytes).write(to: url)
        }

        // ---- CoreAI side: load on the chosen unit, warm, then time `steps` forwards ----
        var coreaiTps = 0.0
        do {
            let options = SpecializationOptions(preferredComputeUnitKind: unit)
            let t0 = DispatchTime.now().uptimeNanoseconds
            let session = try await BASCoreAIDecodeSession(
                assetURL: asset, ropeCosURL: cosURL, ropeSinURL: sinURL,
                nLayers: nLayers, nKV: nKV, headDim: headDim, maxSeq: maxSeq, options: options)
            let loadMs = Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
            fileLog.emit("📊 coreai-gpu loaded unit=\(unitLabel) load_ms=\(String(format: "%.0f", loadMs))")
            _ = await stepMs(session, steps: max(4, steps / 4), startPos: 0)        // warm (program load / JIT)
            let runMs = await stepMs(session, steps: steps, startPos: max(4, steps / 4))
            coreaiTps = runMs > 0 ? Double(steps) * 1000.0 / runMs : 0
            fileLog.emit("📊 coreai-gpu DECODE unit=\(unitLabel) ms=\(String(format: "%.0f", runMs)) "
                + "tok/s=\(String(format: "%.1f", coreaiTps))")
        } catch {
            fileLog.emit("📊 coreai-gpu ERROR loading/running on \(unitLabel)=\(error)")
        }

        // ---- MLX side: same model class (Llama-3.2-1B, int4), warm, then time `steps` forwards ----
        var mlxTps = 0.0
        do {
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.llama3_2_1B_4bit, maxOutputTokens: 64, speculativeDecoding: .off)
            try await adapter.loadModel()
            let req = BASOrganRequest(
                requestID: "caigpu", role: .core, preset: .greedyDeterministic,
                instruction: "Describe the ocean in a few sentences.", context: [])
            _ = try? await adapter.rawTargetForwardsMs(for: req, forwards: max(2, steps / 8))   // warm decode kernels
            let mlxMs = try await adapter.rawTargetForwardsMs(for: req, forwards: steps)
            mlxTps = mlxMs > 0 ? Double(steps) * 1000.0 / mlxMs : 0
            fileLog.emit("📊 coreai-gpu MLX-1B int4 ms=\(String(format: "%.0f", mlxMs)) "
                + "tok/s=\(String(format: "%.1f", mlxTps))")
        } catch {
            fileLog.emit("📊 coreai-gpu MLX ERROR=\(error)")
        }

        // ---- Verdict (byte-aware): CoreAI int8 reads ~1.7× MLX-int4 bytes; competitive => kernel win per byte ----
        let ratio = mlxTps > 0 ? coreaiTps / mlxTps : 0
        let perByte = ratio * 1.7   // CoreAI int8 ~1.2GB vs MLX int4 ~0.7GB ≈ 1.7× bytes/token
        let verdict: String
        if coreaiTps <= 0 { verdict = "INCONCLUSIVE (CoreAI side failed — see ERROR above)" }
        else if ratio >= 1.0 { verdict = "STRONG kernel WIN (CoreAI-GPU ≥ MLX despite ~1.7× bytes ⇒ Neural-Accelerator advantage)" }
        else if perByte >= 1.2 { verdict = "kernel WIN per-byte (raw <MLX but ~1.7× heavier; byte-normalized still ahead)" }
        else if perByte >= 0.9 { verdict = "PARITY (no clear kernel advantage once byte-normalized)" }
        else { verdict = "LOSS (CoreAI-GPU slower even byte-normalized — no Neural-Accelerator win for this shape)" }
        fileLog.emit(String(format:
            "📊 coreai-gpu DONE coreai_%@_tok/s=%.1f mlx_int4_tok/s=%.1f raw_ratio=%.2f byte_norm_ratio≈%.2f VERDICT=%@",
            unitLabel, coreaiTps, mlxTps, ratio, perByte, verdict))
        #else
        fileLog.emit("📊 coreai-gpu SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }

    #if canImport(CoreAI)
    /// Wall-ms of `steps` raw CoreAI forwards (the decode work unit), from `startPos` (KV writes at pos < maxSeq).
    @available(iOS 27, macOS 27, *)
    private static func stepMs(
        _ session: BASCoreAIDecodeSession, steps: Int, startPos: Int
    ) async -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var tok = 1
        var i = 0
        while i < steps {
            tok = (try? await session.step(token: max(0, tok), pos: startPos + i)) ?? 1
            i += 1
        }
        return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000
    }
    #endif
}
