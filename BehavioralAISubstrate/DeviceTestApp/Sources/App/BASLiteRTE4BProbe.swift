// MARK: - BASLiteRTE4BProbe — LiteRT-LM E4B memory + cancellability probe (2026-06-12)
//
// Default-OFF DeviceTestApp probe (`BAS_LITERT_E4B_PROBE=1`) that answers the two load-bearing
// questions from Docs/LITERT_LM_STUDY.md §"Open questions":
//   1. Does Gemma-3n/Gemma-4 E4B (the model MLX jetsam-kills on this device) actually LOAD + DECODE
//      within the iOS per-process memory limit via LiteRT-LM's mmap'd weights? Measure
//      task_vm_info::phys_footprint (the metric jetsam watches) on BOTH .cpu and .gpu backends.
//      The study claim to confirm/falsify: ~961 MB physical footprint for a ~3.66 GB E4B on the
//      iPhone CPU path (clean mmapped pages don't count resident) — vs MLX's full-resident footprint.
//   2. Does LiteRT's `Conversation.cancel()` interrupt an in-flight Metal decode — escaping the
//      ADR-038 uncancellable-wedge that BAS fought all session?
//
// ## Build safety — guarded by `#if canImport(LiteRTLM)`
//
// The LiteRTLM SPM binary package (v0.13.1) is NOT added to the project by default (network-fetched
// binary xcframework + the gated `.litertlm` model + the increased-memory entitlement are all
// deploy-time concerns). Until a host adds it per Docs/LITERT_PROBE_RUNBOOK.md, this compiles to a
// SAFE SKIP STUB — the build stays byte-green. Adding the package flips `canImport` true and activates
// the real probe. The real-probe body is written against the DOCUMENTED v0.13.1 Swift API
// (LITERT_LM_STUDY.md §4) and is COMPILE-VERIFIED ON FIRST PACKAGE ADD (Early-Preview API — expect
// minor signature drift to fix at that step).
//
// ## NOT a BASOrganAdapter (yet)
//
// Observation-only, off the spine — it measures, it does not wire decode into any turn. A
// `BASLiteRTOrganAdapter` (the 3-method BASOrganAdapter conformance) is promoted ONLY if this probe
// pays: E4B fits + acceptable tps + cancellable / no wedge (LITERT_LM_STUDY.md §6.5).

import Foundation
import os
import BASRuntimeCore  // BASTaskVmInfoProbe (phys_footprint — the jetsam metric)
#if canImport(LiteRTLM)
@preconcurrency import LiteRTLM
#endif

public enum BASLiteRTE4BProbe {

    private static let log = Logger(
        subsystem: "com.bas.devicetest", category: "litert-probe")

    /// Self-contained file+oslog sink (mirrors the other device probes). Writes
    /// `litert-probe-<stamp>.log` in Documents for `devicectl device copy from`.
    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first
            else { handle = nil; return }
            let url = docs.appendingPathComponent("litert-probe-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASLiteRTE4BProbe.log.info("\(line, privacy: .public)")
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }
        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

    public static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = env["BAS_LITERT_MODEL_PATH"]
            ?? docs.appendingPathComponent("gemma-3n-E4B-it-int4.litertlm").path

        fileLog.emit("📊 litert-probe START model=\(modelPath)")

        #if canImport(LiteRTLM)
        guard FileManager.default.fileExists(atPath: modelPath) else {
            fileLog.emit("📊 litert-probe ABORT — model not found at \(modelPath) "
                + "(stage the gated .litertlm per LITERT_PROBE_RUNBOOK.md)")
            return
        }
        let baselineMB = footprintMB()
        fileLog.emit("📊 litert-probe baseline_phys_mb="
            + String(format: "%.1f", baselineMB))

        for backend in liteRTBackends() {
            let r = await measure(backend: backend, modelPath: modelPath)
            fileLog.emit("📊 litert-probe RESULT backend=\(r.backend) "
                + "loaded=\(r.loaded) "
                + "phys_mb=\(String(format: "%.1f", r.physFootprintMB)) "
                + "delta_mb=\(String(format: "%.1f", r.physFootprintMB - baselineMB)) "
                + "decode_tokens=\(r.decodeTokens) "
                + "decode_ms=\(String(format: "%.0f", r.decodeMs)) "
                + "tok_per_s=\(tps(r.decodeTokens, r.decodeMs)) "
                + "cancel_interrupted=\(r.cancelInterruptedDecode.map(String.init) ?? "untested") "
                + "note=\(r.note)")
        }
        fileLog.emit("📊 litert-probe DONE — compare phys_mb vs the 3376MB jetsam cap "
            + "(study claim: E4B ≈ 961MB on .cpu); cpu mmap-win vs gpu-resident is the headline")
        #else
        fileLog.emit("📊 litert-probe SKIPPED — LiteRTLM package not linked. "
            + "Add it per Docs/LITERT_PROBE_RUNBOOK.md (SPM v0.13.1) to activate.")
        #endif
    }

    // MARK: - Helpers (always compiled)

    private struct BackendResult: Sendable {
        let backend: String
        let loaded: Bool
        let physFootprintMB: Double
        let decodeTokens: Int
        let decodeMs: Double
        let cancelInterruptedDecode: Bool?
        let note: String
    }

    private static func footprintMB() -> Double {
        let bytes = (try? BASTaskVmInfoProbe.rawSnapshot())?.physFootprintBytes ?? 0
        return Double(bytes) / (1024.0 * 1024.0)
    }

    private static func tps(_ tokens: Int, _ ms: Double) -> String {
        guard ms > 0 else { return "0" }
        return String(format: "%.1f", Double(tokens) / (ms / 1000.0))
    }

    // MARK: - LiteRT-LM path (guarded)

    #if canImport(LiteRTLM)
    /// CPU = where the mmap clean-page win should appear (~961MB); GPU/Metal = faster but ~3380MB
    /// resident (the jetsam-risk path) — measuring BOTH is the point.
    private static func liteRTBackends() -> [Backend] {
        [.cpu(threadCount: nil), .gpu]
    }

    /// Against the documented v0.13.1 API: `actor Engine(engineConfig:)` → `initialize()` →
    /// `createConversation(with:)`; `Conversation.sendMessageStream(_:)`, `.cancel()`.
    /// COMPILE-VERIFY on first package add (Early-Preview — names may drift).
    private static func measure(
        backend: Backend, modelPath: String
    ) async -> BackendResult {
        let backendName = backendLabel(backend)
        do {
            // CANONICAL decode rate via LiteRT's OWN benchmark() — controlled prefill+decode, warmed
            // via initializeForBenchmark, EXACT token counts (lastDecodeTokensPerSecond). This is the
            // same metric AI Edge Gallery reports; it replaces the chars/4 estimate + first-gen-JIT
            // contamination that under-measured. tok_per_s = bench.lastDecodeTokensPerSecond.
            let prefillN = Int(ProcessInfo.processInfo.environment["BAS_LITERT_PREFILL"] ?? "") ?? 256
            let decodeN = Int(ProcessInfo.processInfo.environment["BAS_LITERT_DECODE_CAP"] ?? "") ?? 256
            let beforeMB = footprintMB()
            let bench = try await benchmark(
                modelPath: modelPath, backend: backend,
                prefillTokens: prefillN, decodeTokens: decodeN, cacheDir: nil)
            let afterLoadMB = max(footprintMB(), beforeMB)
            let decTps = bench.lastDecodeTokensPerSecond
            let decTok = bench.lastDecodeTokenCount
            let decMs = decTps > 0 ? Double(decTok) * 1000.0 / decTps : 0

            return BackendResult(
                backend: backendName, loaded: true,
                physFootprintMB: afterLoadMB,
                decodeTokens: decTok, decodeMs: decMs,   // tok_per_s line = LiteRT's OWN canonical decode tok/s
                cancelInterruptedDecode: nil,
                note: "BENCH decode_tps=\(String(format: "%.1f", decTps)) "
                    + "prefill_tps=\(String(format: "%.1f", bench.lastPrefillTokensPerSecond)) "
                    + "ttft_s=\(String(format: "%.2f", bench.timeToFirstTokenInSecond)) "
                    + "init_s=\(String(format: "%.1f", bench.initTimeInSecond)) "
                    + "prefill_tok=\(bench.lastPrefillTokenCount) decode_tok=\(decTok) "
                    + "[cancel unchanged: CPU-yes/GPU-no from prior run]")
        } catch {
            return BackendResult(
                backend: backendName, loaded: false,
                physFootprintMB: footprintMB(),
                decodeTokens: 0, decodeMs: 0,
                cancelInterruptedDecode: nil,
                note: "error=\(error)")
        }
    }

    /// THE ADR-038 ESCAPE TEST. Start a long decode, fire `convo.cancel()` ~2s in from a concurrent
    /// task, and judge: did the stream STOP soon after cancel (interrupted ✅), or run to the safety
    /// cap / past a deadline (NOT interrupted — same wall MLX hits)? HONEST hang caveat: if cancel
    /// does nothing AND the decode hard-hangs with zero tokens, the `for try await` itself blocks —
    /// the in-loop deadline only bounds a *trickling* decode; a true uncancellable hang is the very
    /// failure we're testing for and is backstopped by the external process kill (ADR-038).
    private static func testCancel(
        engine: Engine
    ) async -> (interrupted: Bool, tokens: Int, msAfterCancel: Double, note: String) {
        let safetyTokenCap = 2048
        let cancelDelayNs: UInt64 = 2_000_000_000          // let decode run 2s before cancelling
        let inLoopDeadlineNs = DispatchTime.now().uptimeNanoseconds + 60_000_000_000  // 60s loop bound
        let longPrompt =
            "Write a long, detailed, multi-paragraph essay about the entire history of computing, "
            + "from the abacus and mechanical calculators through to modern AI accelerators."
        do {
            let convo = try await engine.createConversation(with: nil)
            let cancelAtNs = DispatchTime.now().uptimeNanoseconds + cancelDelayNs
            let canceller = Task {
                try? await Task.sleep(nanoseconds: cancelDelayNs)
                try? convo.cancel()
            }
            var tokens = 0
            var threw = false
            var hitDeadline = false
            do {
                let stream = convo.sendMessageStream(
                    Message(longPrompt))
                for try await chunk in stream {
                    tokens += max(1, chunk.toString.count / 4)
                    if tokens >= safetyTokenCap { break }
                    if DispatchTime.now().uptimeNanoseconds >= inLoopDeadlineNs {
                        hitDeadline = true; break
                    }
                }
            } catch { threw = true }   // cancel may surface as a thrown error
            canceller.cancel()
            let msAfterCancel = max(0,
                Double(DispatchTime.now().uptimeNanoseconds &- cancelAtNs) / 1_000_000)
            // Interrupted iff the stream ended SOON after cancel, below the safety cap, no deadline.
            let interrupted = !hitDeadline
                && tokens < safetyTokenCap
                && msAfterCancel < 5_000
            let note: String
            if hitDeadline { note = "NOT-interrupted-60s-deadline" }
            else if tokens >= safetyTokenCap { note = "NOT-interrupted-ran-to-cap" }
            else if msAfterCancel >= 5_000 { note = "NOT-interrupted-slow-stop" }
            else if threw { note = "interrupted-threw" }
            else { note = "interrupted-ended" }
            return (interrupted, tokens, msAfterCancel, note)
        } catch {
            return (false, 0, 0, "cancel-test-setup-error=\(error)")
        }
    }

    private static func backendLabel(_ b: Backend) -> String {
        switch b {
        case .cpu: return "cpu"
        case .gpu: return "gpu"
        @unknown default: return "other"
        }
    }
    #endif
}
