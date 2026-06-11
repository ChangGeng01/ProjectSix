// MARK: - BASFoundationModelsProbe — iOS 27 P5 (IOS27_PERF_ADOPTION_PLAN)
//
// Power/thermal probe for the ANE-resident system language model as
// a lane for reasoning-side BATCH TEXT work (T3.1 consolidation
// summaries / tagging) — the only sanctioned ANE win available this
// cycle (CoreML shipped zero perf API;T1.2 zero-placement verdict
// stands for the custom heads)。
//
// What it measures honestly:
//   - availability (Apple Intelligence device gate — recorded,not
//     assumed)
//   - per-summary latency over 8 consolidation-style prompts
//   - ProcessInfo.thermalState before/after (the power proxy this
//     probe CAN see;battery-level deltas need a longer soak)
// The MLX comparison lane already exists in endurance logs (per-
// prompt mlx_ms) — the human reads both for the verdict。
// Output is NONDETERMINISTIC ⇒ any production lane is default-off,
// reasoning-side only,never spine (ADR-014;gates never
// auto-promote)。 PROBE-ONLY: DeviceTestApp,no SPM symbols。

import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

enum BASFoundationModelsProbe {

    private static let log = Logger(
        subsystem: "com.bas.devicetest", category: "fm-probe")

    private static func emit(_ line: String) {
        log.info("\(line, privacy: .public)")
        print(line)
    }

    private static let prompts = [
        "总结:用户连续三天在深夜讨论工作压力,语气逐渐疲惫。",
        "总结:本周的对话主题从旅行计划转向了预算担忧。",
        "Summarize: the user asked twice about the same deadline.",
        "Tag the theme: conversations about trust with a colleague.",
        "总结:用户反复确认明天的安排,显示出焦虑情绪。",
        "Summarize: planning discussion drifted into self-doubt.",
        "Tag the theme: late-night reflection on a hard decision.",
        "总结:用户对新工具的态度从怀疑转为好奇。",
    ]

    static func run() async {
        emit("📊 fm-probe START prompts=\(prompts.count)")
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            emit("❌ fm-probe ABORT below iOS 26")
            return
        }
        let model = SystemLanguageModel.default
        emit("📊 fm-probe availability=\(model.availability) "
            + "(Apple Intelligence device gate — recorded, not assumed)")
        guard model.isAvailable else {
            emit("📊 fm-probe VERDICT=UNAVAILABLE — lane stays closed "
                + "on this device by evidence")
            return
        }
        let thermalBefore = ProcessInfo.processInfo.thermalState
        let instructions = "你是记忆巩固助手。一句话完成任务,不解释。"
        // Audit fix (gap-close MEDIUM): LanguageModelSession is
        // STATEFUL MULTITURN (transcript accumulates and re-feeds as
        // context),so one shared session inflated prompt i's
        // latency with i-1 prior turns — a structural skew against
        // the FM lane vs the INDEPENDENT per-prompt mlx_ms
        // comparison。 Fix: ONE warm-up call (absorbs model load),
        // then a FRESH session per prompt — every sample is an
        // independent batch item,matching the workload being probed。
        do {
            let warmup = LanguageModelSession(
                model: model, instructions: instructions)
            _ = try await warmup.respond(to: "预热:返回'好'。")
            emit("📊 fm-probe warm-up done (model-load cost excluded "
                + "from per-prompt samples)")
        } catch {
            emit("⚠️ fm-probe warm-up failed: \(error)")
        }
        var latencies: [Double] = []
        var failures = 0
        for (i, prompt) in prompts.enumerated() {
            let session = LanguageModelSession(
                model: model, instructions: instructions)
            let t0 = DispatchTime.now().uptimeNanoseconds
            do {
                let response = try await session.respond(to: prompt)
                let ms = Double(
                    DispatchTime.now().uptimeNanoseconds - t0) / 1e6
                latencies.append(ms)
                emit(String(format:
                    "📊 fm-probe[%d] ms=%.0f chars=%d (fresh session)",
                    i, ms, response.content.count))
            } catch {
                failures += 1
                emit("⚠️ fm-probe[\(i)] failed: \(error) "
                    + "(guardrails can reject — counted, not hidden)")
            }
        }
        let thermalAfter = ProcessInfo.processInfo.thermalState
        let mean = latencies.isEmpty
            ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        emit(String(format:
            "📊 fm-probe RESULT ok=%d fail=%d mean_ms=%.0f "
            + "thermal %d→%d — human compares vs the endurance "
            + "per-prompt mlx_ms lane; output nondeterministic ⇒ any "
            + "production lane is default-off reasoning-side only",
            latencies.count, failures, mean,
            thermalBefore.rawValue, thermalAfter.rawValue))
        #else
        emit("❌ fm-probe ABORT FoundationModels not importable")
        #endif
    }
}
