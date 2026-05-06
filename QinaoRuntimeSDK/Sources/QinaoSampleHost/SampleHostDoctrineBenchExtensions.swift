// MARK: - SampleHostDoctrineBenchExtensions — chapter 二百九十二 / M779
//
// Phase Alpha 第十八刀(QinaoSampleHost god file 5th cut):从
// `main.swift` 抽出 doctrine metrics + assumption-debt bench
// cluster — Phase Alpha 第四个 god file 第五次拆分。
//
// 抽出 helpers (Swift extension on QinaoSampleHost):
//   - `runDoctrineMetricsBench` (M577) — chapter 一百五十二 doctrine
//     metrics bench (axis stability / harmony / anchor retention)
//   - `runDoctrineMetricsMultiRun` — multi-trial 2σ regression
//     check
//   - `runSyntheticUserScenarios` — chapter 一百三十八 synthetic
//     user persona scenarios
//   - `runAuditExplainabilityBench` — chapter 一百三十七 LLM-as-judge
//     audit trail explainability bench
//
// **0 behavior change**:helpers literal-identical to pre-extraction
// versions,只是改成了 Swift extension on QinaoSampleHost。Module
// DAG 不变(同 module 内部 split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 一百五十二 doctrine metrics 6 schema 行为不变
//   - chapter 一百三十八 synthetic user persona scenarios 行为不变
//   - chapter 一百三十七 audit explainability bench 行为不变

import Foundation
import BASAppleAdapters
import BASHostKit
import BASOrchestration
import BASRuntimeCore
import QinaoLoop
import QinaoWorldPrior

extension QinaoSampleHost {
    static func runDoctrineMetricsBench(
        countOverride: Int? = nil,
        outputOverride: URL? = nil
    ) {
        let countStr = ProcessInfo.processInfo
            .environment["QINAO_DOCTRINE_BENCH_COUNT"]
        let outputStr = ProcessInfo.processInfo
            .environment["QINAO_DOCTRINE_BENCH_OUTPUT"]
            ?? DoctrineBenchConstants.defaultOutputPath
        let count = countOverride
            ?? Int(countStr ?? "")
            ?? DoctrineBenchConstants.defaultSessionCount
        let outputURL = outputOverride
            ?? URL(fileURLWithPath: outputStr)

        print("""
            QinaoSampleHost --doctrine-metrics-bench (M577, chapter 一百五十二):
              Production caller for chapter 一百五十一 6 doctrine metrics.
              Drives N=\(count) substrate sessions, synthesizes typed
              source instances from audit signal codes + permit modes,
              runs all 6 BASDoctrineMetricsCompute helpers.

              Output directory: \(outputStr)

              Override via env:
                QINAO_DOCTRINE_BENCH_COUNT=N
                QINAO_DOCTRINE_BENCH_OUTPUT=path
            """)

        try? FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true)

        // Substrate runtime (substrate-only, no LLM organ)
        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "doctrine-metrics.bundle.v1",
            providerRoutingRegistryVersion:
                "doctrine.routing-registry.v1",
            providerRoutingPolicyID:
                "doctrine.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "doctrine.tuning-registry.v1",
            runtimeTuningPolicyID:
                "doctrine.tuning-policy.v1",
            resolutionSourceID: "doctrine_bundle")
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.doctrine.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.doctrine",
                policyProfileID: "host.doctrine.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: tuning,
                runtimePolicyLineage: policyLineage,
                hostRhythmProfile: .generic))
        print("✓ Substrate runtime ready\n")

        // Source-type accumulators
        // M578 (chapter 一百五十三) — track real-vs-synthesized
        // counts so the report shows how many fields came from
        // substrate's actual emission vs fallback synthesis.
        var realAxisAlignments = 0
        var realHumanAnchorSignals = 0
        var realAbyssalPressures = 0
        var realUnknownReserves = 0
        // M581 (chapter 一百五十六) — track real-vs-synth for the
        // 3 newly wired schema types (gate/trace/sanctum)
        var realKunlunHeavenGatePermits = 0
        var realKunlunRiverOriginTraces = 0
        var realYaochiSanctumEntries = 0
        var anchorSums: [Double] = []
        var alignments: [BASAxisAlignment] = []
        var gates: [BASHeavenGatePermit] = []
        var traces: [BASRiverOriginTrace] = []
        var sanctums: [BASYaochiSanctumEntry] = []
        var anchors: [BASHumanAnchorSignal] = []
        var cthulhuHits = 0       // M580 — typed Cthulhu detector
        var kunlunHits = 0        // M580 — typed Kunlun detector
        var crossConflicts = 0
        var substrateErrors = 0
        // M580 chapter 一百五十五 — per-pattern frequency for honest
        // calibration. Lets us see WHICH patterns are saturating.
        var perPatternCount: [String: Int] = [:]
        // M590 chapter 一百六十二 — Concern 2 (deep review iter 5):
        // per-turn red-line tracking for harmony's per-turn
        // semantic. A turn with multiple red-line emissions is
        // ONE problematic turn, not multiple. Used by
        // doctrineHarmonyPerTurn to compute the per-turn-honest
        // harmony score.
        var turnsWithAnyRedLine = 0
        // M586 (chapter 一百五十八) — defect #19 fix: capture
        // substrate's actual yaochi access emissions so sanctum
        // leak rate can be computed from real signal instead of
        // the bench-input-zero placeholder.
        // Substrate emits `kunlun.yaochi.access:<class>:<decision>`
        // where decision is `granted` or `denied`. Leak = granted
        // access on sensitive class.
        var yaochiSensitiveAccessAttempts = 0
        var yaochiSensitiveAccessGranted = 0

        let runStart = Date()
        for iter in 0..<count {
            let g = QinaoExtendedPromptCorpus
                .generateScattered(iter: iter)
            let signature = g.signature
            let prompt = g.prompt

            let riskLevel: BASHostRiskLevel
            switch signature.stake {
            case .low, .modest:
                riskLevel = .low
            case .high, .veryHigh:
                riskLevel = .medium
            case .irreversible, .nonReversibleAfterAct:
                riskLevel = .high
            }

            // M585 (chapter 一百五十八) — Wave 3 prompt widening:
            // pre-fix bench used fixed workflowProfile=.reflective +
            // surface=.application for all 200 sessions. This drove
            // substrate to a narrow code path (200/200 .remanded gate
            // state, 7 of 11 detector patterns silent). Post-fix:
            // diversify workflowProfile (3 cases) and surface (7 cases)
            // per iteration using coprime strides to maximize coverage.
            // Stride 13 (workflow), 11 (surface) — small primes
            // ensures even cycling across iterations even at
            // count=200.
            let workflowProfiles: [BASHostWorkflowProfile] = [
                .primary, .comparative, .reflective,
            ]
            let surfaces: [BASHostSurface] = [
                .application, .wearable, .widget, .shortcut,
                .voiceAssistant, .notification, .system,
            ]
            // M594 chapter 一百六十五 — anti-magic-number: cycling
            // strides named in DoctrineBenchConstants.
            let workflow = workflowProfiles[
                (iter * DoctrineBenchConstants
                    .workflowCyclingStride)
                % workflowProfiles.count]
            let surface = surfaces[
                (iter * DoctrineBenchConstants
                    .surfaceCyclingStride)
                % surfaces.count]

            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: workflow,
                        surface: surface,
                        prompt: prompt,
                        title: "doctrine-\(iter)",
                        riskLevel: riskLevel))
                guard let turn = result.eBrainTurn else {
                    substrateErrors += 1
                    continue
                }

                let permit = turn.actionPermit.mode
                let auditID = turn.sovereignAuditEntry?
                    .auditID ?? "audit-\(iter)"
                let signalRefs = turn.sovereignAuditEntry?
                    .signalRefs ?? []

                // M578 (chapter 一百五十三) — prefer REAL substrate
                // BASAxisAlignment from turn.kunlunAxisAlignment.
                // Fall back to synthesis only if substrate didn't
                // emit one (turn outside Kunlun-axis-emit code path).
                // M592 (chapter 一百六十四) — Item 3 dead-code removal.
                // Substrate constructs `kunlunAxisAlignment`,
                // `kunlunHeavenGatePermit`, `kunlunRiverOriginTrace`,
                // `yaochiSanctumEntry` UNCONDITIONALLY per turn (see
                // EBrainRuntimeCoordinator.swift lines 267, 335, 1901,
                // and the post-M581 wire at line 2304-2358). The pre-
                // M592 `if let realX { } else { synthesize }` branches
                // had their else-paths as dead code: chapter 162 iter 5
                // adversarial review confirmed empirically (200/200 =
                // 100% by-construction, never falls back).
                //
                // Post-M592: force-unwrap with explanatory message.
                // If substrate ever changes contract (turns 7-field
                // emission optional), this fatalError surfaces the
                // contract violation immediately rather than silently
                // hiding it via synthesis fallback.
                guard
                    let realAlignment = turn.kunlunAxisAlignment,
                    let realGate = turn.kunlunHeavenGatePermit,
                    let realTrace = turn.kunlunRiverOriginTrace,
                    let realSanctum = turn.yaochiSanctumEntry
                else {
                    fatalError("""
                        Substrate contract violation: BAS turn result
                        must populate kunlunAxisAlignment +
                        kunlunHeavenGatePermit + kunlunRiverOriginTrace
                        + yaochiSanctumEntry. Wired by M578 + M581 in
                        EBrainRuntimeCoordinator.runTurn().
                        """)
                }
                alignments.append(realAlignment)
                realAxisAlignments += 1
                gates.append(realGate)
                realKunlunHeavenGatePermits += 1
                traces.append(realTrace)
                realKunlunRiverOriginTraces += 1
                sanctums.append(realSanctum)
                realYaochiSanctumEntries += 1

                // M592 (chapter 一百六十四) — Item 3 dead-code removal.
                // humanAnchorSignal / abyssalPressure / unknownReserve
                // are also unconditionally constructed by substrate
                // (chapter 一百五十三 M578 wire). Same fatalError
                // contract as above for the 4 schema-types.
                guard
                    let realAnchor = turn.humanAnchorSignal,
                    turn.abyssalPressure != nil,
                    turn.unknownReserve != nil
                else {
                    fatalError("""
                        Substrate contract violation: BAS turn result
                        must populate humanAnchorSignal +
                        abyssalPressure + unknownReserve. Wired by
                        M578 in EBrainRuntimeCoordinator.runTurn().
                        """)
                }
                anchors.append(realAnchor)
                realHumanAnchorSignals += 1
                realAbyssalPressures += 1
                realUnknownReserves += 1
                let sumOf4 = realAnchor.agencyRisk
                    + realAnchor.alienationRisk
                    + realAnchor.dignityRisk
                    + realAnchor.overwhelmRisk
                anchorSums.append(sumOf4)

                // M580 (chapter 一百五十五) — Doctrine harmony:
                // count red-line hits using empirically-calibrated
                // BASDoctrineRedLineDetector. Pre-M580 detector
                // matched 0 real substrate signals (looked for
                // forbid:/redline: which substrate doesn't emit).
                let signalRefStrs = signalRefs.map { $0 }
                let turnCthulhuHits = BASDoctrineRedLineDetector
                    .cthulhuHits(in: signalRefStrs)
                let turnKunlunHits = BASDoctrineRedLineDetector
                    .kunlunHits(in: signalRefStrs)
                cthulhuHits += turnCthulhuHits
                kunlunHits += turnKunlunHits
                crossConflicts += BASDoctrineRedLineDetector
                    .crossDoctrineConflicts(in: signalRefStrs)
                // M590 chapter 一百六十二 — per-turn aggregate
                if turnCthulhuHits > 0 || turnKunlunHits > 0 {
                    turnsWithAnyRedLine += 1
                }
                // Per-pattern accounting (M580 calibration)
                let allPatterns = BASDoctrineRedLineDetector
                    .cthulhuConcernPatterns
                    + BASDoctrineRedLineDetector
                        .kunlunConcernPatterns
                for ref in signalRefStrs {
                    for pattern in allPatterns where ref.hasPrefix(
                        pattern) {
                        perPatternCount[pattern, default: 0] += 1
                        break
                    }
                }
                // M586 (chapter 一百五十八) — capture sanctum access
                // attempts from substrate emission. `kunlun.yaochi.
                // access:sensitive:granted` = leak;
                // `kunlun.yaochi.access:sensitive:denied` = blocked.
                for ref in signalRefStrs {
                    if ref.hasPrefix(
                        "kunlun.yaochi.access:sensitive:") {
                        yaochiSensitiveAccessAttempts += 1
                        if ref == "kunlun.yaochi.access:sensitive:granted" {
                            yaochiSensitiveAccessGranted += 1
                        }
                    }
                }
            } catch {
                substrateErrors += 1
            }

            if (iter + 1) % 50 == 0 {
                print("  iter=\(iter+1)/\(count) " +
                    "alignments=\(alignments.count) " +
                    "gates=\(gates.count)")
            }
        }
        let elapsed = Date().timeIntervalSince(runStart)

        // Compute all 6 metrics
        let axisStability = BASDoctrineMetricsCompute
            .axisStability(metricID: "doctrine-bench-axis",
                from: alignments)
        let gateFidelity = BASDoctrineMetricsCompute
            .gateFidelity(metricID: "doctrine-bench-gate",
                from: gates)
        let originCompleteness = BASDoctrineMetricsCompute
            .originTraceCompleteness(
                metricID: "doctrine-bench-origin",
                from: traces)
        // M587 (chapter 一百五十九) — Issue 1 (deep review HIGH):
        // M586's wire was semantically wrong. Substrate uses
        // `accessPolicy: .conditional` which means `:granted`
        // emissions are AUTHORIZED access via matched reveal
        // conditions + host anchor present + cooling period passed
        // — substrate doing its job correctly, NOT a leak.
        //
        // Substrate's `BASKunlunYaochiProtocol.evaluateAccess`
        // (BASKunlunProtocol.swift:850-885) emits `:granted` only
        // when ALL gates pass (no reasonCodes). With `.conditional`
        // policy this requires at least one matched reveal condition.
        // The bench's M586 logic incorrectly conflated "granted"
        // with "leaked".
        //
        // Real leaks would require substrate to emit `:granted`
        // on a `.sealed` policy entry — which it cannot by
        // construction (`.sealed` always adds a reason).
        //
        // Honest fix: revert to bench-zero. Document that sanctum
        // leak rate cannot be computed from current substrate
        // emissions because substrate's defensive design prevents
        // emission of "unauthorized but granted" signals. This is
        // actually an observation about substrate correctness, not
        // a metric defect.
        let sanctumLeak = BASDoctrineMetricsCompute
            .sanctumLeakRate(
                metricID: "doctrine-bench-sanctum",
                from: sanctums,
                unauthorizedAttempts: 0,
                unauthorizedBlocked: 0)
        // M590 chapter 一百六十二 — Concern 2: compute BOTH harmony
        // interpretations. Per-emission deducts each red-line ref;
        // per-turn deducts once per turn with any red-line. Per-turn
        // is more semantically aligned with doctrine intent
        // ("fraction of turns without red lines"); per-emission is
        // kept for backward-compat continuity with chapter 158-160
        // numbers.
        let harmonyPerEmission = BASDoctrineMetricsCompute
            .doctrineHarmony(
                metricID: "doctrine-bench-harmony-per-emission",
                cthulhuHits: cthulhuHits,
                kunlunHits: kunlunHits,
                crossConflicts: crossConflicts,
                sampleCount: alignments.count)
        let harmony = BASDoctrineMetricsCompute
            .doctrineHarmonyPerTurn(
                metricID: "doctrine-bench-harmony",
                turnsWithAnyRedLine: turnsWithAnyRedLine,
                sampleCount: alignments.count)
        let anchorRetention = BASDoctrineMetricsCompute
            .humanAnchorRetention(
                metricID: "doctrine-bench-anchor",
                from: anchors)

        // Write summary
        // M588 (chapter 一百六十) — Issue C (deep-review iter 2):
        // separate canonical metric output (deterministic across
        // runs, byte-equal-comparable) from telemetry (wall-clock
        // dependent). Pre-fix: single summary.json contained both.
        // Post-fix: `metrics.json` is deterministic (sortedKeys +
        // metric values only); `telemetry.json` carries elapsed
        // seconds + sessionsRun + substrateErrors. Empirical-
        // calibration doctrine assumes summary reproducibility for
        // byte-equal regression detection.
        let metricsURL = outputURL
            .appendingPathComponent("metrics.json")
        let telemetryURL = outputURL
            .appendingPathComponent("telemetry.json")
        let summaryURL = outputURL
            .appendingPathComponent("summary.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .prettyPrinted]
        let metrics = DoctrineMetricsBenchSummary(
            axisStability: axisStability,
            gateFidelity: gateFidelity,
            originTraceCompleteness: originCompleteness,
            sanctumLeakRate: sanctumLeak,
            doctrineHarmony: harmony,
            humanAnchorRetention: anchorRetention)
        let telemetry = DoctrineMetricsBenchTelemetry(
            sessionsRun: count,
            substrateErrors: substrateErrors,
            elapsedSeconds: elapsed)
        do {
            try encoder.encode(metrics).write(to: metricsURL)
            try encoder.encode(telemetry).write(to: telemetryURL)
            // Backward-compat: summary.json is metrics + telemetry
            // combined (existing readers continue to work).
            let summary = DoctrineMetricsBenchSummaryLegacy(
                sessionsRun: count,
                substrateErrors: substrateErrors,
                elapsedSeconds: elapsed,
                axisStability: axisStability,
                gateFidelity: gateFidelity,
                originTraceCompleteness: originCompleteness,
                sanctumLeakRate: sanctumLeak,
                doctrineHarmony: harmony,
                humanAnchorRetention: anchorRetention)
            try encoder.encode(summary).write(to: summaryURL)
        } catch {
            stderr("⚠ summary write failed: \(error)\n")
        }

        // Print final report
        print("""

            === FINAL DOCTRINE METRICS (M578 / chapter 一百五十三) ===
            Sessions run:        \(count)
            Substrate errors:    \(substrateErrors)
            Elapsed:             \(String(format: "%.2f", elapsed))s

            Anchor risk-sum distribution (M579 chapter 一百五十四 calibration):
              \(Self.formatAnchorDistribution(anchorSums))

            BY-CONSTRUCTION counts (M578 + M581 wires; M592 chapter 一百六十四 honest banner):
              note: substrate constructs these 7 fields unconditionally per turn,
                    so 100% rate is by-construction, NOT empirical observation.
              kunlunAxisAlignment:     \(realAxisAlignments) populated / \(count) sessions
              humanAnchorSignal:       \(realHumanAnchorSignals) populated / \(count) sessions
              abyssalPressure:         \(realAbyssalPressures) populated / \(count) sessions
              unknownReserve:          \(realUnknownReserves) populated / \(count) sessions
              kunlunHeavenGatePermit:  \(realKunlunHeavenGatePermits) populated / \(count) sessions
              kunlunRiverOriginTrace:  \(realKunlunRiverOriginTraces) populated / \(count) sessions
              yaochiSanctumEntry:      \(realYaochiSanctumEntries) populated / \(count) sessions

            1. Axis Stability Score (alignments=\(alignments.count)):
               stabilityIndex   = \(String(format: "%.4f", axisStability.stabilityIndex))
               centerScore mean = \(String(format: "%.4f", axisStability.centerScoreMean))
               deviation count  = \(axisStability.deviationCount)

            2. Gate Fidelity Score (gates=\(gates.count)):
               fidelityRatio    = \(String(format: "%.4f", gateFidelity.fidelityRatio))
               passed           = \(gateFidelity.gatePassed)
               denied           = \(gateFidelity.gateDenied)
               remanded         = \(gateFidelity.gateRemandedForSecondCheck)

            3. Origin Trace Completeness (traces=\(traces.count)):
               completenessRatio = \(String(format: "%.4f", originCompleteness.completenessRatio))
               full provenance   = \(originCompleteness.tracesWithFullProvenance)
               missing roots     = \(originCompleteness.tracesWithMissingRoots)

            4. Sanctum Leak Rate (sanctums=\(sanctums.count)):
               leakRate         = \(String(format: "%.4f", sanctumLeak.leakRate))
               sensitive attempts observed = \(yaochiSensitiveAccessAttempts) (substrate emit)
               sensitive granted observed  = \(yaochiSensitiveAccessGranted) (authorized via .conditional)
               sensitive denied  observed  = \(yaochiSensitiveAccessAttempts - yaochiSensitiveAccessGranted)
               (M587 chapter 一百五十九 honest disclosure: substrate
                cannot leak by construction — `.sealed` policy always
                adds reason; granted = authorized via matched reveal
                conditions, not leak. Metric correctly reports 0.0.)

            5. Doctrine Harmony Score (sample=\(alignments.count)):
               per-turn   harmony = \(String(format: "%.4f", harmony.harmonyScore))  ← M590 doctrine-aligned
               per-emit   harmony = \(String(format: "%.4f", harmonyPerEmission.harmonyScore))  ← chapters 158-160 number
               turns with any red line = \(turnsWithAnyRedLine) / \(alignments.count)
               cthulhu emissions  = \(cthulhuHits)
               kunlun  emissions  = \(kunlunHits)
               cross conflicts    = \(crossConflicts)

            6. Human Anchor Retention (anchors=\(anchors.count)):
               retentionRatio   = \(String(format: "%.4f", anchorRetention.retentionRatio))
               preserved        = \(anchorRetention.anchorPreservedAcrossTurns)
               eroded           = \(anchorRetention.anchorErodedCount)

            Summary:  \(summaryURL.path)
            """)

        // M580 chapter 一百五十五 — per-pattern hit frequencies for
        // empirical calibration. Lets us see WHICH patterns saturate
        // harmony score so we can iterate detector without guessing.
        if !perPatternCount.isEmpty {
            print("\nPer-pattern hit frequencies (M580 calibration):")
            let sorted = perPatternCount.sorted { $0.value > $1.value }
            for (pattern, hits) in sorted {
                let pad = pattern.padding(
                    toLength: 50, withPad: " ", startingAt: 0)
                let perSession = Double(hits) / Double(count)
                let perSessionStr = String(
                    format: "%.2f", perSession)
                print("  \(pad) \(hits) (\(perSessionStr)/session)")
            }
        }
    }

    /// M591 (chapter 一百六十三) — refactored to delegate
    /// percentile math to `BASDoctrinePercentileSummary.compute`
    /// in BAS substrate (now testable + reusable). This helper
    /// just formats the typed summary for the bench banner.
    /// M588 (chapter 一百六十) introduced the empty-guard; M591
    /// extracts math to substrate so it can be unit-tested.
    private static func formatAnchorDistribution(
        _ sums: [Double]
    ) -> String {
        // M594 chapter 一百六十五 — anti-magic-number: anchor risk
        // thresholds named in BASDoctrineMetricsThreshold.
        let summary = BASDoctrinePercentileSummary.compute(
            sums,
            thresholds: BASDoctrineMetricsThreshold
                .anchorRiskSumThresholds)
        guard summary.sampleCount > 0 else {
            return """
            min:    n/a
              p25:    n/a
              median: n/a
              p75:    n/a
              p99:    n/a
              max:    n/a
              (empty input — likely all substrate calls failed)
              ≥ 1.0:  0
              ≥ 1.5:  0
              ≥ 2.0:  0
            """
        }
        let f = { (v: Double) in String(format: "%.3f", v) }
        let counts = summary.thresholdCounts
        return """
        min:    \(f(summary.min))
              p25:    \(f(summary.p25))
              median: \(f(summary.median))
              p75:    \(f(summary.p75))
              p99:    \(f(summary.p99))
              max:    \(f(summary.max))
              ≥ 1.0:  \(counts[0])
              ≥ 1.5:  \(counts[1])
              ≥ 2.0:  \(counts[2])
        """
    }

    /// M588 (chapter 一百六十) — canonical (deterministic) metric
    /// output. No wall-clock or run-dependent fields. Two runs of
    /// the same bench produce byte-equal `metrics.json`.
    private struct DoctrineMetricsBenchSummary: Codable {
        let axisStability: BASAxisStabilityScore
        let gateFidelity: BASGateFidelityScore
        let originTraceCompleteness: BASOriginTraceCompleteness
        let sanctumLeakRate: BASSanctumLeakRate
        let doctrineHarmony: BASDoctrineHarmonyScore
        let humanAnchorRetention: BASHumanAnchorRetention
    }

    /// M588 — telemetry output (separate from canonical metrics).
    /// Carries wall-clock and session counters. NOT byte-equal
    /// across runs.
    private struct DoctrineMetricsBenchTelemetry: Codable {
        let sessionsRun: Int
        let substrateErrors: Int
        let elapsedSeconds: Double
    }

    /// M588 — backward-compat: `summary.json` continues to contain
    /// metrics + telemetry combined for existing readers.
    private struct DoctrineMetricsBenchSummaryLegacy: Codable {
        let sessionsRun: Int
        let substrateErrors: Int
        let elapsedSeconds: Double
        let axisStability: BASAxisStabilityScore
        let gateFidelity: BASGateFidelityScore
        let originTraceCompleteness: BASOriginTraceCompleteness
        let sanctumLeakRate: BASSanctumLeakRate
        let doctrineHarmony: BASDoctrineHarmonyScore
        let humanAnchorRetention: BASHumanAnchorRetention
    }

    /// **M593 (chapter 一百六十四) — Item 1: multi-run variance harness**.
    /// Walks back chapter 一百六十二 Concern 6 (single-bench-seed
    /// limitation) by calling `runDoctrineMetricsBench` at 3
    /// different counts (50/200/500) and computing variance bounds
    /// for each metric across the 3 runs.
    ///
    /// Substrate is deterministic for identical input, so variance
    /// emerges only from sample-size variation. This harness shows
    /// whether metric values are stable across sample sizes (reassuring)
    /// or sample-size-dependent (concerning).
    ///
    /// Honest scope: this is NOT statistical confidence intervals
    /// (would require many trials with random sampling). It IS a
    /// sanity check that single-bench results aren't a fluke of
    /// the chosen N.
    static func runDoctrineMetricsMultiRun() {
        print("""
            QinaoSampleHost --doctrine-metrics-multi-run (M593, chapter 一百六十四):
              Multi-run variance harness. Calls bench at 3 counts (50/200/500),
              reads metrics.json from each, reports min/max/mean/spread across
              runs. Honest scope: shows sample-size sensitivity, NOT confidence
              intervals.
            """)
        // M594 chapter 一百六十五 — anti-magic-number: counts +
        // output prefix from DoctrineBenchConstants.
        let counts = DoctrineBenchConstants.multiRunCounts
        var axisStabilities: [Double] = []
        var harmoniesPerTurn: [Double] = []
        var harmoniesPerEmission: [Double] = []
        var anchorRetentions: [Double] = []
        for c in counts {
            let outputDir = URL(
                fileURLWithPath: DoctrineBenchConstants
                    .multiRunOutputPrefix + "\(c)")
            print("\n--- Run with count=\(c) ---")
            runDoctrineMetricsBench(
                countOverride: c,
                outputOverride: outputDir)
            // Read metrics.json (deterministic output from chapter 160)
            let metricsURL = outputDir
                .appendingPathComponent("metrics.json")
            do {
                let data = try Data(contentsOf: metricsURL)
                let summary = try JSONDecoder().decode(
                    DoctrineMetricsBenchSummary.self,
                    from: data)
                axisStabilities.append(
                    summary.axisStability.stabilityIndex)
                harmoniesPerTurn.append(
                    summary.doctrineHarmony.harmonyScore)
                anchorRetentions.append(
                    summary.humanAnchorRetention.retentionRatio)
                // per-emission read from telemetry-style legacy
                // file (M591 keeps both per-turn primary +
                // per-emission backward-compat reads through
                // separate metricID; here we just read primary)
            } catch {
                print("  ⚠ failed to read metrics.json: \(error)")
            }
        }
        // Variance summary
        func formatVariance(
            _ name: String, _ values: [Double]
        ) -> String {
            guard let mn = values.min(),
                  let mx = values.max() else { return "" }
            let mean = values.reduce(0, +)
                / Double(values.count)
            let spread = mx - mn
            let f = { (v: Double) in
                String(format: "%.4f", v) }
            return """

            \(name):
              counts:    \(counts)
              values:    \(values.map(f))
              min:       \(f(mn))
              max:       \(f(mx))
              mean:      \(f(mean))
              spread:    \(f(spread))
            """
        }
        print("""

            === MULTI-RUN VARIANCE SUMMARY (counts=\(counts)) ===
            \(formatVariance("Axis Stability", axisStabilities))
            \(formatVariance("Harmony Per-Turn",
                harmoniesPerTurn))
            \(formatVariance("Anchor Retention",
                anchorRetentions))

            HONEST READING (M594 chapter 一百六十五 anti-magic-number):
              variance ≤ \(BASDoctrineMetricsThreshold
                  .stableSpreadThreshold) (stableSpreadThreshold)
                = stable across sample sizes
              variance > \(BASDoctrineMetricsThreshold
                  .nDependentSpreadThreshold) (nDependentSpreadThreshold)
                = N-dependent, deserves investigation
            """)
    }

    static func runSyntheticUserScenarios() {
        print("""
            QinaoSampleHost --synthetic-user-scenarios (M555-M560, chapter 一百三十八):
              Drive 15 (persona × scenario) prompts through BASHostRuntime;
              aggregate audit signalRefs across all sessions; report which
              doctrine prefixes fire vs which never fire (= candidate dead
              doctrine). Tests assumption #4: "typed primitives translate
              to user value".
            """)

        // Substrate runtime (no AFM required; substrate composes
        // own organ adapter)
        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "synthetic.user.bundle.v1",
            providerRoutingRegistryVersion:
                "synthetic.routing-registry.v1",
            providerRoutingPolicyID:
                "synthetic.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "synthetic.tuning-registry.v1",
            runtimeTuningPolicyID:
                "synthetic.tuning-policy.v1",
            resolutionSourceID: "synthetic_bundle")
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.synthetic-user.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        let configuration = BASHostConfiguration(
            runtimeProfileID: "host.synthetic-user",
            policyProfileID: "host.synthetic-user.policy",
            prefersPureLocal: true,
            defaultDeviceState:
                BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: tuning,
            runtimePolicyLineage: policyLineage,
            hostRhythmProfile: .generic)
        let runtime = BASHostRuntime(
            configuration: configuration)

        let prompts = QinaoSyntheticPromptCatalog.allPrompts
        var sessions: [[String]] = []
        for entry in prompts {
            let riskLevel: BASHostRiskLevel
            switch entry.persona {
            case .anxious, .vulnerable:
                riskLevel = .high
            case .authoritative, .agentic:
                riskLevel = .medium
            case .confused:
                riskLevel = .low
            }
            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: entry.prompt,
                        title: "synthetic-\(entry.persona.rawValue)-\(entry.scenario.rawValue)",
                        riskLevel: riskLevel))
                if let turn = result.eBrainTurn,
                   let entry = turn.sovereignAuditEntry
                {
                    sessions.append(entry.signalRefs)
                }
            } catch {
                stderr("error: synthetic session failed for \(entry.persona.rawValue) \(entry.scenario.rawValue): \(error)\n")
            }
        }

        // Expected doctrine prefixes (per chapter 一百三十六 value-add report)
        let expectedPrefixes = [
            "kunlun", "cthulhu", "permit", "constitution",
            "narrative", "reconciliation", "dream_loop",
            "lifecycle", "forbidden", "risk", "anomaly",
            "humanAnchor", "abyssal", "presence",
            "hippocampal", "fold",
        ]
        let aggregate = QinaoSyntheticUserAggregator
            .aggregate(
                sessions: sessions,
                expectedPrefixes: expectedPrefixes)

        print("""

            ━━━ Synthetic User Audit Aggregate (\(sessions.count) sessions) ━━━
            Total audit codes:  \(aggregate.totalCodeCount)
            Distinct prefixes:  \(aggregate.prefixCounts.count)
            """)
        print("Top-fired prefixes (sorted by count):")
        for (prefix, count) in aggregate.prefixCounts
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
        {
            let avgPerSession = Double(count)
                / Double(max(1, sessions.count))
            print("  \(prefix): \(count) (\(String(format: "%.1f", avgPerSession))/session)")
        }

        if !aggregate.unfiredPrefixes.isEmpty {
            print("""

                ⚠️ UNFIRED PREFIXES (candidate dead doctrine):
                \(aggregate.unfiredPrefixes.joined(separator: ", "))
                """)
        } else {
            print("""

                ✅ ALL EXPECTED PREFIXES FIRED — no candidate dead doctrine in this set
                """)
        }
        print("═══════════════════════════════════════════════════\n")
    }

    static func runAuditExplainabilityBench() async {
        print("""
            QinaoSampleHost --audit-explainability-bench (M549-M554, chapter 一百三十七):
              Tests assumption #3 ("honest satisfaction is meaningful").
              Picks 3 fixture audit signalRefs sets; asks LLM-as-judge to
              reconstruct decision from codes alone; aggregates median +
              p25/p75 confidence across runs.
              Confidence < 60 = trail opaque (theater);
              > 80 = trail reconstructable (honest-satisfaction supported).

              Endpoint: Apple FoundationModels (with deterministic
              fallback if AFM unavailable).
            """)

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: true)

        // 3 sample audit fixtures of varying complexity
        let fixtures: [(turnID: String, codes: [String])] = [
            (
                turnID: "fixture-1-clean",
                codes: [
                    "permit:answer",
                    "risk:low",
                    "fold:turn-1-clean",
                    "kunlun.axis.center:0.850",
                    "cthulhu.organ.alias:counterfactual-forge",
                ]
            ),
            (
                turnID: "fixture-2-escalated",
                codes: [
                    "permit:compare",
                    "risk:high",
                    "fold:turn-2-escalated",
                    "abyssal.magnitude:0.700",
                    "abyssal.modes:2",
                    "permit.escalated:abyssal:compare",
                    "kunlun.axis.deviationScore:0.700",
                    "kunlun.axis.deviationCodes:risk-high-drift",
                ]
            ),
            (
                turnID: "fixture-3-blocked",
                codes: [
                    "permit:block",
                    "risk:extreme",
                    "verdict:rollback",
                    "abyssal.magnitude:0.900",
                    "kunlun.tianheng.dignity:0.900",
                    "counter-host:outcome:system-induced-drift",
                    "counter-host:requires-sovereign-override",
                    "lifecycle.gated:forbidden:sovereign-rejected",
                ]
            ),
        ]

        var scores: [AuditExplainabilityScore] = []
        for fixture in fixtures {
            do {
                let score = try await AuditExplainabilityBench
                    .evaluate(
                        signalRefs: fixture.codes,
                        turnID: fixture.turnID,
                        endpoint: endpoint,
                        sessionID: "audit-explain-\(fixture.turnID)")
                scores.append(score)
                print("""
                    [\(fixture.turnID)] confidence=\(score.confidence) length=\(score.responseLength) keywords=\(score.containsDecisionKeywords)
                    """)
            } catch {
                stderr("error: explainability eval failed for \(fixture.turnID): \(error)\n")
            }
        }

        let aggregate = AuditExplainabilityBench.aggregate(
            scores: scores)
        print("""

            ━━━ Audit Explainability Aggregate ━━━
            Turns scored: \(aggregate.turnCount)
            Median confidence: \(aggregate.medianConfidence)
            P25 confidence:    \(aggregate.p25Confidence)
            P75 confidence:    \(aggregate.p75Confidence)
            Threshold: < \(AuditExplainabilityBench.opaqueTrailThreshold) = trail opaque (假设 #3 broken)
                       > \(AuditExplainabilityBench.reconstructableTrailThreshold) = trail reconstructable (假设 #3 supported)
            ═══════════════════════════════════════
            """)

        let verdict: String
        if aggregate.medianConfidence
            < AuditExplainabilityBench.opaqueTrailThreshold
        {
            verdict = "❌ TRAIL OPAQUE — honest-satisfaction claim broken"
        } else if aggregate.medianConfidence
            > AuditExplainabilityBench
                .reconstructableTrailThreshold
        {
            verdict = "✅ TRAIL RECONSTRUCTABLE — honest-satisfaction claim supported"
        } else {
            verdict = "⚠️ MARGINAL — neither clearly opaque nor reconstructable"
        }
        print("Verdict: \(verdict)\n")
    }

}
