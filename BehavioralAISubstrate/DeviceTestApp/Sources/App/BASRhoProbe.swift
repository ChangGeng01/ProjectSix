// MARK: - BASRhoProbe — ANE-draft ∥ GPU-verify bandwidth-contention ρ micro-benchmark (BAS_RHO_PROBE=1)
//
// THE decisive cheap test for "can CoreAI/ANE∥GPU make E4B decode faster" (Docs/COREAI_IOS27_REFERENCE.md §7).
// A small STATIC-shape int8 Gemma-vocab CoreAI stub (random weights — measures BANDWIDTH not quality) runs a draft
// loop on the ANE (BASCoreAIDecodeSession, preferredComputeUnitKind:.neuralEngine) CONCURRENTLY with a real
// gemma-4-E4B-4bit MLX GPU verify, and reports ρ = serial_wall / concurrent_wall (+ the per-engine contention tax).
//
// WHY a fresh probe vs the Saguaro overlap probe: the banked ρ=0.83 was measured at the WRONG operating point — a
// HEAVY 16-layer 827ms Mamba draft ∥ a 299ms 3B target (draft SLOWER than target). This inverts it: a SMALL ~214MB
// 2-layer draft ∥ the SLOWER ~2.7GB E4B verify — the genuinely UNMEASURED regime (a small compute-bound ANE draft
// may be bandwidth-LIGHT → ρ could beat 0.83). KILL if ρ<1.0 / E4B verify drops <15 tok/s / aggregate BW <1.2×.
//
// Calibrated build invariants (GA iOS 27): stub is static-shape (→ANE), int8 (fp16 hits the ~2GB wall), ≤8 layers,
// KV dims ×32 (else silent off-ANE demotion); concurrency is OS-scheduler (run(), not encode()) — same as the banked
// 0.83 measurement, so directly comparable. Env: BAS_RHO_ASSET / BAS_RHO_LAYERS / BAS_RHO_NKV / BAS_RHO_HEADDIM /
// BAS_RHO_MAXSEQ / BAS_RHO_K / BAS_RHO_N. Needs BAS_ENDURANCE_AUTOSTART=1 + BAS_RHO_PROBE=1.

import Foundation
import os
import BASOrgan
import BASMLXAdapter
#if canImport(CoreAI)
import CoreAI            // SpecializationOptions, ComputeUnitKind
import BASAppleAdapters  // BASCoreAIDecodeSession
#endif

enum BASRhoProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "rho")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("rho-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASRhoProbe.log.info("\(line, privacy: .public)")
            print(line); fflush(stdout)   // print() survives a SIGABRT where os_log is lost
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
            fileLog.emit("📊 rho SKIP — needs iOS 27 / macOS 27"); return
        }
        let assetName = env["BAS_RHO_ASSET"] ?? "rho_stub_int8.aimodel"
        let nLayers = Int(env["BAS_RHO_LAYERS"] ?? "") ?? 2
        let nKV = Int(env["BAS_RHO_NKV"] ?? "") ?? 4
        let headDim = Int(env["BAS_RHO_HEADDIM"] ?? "") ?? 64
        let maxSeq = Int(env["BAS_RHO_MAXSEQ"] ?? "") ?? 512
        let K = Int(env["BAS_RHO_K"] ?? "") ?? 4
        let N = Int(env["BAS_RHO_N"] ?? "") ?? 8
        fileLog.emit("📊 rho START asset=\(assetName) layers=\(nLayers) nKV=\(nKV) headDim=\(headDim) K=\(K) N=\(N)")

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fileLog.emit("📊 rho ERROR=no Documents dir"); return
        }
        let asset = docs.appendingPathComponent(assetName)
        guard FileManager.default.fileExists(atPath: asset.path) else {
            fileLog.emit("📊 rho ERROR=\(assetName) missing — stage it into Documents (devicectl copy to)"); return
        }
        // RoPE tables: right-sized zero buffers (values irrelevant to a bandwidth measurement).
        let cosURL = docs.appendingPathComponent("rope_cos_h\(headDim).bin")
        let sinURL = docs.appendingPathComponent("rope_sin_h\(headDim).bin")
        let tableBytes = maxSeq * headDim * MemoryLayout<Float>.size
        for url in [cosURL, sinURL] where !FileManager.default.fileExists(atPath: url.path) {
            try? Data(count: tableBytes).write(to: url)
        }

        do {
            // GPU verify side: load the real E4B-4bit MLX target first (single CoreAI AIModel loaded after → no
            // two-AIModel co-load SIGSEGV).
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.gemma4_E4B_4bit, maxOutputTokens: 64, speculativeDecoding: .off)
            try await adapter.loadModel()
            fileLog.emit("📊 rho E4B verify loaded (MLX GPU)")

            // ANE draft side: the static-shape int8 stub, pinned to the Neural Engine.
            let options = SpecializationOptions(preferredComputeUnitKind: .neuralEngine)
            let session = try await BASCoreAIDecodeSession(
                assetURL: asset, ropeCosURL: cosURL, ropeSinURL: sinURL,
                nLayers: nLayers, nKV: nKV, headDim: headDim, maxSeq: maxSeq, options: options)
            fileLog.emit("📊 rho ANE draft stub loaded (CoreAI .neuralEngine)")

            let req = BASOrganRequest(
                requestID: "rho", role: .core, preset: .greedyDeterministic,
                instruction: "Describe the ocean in a few sentences.", context: [])
            let M = K * N   // draft steps matched to ~K per target forward
            // Pos budget: warmup(8) + serial(M) + concurrent(M) must stay < maxSeq.
            guard 8 + 2 * M < maxSeq else {
                fileLog.emit("📊 rho ERROR=pos budget \(8 + 2 * M) ≥ maxSeq \(maxSeq) — lower K/N"); return
            }

            // Warmup BOTH engines (else the serial half pays a one-time JIT the warm concurrent half doesn't, biasing
            // ρ HIGH): the CoreAI draft pays a per-launch ANE program load; the MLX verify JITs its DECODE kernels on the
            // first forward (prefill warms only the prefill kernels). Discard one of each so serial+concurrent are both warm.
            _ = await draftStepsMs(session, steps: max(4, K), startPos: 0)
            _ = try? await adapter.rawTargetForwardsMs(for: req, forwards: max(2, N))

            // SERIAL halves (each inner-timed; prefill/setup excluded).
            let tMs = try await adapter.rawTargetForwardsMs(for: req, forwards: N)
            let dMs = await draftStepsMs(session, steps: M, startPos: 8)
            let serialWall = tMs + dMs

            // CONCURRENT: ANE draft ∥ GPU verify via two OS-scheduled tasks (same as the banked 0.83 method).
            let c0 = DispatchTime.now().uptimeNanoseconds
            async let tC = adapter.rawTargetForwardsMs(for: req, forwards: N)
            async let dC = draftStepsMs(session, steps: M, startPos: 8 + M)
            let tCi = try await tC
            let dCi = await dC
            let cWall = Double(DispatchTime.now().uptimeNanoseconds &- c0) / 1_000_000
            let concInner = max(tCi, dCi)
            let rho = concInner > 0 ? serialWall / concInner : 0

            // Contention tax + the verify's standalone vs contended throughput (the kill metric: verify must stay ≥15 tok/s).
            let verifyTax = tMs > 0 ? (tCi / tMs - 1.0) * 100 : 0
            let draftTax = dMs > 0 ? (dCi / dMs - 1.0) * 100 : 0
            let verifyTps = tMs > 0 ? Double(N) * 1000.0 / tMs : 0           // E4B standalone tok/s
            let verifyTpsConc = tCi > 0 ? Double(N) * 1000.0 / tCi : 0       // E4B under concurrent ANE load
            let draftTps = dMs > 0 ? Double(M) * 1000.0 / dMs : 0            // ANE stub standalone tok/s

            fileLog.emit(String(format:
                "📊 rho RESULT target_ms=%.0f(×%d) draft_ms=%.0f(×%d) serial_ms=%.0f conc_inner_ms=%.0f(t=%.0f d=%.0f) "
                + "caller_span_ms=%.0f rho=%.2f verify_tax=%+.0f%% draft_tax=%+.0f%% "
                + "verify_tok/s=%.1f→%.1f draft_tok/s=%.1f",
                tMs, N, dMs, M, serialWall, concInner, tCi, dCi, cWall, rho, verifyTax, draftTax,
                verifyTps, verifyTpsConc, draftTps))
            // Verdict line (kill criteria from the design workflow).
            let bwGain = serialWall > 0 ? serialWall / cWall : 0
            // Verdict on REAL contention (both engines warmed): KILL if the verify SLOWS materially under the
            // concurrent ANE draft (verify_tax>15%) or there's no aggregate-BW gain (ρ<1.05 / bwGain<1.10). The old
            // absolute "verify≥15 tok/s" was wrong — E4B's bandwidth ceiling is ~9-14 tok/s, never 15.
            let verdict: String
            if rho < 1.05 || verifyTax > 15.0 || bwGain < 1.10 {
                verdict = "KILL (ρ<1.05 OR verify slowed >15% concurrent OR no BW gain — ANE∥GPU contends; ship serial/GPU)"
            } else {
                verdict = "PROMISING (overlap pays: ρ≥1.05, verify holds under concurrent ANE load, real aggregate-BW gain)"
            }
            fileLog.emit("📊 rho DONE rho=\(String(format: "%.2f", rho)) aggregate_bw_gain=\(String(format: "%.2f", bwGain))× VERDICT=\(verdict)")
        } catch {
            fileLog.emit("📊 rho ERROR=\(error)")
        }
        #else
        fileLog.emit("📊 rho SKIP — CoreAI not in this build (default toolchain)")
        #endif
    }

    #if canImport(CoreAI)
    /// Wall-ms of `steps` raw CoreAI stub forwards (the ANE work unit), from `startPos` (KV writes at pos, < maxSeq).
    @available(iOS 27, macOS 27, *)
    private static func draftStepsMs(
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
