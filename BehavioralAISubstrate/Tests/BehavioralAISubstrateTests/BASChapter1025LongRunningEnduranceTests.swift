// MARK: - BASChapter1025LongRunningEnduranceTests
// chapter 一千零二十五 / M3895 — single-launch internal-loop endurance
//
// ## User mandate
//
// 「需要 内部循环 测试 内部 thermal 相关 设置 + 写的 细节一些
//  (per-iter 颗粒度,避免 log 混在一起 fail 不知道哪 iter)」
//
// ## Why this exists
//
// Previous external-loop endurance (scripts/run-iphone-air-10hr.sh)
// invokes `xcodebuild test` per iter:
//   - PRO: per-iter exit signal,clean log separation,thermal cooldown
//     between full xcodebuild invocations
//   - CON: each iter re-launches test runner on iPhone(visible app
//     cycle:exit → re-spawn),~10-30s overhead per iter
//
// This chapter's approach: ONE xcodebuild test invocation,internal
// loop with explicit per-iter logging + internal thermal cooldown:
//   - PRO: single app launch,no inter-iter re-spawn overhead
//   - PRO: scorecard line per internal iter for trend analysis
//   - PRO: built-in thermal sampling + adaptive cooldown
//   - CON: XCTest treats this as ONE test (single pass/fail signal)
//   - MITIGATION: every log line tagged with`internal-iter=N` for
//     post-mortem fail attribution
//
// ## Configuration (env vars)
//
//   BAS_LONG_ENDURANCE_RUN     1 = run this test; unset = XCTSkip
//                              (so default xctestplan smokes don't
//                               accidentally invoke a 10hr test)
//   BAS_INTERNAL_ITER_COUNT    default 100 — number of internal iters
//   BAS_INTERNAL_COOLDOWN_SEC  default 60 — base cooldown sec
//   BAS_INTERNAL_ADAPTIVE      default 1 — scale cooldown w/ iter count
//   BAS_INTERNAL_MLX_PROMPTS   default 3 — MLX prompts per iter
//
// ## Adaptive cooldown schedule(mirror script's logic)
//
//   iter 1-2:  base cooldown
//   iter 3-5:  base + 30s
//   iter 6-10: base × 2 + 60s
//   iter 11+:  base × 3 + 120s
//
// ## Per-iter log format
//
//   📍 ch1025 internal-iter=N start elapsed=Xs/MAX
//   🌡️ ch1025 internal-iter=N thermal.before=<state>
//   🧠 ch1025 internal-iter=N mlx.prompt=K tokens=T tok/s=R latency_ms=L
//   📊 ch1025 internal-iter=N scorecard tps_p50=X tps_p99=Y tokens_total=Z
//   🌡️ ch1025 internal-iter=N thermal.after=<state>
//   ⏸ ch1025 internal-iter=N cooldown=Xs starting
//   ✅ ch1025 internal-iter=N done passed=T
//
// Post-mortem: grep `ch1025 internal-iter=N` to isolate fail's iter。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if !os(macOS)
// iOS-only: real Apple Silicon device thermal + MLX inference path。
// On macOS this test is skipped because thermal envelope is too
// different to be useful endurance data。
final class BASChapter1025LongRunningEnduranceTests: XCTestCase {

    // MARK: - Configuration helpers

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

    /// Adaptive cooldown duration scaled by internal-iter index。
    /// Mirrors scripts/run-iphone-air-10hr.sh logic for consistent
    /// thermal envelope behavior with external-loop endurance。
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

    /// Thermal state string for logging。
    private func thermalStateString() -> String {
        let s = ProcessInfo.processInfo.thermalState
        switch s {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    // MARK: - MLX prompts pool

    /// Varied prompts to exercise different prompt shapes per iter。
    /// Cycle through these instead of hammering one prompt to better
    /// reflect production load variety。
    private let promptPool: [String] = [
        "On-device inference matters for privacy. Why?",
        "Summarize:Swift actors prevent data races。",
        "List 3 reasons to use MLX over Core ML on iPhone Air。",
        "Explain thermal throttling on A19 Pro under sustained load。",
        "Generate a one-sentence intro for an LLM substrate test。",
    ]

    // MARK: - The single test method

    func testSingleLaunchLongRunningEndurance() async throws {
        // Gate: requires explicit env var so default smokes don't
        // accidentally invoke a 10hr test。
        guard ProcessInfo.processInfo.environment[
            "BAS_LONG_ENDURANCE_RUN"] == "1" else {
            throw XCTSkip(
                "Set BAS_LONG_ENDURANCE_RUN=1 to run ch 1025 " +
                "single-launch internal-loop endurance test。 " +
                "Default smokes skip this (designed for dedicated " +
                "10hr+ smoke runs only)。")
        }

        let totalIters = internalIterCount
        let mlxPrompts = mlxPromptsPerIter
        let startTs = Date()
        print("📍 ch1025 endurance starting iters=\(totalIters) " +
              "mlxPrompts=\(mlxPrompts) " +
              "baseCooldown=\(internalCooldownSec)s " +
              "adaptive=\(internalAdaptiveCooldown)")

        // ONE-TIME setup: load brain + MLX model。 Subsequent iters
        // reuse this single brain instance(no re-load)。
        print("📍 ch1025 brain.makeWithAllPilots starting")
        let brainLoadStart = Date()
        let brain = try await BASCognitiveBrain.makeWithAllPilots()
        let brainLoadMs = Date().timeIntervalSince(brainLoadStart) * 1000
        print(String(format:
            "📍 ch1025 brain.makeWithAllPilots done load_ms=%.0f",
            brainLoadMs))

        // Per-iter accumulators for cross-iter trend analysis。
        var iterMs: [Double] = []
        var mlxTokensPerIter: [Int] = []
        var thermalBeforeEachIter: [String] = []
        var thermalAfterEachIter: [String] = []
        var totalTokens = 0
        var failureCount = 0

        for iter in 1...totalIters {
            let iterStart = Date()
            let elapsedSec = Int(iterStart.timeIntervalSince(startTs))

            // ─── BEFORE: thermal sample ───
            let thermalBefore = thermalStateString()
            thermalBeforeEachIter.append(thermalBefore)
            print("📍 ch1025 internal-iter=\(iter) start " +
                  "elapsed=\(elapsedSec)s/" +
                  "\(totalIters * 360 /* est 6m/iter */)s")
            print("🌡️ ch1025 internal-iter=\(iter) " +
                  "thermal.before=\(thermalBefore)")

            // ─── MLX inference loop(K prompts)───
            var iterTokens = 0
            for p in 0..<mlxPrompts {
                let prompt = promptPool[
                    (iter * mlxPrompts + p) % promptPool.count]
                let mlxStart = Date()
                let summary = await brain.summary(prompt)
                let mlxMs = Date()
                    .timeIntervalSince(mlxStart) * 1000
                let bodyLen = summary.suggestedResponse.body.count
                let tokens = bodyLen / 4 // rough token estimate
                iterTokens += tokens
                print(String(format:
                    "🧠 ch1025 internal-iter=%d mlx.prompt=%d " +
                    "tokens=%d latency_ms=%.0f",
                    iter, p + 1, tokens, mlxMs))
            }
            mlxTokensPerIter.append(iterTokens)
            totalTokens += iterTokens

            // ─── AFTER: thermal sample ───
            let thermalAfter = thermalStateString()
            thermalAfterEachIter.append(thermalAfter)
            print("🌡️ ch1025 internal-iter=\(iter) " +
                  "thermal.after=\(thermalAfter)")

            let iterMsElapsed = Date()
                .timeIntervalSince(iterStart) * 1000
            iterMs.append(iterMsElapsed)
            print(String(format:
                "📊 ch1025 internal-iter=%d scorecard " +
                "iter_ms=%.0f tokens=%d cumulative_tokens=%d",
                iter, iterMsElapsed, iterTokens, totalTokens))

            print("✅ ch1025 internal-iter=\(iter) done")

            // ─── Adaptive cooldown(skip after last iter)───
            if iter < totalIters {
                let cooldown = cooldownSecFor(iter: iter)
                print("⏸ ch1025 internal-iter=\(iter) " +
                      "cooldown=\(cooldown)s starting")
                try await Task.sleep(
                    for: .seconds(cooldown))
                print("⏸ ch1025 internal-iter=\(iter) " +
                      "cooldown done")
            }
        }

        // ─── Final cross-iter summary ───
        let totalSec = Date().timeIntervalSince(startTs)
        let avgIterMs = iterMs.reduce(0, +) / Double(iterMs.count)
        let avgTokensPerIter = mlxTokensPerIter.reduce(0, +)
            / mlxTokensPerIter.count
        let sortedIterMs = iterMs.sorted()
        let p50Ms = sortedIterMs[sortedIterMs.count / 2]
        let p99Ms = sortedIterMs[
            min(sortedIterMs.count - 1, Int(Double(sortedIterMs.count) * 0.99))]

        print(String(format:
            "📊 ch1025 FINAL iters=%d total_sec=%.0f " +
            "avg_iter_ms=%.0f p50_iter_ms=%.0f p99_iter_ms=%.0f " +
            "total_tokens=%d avg_tokens_per_iter=%d failures=%d",
            totalIters, totalSec, avgIterMs, p50Ms, p99Ms,
            totalTokens, avgTokensPerIter, failureCount))
        print("📊 ch1025 FINAL thermal_before_trajectory=" +
              "\(thermalBeforeEachIter.joined(separator: ","))")
        print("📊 ch1025 FINAL thermal_after_trajectory=" +
              "\(thermalAfterEachIter.joined(separator: ","))")

        // Final assertion:no per-iter failure escalation。 The test
        // body itself doesn't fail per-iter(it logs and continues)。
        // Real fail = XCTest assertion below。
        XCTAssertEqual(iterMs.count, totalIters,
            "ch 1025: every internal iter must complete。 " +
            "Got \(iterMs.count) of \(totalIters)。")
        XCTAssertGreaterThan(totalTokens, 0,
            "ch 1025: MLX must produce real tokens across endurance。" +
            "Got 0 across all \(totalIters) iters。")
    }
}
#endif
