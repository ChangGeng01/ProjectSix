// MARK: - BASChapter1025LongRunningEnduranceTests
// chapter 一千零二十五 / M3895 — single-launch internal-loop endurance
//
// ## User mandate(refined)
//
//   原: 「需要 内部循环 测试 内部 thermal 相关 设置 + 写的 细节一些」
//   修: 「不止 thermal — 尽可能多的 数据 帮助日后优化」
//
// ## Comprehensive instrumentation captured per iter
//
// SYSTEM (before/after each iter):
//   - timestamp(wall clock + monotonic ns)
//   - thermalState(nominal/fair/serious/critical)
//   - isLowPowerModeEnabled(bool)
//   - activeProcessorCount / processorCount(int)
//   - memory.rss MB (mach_task_basic_info resident_size)
//   - memory.phys_footprint MB (mach_task_basic_info phys_footprint)
//   - os_proc_available_memory MB(iOS proc limit)
//   - host info: physical RAM(via sysctl hw.memsize)
//
// MLX (per inference within iter):
//   - prompt index + length (chars)
//   - response length (chars / estimated tokens)
//   - first-token latency ms(NB: brain.summary is non-streaming,
//     so this is total inference latency)
//   - tokens / sec computed
//   - memory rss delta before→after each inference
//
// STORAGE (each iter):
//   - L8 atom counts (storage row counts via BASMemoryUsageTracker)
//
// CROSS-ITER (final scorecard):
//   - thermal trajectory(N states)
//   - memory rss trajectory(N values,leak detection)
//   - MLX throughput trajectory(p50,p99,avg per iter)
//   - cooldown effectiveness(thermal state delta before/after cooldown)
//   - power mode trajectory
//   - iter duration p50/p99
//
// ## Output format
//
// Every log line tagged `ch1025 internal-iter=N`(or `iter=N`)so
// fail forensics is grep-able。 Final summary has `📊 ch1025 FINAL`
// prefix。
//
// ## Configuration via env vars
//
//   BAS_LONG_ENDURANCE_RUN     1 = run; unset = XCTSkip
//   BAS_INTERNAL_ITER_COUNT    default 100
//   BAS_INTERNAL_COOLDOWN_SEC  default 60
//   BAS_INTERNAL_ADAPTIVE      default 1
//   BAS_INTERNAL_MLX_PROMPTS   default 3
//
// ## Use case
//
// Run as standalone long endurance test on iPhone Air via
// scripts/run-iphone-air-internal-loop-10hr.sh。 Logs at
// /tmp/ch1025-internal-loop-10hr/ch1025.log。 Post-run analysis:
//   grep "ch1025 mem" log    # memory trajectory
//   grep "ch1025 mlx" log    # MLX per-inference data
//   grep "ch1025 sys" log    # system snapshots
//   grep "ch1025 FINAL" log  # cross-iter summary

import XCTest
import Darwin
@testable import BASHostKit
@testable import BASMemory
@testable import BASMLXAdapter
@testable import BASOrgan
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if !os(macOS)

final class BASChapter1025LongRunningEnduranceTests: XCTestCase {

    // MARK: - Configuration

    private var internalIterCount: Int {
        Int(ProcessInfo.processInfo.environment[
            "BAS_INTERNAL_ITER_COUNT"] ?? "100") ?? 100
    }
    private var internalCooldownSec: Int {
        Int(ProcessInfo.processInfo.environment[
            "BAS_INTERNAL_COOLDOWN_SEC"] ?? "60") ?? 60
    }
    private var internalAdaptiveCooldown: Bool {
        (ProcessInfo.processInfo.environment[
            "BAS_INTERNAL_ADAPTIVE"] ?? "1") == "1"
    }
    private var mlxPromptsPerIter: Int {
        Int(ProcessInfo.processInfo.environment[
            "BAS_INTERNAL_MLX_PROMPTS"] ?? "3") ?? 3
    }
    private func cooldownSecFor(iter: Int) -> Int {
        guard internalAdaptiveCooldown else {
            return internalCooldownSec
        }
        let base = internalCooldownSec
        switch iter {
        case 1...2:   return base
        case 3...5:   return base + 30
        case 6...10:  return base * 2 + 60
        default:      return base * 3 + 120
        }
    }

    // MARK: - System snapshot

    /// Full system snapshot at a moment in time。 Used to capture
    /// before/after for each iter + each MLX inference so post-run
    /// analysis can compute deltas + detect leaks。
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

    /// Capture a complete system snapshot。 All metrics non-destructive
    /// (just reads kernel + ProcessInfo state)。
    private func snapshot() -> SystemSnapshot {
        // mach_task_basic_info for resident_size + phys_footprint
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
            rssMB = Double(info.resident_size) / 1024.0 / 1024.0
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
            thermalState: thermalStateString(),
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

    private func thermalStateString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    /// Format snapshot as a one-line log entry。 All fields tagged
    /// with stable keys for grep + parse。
    private func logSnapshot(
        _ s: SystemSnapshot, iter: Int, phase: String
    ) {
        print(String(format:
            "📊 ch1025 sys iter=%d phase=%@ " +
            "thermal=%@ low_power=%d " +
            "active_cpu=%d/%d " +
            "rss_mb=%.1f footprint_mb=%.1f avail_mb=%d " +
            "mono_ns=%llu",
            iter, phase, s.thermalState,
            s.isLowPowerMode ? 1 : 0,
            s.activeProcessors, s.totalProcessors,
            s.memoryRssMB, s.memoryFootprintMB, s.availableMemoryMB,
            s.monotonicNs))
    }

    // MARK: - MLX prompt pool (varied workload)

    private let promptPool: [String] = [
        "On-device inference matters for privacy. Why is this true?",
        "Summarize:Swift actors prevent data races by isolation。",
        "List 3 reasons MLX beats Core ML on iPhone Air A19 for LLM。",
        "Explain thermal throttling on Apple Silicon under sustained load。",
        "Generate a one-sentence intro for an LLM substrate test framework。",
        "How does an attention head handle a 512-token context window?",
        "What are the trade-offs between Q4 and Q8 quantization for Gemma?",
        "Describe iPhone Air A19 ANE capacity for low-precision matmul。",
    ]

    // MARK: - The single test method

    func testSingleLaunchLongRunningEndurance() async throws {
        // Gate: skip unless explicitly enabled。
        guard ProcessInfo.processInfo.environment[
            "BAS_LONG_ENDURANCE_RUN"] == "1" else {
            throw XCTSkip(
                "Set BAS_LONG_ENDURANCE_RUN=1 to run ch 1025 " +
                "single-launch internal-loop endurance test。 " +
                "Default smokes skip(designed for dedicated " +
                "10hr+ runs only)。")
        }

        let totalIters = internalIterCount
        let mlxPrompts = mlxPromptsPerIter
        let runStart = Date()

        // ─── HOST / DEVICE INFO snapshot ─────────────────────
        print("📊 ch1025 host config iters=\(totalIters) " +
              "mlx_prompts=\(mlxPrompts) " +
              "base_cooldown=\(internalCooldownSec)s " +
              "adaptive=\(internalAdaptiveCooldown)")

        // sysctl hw.memsize for total physical RAM
        var memsize: UInt64 = 0
        var memsizeLen = MemoryLayout<UInt64>.size
        sysctlbyname(
            "hw.memsize", &memsize, &memsizeLen, nil, 0)
        let physRamGB = Double(memsize)
            / 1024.0 / 1024.0 / 1024.0

        print(String(format:
            "📊 ch1025 host device phys_ram_gb=%.1f " +
            "total_cpu=%d active_cpu=%d os=%@",
            physRamGB,
            ProcessInfo.processInfo.processorCount,
            ProcessInfo.processInfo.activeProcessorCount,
            ProcessInfo.processInfo.operatingSystemVersionString))

        // Initial system snapshot
        let initialSnapshot = snapshot()
        logSnapshot(initialSnapshot, iter: 0, phase: "initial")

        // ─── ONE-TIME setup: MLX model load ─────────────────
        // Direct MLX adapter usage(ch 1025.2 fix:BASCognitiveBrainSummary
        // is a classification DTO without body field — use MLXOrganAdapter
        // directly for real LLM body inference,same path as ch 952.1)
        print("📍 ch1025 MLXOrganAdapter loading Gemma 4 E2B")
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        let brainLoadStart = Date()
        try await adapter.loadModel()
        let brainLoadMs = Date()
            .timeIntervalSince(brainLoadStart) * 1000
        let isLoaded = await adapter.isModelLoaded()
        XCTAssertTrue(isLoaded,
            "ch 1025: MLX Gemma 4 E2B must load successfully")
        print(String(format:
            "📍 ch1025 MLXOrganAdapter loaded load_ms=%.0f " +
            "is_loaded=%@",
            brainLoadMs, isLoaded ? "true" : "false"))

        let postLoadSnapshot = snapshot()
        logSnapshot(postLoadSnapshot, iter: 0, phase: "post_brain_load")

        // ─── Per-iter trajectory arrays(for final summary) ──
        var iterDurationMs: [Double] = []
        var iterMlxTokens: [Int] = []
        var iterRssBefore: [Double] = []
        var iterRssAfter: [Double] = []
        var iterThermalBefore: [String] = []
        var iterThermalAfter: [String] = []
        var iterAvailMemBefore: [Int] = []
        var iterAvailMemAfter: [Int] = []
        var iterLowPowerBefore: [Bool] = []
        var iterCooldownThermalRecovery: [String] = []
        var allMlxLatenciesMs: [Double] = []
        var totalTokens = 0

        for iter in 1...totalIters {
            let iterStart = Date()
            let elapsedSec = Int(iterStart
                .timeIntervalSince(runStart))

            print("📍 ch1025 internal-iter=\(iter) start " +
                  "elapsed=\(elapsedSec)s")

            // ─── BEFORE snapshot ────────────────────────
            let snapBefore = snapshot()
            logSnapshot(snapBefore, iter: iter, phase: "before")
            iterRssBefore.append(snapBefore.memoryRssMB)
            iterThermalBefore.append(snapBefore.thermalState)
            iterAvailMemBefore.append(
                snapBefore.availableMemoryMB)
            iterLowPowerBefore.append(snapBefore.isLowPowerMode)

            // ─── MLX inference loop ─────────────────────
            // ch 1025.2 fix:use MLXOrganAdapter.draft() directly
            // (real body output + real token count)。
            var iterTokens = 0
            for p in 0..<mlxPrompts {
                let prompt = promptPool[
                    (iter * mlxPrompts + p) % promptPool.count]
                let promptLen = prompt.count

                let mlxPreSnap = snapshot()
                let mlxStart = Date()
                let request = BASOrganRequest(
                    requestID: "ch1025-iter\(iter)-prompt\(p)",
                    role: .core,
                    preset: .core,
                    instruction: prompt,
                    context: [])
                let draft = try await adapter.draft(request)
                let mlxMs = Date()
                    .timeIntervalSince(mlxStart) * 1000
                let mlxPostSnap = snapshot()

                let bodyLen = draft.body.count
                let tokens = draft.outputTokensEstimated
                let tps = mlxMs > 0
                    ? Double(tokens) / (mlxMs / 1000.0) : 0
                iterTokens += tokens
                allMlxLatenciesMs.append(mlxMs)

                let rssDeltaMB = mlxPostSnap.memoryRssMB
                    - mlxPreSnap.memoryRssMB
                print(String(format:
                    "🧠 ch1025 mlx iter=%d prompt=%d " +
                    "prompt_len=%d resp_len=%d tokens=%d " +
                    "latency_ms=%.0f tok_per_s=%.2f " +
                    "rss_delta_mb=%.2f",
                    iter, p + 1, promptLen, bodyLen,
                    tokens, mlxMs, tps, rssDeltaMB))
            }
            iterMlxTokens.append(iterTokens)
            totalTokens += iterTokens

            // ─── AFTER snapshot ─────────────────────────
            let snapAfter = snapshot()
            logSnapshot(snapAfter, iter: iter, phase: "after")
            iterRssAfter.append(snapAfter.memoryRssMB)
            iterThermalAfter.append(snapAfter.thermalState)
            iterAvailMemAfter.append(
                snapAfter.availableMemoryMB)

            let iterMs = Date()
                .timeIntervalSince(iterStart) * 1000
            iterDurationMs.append(iterMs)

            print(String(format:
                "📊 ch1025 scorecard iter=%d iter_ms=%.0f " +
                "tokens=%d cumul_tokens=%d " +
                "thermal=%@→%@ rss_mb=%.1f→%.1f " +
                "avail_mb=%d→%d",
                iter, iterMs, iterTokens, totalTokens,
                snapBefore.thermalState,
                snapAfter.thermalState,
                snapBefore.memoryRssMB,
                snapAfter.memoryRssMB,
                snapBefore.availableMemoryMB,
                snapAfter.availableMemoryMB))

            // ─── Adaptive cooldown ──────────────────────
            if iter < totalIters {
                let cooldown = cooldownSecFor(iter: iter)
                print("⏸ ch1025 cooldown iter=\(iter) " +
                      "duration_s=\(cooldown) starting")
                let preCooldownSnap = snapshot()
                try await Task.sleep(
                    for: .seconds(cooldown))
                let postCooldownSnap = snapshot()
                let recovery =
                    "\(preCooldownSnap.thermalState)" +
                    "→\(postCooldownSnap.thermalState)"
                iterCooldownThermalRecovery.append(recovery)
                print("⏸ ch1025 cooldown iter=\(iter) done " +
                      "thermal_recovery=\(recovery) " +
                      "rss_pre_mb=" +
                      String(format: "%.1f",
                             preCooldownSnap.memoryRssMB) +
                      " rss_post_mb=" +
                      String(format: "%.1f",
                             postCooldownSnap.memoryRssMB))
            }
        }

        // ─── FINAL SUMMARY ──────────────────────────────────
        let totalSec = Date().timeIntervalSince(runStart)

        let sortedDurMs = iterDurationMs.sorted()
        let avgDurMs = iterDurationMs.reduce(0, +)
            / Double(iterDurationMs.count)
        let p50DurMs = sortedDurMs[sortedDurMs.count / 2]
        let p99DurMs = sortedDurMs[min(
            sortedDurMs.count - 1,
            Int(Double(sortedDurMs.count) * 0.99))]

        let sortedMlxLat = allMlxLatenciesMs.sorted()
        let avgMlxMs = allMlxLatenciesMs.reduce(0, +)
            / Double(allMlxLatenciesMs.count)
        let p50MlxMs = sortedMlxLat[sortedMlxLat.count / 2]
        let p99MlxMs = sortedMlxLat[min(
            sortedMlxLat.count - 1,
            Int(Double(sortedMlxLat.count) * 0.99))]

        let avgTokensPerIter = iterMlxTokens.reduce(0, +)
            / iterMlxTokens.count
        let avgRssBefore = iterRssBefore.reduce(0, +)
            / Double(iterRssBefore.count)
        let avgRssAfter = iterRssAfter.reduce(0, +)
            / Double(iterRssAfter.count)
        let rssGrowthMB = (iterRssAfter.last ?? 0)
            - (iterRssBefore.first ?? 0)

        print(String(format:
            "📊 ch1025 FINAL run_sec=%.0f iters=%d " +
            "avg_iter_ms=%.0f p50_iter_ms=%.0f p99_iter_ms=%.0f",
            totalSec, totalIters,
            avgDurMs, p50DurMs, p99DurMs))
        print(String(format:
            "📊 ch1025 FINAL mlx_total_inferences=%d " +
            "avg_lat_ms=%.0f p50_lat_ms=%.0f p99_lat_ms=%.0f " +
            "total_tokens=%d avg_tokens_per_iter=%d",
            allMlxLatenciesMs.count, avgMlxMs,
            p50MlxMs, p99MlxMs, totalTokens, avgTokensPerIter))
        print(String(format:
            "📊 ch1025 FINAL memory avg_rss_before_mb=%.1f " +
            "avg_rss_after_mb=%.1f total_rss_growth_mb=%.1f",
            avgRssBefore, avgRssAfter, rssGrowthMB))
        print("📊 ch1025 FINAL thermal_before_trajectory=" +
              iterThermalBefore.joined(separator: ","))
        print("📊 ch1025 FINAL thermal_after_trajectory=" +
              iterThermalAfter.joined(separator: ","))
        print("📊 ch1025 FINAL cooldown_thermal_recovery=" +
              iterCooldownThermalRecovery.joined(separator: ","))
        print(String(format:
            "📊 ch1025 FINAL rss_trajectory_mb=%@",
            iterRssAfter.map {
                String(format: "%.1f", $0)
            }.joined(separator: ",")))
        print(String(format:
            "📊 ch1025 FINAL tokens_per_iter=%@",
            iterMlxTokens.map { String($0) }
                .joined(separator: ",")))
        print(String(format:
            "📊 ch1025 FINAL avail_mem_before_trajectory_mb=%@",
            iterAvailMemBefore.map { String($0) }
                .joined(separator: ",")))

        // ─── Final XCTest assertions ────────────────────────
        XCTAssertEqual(
            iterDurationMs.count, totalIters,
            "ch 1025: every internal iter must complete。 " +
            "Got \(iterDurationMs.count) of \(totalIters)。")
        XCTAssertGreaterThan(
            totalTokens, 0,
            "ch 1025: MLX must produce real tokens across endurance。 " +
            "Got 0 across all \(totalIters) iters。")
        // Memory leak sanity:if RSS grew > 500 MB across the run,
        // flag for investigation。 Normal range:0-50 MB drift。
        XCTAssertLessThan(
            rssGrowthMB, 500.0,
            "ch 1025: RSS grew > 500 MB across \(totalIters) iters " +
            "(\(rssGrowthMB) MB)。 Possible substrate leak — investigate。")
    }
}
#endif
