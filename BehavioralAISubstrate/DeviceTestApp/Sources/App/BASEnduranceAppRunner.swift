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

// ch 1025.4 — Unified logging via `os.Logger`。 Swift `print()` does
// NOT appear in iOS system log,which means `idevicesyslog` from
// Mac cannot capture endurance progress。 By routing through
// `Logger`,emit lines are visible to:
//   - idevicesyslog -u <UDID>(real-time stream)
//   - log show / log stream / Xcode Devices Console
// while still also writing to Documents/ for post-run analysis。
private let ch1025Log = Logger(
    subsystem: "com.changgeng.basdevicetest",
    category: "ch1025-endurance")

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
    }

    @Published var status: RunStatus = .autostartOff
    static let shared = BASEnduranceAppController()

    private var started = false
    private var logFileHandle: FileHandle?
    private var logFileURL: URL?

    // MARK: - Autostart hook

    func autostartIfEnabled() {
        guard !started else { return }
        let env = ProcessInfo.processInfo.environment
        guard env["BAS_ENDURANCE_AUTOSTART"] == "1" else {
            status = .autostartOff
            return
        }
        started = true
        status = .starting
        // Prevent screen auto-lock during long endurance run。 The
        // operator should also set Settings → Display & Brightness
        // → Auto-Lock = Never on the device,and keep it charging。
        UIApplication.shared.isIdleTimerDisabled = true
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runEndurance()
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
        let footprintMB: Double
        if result == KERN_SUCCESS {
            rssMB = Double(info.resident_size)
                / 1024.0 / 1024.0
            footprintMB = Double(info.virtual_size)
                / 1024.0 / 1024.0
        } else {
            rssMB = 0
            footprintMB = 0
        }
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
        // recoveries occurred at ≥180s。 So gate cooldown on MEASURED
        // thermal,not blind iter count — `serious` gets a ≥180s floor
        // (skipping the empirically-wasted 60-90s steps the old
        // iter-schedule burned),`critical` 300s,fair/nominal keep the
        // light iter schedule。 This is the test-infra PROTOTYPE of
        // ch 1026's thermal-aware kernel policy(same data,same ≥180s
        // threshold)— validating the thermal-feedback idea cheaply
        // before it graduates to the substrate executor。
        switch thermalState {
        case "critical":
            return max(base * 3 + 120, 300)
        case "serious":
            return max(base * 2 + 60, 180)  // ≥180s floor(measured)
        default:  // fair / nominal — light schedule suffices
            switch iter {
            case 1...2:   return base
            case 3...5:   return base + 30
            default:      return base * 2 + 60
            }
        }
    }

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
    private nonisolated func runEndurance() async {
        let env = ProcessInfo.processInfo.environment
        // ch 1025.8 C1 fix(CRITICAL):clamp to ≥1。 env "0"/negative
        // would make `for iter in 1...totalIters` a ClosedRange with
        // lowerBound > upperBound,which TRAPS at runtime(hard crash
        // + skips closeLogFile/idleTimer cleanup = C2)。 mlxPrompts=0
        // makes the inner `0..<0` a silent 0-token no-op — clamp too。
        let totalIters = max(1, Int(
            env["BAS_INTERNAL_ITER_COUNT"] ?? "100") ?? 100)
        let mlxPrompts = max(1, Int(
            env["BAS_INTERNAL_MLX_PROMPTS"] ?? "3") ?? 3)
        let baseCooldown = Int(
            env["BAS_INTERNAL_COOLDOWN_SEC"] ?? "60") ?? 60
        let adaptive = (
            env["BAS_INTERNAL_ADAPTIVE"] ?? "1") == "1"
        // ch1044 ADR-022 #3 — OPT-IN sovereign-verdict parity shadow。
        // Default OFF (env unset) → byte-equal:no projection,no verify,no log。
        // With `BAS_SHADOW_PARITY=enabled`,each turn's coordinator verdict is
        // compared against the engine's (observation-only — NEVER halts) so an
        // on-device endurance run gathers ADR-022 §6 parity evidence。
        let shadowParityEnabled =
            (env["BAS_SHADOW_PARITY"] ?? "") == "enabled"
        // ch 1025.10 — monotonic run start(NTP/DST-safe)。
        let runStartNs = monoNowNs()

        await MainActor.run {
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
        let cognitiveBrainStartNs = monoNowNs()
        do {
            brain = try await BASCognitiveBrain.makeWithDefaults()
        } catch {
            let msg = "Brain init failed: \(error)"
            await emitBoth("⚠️ ch1025 \(msg)")
            await MainActor.run {
                self.status = .failed(message: msg)
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
        let fabricGateOn = (env["BAS_AGENT_FABRIC"] == "enabled")
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

        for iter in 1...totalIters {
            let iterStartNs = monoNowNs()
            let elapsedSec = Int(
                monoElapsedMs(since: runStartNs) / 1000.0)
            await emitBoth(
                "📍 ch1025 internal-iter=\(iter) start " +
                "elapsed=\(elapsedSec)s")

            let snapBefore = snapshot()
            await emitBoth(formatSnap(
                snapBefore, iter: iter, phase: "before"))
            iterRssBefore.append(snapBefore.memoryRssMB)
            iterThermalBefore.append(snapBefore.thermalState)
            iterAvailMemBefore.append(
                snapBefore.availableMemoryMB)

            var iterTokens = 0
            for p in 0..<mlxPrompts {
                let prompt = Self.promptPool[
                    (iter * mlxPrompts + p)
                    % Self.promptPool.count]
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

                let mlxPreSnap = snapshot()
                let mlxStartNs = monoNowNs()
                let request = BASOrganRequest(
                    requestID:
                        "ch1025-iter\(iter)-prompt\(p)",
                    role: .core,
                    preset: .core,
                    instruction: prompt,
                    context: [])
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
            // ch 1025.8 MED-1 NOTE:p50/p99 below still use the
            // biased index(sorted[count/2] / last-element)— a known
            // overstatement deferred to the next batch(BACKLOG)。
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

        await MainActor.run {
            self.status = .completed(
                totalIters: totalIters,
                totalTokens: totalTokens,
                runSec: totalSec)
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
            "rss_mb=%.1f vsize_mb=%.1f " +
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
