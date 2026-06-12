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
import LiteRTLM
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
            let config = EngineConfig(modelPath: modelPath, backend: backend)
            let engine = Engine(engineConfig: config)
            try await engine.initialize()
            let afterLoadMB = footprintMB()

            let convo = try engine.createConversation(with: nil)
            let startNs = DispatchTime.now().uptimeNanoseconds
            var tokens = 0
            let stream = convo.sendMessageStream(
                Message(role: .user, text: "Reply in one short sentence: name a primary color."))
            for try await chunk in stream {
                tokens += max(1, chunk.text.count / 4)
                if tokens >= 64 { try? convo.cancel(); break }
            }
            let decodeMs = Double(DispatchTime.now().uptimeNanoseconds &- startNs) / 1_000_000

            return BackendResult(
                backend: backendName, loaded: true,
                physFootprintMB: afterLoadMB,
                decodeTokens: tokens, decodeMs: decodeMs,
                cancelInterruptedDecode: nil,  // dedicated mid-decode cancel test = runbook step 4
                note: "ok")
        } catch {
            return BackendResult(
                backend: backendName, loaded: false,
                physFootprintMB: footprintMB(),
                decodeTokens: 0, decodeMs: 0,
                cancelInterruptedDecode: nil,
                note: "error=\(error)")
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
