// MARK: - BASEnduranceAppRunner
// chapter 一千零二十五.4 / M3899 — in-app endurance entrypoint
// chapter 一千零二十五.5 / M3899 — L1-L14 substrate cascade per prompt
// chapter 一千零二十五.5.5 / M3899 — audit fix(UI honesty + conf=n/a)
// chapter 一千零二十五.7 / M3899 — comprehensive turnResult instrumentation
//
// ch 1025.7 — user mandate「最最 严苛 全面 — 所有 组件 数据 都要记录」。
// Each prompt now emits 8 additional log lines covering every public
// field on `BASEBrainTurnResult` that ch 1025.5 did not surface:
//   `ctx`        — L6 BASContextFrame full signal panel (emotionalLoad,
//                  timePressure,ambiguityScore,consequenceLevel,
//                  manipulationHints,sceneType)
//   `decompose`  — L7 BASDecomposeFrame signal counts(emotions /
//                  pressure / manipulation / unknowns / contradictions
//                  / facts / goals)
//   `risk`       — L11 BASRiskCard scalars(totalRisk,uncertainty,
//                  irreversibility,manipulationStrength,gsiScore)
//   `permit`     — L11 BASActionPermit(mode,reasonCodes,allowed/
//                  blocked domains,toolScope,memoryScope,requireMirror)
//   `mem`        — L8 BASMemoryBundle(atoms,retrievalTags,conflictRefs)
//   `render`     — L12 BASRenderedOutput(headline / body / alts /
//                  explanationCodes counts — body is rule-template,
//                  NOT MLX tokens)
//   `triself`    — L10 [BASTriSelfScore] per candidate(id/ego/super/
//                  merged/veto)
//   `candidates` — L9 per-BASCandidatePath(benefit / cost /
//                  reversibility / confidence)
//   `host_gate`  — L13 hostGateValue + emergencyBrake summary
// Plus per-MLX-call:
//   `mlx-detail` — sessionCount + currentCapacity from MLXOrganAdapter
// Plus one-time boot inventory line listing NYI components(Mamba,ANE
// direct,Rust crates,MPSGraph rotation,fabric.runTurn)so a future
// operator reading the log knows EXACTLY what's tested vs not。
// See Docs/CH_1024_PLUS_OPTIMIZATION_BACKLOG.md "ch 1025.5 endurance
// coverage audit" section for the deferred-component arc plan。
//
// Bypass the xcodebuild test controller architecture so endurance
// runs survive Mac-side controller preemption。 Background:
// ch 1025 v4 endurance smoke (PID 73350) was killed at 01:38:35 AEST
// May 29 2026 when a competing xcodebuild start (PID 79959,
// ProjectEleven UITests on simulator DA99B4D8) triggered Xcode
// CoreDevice test session cleanup of all running xcodebuild test
// instances on the Mac (see Docs/CH_1024_PLUS_OPTIMIZATION_BACKLOG.md
// "ch 1025 v4 internal-loop smoke" section)。 By running the endurance
// loop inside the app process directly,Mac side can disconnect
// without killing iPhone-side execution。
//
// ch 1025.5 — each prompt now invokes `brain.process()` (L1-L14
// substrate classifier → decompose → memory → loop → triSelf →
// risk → action render → evolution synthesis) BEFORE
// `adapter.draft()` for MLX tokens。 The endurance loop now exercises
// both the substrate cascade AND the LLM end-to-end,not just MLX。
// Full `BASAgentFabricHostPipeline.runTurn()` integration is
// deferred to ch 1025.6 — requires a substrate-side
// `makeMinimalForEndurance(brain:adapter:)` factory that doesn't
// exist yet (app target lacks zero-config fabric assembly entry)。
//
// ch 1025.5.5 — audit fix-of-fix。 HIGH-1: each prompt now emits
// `🪧 ch1025 fabric_activation=bypassed reason=no_pipeline_in_runner`
// so the syslog log honestly reflects that fabric.runTurn() does
// NOT fire,even though the UI badge shows "Fabric: enabled (all)"
// because BAS_AGENT_FABRIC=enabled is in launch env。 MED-2: brain
// confidence band rendered `n/a` when nil instead of `0.00`
// (which previously implied the classifier returned 0 confidence)。
// MED-1 (operator-facing): brain singleton may stay resident on
// MLX-load-failure path,non-issue for one-shot endurance binary。
//
// Launch from Mac:
//
//   xcrun devicectl device process launch \
//     --device 9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6 \
//     --environment BAS_ENDURANCE_AUTOSTART=1 \
//     --environment BAS_INTERNAL_ITER_COUNT=100 \
//     --environment BAS_INTERNAL_MLX_PROMPTS=3 \
//     --environment BAS_INTERNAL_COOLDOWN_SEC=60 \
//     com.changgeng.basdevicetest
//
// Capture log on Mac:
//
//   idevicesyslog -u <UDID> | grep ch1025
//
// Or pull Documents/ post-run via Xcode Devices window
// ("Container" → BASDeviceTestApp → Download)
//
// Env vars(read at app launch):
//   BAS_ENDURANCE_AUTOSTART     1 = run; unset / other = idle
//   BAS_INTERNAL_ITER_COUNT     default 100
//   BAS_INTERNAL_COOLDOWN_SEC   default 60
//   BAS_INTERNAL_ADAPTIVE       default 1
//   BAS_INTERNAL_MLX_PROMPTS    default 3

import Foundation
import Darwin
import UIKit
import os
import BASHostKit
import BASMLXAdapter
import BASOrgan
import BASMemory  // ch 1025.6 — fabric roster/graph/runtime types
import BASRuntimeCore  // ch1044 — BASTaskVmInfoProbe (phys_footprint, jetsam metric)
import BASAppleAdapters  // Step-2 flip — on-device MiniLM semantic memory embedder
import BASMetalSubstrate  // ADR-039 — Metal kernel dispatchers + the determinism-boundary quarantine

// ch 1025.4 — Unified logging via `os.Logger`。 Swift `print()` does
// NOT appear in iOS system log,which means `idevicesyslog` from
// Mac cannot capture endurance progress。 By routing through
// `Logger`,emit lines are visible to:
//   - idevicesyslog -u <UDID>(real-time stream)
//   - log show / log stream / Xcode Devices Console
// while still also writing to Documents/ for post-run analysis。
private let ch1025Log = Logger(
    subsystem: BASDeviceLog.subsystem,
    category: "ch1025-endurance")

// ADR-037 — BASGlobalRecallResolver moved to Sources/BASHostKit/BASGlobalRecallResolver.swift
// (public, SPM-unit-testable). The runner wires it as the global-recall seam's atomForID backing.

@MainActor
final class BASEnduranceAppController: ObservableObject {

    // MARK: - Status surface

    enum RunStatus {
        case autostartOff
        case starting
        case running(iter: Int, totalIters: Int,
                     cumulTokens: Int, thermal: String)
        case completed(totalIters: Int, totalTokens: Int,
                       runSec: Double)
        case failed(message: String)

        var label: String {
            switch self {
            case .autostartOff:
                return "autostart=off (set BAS_ENDURANCE_AUTOSTART=1)"
            case .starting:
                return "starting…"
            case .running(let i, let t, let n, let th):
                return "iter \(i)/\(t)  tok=\(n)  th=\(th)"
            case .completed(let t, let n, let s):
                return "DONE iters=\(t) tokens=\(n) sec=\(Int(s))"
            case .failed(let m):
                return "FAILED: \(m)"
            }
        }

        /// ch1057 — true while the run is starting or in progress (button-disable guard)。
        var isActive: Bool {
            switch self {
            case .starting, .running: return true
            default: return false
            }
        }
    }

    @Published var status: RunStatus = .autostartOff
    static let shared = BASEnduranceAppController()

    private var started = false
    private var autostartConsumed = false
    private var logFileHandle: FileHandle?
    private var logFileURL: URL?

    // MARK: - Launch environment(keys + defaults, one documented place)
    //
    // The endurance launch env vars were scattered across `autostartIfEnabled`
    // and `runEndurance`。 Extracted here so each KEY string lives with its
    // DOCUMENTED default — values byte-identical to the prior inline literals。
    // `key` is the `ProcessInfo` env key;`default` is the `??` fallback the read
    // site used (the integer-parse fallback `?? N` at the numeric sites is kept
    // inline — it's the malformed-value fallback, same N as the string default)。
    private enum EnduranceEnv {
        /// `1` = run endurance;unset / other = idle。 Gate is `== "1"`。
        static let autostartKey = "BAS_ENDURANCE_AUTOSTART"
        /// Iteration count。 Default `"100"` (parse fallback 100)。
        static let iterCountKey = "BAS_INTERNAL_ITER_COUNT"
        static let iterCountDefault = "100"
        /// MLX prompts per iteration。 Default `"3"` (parse fallback 3)。
        static let mlxPromptsKey = "BAS_INTERNAL_MLX_PROMPTS"
        static let mlxPromptsDefault = "3"
        /// Base cooldown seconds。 Default `"60"` (parse fallback 60)。
        static let cooldownSecKey = "BAS_INTERNAL_COOLDOWN_SEC"
        static let cooldownSecDefault = "60"
        /// Adaptive cooldown schedule。 Default `"1"`;enabled when `== "1"`。
        static let adaptiveKey = "BAS_INTERNAL_ADAPTIVE"
        static let adaptiveDefault = "1"
        /// Wall-clock cap seconds (0 = run all iters)。 Default `"0"` (parse fallback 0)。
        static let maxRuntimeSecKey = "BAS_INTERNAL_MAX_RUNTIME_SEC"
        static let maxRuntimeSecDefault = "0"
        /// WS2 — explicit per-request MLX DECODE cap (tokens) for the endurance draft. Default "256".
        /// Bounds decode length only (defense-in-depth + shorter iters) — NOT the zero-token prefill
        /// wedge. Env-tunable for a sweep. (Was implicit: the `.core` preset's 1024.)
        static let maxDecodeTokensKey = "BAS_INTERNAL_MAX_DECODE_TOKENS"
        static let maxDecodeTokensDefault = "256"
        /// Opt-in sovereign-verdict parity shadow。 Default `""`;enabled when `== "enabled"`。
        static let shadowParityKey = "BAS_SHADOW_PARITY"
        static let shadowParityDefault = ""
        /// Opt-in WS2 fabric-authoritative N→N+1 feed-forward。 Default `"0"`;on when `== "1"`。
        static let fabricAuthFeedForwardKey = "BAS_FABRIC_AUTH_FEEDFORWARD"
        static let fabricAuthFeedForwardDefault = "0"
        /// ADR-038 §6 wedge lever: enriched contextBlock char cap (default "512" = the
        /// maxContextBlockChars backstop) + fold-top-1-only (default "0"). Shrink to test
        /// whether a smaller OOD prefill clears the on-device MLX wedge (Run B: typed prompt
        /// cleared iter1/prompt2 but the wedge MOVED to iter2/prompt2).
        static let contextBlockCharsKey = "BAS_FABRIC_CONTEXT_BLOCK_CHARS"
        static let contextBlockCharsDefault = "512"
        static let topConclusionsOnlyKey = "BAS_FABRIC_TOP_CONCLUSIONS_ONLY"
        static let topConclusionsOnlyDefault = "0"
        /// ADR-039 on-device cert — opt-in Metal smoke (default off → byte-equal). When "1", a boot-time
        /// topK dispatch + parity check + router decision are logged, certifying the Metal mechanisms
        /// (Phases 1-3) really run on the GPU + hold parity on real hardware.
        static let metalSmokeKey = "BAS_METAL_SMOKE"
        /// Opt-in ADR-037 GLOBAL durable cosineTopK recall. Default `"0"`; on when `== "1"`.
        static let globalRecallKey = "BAS_GLOBAL_RECALL"
        static let globalRecallDefault = "0"
        /// FIFO cap for the global-recall corpus — bounds BOTH the resolver map AND the engine
        /// (lockstep eviction = the real memory bound). Default `"4096"`.
        static let globalRecallCapKey = "BAS_GLOBAL_RECALL_CAP"
        static let globalRecallCapDefault = "4096"
        /// Agent-fabric activation gate。 Activated when `== "enabled"` (ADR-014 opt-in)。
        static let agentFabricKey = "BAS_AGENT_FABRIC"
    }

    // MARK: - Autostart hook

    func autostartIfEnabled() {
        guard !started else { return }
        guard !autostartConsumed else { return }
        let env = ProcessInfo.processInfo.environment
        guard env[EnduranceEnv.autostartKey] == "1" else {
            status = .autostartOff
            return
        }
        autostartConsumed = true
        // env-driven sizing (devicectl autostart / xcodebuild test path)。
        let iters = max(1, Int(env[EnduranceEnv.iterCountKey] ?? EnduranceEnv.iterCountDefault) ?? 100)
        let mlxPrompts = max(1, Int(env[EnduranceEnv.mlxPromptsKey] ?? EnduranceEnv.mlxPromptsDefault) ?? 3)
        let cooldownSec = Int(env[EnduranceEnv.cooldownSecKey] ?? EnduranceEnv.cooldownSecDefault) ?? 60
        launch(iters: iters, cooldownSec: cooldownSec, mlxPrompts: mlxPrompts)
    }

    /// ch1057 — button-triggered manual start (no env var needed)。 Tapping the in-app
    /// 「Start 1-Hour Endurance」button runs the endurance inside THIS app process,
    /// fully decoupled from the Mac / xcodebuild — so it survives the host idle-kill
    /// that capped xcodebuild-test runs at ~19 min。 Defaults size a ~1-hour run。
    /// Idempotent:a second tap while a run is active is a no-op。
    func startManual(iters: Int = 30, cooldownSec: Int = 30, mlxPrompts: Int = 2) {
        guard !started else { return }
        launch(iters: max(1, iters),
               cooldownSec: max(0, cooldownSec),
               mlxPrompts: max(1, mlxPrompts))
    }

    /// Shared start path for both the env-autostart and the manual-button entry points。
    private func launch(iters: Int, cooldownSec: Int, mlxPrompts: Int) {
        guard !started else { return }
        #if targetEnvironment(simulator)
        // The endurance loop loads MLX (Gemma-4-E2B-4bit), whose Metal device constructor
        // (`mlx::core::metal::Device::Device`) calls `std::__libcpp_verbose_abort` on the iOS
        // Simulator — a C++ abort (SIGABRT) that the Swift do/catch around loadModel() CANNOT
        // intercept. The endurance benchmark is device-only by design (on-device LLM on the
        // ANE/GPU), so refuse to start it on the simulator instead of crashing. Runs normally on
        // a physical iPhone.
        status = .failed(message:
            "endurance is device-only — MLX aborts on the Simulator; run on a physical iPhone")
        return
        #endif
        started = true
        status = .starting
        // Prevent screen auto-lock during the long run。 The operator should also set
        // Settings → Display & Brightness → Auto-Lock = Never + keep the device charging。
        UIApplication.shared.isIdleTimerDisabled = true
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runEndurance(iters: iters,
                                     cooldownSec: cooldownSec,
                                     mlxPrompts: mlxPrompts)
        }
    }

    // MARK: - System snapshot(parallel to ch 1025 test)

    private struct SystemSnapshot {
        let wallClock: Date
        let monotonicNs: UInt64
        let thermalState: String
        let isLowPowerMode: Bool
        let activeProcessors: Int
        let totalProcessors: Int
        let memoryRssMB: Double
        let memoryFootprintMB: Double
        let availableMemoryMB: Int
    }

    private nonisolated func snapshot() -> SystemSnapshot {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size
            / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(
                to: integer_t.self, capacity: Int(count)
            ) { iptr in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    iptr, &count)
            }
        }
        let rssMB: Double
        if result == KERN_SUCCESS {
            rssMB = Double(info.resident_size)
                / 1024.0 / 1024.0
        } else {
            rssMB = 0
        }
        // ch1044 fix: report phys_footprint (the OS metric jetsam actually uses), NOT
        // info.virtual_size — which is the ~400 GB of reserved 64-bit address space
        // (near-constant, independent of real memory) and made footprint_mb useless for
        // the endurance monitor. mach_task_basic_info has no phys_footprint field; use the
        // substrate's TASK_VM_INFO probe (single source of truth).
        let footprintMB = Double(
            (try? BASTaskVmInfoProbe.rawSnapshot())?.physFootprintBytes ?? 0)
            / 1024.0 / 1024.0
        let availMB = Int(os_proc_available_memory())
            / 1024 / 1024
        return SystemSnapshot(
            wallClock: Date(),
            monotonicNs: DispatchTime.now().uptimeNanoseconds,
            thermalState: Self.thermalStateString(),
            isLowPowerMode: ProcessInfo.processInfo
                .isLowPowerModeEnabled,
            activeProcessors: ProcessInfo.processInfo
                .activeProcessorCount,
            totalProcessors: ProcessInfo.processInfo
                .processorCount,
            memoryRssMB: rssMB,
            memoryFootprintMB: footprintMB,
            availableMemoryMB: availMB)
    }

    private nonisolated static func thermalStateString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Monotonic clock(ch 1025.10 MED-mono fix)

    /// ch 1025.10 — monotonic now,in nanoseconds。 ALL latency/
    /// duration deltas use this(not `Date()`)。 Wall-clock
    /// `Date().timeIntervalSince` is subject to NTP steps / DST /
    /// manual clock changes — on a 10-hour run that silently
    /// corrupts every latency + the p50/p99/avg derived from them。
    /// `DispatchTime.now().uptimeNanoseconds` is monotonic(does not
    /// move when the wall clock is adjusted)。 `snapshot()` already
    /// captured this but only LOGGED it — now it drives the deltas。
    private nonisolated func monoNowNs() -> UInt64 {
        return DispatchTime.now().uptimeNanoseconds
    }

    /// Elapsed milliseconds between two `monoNowNs()` readings。
    private nonisolated func monoElapsedMs(
        since startNs: UInt64
    ) -> Double {
        let now = monoNowNs()
        // Monotonic ⇒ now ≥ startNs;guard defensively anyway。
        let deltaNs = now >= startNs ? now - startNs : 0
        return Double(deltaNs) / 1_000_000.0
    }

    // MARK: - Adaptive cooldown(matches ch 1025 schedule)

    /// ch 1025.11 cooldown thresholds/formulas, extracted (same exact values) so
    /// the `cooldownSecFor` policy numbers live in one named place。 The formulas
    /// combine these with the runtime `base` cooldown:`base * multiplier + addend`,
    /// floored at the per-state floor。 The `sustainedLoad*` pair is the shared
    /// `base*2+60` form used by BOTH the serious floor formula AND the light
    /// schedule's heavy-iter (default) step。
    private enum CooldownPolicy {
        // `critical` thermal:base*3+120, ≥300s floor。
        static let criticalMultiplier = 3
        static let criticalAddendSec = 120
        static let criticalFloorSec = 300
        // `serious` thermal:base*2+60, ≥180s floor(measured zero-recovery <180s)。
        static let seriousFloorSec = 180
        // Shared `base*2+60` form (serious floor body + light schedule default)。
        static let sustainedLoadMultiplier = 2
        static let sustainedLoadAddendSec = 60
        // Light schedule mid-step (iter 3...5):base+30。
        static let lightStepAddendSec = 30
    }

    private nonisolated func cooldownSecFor(
        iter: Int, base: Int, adaptive: Bool,
        thermalState: String
    ) -> Int {
        guard adaptive else { return base }
        // ch 1025.11 — DATA-DRIVEN(10hr endurance 2026-05-29,first
        // time the 10hr data actually reshaped behavior)。 Measured
        // cooldown→recovery proved <180s at `serious` is ZERO-recovery:
        // 8/8 serious→serious at 60-90s,AND 180s was still wasted
        // while heat peaked at iter 6-8;ALL 5 serious→nominal
        // recoveries occurred at ≥180s。 So the HIGH-heat states gate on
        // MEASURED thermal,not blind iter count — `serious` gets a ≥180s
        // floor(skipping the empirically-wasted 60-90s steps the old
        // iter-schedule burned),`critical` 300s。 The fair/nominal
        // states are NOT thermal-gated:they keep the original light iter
        // schedule(base / base+30 / base*2+60 by iter band)。 This is the
        // test-infra PROTOTYPE of ch 1026's thermal-aware kernel policy
        // (same data,same ≥180s threshold)— validating the thermal-
        // feedback idea cheaply before it graduates to the substrate
        // executor。
        switch thermalState {
        case "critical":
            return max(
                base * CooldownPolicy.criticalMultiplier
                    + CooldownPolicy.criticalAddendSec,
                CooldownPolicy.criticalFloorSec)
        case "serious":
            return max(
                base * CooldownPolicy.sustainedLoadMultiplier
                    + CooldownPolicy.sustainedLoadAddendSec,
                CooldownPolicy.seriousFloorSec)  // ≥180s floor(measured)
        default:  // fair / nominal — light iter schedule(NOT thermal-gated)
            switch iter {
            case 1...2:   return base
            case 3...5:   return base + CooldownPolicy.lightStepAddendSec
            default:      return base * CooldownPolicy.sustainedLoadMultiplier
                                 + CooldownPolicy.sustainedLoadAddendSec
            }
        }
    }

    // MARK: - Durable-store identity constants(ch1063/ch1064)
    //
    // LOAD-BEARING for cross-restart durability:the SQLite filenames key the
    // Documents-backed atom + vector stores that must survive an app restart,and
    // the provider-version tags the persisted embeddings。 Extracted (same exact
    // strings) so they live in one place;changing any of these silently orphans a
    // prior run's durable memory。
    private static let memoryAtomsDBFilename = "bas-memory-atoms.sqlite"
    private static let vectorIndexDBFilename = "bas-vector-index.sqlite"
    private static let embeddingProviderVersion = "MiniLM-L6-v2-coreml-fp32-v1"

    /// ch1062 WS2 — max rounds for the fabric-authoritative multi-round loop。
    /// Extracted (same value) from the inline `maxRounds:` arg at the loopResult
    /// call site。
    private static let fabricAuthMaxRounds = 5

    private nonisolated static let promptPool: [String] = [
        "On-device inference matters for privacy. Why is this true?",
        "Summarize:Swift actors prevent data races by isolation。",
        "List 3 reasons MLX beats Core ML on iPhone Air A19 for LLM。",
        "Explain thermal throttling on Apple Silicon under sustained load。",
        "Generate a one-sentence intro for an LLM substrate test framework。",
        "How does an attention head handle a 512-token context window?",
        "What are the trade-offs between Q4 and Q8 quantization for Gemma?",
        "Describe iPhone Air A19 ANE capacity for low-precision matmul。",
    ]

    // MARK: - Log destination(stdout + Documents file)

    private func openLogFile() {
        let docsRoot = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first
        guard let docs = docsRoot else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = fmt.string(from: Date())
        let url = docs.appendingPathComponent(
            "ch1025-endurance-\(stamp).log")
        FileManager.default.createFile(
            atPath: url.path, contents: nil)
        if let fh = try? FileHandle(forWritingTo: url) {
            logFileHandle = fh
            logFileURL = url
        }
    }

    private nonisolated func emit(_ line: String) {
        // stdout — useful for Xcode console attach
        print(line)
        // os.Logger.notice — captured by idevicesyslog / log stream
        // `\(line, privacy: .public)` marker required;default is
        // `.auto` which redacts non-literal interpolations。
        ch1025Log.notice("\(line, privacy: .public)")
    }

    @MainActor
    private func writeToLogFile(_ line: String) {
        guard let fh = logFileHandle else { return }
        let withNL = line + "\n"
        if let data = withNL.data(using: .utf8) {
            try? fh.write(contentsOf: data)
        }
    }

    @MainActor
    private func closeLogFile() {
        try? logFileHandle?.close()
        logFileHandle = nil
    }

    // MARK: - Run loop

    // ch 1025.12 #4 fix:`nonisolated` so the multi-hour loop actually
    // runs OFF the MainActor(the `Task.detached` intent)。 Pre-fix the
    // method inherited the class's @MainActor → the whole loop +300s
    // sleeps were main-actor-pinned。 Every self-state touch inside is
    // already wrapped in `await MainActor.run { … }`(status / log
    // handle),so making the method nonisolated is safe:isolated work
    // hops explicitly,everything else(snapshot / brain / mlx / emit)
    // is genuinely off-main where it belongs。
    private nonisolated func runEndurance(iters: Int, cooldownSec: Int,
                                          mlxPrompts mlxPromptsArg: Int) async {
        let env = ProcessInfo.processInfo.environment
        // ch1057 — sizing now arrives as params (from the env-autostart path OR the
        // in-app button)。 The ≥1 clamp is kept here as the last line of defense:a
        // 0/negative count would make `1...totalIters` a lowerBound>upperBound range
        // that TRAPS at runtime (skipping closeLogFile/idleTimer cleanup)。
        let totalIters = max(1, iters)
        let mlxPrompts = max(1, mlxPromptsArg)
        let baseCooldown = cooldownSec
        let adaptive = (
            env[EnduranceEnv.adaptiveKey] ?? EnduranceEnv.adaptiveDefault) == "1"
        // ch1057 — optional wall-clock cap (seconds; 0 = run all iters). Lets a
        // "run for N hours" launch finish CLEANLY at the cap regardless of iter count
        // (the post-loop summary + closeLogFile + idleTimer reset still run).
        let maxRuntimeSec = Int(
            env[EnduranceEnv.maxRuntimeSecKey] ?? EnduranceEnv.maxRuntimeSecDefault) ?? 0
        // WS2 — explicit low decode cap on each endurance MLX request (bounds decode, not prefill).
        let maxDecodeTokens = max(1, Int(
            env[EnduranceEnv.maxDecodeTokensKey] ?? EnduranceEnv.maxDecodeTokensDefault) ?? 256)
        // ADR-038 §6 wedge lever — configurable enriched-prefill size for the on-device A/B
        // (shrink the feed-forward contextBlock / fold top-1 only). Defaults = byte-equal.
        let fabricContextBlockChars = max(0, Int(
            env[EnduranceEnv.contextBlockCharsKey] ?? EnduranceEnv.contextBlockCharsDefault) ?? 512)
        let fabricTopConclusionsOnly =
            (env[EnduranceEnv.topConclusionsOnlyKey] ?? EnduranceEnv.topConclusionsOnlyDefault) == "1"
        // ch1044 ADR-022 #3 — OPT-IN sovereign-verdict parity shadow。
        // Default OFF (env unset) → byte-equal:no projection,no verify,no log。
        // With `BAS_SHADOW_PARITY=enabled`,each turn's coordinator verdict is
        // compared against the engine's (observation-only — NEVER halts) so an
        // on-device endurance run gathers ADR-022 §6 parity evidence。
        let shadowParityEnabled =
            (env[EnduranceEnv.shadowParityKey] ?? EnduranceEnv.shadowParityDefault) == "enabled"
        // ch1066 全面修复 — OPT-IN gate for the WS2 fabric-authoritative N→N+1
        // feed-forward (default OFF). DEFAULT-ON regressed the on-device endurance
        // run: the enriched prompt (raw + fabric JSON conclusions) fed a long
        // out-of-distribution structured blob into MLX eval and wedged the small 4-bit
        // gemma at iter=1 prompt=2 — EVERY run today froze there, vs June-4's 2408
        // iters on raw prompts (same device, looser memory). Default OFF restores the
        // verified June-4 behavior (ADR-014 opt-in / R1 不上未验证). Set
        // `BAS_FABRIC_AUTH_FEEDFORWARD=1` only after the sanitized enriched-prompt
        // decode is proven non-wedging on-device.
        let fabricAuthFeedForward =
            (env[EnduranceEnv.fabricAuthFeedForwardKey] ?? EnduranceEnv.fabricAuthFeedForwardDefault) == "1"
        // ADR-037 — opt-in GLOBAL durable recall (default OFF → verify-on, mirrors fabricAuthFeedForward).
        let globalRecallEnabled =
            (env[EnduranceEnv.globalRecallKey] ?? EnduranceEnv.globalRecallDefault) == "1"
        // Floor + default single-sourced (no bare 64/4096): env value if parseable, else the documented
        // default constant, else the floor. Floor = BASGlobalRecallResolver.minCap.
        let globalRecallCap = max(
            BASGlobalRecallResolver.minCap,
            Int(env[EnduranceEnv.globalRecallCapKey] ?? "")
                ?? Int(EnduranceEnv.globalRecallCapDefault) ?? BASGlobalRecallResolver.minCap)
        // ch1066 再查 — a per-turn wall-clock TIMEOUT around adapter.draft was tried here
        // and REMOVED after on-device proof it cannot work: the MLX decode is a SYNCHRONOUS,
        // UNCANCELLABLE Metal eval, so (a) a structured task-group timeout hangs in teardown
        // awaiting the wedged child, and (b) the GPU wedge gets the app killed within tens of
        // seconds regardless — a decode-timeout races a kill it can't win and the GPU stays
        // wedged. The robust fix is to PREVENT the wedge: keep the feed-forward gate OFF
        // (above) + sanitize/bound the enriched prompt (BASAgentFabricAuthoritativeProjection).
        // ch 1025.10 — monotonic run start(NTP/DST-safe)。
        let runStartNs = monoNowNs()

        await MainActor.run {
            // ch1066 — disable auto-lock at the START of the run (before the brain load) so the
            // hands-off autostart path keeps the screen lit for an unattended long run. The
            // button path (startManual) already disables it on tap; the autostart path
            // (autostartIfEnabled → launch) bypasses that, so without this the screen locks, the
            // foregroundless app backgrounds, and iOS jetsam-kills it (signal 9). Required for a
            // 10h endurance run.
            UIApplication.shared.isIdleTimerDisabled = true
            self.openLogFile()
        }

        await emitBoth(
            "📊 ch1025 host config iters=\(totalIters) " +
            "mlx_prompts=\(mlxPrompts) " +
            "base_cooldown=\(baseCooldown)s " +
            "adaptive=\(adaptive)")

        var memsize: UInt64 = 0
        var memsizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memsize,
                     &memsizeLen, nil, 0)
        let physRamGB = Double(memsize)
            / 1024.0 / 1024.0 / 1024.0

        await emitBoth(String(format:
            "📊 ch1025 host device phys_ram_gb=%.1f " +
            "total_cpu=%d active_cpu=%d os=%@",
            physRamGB,
            ProcessInfo.processInfo.processorCount,
            ProcessInfo.processInfo.activeProcessorCount,
            ProcessInfo.processInfo
                .operatingSystemVersionString))

        let initialSnap = snapshot()
        await emitBoth(formatSnap(initialSnap, iter: 0,
                                  phase: "initial"))

        // ch 1025.5 — L1-L14 brain cascade (real substrate, not just MLX)
        await emitBoth(
            "📍 ch1025 BASCognitiveBrain.makeWithDefaults loading")
        let brain: BASCognitiveBrain
        // ch1063 — DURABLE cross-restart memory store: a FILE-BACKED SQLite atom store under Documents.
        // This app is a REAL host that DRIVES brain.refreshMemory() at start + drainMemoryIntents() per
        // iteration. Atoms (incl. content) persist as payload_json and survive an app restart.
        let memoryStore: BASSQLiteMemoryAtomStore?
        // ch1064 — durable VECTOR INDEX (persisted embeddings, BLOB) so refresh() loads vectors on
        // restart instead of re-embedding every atom via CoreML.
        let memoryVectorIndex: BASSQLiteVectorIndexStorage?
        // ADR-037 — function-local (NOT a @MainActor stored prop, which runEndurance's nonisolated
        // context can't touch): the in-memory global-recall engine + resolver, built in the brain-init
        // block below and read by the per-turn incremental sync. Retained for the whole runEndurance
        // call; the seam closures capture them strongly too.
        var globalRecallEngine: BASRoutedVectorIndexStorage? = nil
        var globalRecallResolver: BASGlobalRecallResolver? = nil
        // ADR-037 — monotonic "seen" set: the per-turn delta-sync gate. Each atom is synced to the
        // engine+resolver exactly once (when first seen WITH an embedding); the FIFO cap then keeps the
        // newest `cap`. Gating on this (NOT resolver presence) avoids re-syncing evicted atoms — which
        // would oscillate the capped membership + thrash O(corpus)/turn past the cap.
        var globalRecallSynced = Set<String>()
        let cognitiveBrainStartNs = monoNowNs()
        do {
            // Step-2 flip: wire the on-device MiniLM embedder so the brain's default L8 memory is
            // real semantic vector recall (falls back to legacy Jaccard if the model can't load).
            let memoryEmbed = BASMiniLMEmbeddingProvider()?.syncEmbedClosure()
            // ch1063/ch1064 — when the routed backend is active, wire opt-in DURABLE persistence to a
            // file-backed BASSQLiteMemoryAtomStore (full content as payload_json — survives restart,
            // unlike the in-memory event store whose reducer replays content empty per the privacy
            // doctrine) AND a file-backed BASSQLiteVectorIndexStorage (persisted embeddings). The brain
            // queues self-populated atoms during process(); THIS host flushes them via
            // drainMemoryIntents() each iteration and reloads them via refreshMemory() at start.
            let memoryPersistence: BASRoutedMemoryPersistence?
            if memoryEmbed != nil {
                let docs = FileManager.default.urls(
                    for: .documentDirectory, in: .userDomainMask).first!
                let store = try BASSQLiteMemoryAtomStore(
                    databaseURL: docs.appendingPathComponent(Self.memoryAtomsDBFilename))
                let vindex = try BASSQLiteVectorIndexStorage(
                    databaseURL: docs.appendingPathComponent(Self.vectorIndexDBFilename))
                memoryStore = store
                memoryVectorIndex = vindex
                // ADR-037 — OPT-IN GLOBAL durable recall (BAS_GLOBAL_RECALL=1). Build a SEPARATE
                // in-memory Rust L8 engine + a bounded resolver from the durable store WITHOUT
                // re-embedding (reuse persisted vectors — preserves ch1064), and wire the cosineTopK
                // seam over the FULL durable corpus (recall reaches BEYOND the ≤64 in-memory window).
                // The durable BASSQLiteVectorIndexStorage (system SQLite3) stays the UNTOUCHED source
                // of truth; the engine is a private :memory: replica (rusqlite-bundled) — never the
                // same WAL file (two sqlite libs on one -shm = corruption). nil seam ⇒ byte-equal-off
                // (ADR-014). Cross-restart durability is preserved by construction (the durable write
                // path is unchanged); the engine is rebuilt from it at startup + synced per turn.
                var globalSeam: BASGlobalRecallSeam? = nil
                if globalRecallEnabled {
                    let engine = try BASRoutedVectorIndexStorage(inMemory: ())
                    let resolver = BASGlobalRecallResolver(cap: globalRecallCap)
                    let pin = BASL8RoutedMemoryService.Parameters.atomSource
                    let durableAtoms = (try? await store.allAtoms()) ?? []
                    let durableEntries = await vindex.allEntries()
                    let entryByID = Dictionary(
                        durableEntries.map { ($0.atomID, $0) }, uniquingKeysWith: { a, _ in a })
                    // Load only the NEWEST `cap` durable atoms into the engine+resolver (recency — the
                    // FIFO keeps the newest); mark EVERY durable atom "seen" so the per-turn delta-sync
                    // handles only NEW atoms (monotonic, no churn). `allAtoms()` is created-ASC, so the
                    // suffix is the newest. A newest-window atom missing its vector is left UNSEEN so the
                    // per-turn sync retries it once the embedding lands (no resolver-only strand).
                    let newest = durableAtoms.suffix(globalRecallCap)
                    let newestIDs = Set(newest.map { $0.id.uuidString })
                    for record in durableAtoms where !newestIDs.contains(record.id.uuidString) {
                        globalRecallSynced.insert(record.id.uuidString)   // older than window — excluded
                    }
                    for record in newest {
                        let id = record.id.uuidString
                        guard let e = entryByID[id] else { continue }     // no vector → retried next turn
                        do {
                            try await engine.upsert(BASVectorIndexEntry(
                                atomID: id, normalizedEmbedding: e.normalizedEmbedding, domain: pin))
                            resolver.put(id: id,                          // newest.count ≤ cap ⇒ no evict
                                atom: BASL8RoutedMemoryService.memoryAtom(from: record),
                                domain: record.sourceType)
                            globalRecallSynced.insert(id)
                        } catch {
                            await emitBoth("⚠️ ADR-037 engine upsert failed id=\(id): \(error)")
                        }
                    }
                    globalRecallEngine = engine
                    globalRecallResolver = resolver
                    let corpus = await engine.totalCount
                    await emitBoth(
                        "📍 ADR-037 global recall ACTIVE corpus=\(corpus) resolver=\(resolver.count) " +
                        "cap=\(globalRecallCap) domain=\(pin)")
                    globalSeam = BASGlobalRecallSeam(
                        cosineTopK: { [engine, pin, resolver] q, k in
                            resolver.assertNotWriting()   // no-op in release; guards the ENGINE read too
                            return (try? engine.cosineTopKAtomIDsSync(forDomain: pin, query: q, k: k)) ?? []
                        },
                        atomForID: { [resolver] id in
                            resolver.assertNotWriting()   // no-op in release; guards the resolver read
                            return resolver.lookupSync(id: id)
                        })
                } else {
                    await emitBoth("📍 ADR-037 global recall OFF (BAS_GLOBAL_RECALL!=1)")
                }
                memoryPersistence = BASRoutedMemoryPersistence(
                    loadAllAtoms: { (try? await store.allAtoms()) ?? [] },
                    admitAtom: { _ = try? await store.admit($0) },
                    atomStore: store,
                    loadEmbedding: { await vindex.entry(forID: $0)?.normalizedEmbedding.vector },
                    upsertEmbedding: { id, vec, domain in
                        _ = try? await vindex.upsert(BASVectorIndexEntry(
                            atomID: id,
                            normalizedEmbedding: BASEmbedding(
                                vector: vec, dimension: vec.count,
                                providerVersion: Self.embeddingProviderVersion).normalized,
                            domain: domain))
                    },
                    globalRecall: globalSeam)
            } else {
                memoryStore = nil
                memoryVectorIndex = nil
                memoryPersistence = nil
            }
            await emitBoth(memoryEmbed != nil
                ? "📍 ch1061 memory backend = routed+MiniLM (on-device semantic) + durable SQLite (cross-restart)"
                : "📍 ch1061 memory backend = legacy Jaccard (MiniLM unavailable)")
            brain = try await BASCognitiveBrain.makeWithDefaults(
                memoryEmbed: memoryEmbed,
                memoryPersistence: memoryPersistence)
        } catch {
            let msg = "Brain init failed: \(error)"
            await emitBoth("⚠️ ch1025 \(msg)")
            await MainActor.run {
                self.status = .failed(message: msg)
                self.started = false
                self.closeLogFile()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            return
        }
        let cognitiveBrainMs = monoElapsedMs(
            since: cognitiveBrainStartNs)
        await emitBoth(String(format:
            "📍 ch1025 BASCognitiveBrain loaded load_ms=%.0f",
            cognitiveBrainMs))

        // ch1063 — CROSS-RESTART proof: reload the durable store into the routed snapshot at start.
        // store_atoms is 0 on launch #1 over a fresh container, and >0 on launch #2 over the SAME
        // container — i.e. a prior run's self-populated memory survived an app restart.
        if let store = memoryStore {
            await brain.refreshMemory()
            let preloaded = (try? await store.allAtoms().count) ?? 0
            let vidxEntries = (memoryVectorIndex != nil)
                ? await memoryVectorIndex!.totalCount : 0
            await emitBoth(
                "📍 ch1063 memory reload-at-start store_atoms=\(preloaded) " +
                "vector_index_entries=\(vidxEntries) " +
                "(>0 on 2nd launch over same container = cross-restart durable content + embeddings)")
        }

        // ch 1025.6 — REAL fabric pipeline(closes the last
        // self-audit gap:fabric was ALWAYS bypassed before)。
        // Investigation(this chapter)found ch 1025.5's "needs 200
        // LOC / 11 services / @testable" deferral was stale,exactly
        // like the ch 1027 Rust misdiagnosis:all 10 `BASML*Service`
        // are PUBLIC(Sources/BASHostKit),9 have no-arg `init()`,
        // and `BASContextClassifierMLAdapter()` already works in-app
        // (ch 1025.5.0)。 So the app CAN build a real coordinator +
        // fabric runtime + 4-seat roster from public API in ~25 LOC。
        // `pipeline.runTurn(...)` then fires per prompt fed by the
        // turnResult fields brain.process() already produces。 Only
        // active when BAS_AGENT_FABRIC=enabled(env gate inside
        // runTurn);otherwise it returns activated=false(no behavior
        // change — ADR-014 OPT-IN preserved)。
        let fabricPipeline: BASAgentFabricHostPipeline?
        do {
            let fabricRuntime = BASAgentFabricRuntime(
                roster: BASAgentTurnRoster(
                    scout: BASAgentSpec(
                        agentID: "scout.1", role: .scout,
                        writeDomains: [.situationField],
                        defaultLeaseProfile: .hotSeat,
                        visibility: .high),
                    planner: BASAgentSpec(
                        agentID: "planner.1", role: .planner,
                        writeDomains: [.candidateFrontier],
                        defaultLeaseProfile: .hotSeat,
                        visibility: .high),
                    risk: BASAgentSpec(
                        agentID: "risk.1", role: .risk,
                        writeDomains: [.riskField],
                        defaultLeaseProfile: .hotSeat,
                        visibility: .high),
                    surface: BASAgentSpec(
                        agentID: "surface.1", role: .surface,
                        writeDomains: [.renderFrame],
                        defaultLeaseProfile: .hotSeat,
                        visibility: .high)),
                graph: BASSharedStateGraph())
            let fabricCoordinator = try BASEBrainRuntimeCoordinator(
                powerClockService: BASMLPowerClockService(),
                hostProfileService: BASMLHostProfileService(),
                contextService: BASMLContextService(
                    adapter: BASContextClassifierMLAdapter()),
                decomposeService: BASMLDecomposeService(),
                memoryService: BASMLMemoryService(),
                loopService: BASMLLoopService(),
                triSelfService: BASMLTriSelfService(),
                riskService: BASMLRiskService(),
                actionService: BASMLActionService(),
                evolutionService: BASMLEvolutionService(),
                agentFabric: fabricRuntime)
            fabricPipeline = BASAgentFabricHostPipeline(
                coordinator: fabricCoordinator,
                sessionID: "ch1025-endurance")
            await emitBoth(
                "📍 ch1025 fabric pipeline constructed " +
                "(4-seat roster:scout/planner/risk/surface)")
        } catch {
            fabricPipeline = nil
            await emitBoth(
                "⚠️ ch1025 fabric pipeline construct failed=" +
                "\(error) — falling back to bypass")
        }

        // ch1062 WS2 — the Agent Fabric AUTHORITATIVE multi-round loop is now built
        // into the DeviceTestApp endurance path for observation. The actual N→N+1
        // feed-forward fold is gated by BAS_FABRIC_AUTH_FEEDFORWARD (default OFF);
        // library makeWithDefaults stays byte-equal-off. When enabled, turn N's
        // accepted fabric deltas fold into turn N+1's userInput (INPUT-class,
        // verdict-gated — 红线 7 / 不变量 #2; the sovereign verdict stays sole authority).
        let fabricAuthRuntime = BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
                scout: BASAgentSpec(
                    agentID: "scout.1", role: .scout,
                    writeDomains: [.situationField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                planner: BASAgentSpec(
                    agentID: "planner.1", role: .planner,
                    writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                risk: BASAgentSpec(
                    agentID: "risk.1", role: .risk,
                    writeDomains: [.riskField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                surface: BASAgentSpec(
                    agentID: "surface.1", role: .surface,
                    writeDomains: [.renderFrame],
                    defaultLeaseProfile: .hotSeat, visibility: .high)),
            graph: BASSharedStateGraph(),
            mode: .authoritative)
        await emitBoth(
            "📍 ch1062 fabric-authoritative runtime constructed " +
            "(.authoritative loop observable; N→N+1 feed-forward opt-in/default-off)")

        // MLX model load
        await emitBoth(
            "📍 ch1025 MLXOrganAdapter loading Gemma 4 E2B")
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        let brainLoadStartNs = monoNowNs()
        do {
            try await adapter.loadModel()
        } catch {
            let msg = "MLX load failed: \(error)"
            await emitBoth("⚠️ ch1025 \(msg)")
            await MainActor.run {
                self.status = .failed(message: msg)
                self.started = false
                self.closeLogFile()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            return
        }
        let brainLoadMs = monoElapsedMs(
            since: brainLoadStartNs)
        let isLoaded = await adapter.isModelLoaded()
        await emitBoth(String(format:
            "📍 ch1025 MLXOrganAdapter loaded load_ms=%.0f " +
            "is_loaded=%@",
            brainLoadMs, isLoaded ? "true" : "false"))

        if !isLoaded {
            let msg = "MLX not loaded post-loadModel"
            await emitBoth("⚠️ ch1025 \(msg)")
            await MainActor.run {
                self.status = .failed(message: msg)
                self.started = false
                self.closeLogFile()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            return
        }

        let postLoadSnap = snapshot()
        await emitBoth(formatSnap(postLoadSnap, iter: 0,
                                  phase: "post_brain_load"))

        // ch 1025.7 — explicit coverage inventory in boot log so
        // operators reading the syslog know EXACTLY what's exercised
        // vs what's NYI(grep-able)。 See BACKLOG "ch 1025.5
        // endurance coverage audit" section for the deferred arc。
        // ch 1025.8 — HONEST fabric token. Was hardcoded
        // "fabric_runTurn(ch1025.6_activated)" — an overclaim: it said
        // "activated" even when the BAS_AGENT_FABRIC gate is OFF (the
        // default), so the boot line disagreed with the per-prompt
        // `activated=false` truth. Now derived from the SAME predicate
        // the adapter uses (BASAgentFabricFullTurnAdapter.swift:385:
        // environment["BAS_AGENT_FABRIC"] == "enabled") + construction
        // success, so the boot line cannot lie about activation again.
        let fabricGateOn = (env[EnduranceEnv.agentFabricKey] == "enabled")
        let fabricInventory: String
        if fabricPipeline == nil {
            fabricInventory = "construct_failed"
        } else if fabricGateOn {
            fabricInventory = "active"
        } else {
            fabricInventory = "constructed_gate_off"
        }
        await emitBoth(
            "📊 ch1025 inventory " +
            "exercised=mlx_gemma4_E2B_4bit+" +
            "coreml_BASContextClassifier_18Kparams+" +
            "L0_to_L14_cascade_all14_surfaced(ch1025.13)+" +
            "fabric_runTurn(\(fabricInventory))+" +
            "mamba_SSM(ch1033_boot_probe)+" +
            "L8_LRU_bounded " +
            "nyi=ANE_utilization_pct(WONTDO_iOS_sandbox)+" +
            "thermal_executor_wire(ch1026_5axis_perf)+" +
            "multi_organ_real_LLM(ch1036)")

        // ADR-039 on-device cert — Metal smoke (opt-in BAS_METAL_SMOKE; default off → byte-equal). A
        // self-contained boot-time topK dispatch + on-device parity + router decision: proves the Metal
        // mechanisms (Phases 1-3) really run on the GPU + agree with the CPU reference on real hardware,
        // ahead of the deep L8/RunTurn integration.
        if (env[EnduranceEnv.metalSmokeKey] ?? "0") == "1" {
            let smokeQuery: [Float] = [0.2, 0.5, 0.1, 0.9]
            var smokeCorpus: [Float] = []
            for r in 0..<64 {
                for d in 0..<4 {
                    smokeCorpus.append(Float((r * 7 + d * 3) % 11) / 11.0 + 0.013 * Float(r % 3))
                }
            }
            let smokeDim = 4, smokeK = 5
            let cpuTop = BASMetalTopKDispatcher.cpuReference(
                query: smokeQuery, corpus: smokeCorpus, dim: smokeDim, k: smokeK)
            let smokeRouting = BASMetalKernelDispatchRouter.decide(
                op: .matMul, thermalState: .nominal, anePriority: .aneFirst).routing
            let smokeDispatcher = BASMetalTopKDispatcher(loader: BASMetalKernelLibraryLoader())
            let smokeT0 = monoNowNs()
            do {
                let approx = try await smokeDispatcher.dispatch(
                    query: smokeQuery, corpus: smokeCorpus, dim: smokeDim, k: smokeK)
                let ms = Double(monoNowNs() - smokeT0) / 1_000_000.0
                let metalTop = approx.approximateOnly()
                let sameSet = Set(metalTop.map(\.rowIndex)) == Set(cpuTop.map(\.rowIndex))
                let cpuByRow = Dictionary(uniqueKeysWithValues: cpuTop.map { ($0.rowIndex, $0.score) })
                let maxErr = metalTop.map { abs($0.score - (cpuByRow[$0.rowIndex] ?? .nan)) }.max() ?? 0
                await emitBoth(String(format:
                    "📊 ch1025 metal-smoke gpu=%@ topk_ms=%.2f parity_set_ok=%@ max_score_err=%.6f routing=%@ hits=%d",
                    approx.provenance.didRunOnGPU ? "true" : "false", ms,
                    sameSet ? "true" : "false", maxErr, smokeRouting.rawValue, metalTop.count))
            } catch {
                let ms = Double(monoNowNs() - smokeT0) / 1_000_000.0
                await emitBoth(String(format:
                    "📊 ch1025 metal-smoke gpu=false FALLBACK topk_ms=%.2f routing=%@ error=%@",
                    ms, smokeRouting.rawValue, String(describing: error)))
            }
        }

        var iterDurationMs: [Double] = []
        var iterMlxTokens: [Int] = []
        var iterRssBefore: [Double] = []
        var iterRssAfter: [Double] = []
        var iterThermalBefore: [String] = []
        var iterThermalAfter: [String] = []
        var iterAvailMemBefore: [Int] = []
        var iterAvailMemAfter: [Int] = []
        var iterCooldownThermalRecovery: [String] = []
        var allMlxLatenciesMs: [Double] = []
        var totalTokens = 0
        // ch1062 WS2 — carries the fabric-authoritative enrichment from turn N into
        // turn N+1's prompt (the N→N+1 feed-forward). nil ⇒ use the raw promptPool prompt.
        var pendingEnrichedPrompt: String?

        for iter in 1...totalIters {
            let iterStartNs = monoNowNs()
            let elapsedSec = Int(
                monoElapsedMs(since: runStartNs) / 1000.0)
            await emitBoth(
                "📍 ch1025 internal-iter=\(iter) start " +
                "elapsed=\(elapsedSec)s")
            // ch1057 — wall-clock cap check. Break BEFORE the iter's work so a capped
            // run ends at a clean iteration boundary; the loop exit runs the normal
            // post-loop summary / closeLogFile / idleTimer reset.
            if maxRuntimeSec > 0 && elapsedSec >= maxRuntimeSec {
                await emitBoth(
                    "⏹ ch1025 time-cap reached elapsed=\(elapsedSec)s " +
                    "cap=\(maxRuntimeSec)s — finishing (completed \(iter - 1) iters)")
                break
            }

            let snapBefore = snapshot()
            await emitBoth(formatSnap(
                snapBefore, iter: iter, phase: "before"))
            iterRssBefore.append(snapBefore.memoryRssMB)
            iterThermalBefore.append(snapBefore.thermalState)
            iterAvailMemBefore.append(
                snapBefore.availableMemoryMB)

            var iterTokens = 0
            for p in 0..<mlxPrompts {
                // ch1062 WS2 — if the prior turn's authoritative loop produced an
                // enriched input, use it (the N→N+1 feed-forward); else the raw prompt.
                let prompt: String
                if let enriched = pendingEnrichedPrompt {
                    prompt = enriched
                    pendingEnrichedPrompt = nil
                } else {
                    prompt = Self.promptPool[
                        (iter * mlxPrompts + p)
                        % Self.promptPool.count]
                }
                let promptLen = prompt.count

                // ch 1025.5 — brain.process() exercises L1-L14 cascade
                // (context classify → decompose → memory → loop → triSelf
                // → risk → action render → evolution synthesis)。 This
                // is REAL substrate work,not just MLX。 No fabric
                // activation yet (pipeline.runTurn deferred to ch 1025.6
                // — needs fabric+roster+graph build in app target)。
                let brainStartNs = monoNowNs()
                let turnResult = await brain.process(prompt)
                let brainMs = monoElapsedMs(since: brainStartNs)
                let taskType = turnResult.contextFrame.taskType
                // ch 1025.5.5 audit MED-2:`confidenceBand` is
                // `Optional<Double>` and the `brain.process` path
                // (BASMLContextService) never sets it,so we always
                // see nil。 Previously rendered as `conf=0.00` which
                // implies the classifier returned 0 confidence —
                // misleading。 Render `n/a` when nil so operators
                // reading the log don't assume the model is broken。
                let confStr = turnResult.contextFrame.confidenceBand
                    .map { String(format: "%.2f", $0) } ?? "n/a"
                let riskLevel = turnResult.riskCard.riskLevel
                let candidateCount =
                    turnResult.thoughtFrame.candidates.count
                await emitBoth(String(format:
                    "🧠 ch1025 brain iter=%d prompt=%d " +
                    "latency_ms=%.0f task=%@ conf=%@ " +
                    "risk=%@ candidates=%d",
                    iter, p + 1, brainMs,
                    String(describing: taskType),
                    confStr,
                    String(describing: riskLevel),
                    candidateCount))
                // ch 1025.6 — REAL fabric turn(replaces the ch
                // 1025.5.5 bypass marker)。 fabric.runTurn() is now
                // ACTUALLY called per prompt,fed by the turnResult
                // fields brain.process() already produced(decompose
                // frame + candidate paths + risk + triScores)。 The
                // env gate(BAS_AGENT_FABRIC)lives INSIDE runTurn:
                // enabled → fabric coordinates(activated=true);
                // unset → returns activated=false with a skipReason
                // (no behavior change,ADR-014 OPT-IN preserved)。 So
                // the syslog now reports the TRUTH of whether fabric
                // fired,not a hardcoded "bypassed"。
                if let pipeline = fabricPipeline {
                    do {
                        let outcome = try await pipeline.runTurn(
                            turnID: "ch1025-i\(iter)-p\(p)",
                            decomposeFrame:
                                turnResult.decomposeFrame,
                            candidatePaths:
                                turnResult.thoughtFrame.candidates,
                            riskCard: turnResult.riskCard,
                            triScores: turnResult.triScores)
                        let skip = outcome.skipReason ?? "-"
                        // ch 1038 不满2 fix:`activated=true` alone is
                        // only OBSERVABILITY(it fired)— NOT proof
                        // fabric influenced anything。 Log the real
                        // BEHAVIOR evidence from diagnostics:how many
                        // deltas the seats EMITTED + how many the
                        // merge engine ACCEPTED。 deltas.accepted>0 is
                        // the honest proof fabric actually merged seat
                        // proposals,not just ran without crashing。
                        let emitted = outcome
                            .diagnostics["deltas.emitted"] ?? "-"
                        let accepted = outcome
                            .diagnostics["deltas.accepted"] ?? "-"
                        await emitBoth(String(format:
                            "🪧 ch1025 fabric iter=%d prompt=%d " +
                            "activated=%@ skip=%@ " +
                            "deltas_emitted=%@ deltas_accepted=%@",
                            iter, p + 1,
                            outcome.activated ? "true" : "false",
                            skip, emitted, accepted))
                    } catch {
                        await emitBoth(
                            "⚠️ ch1025 fabric iter=\(iter) " +
                            "prompt=\(p+1) runTurn_error=\(error)")
                    }
                } else {
                    await emitBoth(
                        "🪧 ch1025 fabric iter=\(iter) " +
                        "prompt=\(p+1) activated=false " +
                        "skip=pipeline_construct_failed")
                }

                // ch1062 WS2 — Agent Fabric AUTHORITATIVE multi-round loop:
                // run it on THIS turn's outputs; only when fabricAuthFeedForward is true
                // do the converged conclusions fold into the NEXT prompt's input (N→N+1).
                // Deterministic: nowNanos pinned per turn; converges on the content
                // digest. The enriched text enters turn N+1 as INPUT (userInput), gated
                // by the sovereign verdict exactly as any input.
                let authLoop = await BASAgentFabricAuthoritativeTurn.loopResult(
                    decomposeFrame: turnResult.decomposeFrame,
                    candidatePaths: turnResult.thoughtFrame.candidates,
                    acceptedCandidateID: turnResult.mergedChoice.candidateID,
                    runtime: fabricAuthRuntime,
                    config: BASAgentFabricMultiRoundConfig(
                        maxRounds: Self.fabricAuthMaxRounds,
                        baseTurnID: "ch1062-i\(iter)-p\(p)",
                        nowNanos: Int64(bitPattern: monoNowNs())))
                // ch1066 — feed-forward is OPT-IN (default OFF; see fabricAuthFeedForward).
                // The loop above still runs + logs (WS2 stays observable); we just do NOT
                // fold the enriched conclusions into the next prompt's MLX input unless the
                // operator opted in — the raw structured fold wedged on-device MLX eval.
                if fabricAuthFeedForward, let proj = authLoop.finalProjection {
                    // ch — nextRaw is only consumed here (default-OFF path skips it),
                    // so compute it inside the gate to avoid the wasted promptPool index
                    // every prompt。 Index expression is unchanged from the prior site。
                    let nextRaw = Self.promptPool[
                        (iter * mlxPrompts + p + 1) % Self.promptPool.count]
                    // ADR-038 §6 lever: rebuild the enriched block at the configured size
                    // (default 512 / all-conclusions == byte-equal to proj.contextBlock).
                    let block = BASAgentFabricAuthoritativeProjection.contextBlock(
                        sourceTurnID: proj.sourceTurnID,
                        conclusions: proj.conclusions,
                        maxChars: fabricContextBlockChars,
                        topConclusionsOnly: fabricTopConclusionsOnly)
                    pendingEnrichedPrompt = nextRaw.isEmpty
                        ? block
                        : nextRaw + "\n\n" + block
                }
                await emitBoth(String(format:
                    "🪧 ch1062 fabric-authoritative iter=%d prompt=%d " +
                    "rounds=%d %@ deltas=%d stop=%@",
                    iter, p + 1, authLoop.roundsRun,
                    authLoop.converged ? "converged" : "incomplete",
                    authLoop.finalProjection?.conclusions.count ?? 0,
                    authLoop.stopReason))

                // ch 1025.7 — comprehensive turnResult instrumentation:
                // emit 8+ detailed log lines covering all public
                // fields the standard brain line doesn't surface。
                await emitBrainDetail(
                    turnResult, iter: iter, prompt: p + 1)

                // ch1044 ADR-022 #3 — opt-in parity shadow (observation-only,
                // no-op when disabled)。 One-liner via the BASHostKit helper —
                // the app needs no BASSovereign import。
                if let parityLine = await
                    BASSovereignTurnObservationProjection
                        .shadowParitySummary(
                            turnResult, enabled: shadowParityEnabled) {
                    await emitBoth(
                        "🛡 ch1025 shadow_parity iter=\(iter) "
                        + "prompt=\(p + 1) \(parityLine)")
                }

                // ch1044 (a) — coordinator self-consistency: the GENUINE
                // fail-closed signal (vs the observability shadow above). Cheap,
                // sync, observation-only; emits ONLY on a regression (stored
                // verdict laxer than the coordinator's own rules re-derived from
                // this turn's settled state). Always-on — this is the real signal.
                if case .regression(let stored, let atLeast) =
                    BASCoordinatorConsistencyCheck.check(turnResult) {
                    await emitBoth(
                        "🚨 ch1025 coordinator_regression iter=\(iter) "
                        + "prompt=\(p + 1) stored=\(stored.rawValue) "
                        + "should_be_at_least=\(atLeast.rawValue)")
                }

                let mlxPreSnap = snapshot()
                let mlxStartNs = monoNowNs()
                let request = BASOrganRequest(
                    requestID:
                        "ch1025-iter\(iter)-prompt\(p)",
                    role: .core,
                    preset: .core,
                    instruction: prompt,
                    context: [],
                    maxOutputTokens: maxDecodeTokens)   // WS2: explicit low decode cap (was preset 1024)
                do {
                    let draft = try await adapter.draft(request)
                    let mlxMs = monoElapsedMs(since: mlxStartNs)
                    let mlxPostSnap = snapshot()
                    let bodyLen = draft.body.count
                    // ch 1025.8 HIGH-1 fix:`outputTokensEstimated` is
                    // a chars/4 heuristic(BASOrganDeterministicAdapter
                    // .estimateTokens = (body.count+3)/4),NOT a real
                    // MLX decode-token count(the adapter never exposes
                    // one)。 Renamed tokens→est_tokens + tok_per_s→
                    // est_tok_per_s so the log + report don't claim
                    // measured throughput they can't deliver(diverges
                    // sharply for multibyte / whitespace-heavy output)。
                    let estTokens = draft.outputTokensEstimated
                    let estTps = mlxMs > 0
                        ? Double(estTokens) / (mlxMs / 1000.0)
                        : 0
                    iterTokens += estTokens
                    allMlxLatenciesMs.append(mlxMs)
                    // ch 1025.8 HIGH-3 fix:mlxPreSnap is taken AFTER
                    // brain.process + emitBrainDetail already ran,so
                    // this delta brackets ONLY adapter.draft() memory,
                    // not total per-prompt。 Renamed rss_delta_mb→
                    // mlx_rss_delta_mb to scope it honestly。
                    let mlxRssDeltaMB = mlxPostSnap.memoryRssMB
                        - mlxPreSnap.memoryRssMB
                    await emitBoth(String(format:
                        "🧠 ch1025 mlx iter=%d prompt=%d " +
                        "prompt_len=%d resp_len=%d est_tokens=%d " +
                        "latency_ms=%.0f est_tok_per_s=%.2f " +
                        "mlx_rss_delta_mb=%.2f",
                        iter, p + 1, promptLen, bodyLen,
                        estTokens, mlxMs, estTps, mlxRssDeltaMB))
                    // ch 1025.7 — MLX adapter telemetry per prompt
                    let sessions = await adapter.sessionCount()
                    let capacity = await adapter.currentCapacity()
                    await emitBoth(String(format:
                        "🧠 ch1025 mlx-detail iter=%d prompt=%d " +
                        "sessions=%d capacity=%@",
                        iter, p + 1, sessions,
                        String(describing: capacity)))
                } catch {
                    await emitBoth(
                        "⚠️ ch1025 mlx iter=\(iter) " +
                        "prompt=\(p+1) error=\(error)")
                }
            }
            iterMlxTokens.append(iterTokens)
            totalTokens += iterTokens

            let snapAfter = snapshot()
            await emitBoth(formatSnap(
                snapAfter, iter: iter, phase: "after"))
            iterRssAfter.append(snapAfter.memoryRssMB)
            iterThermalAfter.append(snapAfter.thermalState)
            iterAvailMemAfter.append(
                snapAfter.availableMemoryMB)

            let iterMs = monoElapsedMs(since: iterStartNs)
            iterDurationMs.append(iterMs)

            // ch 1025.8 HIGH-1:est_ prefix — these are chars/4
            // estimates(see mlx line),not real decode tokens。
            await emitBoth(String(format:
                "📊 ch1025 scorecard iter=%d iter_ms=%.0f " +
                "est_tokens=%d est_cumul_tokens=%d " +
                "thermal=%@→%@ rss_mb=%.1f→%.1f " +
                "avail_mb=%d→%d",
                iter, iterMs, iterTokens, totalTokens,
                snapBefore.thermalState,
                snapAfter.thermalState,
                snapBefore.memoryRssMB,
                snapAfter.memoryRssMB,
                snapBefore.availableMemoryMB,
                snapAfter.availableMemoryMB))

            let updateThermal = snapAfter.thermalState
            await MainActor.run {
                self.status = .running(
                    iter: iter, totalIters: totalIters,
                    cumulTokens: totalTokens,
                    thermal: updateThermal)
            }

            // ch1062 — PER-ITERATION host-driven persistence flush. The brain queued this iter's
            // self-populated atoms during process(); drive the durable admit (one event + provenance
            // per atom) at the iteration boundary so the persist path is EXERCISED CONTINUOUSLY over
            // a long endurance (not just once at the end) and the admit-intent queue never backs up.
            // No-op for the legacy backend.
            if let store = memoryStore {
                let mem = await brain.drainMemoryIntents()
                let allAtoms = try? await store.allAtoms()
                let storedAtoms = allAtoms?.count ?? -1
                await emitBoth(
                    "📍 ch1062 iter=\(iter) memory persisted " +
                    "admitted=\(mem.admitted) store_atoms=\(storedAtoms) " +
                    "promoted=\(mem.promoted)")
                // ADR-037 — incremental sync: fold NEW durable atoms into the in-memory global-recall
                // engine + resolver so this turn's persisted atoms are globally recall-eligible next
                // turn, keeping engine-rows == resolver-keys (lockstep eviction). Between-turns ONLY
                // (turn-phase separation: these writes never overlap the sync atomForID read inside
                // retrieve(); the DEBUG begin/endWrite asserts it).
                if let engine = globalRecallEngine, let resolver = globalRecallResolver,
                   let vindex = memoryVectorIndex {
                    let pin = BASL8RoutedMemoryService.Parameters.atomSource
                    resolver.beginWrite()   // no-op in release; brackets the between-turns write window
                    var added = 0
                    // Monotonic gate: only atoms NEVER synced (NOT resolver-presence — that re-finds
                    // evicted atoms + oscillates the capped membership). Upsert FIRST, then put + mirror
                    // the FIFO eviction into the engine; mark synced only on success (a no-vector or
                    // failed atom stays unseen ⇒ retried next turn — no resolver-only strand, no divergence).
                    for record in (allAtoms ?? [])
                    where !globalRecallSynced.contains(record.id.uuidString) {
                        let id = record.id.uuidString
                        guard let e = await vindex.entry(forID: id) else { continue }
                        do {
                            try await engine.upsert(BASVectorIndexEntry(
                                atomID: id, normalizedEmbedding: e.normalizedEmbedding, domain: pin))
                            let evicted = resolver.put(id: id,
                                atom: BASL8RoutedMemoryService.memoryAtom(from: record),
                                domain: record.sourceType)
                            for ev in evicted {
                                // Log (don't swallow) an evict-remove failure: it would leave the engine
                                // with a row the resolver dropped (a mini-HIGH-1 slot loss) — rare for an
                                // in-memory engine, but it must be visible, symmetric with upsert.
                                do { _ = try await engine.remove(atomID: ev) }
                                catch {
                                    await emitBoth("⚠️ ADR-037 engine evict-remove failed id=\(ev): \(error)")
                                }
                            }
                            globalRecallSynced.insert(id)
                            added += 1
                        } catch {
                            await emitBoth("⚠️ ADR-037 engine upsert failed id=\(id): \(error)")
                        }
                    }
                    resolver.endWrite()     // no-op in release
                    if added > 0 {
                        let corpus = await engine.totalCount
                        await emitBoth(
                            "📍 ADR-037 iter=\(iter) global recall synced +\(added) corpus=\(corpus)")
                    }
                }
            }

            if iter < totalIters {
                // ch 1025.11 — feed MEASURED thermal(iter-end
                // snapshot)so cooldown is thermal-aware,not blind。
                let cooldown = cooldownSecFor(
                    iter: iter, base: baseCooldown,
                    adaptive: adaptive,
                    thermalState: snapAfter.thermalState)
                await emitBoth(
                    "⏸ ch1025 cooldown iter=\(iter) " +
                    "duration_s=\(cooldown) starting")
                let preCoolSnap = snapshot()
                try? await Task.sleep(
                    for: .seconds(cooldown))
                let postCoolSnap = snapshot()
                let recovery =
                    "\(preCoolSnap.thermalState)" +
                    "→\(postCoolSnap.thermalState)"
                iterCooldownThermalRecovery.append(recovery)
                await emitBoth(
                    "⏸ ch1025 cooldown iter=\(iter) done " +
                    "thermal_recovery=\(recovery) " +
                    "rss_pre_mb=" +
                    String(format: "%.1f",
                           preCoolSnap.memoryRssMB) +
                    " rss_post_mb=" +
                    String(format: "%.1f",
                           postCoolSnap.memoryRssMB))
            }
        }

        let totalSec = monoElapsedMs(since: runStartNs) / 1000.0
        if !iterDurationMs.isEmpty {
            let sortedDurMs = iterDurationMs.sorted()
            let avgDurMs = iterDurationMs.reduce(0, +)
                / Double(iterDurationMs.count)
            let p50DurMs = sortedDurMs[Self.nearestRankIndex(
                0.5, count: sortedDurMs.count)]
            let p99DurMs = sortedDurMs[Self.nearestRankIndex(
                0.99, count: sortedDurMs.count)]
            let sortedMlxLat = allMlxLatenciesMs.sorted()
            let avgMlxMs = sortedMlxLat.isEmpty
                ? 0
                : allMlxLatenciesMs.reduce(0, +)
                    / Double(allMlxLatenciesMs.count)
            let p50MlxMs = sortedMlxLat.isEmpty
                ? 0
                : sortedMlxLat[Self.nearestRankIndex(
                    0.5, count: sortedMlxLat.count)]
            let p99MlxMs = sortedMlxLat.isEmpty
                ? 0
                : sortedMlxLat[Self.nearestRankIndex(
                    0.99, count: sortedMlxLat.count)]
            let avgRssBefore = iterRssBefore.reduce(0, +)
                / Double(iterRssBefore.count)
            let avgRssAfter = iterRssAfter.reduce(0, +)
                / Double(iterRssAfter.count)
            // ch 1025.9 HIGH-2 fix:`last − first` endpoint delta hides
            // intra-run leaks(peak mid-run then reclaimed by cooldown
            // GC reads as negative "growth")。 Also report max + peak-
            // vs-first so a reclaimed-late leak stays visible。
            let rssEndpointDeltaMB = (iterRssAfter.last ?? 0)
                - (iterRssBefore.first ?? 0)
            let rssMaxMB = iterRssAfter.max() ?? 0
            let rssPeakVsFirstMB = rssMaxMB
                - (iterRssBefore.first ?? 0)

            await emitBoth(String(format:
                "📊 ch1025 FINAL run_sec=%.0f iters=%d " +
                "avg_iter_ms=%.0f p50_iter_ms=%.0f " +
                "p99_iter_ms=%.0f",
                totalSec, totalIters,
                avgDurMs, p50DurMs, p99DurMs))
            // ch 1025.8 HIGH-1:est_total_tokens(chars/4,not real)。
            // p50/p99 below use nearest-rank percentiles via
            // `Self.nearestRankIndex(...)`(rank=ceil(p×N), 0-based
            // index=rank−1, clamped)— the correct, unbiased index
            // (ch 1025.9 MED-1 fix already replaced the old
            // sorted[count/2] / last-element estimates)。
            await emitBoth(String(format:
                "📊 ch1025 FINAL mlx_total_inferences=%d " +
                "avg_lat_ms=%.0f p50_lat_ms=%.0f " +
                "p99_lat_ms=%.0f est_total_tokens=%d",
                allMlxLatenciesMs.count, avgMlxMs,
                p50MlxMs, p99MlxMs, totalTokens))
            await emitBoth(String(format:
                "📊 ch1025 FINAL memory " +
                "avg_rss_before_mb=%.1f " +
                "avg_rss_after_mb=%.1f " +
                "endpoint_delta_mb=%.1f " +
                "rss_max_mb=%.1f peak_vs_first_mb=%.1f",
                avgRssBefore, avgRssAfter, rssEndpointDeltaMB,
                rssMaxMB, rssPeakVsFirstMB))
            await emitBoth(
                "📊 ch1025 FINAL thermal_trajectory=" +
                iterThermalAfter.joined(separator: ","))
            await emitBoth(
                "📊 ch1025 FINAL cooldown_thermal_recovery=" +
                iterCooldownThermalRecovery
                    .joined(separator: ","))
            await emitBoth(
                "📊 ch1025 FINAL est_tokens_per_iter=" +
                iterMlxTokens.map { String($0) }
                    .joined(separator: ","))
        }

        // ch1062 — FINAL persistence summary. The per-ITERATION flushes (above) already drove the
        // durable admits throughout the run (host-driven; process() only queues — ch883). This does a
        // last flush to catch any straggler and reports the run's CUMULATIVE store total (one event +
        // provenance per atom over the whole run). No-op for the legacy backend.
        if let store = memoryStore {
            let mem = await brain.drainMemoryIntents()
            let storedAtoms = (try? await store.allAtoms().count) ?? -1
            await emitBoth(
                "📊 ch1062 FINAL memory total_store_atoms=\(storedAtoms) " +
                "final_flush_admitted=\(mem.admitted) " +
                "(host-driven durable SQLite persistence: per-iteration + final)")
        }

        await MainActor.run {
            self.status = .completed(
                totalIters: totalIters,
                totalTokens: totalTokens,
                runSec: totalSec)
            self.started = false
            self.closeLogFile()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Helpers

    /// Emit to both stdout (for idevicesyslog) and the Documents log
    /// file (for post-run pull via Xcode Devices)。
    // ch 1025.12 #4 fix:nonisolated so the off-main detached
    // endurance task runs emit off the MainActor;the actual
    // file write hops back via MainActor.run(writeToLogFile is
    // @MainActor-isolated)。
    private nonisolated func emitBoth(_ line: String) async {
        emit(line)
        await MainActor.run {
            self.writeToLogFile(line)
        }
    }

    /// ch 1025.9 MED-1 fix:nearest-rank percentile index。 1-based
    /// rank = ceil(p×N),0-based index = rank−1,clamped [0, N−1]。
    /// For N=100:p50→idx49(50th elem),p99→idx98(99th)。 Pre-fix used
    /// `count/2`(→idx50=51st≈p51)and `Int(count×0.99)`(→idx99=MAX),
    /// both biased the tail high。
    private nonisolated static func nearestRankIndex(
        _ p: Double, count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        let rank = Int((Double(count) * p).rounded(.up))
        return max(0, min(count - 1, rank - 1))
    }

    private nonisolated func formatSnap(
        _ s: SystemSnapshot, iter: Int, phase: String
    ) -> String {
        return String(format:
            "📊 ch1025 sys iter=%d phase=%@ thermal=%@ " +
            "low_power=%d active_cpu=%d/%d " +
            "rss_mb=%.1f footprint_mb=%.1f " +
            "avail_mb=%d mono_ns=%llu",
            iter, phase, s.thermalState,
            s.isLowPowerMode ? 1 : 0,
            s.activeProcessors, s.totalProcessors,
            s.memoryRssMB, s.memoryFootprintMB,
            s.availableMemoryMB, s.monotonicNs)
    }

    // MARK: - ch 1025.7 comprehensive instrumentation

    /// Emit 8+ detailed log lines covering every public field on
    /// BASEBrainTurnResult that the standard `🧠 ch1025 brain ...`
    /// line does not。 Operators can grep by sub-category(ctx /
    /// decompose / risk / permit / mem / render / triself /
    /// candidates / host_gate)to investigate specific substrate
    /// layers under load。
    // ch 1025.12 #4 fix:nonisolated(only calls nonisolated emitBoth)。
    private nonisolated func emitBrainDetail(
        _ tr: BASEBrainTurnResult, iter: Int, prompt: Int
    ) async {
        // ── L6 context frame full signal panel ─────────────────
        let ctx = tr.contextFrame
        await emitBoth(String(format:
            "🧠 ch1025 ctx iter=%d prompt=%d " +
            "emo_load=%.2f time_pres=%.2f ambig=%.2f " +
            "conseq=%.2f manip_hints=%d host_rel=%.2f " +
            "scene=%@",
            iter, prompt,
            ctx.emotionalLoad, ctx.timePressure,
            ctx.ambiguityScore, ctx.consequenceLevel,
            ctx.manipulationHints.count, ctx.hostRelevance,
            String(describing: ctx.sceneType)))

        // ── L7 decompose frame signal counts ───────────────────
        let dec = tr.decomposeFrame
        await emitBoth(String(format:
            "🧠 ch1025 decompose iter=%d prompt=%d " +
            "facts=%d goals=%d emotions=%d unknowns=%d " +
            "contradictions=%d pressure=%d manip=%d " +
            "fact_shards=%d claim_shards=%d",
            iter, prompt,
            dec.facts.count, dec.goals.count,
            dec.emotions.count, dec.unknowns.count,
            dec.contradictions.count,
            dec.pressureSignals.count,
            dec.manipulationSignals.count,
            dec.factShards.count, dec.claimShards.count))

        // ── L11 risk card scalars ──────────────────────────────
        let rc = tr.riskCard
        await emitBoth(String(format:
            "🧠 ch1025 risk iter=%d prompt=%d " +
            "total=%.2f uncertainty=%.2f irrev=%.2f " +
            "manip_str=%.2f gsi=%.2f factors=%d " +
            "rec_mode=%@ stacked=%d",
            iter, prompt,
            rc.totalRisk, rc.uncertainty,
            rc.irreversibility, rc.manipulationStrength,
            rc.gsiScore, rc.factors.count,
            String(describing: rc.recommendedMode),
            rc.stackedModes.count))

        // ── L11 action permit ──────────────────────────────────
        let ap = tr.actionPermit
        await emitBoth(String(format:
            "🧠 ch1025 permit iter=%d prompt=%d " +
            "mode=%@ stacked=%d reason_codes=%d " +
            "allowed_doms=%d blocked_doms=%d " +
            "tool_scope=%@ memory_scope=%@ " +
            "requires_mirror=%@",
            iter, prompt,
            String(describing: ap.mode),
            ap.stackedModes.count,
            ap.reasonCodes.count,
            ap.allowedDomains.count, ap.blockedDomains.count,
            ap.toolScope, ap.memoryScope,
            ap.requireMirror ? "true" : "false"))

        // ── L8 memory bundle ───────────────────────────────────
        let mb = tr.memoryBundle
        await emitBoth(String(format:
            "🧠 ch1025 mem iter=%d prompt=%d " +
            "atoms=%d tags=%d conflicts=%d",
            iter, prompt,
            mb.atoms.count, mb.retrievalTags.count,
            mb.conflictRefs.count))

        // ── L12 rendered output(rule-template,NOT MLX tokens)──
        let ro = tr.renderedOutput
        await emitBoth(String(format:
            "🧠 ch1025 render iter=%d prompt=%d " +
            "headline_len=%d body_len=%d " +
            "alt_actions=%d explain_codes=%d " +
            "mode=%@",
            iter, prompt,
            ro.headline.count, ro.body.count,
            ro.alternativeActions.count,
            ro.explanationCodes.count,
            String(describing: ro.mode)))

        // ── L10 triself scores per candidate ────────────────────
        if !tr.triScores.isEmpty {
            let preview = tr.triScores.prefix(3).map {
                String(format:
                    "id=%.2f/ego=%.2f/super=%.2f" +
                    "/m=%.2f/v=%@",
                    $0.idScore, $0.egoScore,
                    $0.superegoScore, $0.mergedScore,
                    $0.veto ? "y" : "n")
            }.joined(separator: "|")
            await emitBoth(String(format:
                "🧠 ch1025 triself iter=%d prompt=%d " +
                "count=%d scores=%@",
                iter, prompt, tr.triScores.count, preview))
        }

        // ── L9 candidate paths detail ──────────────────────────
        if !tr.thoughtFrame.candidates.isEmpty {
            let preview = tr.thoughtFrame.candidates
                .prefix(3).map {
                    String(format:
                        "b=%.2f/c=%.2f/r=%.2f/cf=%.2f",
                        $0.expectedBenefit, $0.expectedCost,
                        $0.reversibility, $0.confidence)
                }.joined(separator: "|")
            await emitBoth(String(format:
                "🧠 ch1025 candidates iter=%d prompt=%d " +
                "details=%@",
                iter, prompt, preview))
        }

        // ── L14 host gate + sovereign verdict ──────────────────
        let svPresent = tr.sovereignVerdict != nil
            ? "true" : "false"
        await emitBoth(String(format:
            "🧠 ch1025 host_gate iter=%d prompt=%d " +
            "value=%.2f sovereign_present=%@ " +
            "warrants=%d commit_tokens=%d " +
            "update_tickets=%d",
            iter, prompt,
            tr.hostGateValue, svPresent,
            tr.sovereignWarrants.count,
            tr.sovereignCommitTokens.count,
            tr.updateTickets.count))

        // ── ch 1025.13 — the 4 layers the original probe MISSED ──
        // (honest-mode self-audit found instrumentation was ~9/14
        // layers — these close the gap so "14-layer" is real)。

        // L0 device/lifecycle frame(budget + wake + vital)
        let bf = tr.budgetFrame
        let vs = tr.vitalState
        await emitBoth(String(format:
            "🧠 ch1025 L0frame iter=%d prompt=%d " +
            "run_mode=%@ max_loops=%d max_cands=%d " +
            "max_decode=%d wake=%@ " +
            "survival=%.2f thermal_margin=%.2f " +
            "power_margin=%.2f continuity=%.2f stability=%.2f",
            iter, prompt,
            bf.runMode.rawValue, bf.maxLoops, bf.maxCandidates,
            bf.maxDecodeTokens,
            String(describing: tr.wakeIntent),
            vs.survivalMargin, vs.thermalMargin,
            vs.powerMargin, vs.continuityScore, vs.stabilityScore))

        // L1 run lease(budget envelope for the turn)
        if let lease = tr.runLease {
            await emitBoth(String(format:
                "🧠 ch1025 L1lease iter=%d prompt=%d " +
                "allowed_mode=%@ max_loops=%d max_ms=%d " +
                "energy_quota=%.2f valid_heads=%d",
                iter, prompt,
                lease.allowedMode.rawValue, lease.maxLoops,
                lease.maxMs, lease.maxEnergyQuota,
                lease.validHeads.count))
        } else {
            await emitBoth(
                "🧠 ch1025 L1lease iter=\(iter) " +
                "prompt=\(prompt) lease=nil")
        }

        // L5 host constitution(identity/value spine)
        if let hc = tr.hostConstitution {
            await emitBoth(String(format:
                "🧠 ch1025 L5host iter=%d prompt=%d " +
                "constitution_id=%@ active_version=%@",
                iter, prompt,
                hc.constitutionID, hc.activeVersion))
        } else {
            await emitBoth(
                "🧠 ch1025 L5host iter=\(iter) " +
                "prompt=\(prompt) constitution=nil")
        }

        // L13 host version tree(evolution lineage)
        if let vt = tr.hostVersionTree {
            await emitBoth(String(format:
                "🧠 ch1025 L13vtree iter=%d prompt=%d " +
                "active=%@ versions=%d pending=%d frozen=%d",
                iter, prompt,
                vt.activeVersionID, vt.versions.count,
                vt.pendingCandidateIDs.count,
                vt.frozenVersionIDs.count))
        } else {
            await emitBoth(
                "🧠 ch1025 L13vtree iter=\(iter) " +
                "prompt=\(prompt) version_tree=nil")
        }
    }
}
