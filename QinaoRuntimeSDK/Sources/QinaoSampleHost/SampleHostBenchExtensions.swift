// MARK: - SampleHostBenchExtensions — chapter 二百八十八 / M775
//
// Phase Alpha 第十四刀(QinaoSampleHost god file 1st cut):从
// `main.swift` (8224 LOC) 抽出 bench cluster 的 8 个 helper
// functions + 3 个 static lets。Phase Alpha 第四个 god file 拆分启动。
//
// 抽出 helpers (Swift extension on QinaoSampleHost):
//   - `runAuditLedgerBench` (M357) — Ed25519-signed audit ledger
//     append latency bench
//   - `runMultiHostMergeBench` (M358) — cross-device fragment
//     merger latency bench
//   - `runFullStackBench` + `emitFullStackBanner` + 3 static lets
//     (M361/M362) — full L1-L14 stack throughput bench
//   - `runLifecycleBench` (M363) — update-ticket lifecycle bench
//   - `runSHA256Bench` (M364) — CryptoKit SHA256 bench
//   - `runJSONCodecBench` (M365) — Foundation JSON codec bench
//   - `runBenchSuite` (M366) — orchestrates all 8 benches
//   - `runEd25519SignBench` (M380) — pure Ed25519 sign bench
//
// **0 behavior change**:helpers literal-identical to pre-extraction
// versions,只是改成了 Swift extension on QinaoSampleHost。Module
// DAG 不变(同 module 内部 split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth: helpers 仅 owned by 此 file
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//   - bench baselines + multi-trial 2σ regression check 行为不变

import Foundation
import BASObservability
import BASSovereign

extension QinaoSampleHost {

    // MARK: - M357 audit-ledger-bench

    /// Drive `BASSovereignAuditLedger.append` × N entries +
    /// emit M355 latency stats banner. Default N=10000;
    /// `QINAO_BENCH_LEDGER_ENTRY_COUNT=N` override.
    static func runAuditLedgerBench() async {
        let entryCount: Int = {
            if let raw = ProcessInfo.processInfo
                .environment[
                    "QINAO_BENCH_LEDGER_ENTRY_COUNT"],
               let n = Int(raw),
               n > 0
            {
                return n
            }
            return 10_000
        }()

        print("""
            QinaoSampleHost --audit-ledger-bench (M357):
              append \(entryCount) entries to a fresh
              Ed25519-signed BASSovereignAuditLedger.

              \(AuditLedgerBench.scopeStatement)
            """)

        do {
            let outcome = try await AuditLedgerBench.run(
                entryCount: entryCount)
            print("""

                ━━━ M357 audit-ledger-bench (\(outcome.entryCount) entries) ━━━
                elapsed wall:  \(String(format: "%.2f", outcome.elapsedSeconds)) sec
                throughput:    \(String(format: "%.1f", Double(outcome.entryCount) / outcome.elapsedSeconds)) entries/sec

                """)
            for line in outcome.latency.bannerLines() {
                print("  " + line)
            }
            compareToBaselineIfConfigured(
                benchName: "audit-ledger-bench",
                stats: outcome.latency)
            print("\n  ━━━ Demo complete — \(outcome.entryCount) entries appended ━━━")
        } catch {
            print("ERROR: --audit-ledger-bench failed: \(error)")
            exit(2)
        }
    }

    // MARK: - M358 multi-host-merge-bench

    /// Drive `BASMultiHostConvergenceMetric.measure` over
    /// varying frame counts (10 / 100 / 1000 / 10000) to
    /// quantify FragmentMerger growth shape.
    static func runMultiHostMergeBench() async {
        let frameCounts: [Int] = [10, 100, 1_000, 10_000]
        print("""
            QinaoSampleHost --multi-host-merge-bench (M358):
              measure BASSovereignFragmentMerger.mergeOrdered
              latency over varying frame counts. Each row
              measures forward + reverse merge for symmetry
              verification (so wall-time = ~2× single merge).

              [scope] regression alarm, not an SLA. measures
              in-process FragmentMerger only — no network, no
              ledger I/O, no actor hops across runtime layers.
              do not quote these numbers as customer-facing
              latency.

            """)
        for n in frameCounts {
            let outcome = MultiHostMergeBench.run(
                framesPerHost: n)
            print("""
                ━━━ M358 multi-host-merge-bench: \(n) frames per host ━━━
                """)
            print("""
                  consensus frames:    \(outcome.metric.framesInConsensus)
                  duplicates:          \(outcome.metric.duplicateFramesInConsensus)
                  symmetric:           \(outcome.metric.mergeIsSymmetric ? "✓" : "✗")
                  wall (sec):          \(String(format: "%.6f", outcome.metric.mergeWallClockSeconds))
                  throughput (frames/sec): \(String(format: "%.0f", Double(2 * n) / outcome.metric.mergeWallClockSeconds))
                  invariants hold:     \(outcome.metric.allInvariantsHold ? "✓" : "✗")
                """)
            if !outcome.metric.failingInvariants.isEmpty {
                print("  failing: \(outcome.metric.failingInvariants)")
            }
            print("")
        }
        print("  ━━━ Demo complete — merge growth shape captured across 4 sizes ━━━")
    }

    // MARK: - M359 full-stack-bench

    /// Drive `BASHostRuntime.startSession` × N sessions × M
    /// turns each, measuring per-session latency.
    /// M438 (chapter 一百十三 anti-magic-number sweep) — named
    /// defaults for `runFullStackBench`. Pre-M438 these were
    /// `return 20` and `return 5` literals inside the env-
    /// fallback closures, with no explanation of why those
    /// numbers. The defaults are chosen for "fast smoke test"
    /// shape (~1 sec wall-clock at 20 sessions × 5 turns); the
    /// production bench-suite invocation overrides via env
    /// `QINAO_BENCH_FULL_STACK_SESSIONS=100` (chapter 一百九).
    /// Naming the constants also lets future tests pin them.
    static let runFullStackBenchDefaultSessionCount: Int = 20
    static let runFullStackBenchDefaultTurnCount: Int = 5
    /// M438 — when no `QINAO_BENCH_FULL_STACK_TRIALS` env var
    /// set, fall back to single-trial path (chapter 一百十一
    /// backward-compat). Production bench-suite (chapter 一百十二)
    /// overrides to 3 via env.
    static let runFullStackBenchDefaultTrialCount: Int = 1

    static func runFullStackBench() async {
        let sessionCount: Int = {
            if let raw = ProcessInfo.processInfo
                .environment[
                    "QINAO_BENCH_FULL_STACK_SESSIONS"],
               let n = Int(raw),
               n > 0
            {
                return n
            }
            return Self.runFullStackBenchDefaultSessionCount
        }()
        let turnCount: Int = {
            if let raw = ProcessInfo.processInfo
                .environment[
                    "QINAO_BENCH_FULL_STACK_TURNS"],
               let n = Int(raw),
               n > 0
            {
                return n
            }
            return Self.runFullStackBenchDefaultTurnCount
        }()
        // M437.1 (chapter 一百十一) — multi-trial capture mode.
        // When `QINAO_BENCH_FULL_STACK_TRIALS=N` (N≥2) is set,
        // run the bench N times and aggregate trial-level
        // stats into a v2 baseline (chapter 一百十 schema). This
        // consumes the M437 multi-trial baseline schema for
        // stat-rigorous regression detection at <10% (vs the
        // ~20% single-trial floor).
        let trialCount: Int = {
            if let raw = ProcessInfo.processInfo
                .environment[
                    "QINAO_BENCH_FULL_STACK_TRIALS"],
               let n = Int(raw),
               n >= 1
            {
                return n
            }
            return Self.runFullStackBenchDefaultTrialCount
        }()

        print("""
            QinaoSampleHost --full-stack-bench (M359):
              drive BASHostRuntime.startSession × \(sessionCount)
              sessions × \(turnCount) turns each \
              \(trialCount > 1 ? "× \(trialCount) trials (M437.1)" : "").

              [scope] regression alarm, not an SLA. measures
              in-process BASHostRuntime startSession only —
              no Apple Foundation Models inference, no
              persistent SQLite I/O, no real network. do not
              quote these numbers as customer-facing latency.

            """)

        // Single-trial path (backward-compat): no aggregation,
        // emit single-trial stats.
        if trialCount == 1 {
            let outcome = await FullStackBench.run(
                sessionCount: sessionCount,
                turnCount: turnCount)
            emitFullStackBanner(outcome: outcome)
            if let warmupOutcome = outcome.perSessionOutcome {
                let stats = warmupOutcome.warm
                    ?? warmupOutcome.combined
                compareToBaselineIfConfigured(
                    benchName: "full-stack-bench",
                    stats: stats)
            }
            print(
                "\n  ━━━ Demo complete — "
                + "\(outcome.successfulSessions) sessions "
                + "completed ━━━")
            return
        }

        // Multi-trial path: run N trials, aggregate stats.
        var trialStats: [BASBenchLatencyStats] = []
        var lastSingleTrialStats: BASBenchLatencyStats?
        for trial in 1 ... trialCount {
            print("\n  ── trial \(trial)/\(trialCount) ──")
            let outcome = await FullStackBench.run(
                sessionCount: sessionCount,
                turnCount: turnCount)
            if let warmupOutcome = outcome.perSessionOutcome {
                let stats = warmupOutcome.warm
                    ?? warmupOutcome.combined
                trialStats.append(stats)
                lastSingleTrialStats = stats
                print(
                    "    p50=\(String(format: "%.4f", stats.p50)) ms "
                    + "p95=\(String(format: "%.4f", stats.p95)) ms "
                    + "mean=\(String(format: "%.4f", stats.mean)) ms")
            }
        }
        guard
            let summary = BASBenchBaselineStorage
                .MultiTrialStats.summarize(trials: trialStats),
            let lastStats = lastSingleTrialStats
        else {
            print("  multi-trial: no successful trials")
            return
        }
        print("""

              ── multi-trial summary (N=\(summary.trialCount), M437.1) ──
                p50:  mean \(String(format: "%.4f", summary.p50Mean)) ± \(String(format: "%.4f", summary.p50StdDev)) ms
                p95:  mean \(String(format: "%.4f", summary.p95Mean)) ± \(String(format: "%.4f", summary.p95StdDev)) ms
                mean: mean \(String(format: "%.4f", summary.meanMean)) ± \(String(format: "%.4f", summary.meanStdDev)) ms
            """)
        compareToBaselineIfConfiguredMultiTrial(
            benchName: "full-stack-bench",
            stats: lastStats,
            trialStats: summary)
        print(
            "\n  ━━━ Multi-trial complete — "
            + "\(trialCount) trials aggregated ━━━")
    }

    private static func emitFullStackBanner(
        outcome: FullStackBench.Outcome
    ) {
        print("""

            ━━━ M359 full-stack-bench (\(outcome.sessionCount) sessions × \(outcome.turnsPerSession) turns) ━━━
            elapsed wall:  \(String(format: "%.2f", outcome.elapsedSeconds)) sec
            sessions ok:   \(outcome.successfulSessions) / \(outcome.sessionCount)

            """)
        if let warmupOutcome = outcome.perSessionOutcome {
            // M377 — emit cold/warm split bannerLines.
            for line in warmupOutcome.bannerLines(
                unit: "ms")
            {
                print("  " + line)
            }
        } else {
            print("  no successful sessions to measure")
        }
    }

    // MARK: - M363 lifecycle-bench

    static func runLifecycleBench() {
        let count = envInt(
            "QINAO_BENCH_LIFECYCLE_COUNT",
            default: 100_000)
        print("""
            QinaoSampleHost --lifecycle-bench (M363):
              \(count) full L13 traversals (5 transitions
              each: registerCandidate → startShadowTrial →
              finalizeTrial → promote → retract).

              \(LifecycleBench.scopeStatement)
            """)
        let outcome = LifecycleBench.run(
            traversalCount: count)
        print("""

            ━━━ M363 lifecycle-bench (\(outcome.traversalCount) traversals) ━━━
            elapsed wall:  \(String(format: "%.4f", outcome.elapsedSeconds)) sec
            throughput:    \(String(format: "%.1f", Double(outcome.traversalCount) / outcome.elapsedSeconds)) traversals/sec

            """)
        for line in outcome.outcome.bannerLines(unit: "ms") {
            print("  " + line)
        }
        compareToBaselineIfConfigured(
            benchName: "lifecycle-bench",
            stats: outcome.outcome.warm
                ?? outcome.outcome.combined)
        print("\n  ━━━ Demo complete — \(outcome.traversalCount) traversals ━━━")
    }

    // MARK: - M364 sha256-bench

    static func runSHA256Bench() {
        let count = envInt(
            "QINAO_BENCH_SHA256_COUNT",
            default: 100_000)
        print("""
            QinaoSampleHost --sha256-bench (M364):
              \(count) SHA-256 hashes over the L13
              canonical encoding (\(SHA256Bench.canonicalInput.utf8.count) bytes).

              \(SHA256Bench.scopeStatement)
            """)
        let outcome = SHA256Bench.run(
            hashCount: count)
        let throughputBytesPerSec =
            Double(outcome.hashCount * outcome.inputBytes)
            / outcome.elapsedSeconds
        let throughputMB = throughputBytesPerSec
            / (1024.0 * 1024.0)
        print("""

            ━━━ M364 sha256-bench (\(outcome.hashCount) hashes × \(outcome.inputBytes) bytes) ━━━
            elapsed wall:  \(String(format: "%.4f", outcome.elapsedSeconds)) sec
            throughput:    \(String(format: "%.1f", Double(outcome.hashCount) / outcome.elapsedSeconds)) hashes/sec
                           \(String(format: "%.2f", throughputMB)) MB/sec

            """)
        for line in outcome.outcome.bannerLines(unit: "ms") {
            print("  " + line)
        }
        compareToBaselineIfConfigured(
            benchName: "sha256-bench",
            stats: outcome.outcome.warm
                ?? outcome.outcome.combined)
        print("\n  ━━━ Demo complete — \(outcome.hashCount) hashes ━━━")
    }

    // MARK: - M365 json-codec-bench

    static func runJSONCodecBench() {
        let count = envInt(
            "QINAO_BENCH_JSON_COUNT", default: 50_000)
        print("""
            QinaoSampleHost --json-codec-bench (M365):
              \(count) BASSovereignAuditEntry JSON encode +
              decode round-trips on a representative entry
              (~5 ruleIDs × ~5 signal refs).

              \(JSONCodecBench.scopeStatement)
            """)
        do {
            let outcome = try JSONCodecBench.run(
                roundTripCount: count)
            print("""

                ━━━ M365 json-codec-bench (\(outcome.roundTripCount) round-trips × \(outcome.entrySerializedBytes) bytes/entry) ━━━
                elapsed wall:  \(String(format: "%.4f", outcome.elapsedSeconds)) sec
                throughput:    \(String(format: "%.1f", Double(outcome.roundTripCount) / outcome.elapsedSeconds)) round-trips/sec

                """)
            for line in outcome.outcome.bannerLines(
                unit: "ms")
            {
                print("  " + line)
            }
            compareToBaselineIfConfigured(
                benchName: "json-codec-bench",
                stats: outcome.outcome.warm
                    ?? outcome.outcome.combined)
            print("\n  ━━━ Demo complete — \(outcome.roundTripCount) round-trips ━━━")
        } catch {
            print("ERROR: --json-codec-bench failed: \(error)")
            exit(2)
        }
    }

    // MARK: - M366 bench-suite

    static func runBenchSuite() async {
        print("""
            QinaoSampleHost --bench-suite (M366):
              run all 8 bench modes sequentially with small
              default sample sizes (override per-bench via
              env vars). Emits consolidated BASBenchSuiteReport
              banner + JSON + markdown table.
            """)
        let suiteStart = Date()
        var benches:
            [BASBenchSuiteReport.BenchResult] = []

        // M333 evolution-loop demo doesn't return latency
        // stats per se (it pins invariants). Skip in suite.

        // M334 throughput-bench: 100 turns of lease/lung
        // recordTurn. Convert M334's inline LatencyStats to
        // M355 BASBenchLatencyStats for suite uniformity.
        do {
            let bench = await ThroughputBenchDemo.run(
                turnCount: 100)
            let m355Stats = BASBenchLatencyStats(
                sampleCount: bench.latency.count,
                min: bench.latency.min,
                max: bench.latency.max,
                mean: bench.latency.mean,
                p50: bench.latency.p50,
                p95: bench.latency.p95,
                p99: bench.latency.p99,
                p999: bench.latency.p99,
                standardDeviation: 0,
                outlierCount: 0)
            let outcome = BASBenchWarmupOutcome(
                combined: m355Stats,
                cold: nil, warm: m355Stats,
                config: .none)
            benches.append(.init(
                benchName: "throughput-bench",
                outcome: outcome,
                elapsedSeconds:
                    bench.elapsedSeconds,
                notes: "100 turns of lease/lung recordTurn"))
        }

        // M357 audit-ledger-bench: 1000 entries.
        do {
            let bench = try await AuditLedgerBench.run(
                entryCount: 1_000)
            let outcome = BASBenchWarmupOutcome(
                combined: bench.latency,
                cold: nil, warm: bench.latency,
                config: .none)
            benches.append(.init(
                benchName: "audit-ledger-bench",
                outcome: outcome,
                elapsedSeconds:
                    bench.elapsedSeconds,
                notes: "1000 entries appended to in-memory Ed25519 ledger"))
        } catch {
            print("  audit-ledger-bench failed: \(error)")
        }

        // M358 multi-host-merge-bench: 100 frames per host.
        do {
            let bench = MultiHostMergeBench.run(
                framesPerHost: 100)
            let lat = BASBenchLatencyStats.compute(
                samples: [bench.metric.mergeWallClockSeconds * 1000.0])
                ?? BASBenchLatencyStats(
                    sampleCount: 1,
                    min: bench.metric.mergeWallClockSeconds * 1000.0,
                    max: bench.metric.mergeWallClockSeconds * 1000.0,
                    mean: bench.metric.mergeWallClockSeconds * 1000.0,
                    p50: bench.metric.mergeWallClockSeconds * 1000.0,
                    p95: bench.metric.mergeWallClockSeconds * 1000.0,
                    p99: bench.metric.mergeWallClockSeconds * 1000.0,
                    p999: bench.metric.mergeWallClockSeconds * 1000.0,
                    standardDeviation: 0,
                    outlierCount: 0)
            benches.append(.init(
                benchName: "multi-host-merge-bench",
                scenarioLabel: "100 frames/host",
                outcome: BASBenchWarmupOutcome(
                    combined: lat,
                    cold: nil, warm: lat,
                    config: .none),
                elapsedSeconds:
                    bench.metric.mergeWallClockSeconds,
                notes: "1 fwd + 1 rev merge; consensus=\(bench.metric.framesInConsensus)"))
        }

        // M359 full-stack-bench: 5 sessions × 1 turn.
        // M377 — uses native warmup-aware outcome now.
        do {
            let bench = await FullStackBench.run(
                sessionCount: 5, turnCount: 1)
            let outcome = bench.perSessionOutcome
                ?? BASBenchWarmupOutcome(
                    combined: BASBenchLatencyStats(
                        sampleCount: 0, min: 0, max: 0,
                        mean: 0, p50: 0, p95: 0, p99: 0,
                        p999: 0, standardDeviation: 0,
                        outlierCount: 0),
                    cold: nil, warm: nil,
                    config: .none)
            benches.append(.init(
                benchName: "full-stack-bench",
                scenarioLabel: "\(bench.successfulSessions)/\(bench.sessionCount) ok",
                outcome: outcome,
                elapsedSeconds: bench.elapsedSeconds,
                notes: "BASHostRuntime.startSession × N"))
        }

        // M363 lifecycle-bench: 10K traversals.
        do {
            let bench = LifecycleBench.run(
                traversalCount: 10_000)
            benches.append(.init(
                benchName: "lifecycle-bench",
                outcome: bench.outcome,
                elapsedSeconds: bench.elapsedSeconds,
                notes: "10K full L13 traversals (5 transitions each)"))
        }

        // M364 sha256-bench: 10K hashes.
        do {
            let bench = SHA256Bench.run(
                hashCount: 10_000)
            benches.append(.init(
                benchName: "sha256-bench",
                outcome: bench.outcome,
                elapsedSeconds: bench.elapsedSeconds,
                notes: "10K hashes × \(bench.inputBytes) bytes"))
        }

        // M365 json-codec-bench: 5K round-trips.
        do {
            let bench = try JSONCodecBench.run(
                roundTripCount: 5_000)
            benches.append(.init(
                benchName: "json-codec-bench",
                outcome: bench.outcome,
                elapsedSeconds: bench.elapsedSeconds,
                notes: "5K round-trips × \(bench.entrySerializedBytes) bytes"))
        } catch {
            print("  json-codec-bench failed: \(error)")
        }

        let suiteEnd = Date()
        let report = BASBenchSuiteReport(
            suiteName: "qinao-sample-host",
            runStartedAt: suiteStart,
            runCompletedAt: suiteEnd,
            totalElapsedSeconds:
                suiteEnd.timeIntervalSince(suiteStart),
            benches: benches)
        print("")
        for line in report.bannerLines() {
            print(line)
        }
        // M372 — when QINAO_BENCH_BASELINE_DIR is set, use the
        // delta-augmented table; otherwise fall back to the
        // basic table.
        if let baselineDirPath = ProcessInfo.processInfo
            .environment["QINAO_BENCH_BASELINE_DIR"]
        {
            print("\n══ Markdown table (vs baseline) ══\n")
            print(report
                .markdownTableWithBaselineDelta(
                    unit: "ms",
                    baselineDirectory: URL(
                        fileURLWithPath: baselineDirPath)))
        } else {
            print("\n══ Markdown table ══\n")
            print(report.markdownTable(unit: "ms"))
        }
        // M366 — also dump JSON when env var requests it.
        if ProcessInfo.processInfo.environment[
            "QINAO_BENCH_SUITE_JSON_DUMP"] == "1",
           let json = try? report.encodedJSONString()
        {
            print("\n══ JSON (machine-readable) ══\n")
            print(json)
        }
    }

    // MARK: - M380 ed25519-sign-bench

    static func runEd25519SignBench() {
        let count = envInt(
            "QINAO_BENCH_ED25519_SIGN_COUNT",
            default: 10_000)
        print("""
            QinaoSampleHost --ed25519-sign-bench (M380):
              \(count) Ed25519 signatures over the L13
              canonical encoding (446 bytes).

              \(Ed25519SignBench.scopeStatement)
            """)
        do {
            let outcome = try Ed25519SignBench.run(
                signCount: count)
            print("""

                ━━━ M380 ed25519-sign-bench (\(outcome.signCount) signs × \(outcome.payloadBytes) bytes) ━━━
                elapsed wall:  \(String(format: "%.4f", outcome.elapsedSeconds)) sec
                throughput:    \(String(format: "%.1f", Double(outcome.signCount) / outcome.elapsedSeconds)) sigs/sec

                """)
            for line in outcome.outcome.bannerLines(
                unit: "ms")
            {
                print("  " + line)
            }
            compareToBaselineIfConfigured(
                benchName: "ed25519-sign-bench",
                stats: outcome.outcome.warm
                    ?? outcome.outcome.combined)
            print("\n  ━━━ Demo complete — \(outcome.signCount) signatures ━━━")
        } catch {
            print("ERROR: --ed25519-sign-bench failed: \(error)")
            exit(2)
        }
    }


}
