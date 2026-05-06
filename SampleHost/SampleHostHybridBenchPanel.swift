// MARK: - SampleHostHybridBenchPanel
//
// chapter 二百二十七 / M808 — extracted from SampleHostView.swift.
//
// The largest UI panel in the SampleHost view (chapter 一百七十七 §177
// hybrid AFM⇄Gemma router bench) plus 5 supporting status-string
// computed helpers used only by this panel:
//   - meridianHeadsStatus  (chapter 一百八十二 / M654 — 5 CoreML
//     heads' running stats + substrate dispatch counts)
//   - safetyKitStatus      (chapter 一百九十三 / M727 + chapter
//     一百九十八 / M745 — chapter-192 10h-readiness pack live
//     dashboard)
//   - safetyKitTint        (chapter 一百九十三 / M727 + chapter
//     一百九十八 / M745 — Color tint based on alarm state)
//   - hybridBenchLiveStatus (running stats + router accuracy)
//   - hybridBenchFinalStatus (post-run summary)
//
// Pre-this-batch: ~473 LOC of inline panel + 5 helpers on
// SampleHostView (the largest panel by far).
//
// Post-this-batch: dedicated standalone View struct. Status helpers
// move with the panel as private computed properties on the new
// struct. SampleHostView body composes via
// `SampleHostHybridBenchPanel(model: model)`.
//
// Doctrine pins (preserved verbatim from original):
//   - chapter 一百七十七 §177 / M619 hybrid bench architecture
//   - chapter 一百七十八 / M628 substrate→LLM dispatch coupling
//   - chapter 一百八十一 / M649 MultiHead inference path
//   - chapter 一百八十二 / M654 5-head meridian
//   - chapter 一百九十二 / M716-M725 10h-readiness safety kit
//   - chapter 一百九十三 / M727 live anomaly dashboard
//   - chapter 一百九十四 / M731-M732 4-flex slider config
//   - chapter 一百九十五 / M735 LLM timeout
//   - chapter 一百九十七 / M740-M742 .serious thermal pause +
//     SmokeMode picker
//   - chapter 一百九十八 / M744-M745 cooling sleep + thermal NOW
//   - chapter 二百四 / M768 workflowProfile picker
//   - chapter 二百五 / M772 .benign smoke mode
//   - chapter 二百八 / M785 .rawLLM smoke mode (ADR-006)
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI rendering, no decision.

import SwiftUI
import BASHostKit

struct SampleHostHybridBenchPanel: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hybrid 8h bench (router + AFM⇄Gemma fallback)")
                    .font(.headline)
                Spacer()
                Button(model.hybridBenchIsRunning ? "Stop" : "Start") {
                    if model.hybridBenchIsRunning {
                        model.stopHybridBench()
                    } else {
                        model.startHybridBench()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(model.hybridBenchIsRunning ? .red : .cyan)
            }

            Text(
                "Per-iter: substrate routing (14 layers) → " +
                "ChengluPreflight router → AFM or Gemma → fallback " +
                "to other on error. Records prediction vs actual " +
                "outcome to JSONL for next-gen training."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Group {
                HStack {
                    Text("Hours:").font(.caption)
                    // M736 (chapter 195 follow-up): step 0.1 lets
                    // operator flex to 0.1h (6 min) / 0.2h (12 min)
                    // for short smoke tests instead of jumping by 30 min.
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchDurationHours },
                            set: { model.updateHybridBenchDurationHours($0) }
                        ),
                        in: 0.1...24.0,
                        step: 0.1
                    ) {
                        Text(String(format: "%.1f h",
                                    model.hybridBenchDurationHours))
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Text("Stride CSV:").font(.caption)
                    TextField("coprime to 40320", text: Binding(
                        get: { model.hybridBenchStrideRotationCSV },
                        set: { model.updateHybridBenchStrideCSV($0) }
                    ))
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.hybridBenchIsRunning)
                }
                HStack {
                    Text("Mutations:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchMutationSeedCount },
                            set: { model.updateHybridBenchMutationCount($0) }
                        ),
                        in: 1...5,
                        step: 1
                    ) {
                        Text("\(model.hybridBenchMutationSeedCount)")
                            .font(.caption.monospacedDigit())
                    }
                }
                // M732 chapter 一百九十四 — UI sliders for the 4
                // chapter-192 safety-kit flex constants.
                // Disabled mid-bench so changes don't desync.
                HStack {
                    Text("Anomaly window:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchAnomalyWindowSize },
                            set: { model.updateAnomalyWindowSize($0) }
                        ),
                        in: 10...1000,
                        step: 10
                    ) {
                        Text("\(model.hybridBenchAnomalyWindowSize)")
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                HStack {
                    Text("Drift σ-thresh:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchDriftSigmaThreshold },
                            set: { model.updateDriftSigmaThreshold($0) }
                        ),
                        in: 1.0...10.0,
                        step: 0.5
                    ) {
                        Text(String(
                            format: "%.1fσ",
                            model.hybridBenchDriftSigmaThreshold))
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                HStack {
                    Text("Mutation prob:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchMutationProbability },
                            set: { model.updateMutationProbability($0) }
                        ),
                        in: 0.0...1.0,
                        step: 0.01
                    ) {
                        Text(String(
                            format: "%.0f%%",
                            model.hybridBenchMutationProbability * 100))
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                HStack {
                    Text("Checkpoint @:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchCheckpointEveryNIters },
                            set: { model.updateCheckpointEveryNIters($0) }
                        ),
                        in: 100...100_000,
                        step: 100
                    ) {
                        Text("\(model.hybridBenchCheckpointEveryNIters)")
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                // M741 chapter 一百九十七 — SmokeMode picker.
                // 3 modes: canonical (chapter 178+ default) /
                // 14-layer (chapter 191) / heavy-tailed (chapter 192).
                // iPhone smoke ran .canonical (default) → 100%
                // skip path. .heavyTailed = production-realistic.
                HStack {
                    Text("Smoke mode:").font(.caption)
                    Picker("", selection: Binding(
                        get: { model.hybridBenchSmokeMode },
                        set: { model.hybridBenchSmokeMode = $0 }
                    )) {
                        Text("canon")
                            .tag(HybridBenchConfig.SmokeMode.canonical)
                        Text("14-L")
                            .tag(HybridBenchConfig.SmokeMode.fourteenLayer)
                        Text("heavy")
                            .tag(HybridBenchConfig.SmokeMode.heavyTailed)
                        Text("benign")
                            .tag(HybridBenchConfig.SmokeMode.benign)
                        // M785 chapter 二百八 — raw LLM mode (ADR-006).
                        // Substrate audit-only; dispatch FORCED to
                        // singleLLM. For training-data accumulation
                        // when substrate's risk eval refuses the
                        // .answer permit on benign inputs (chapter
                        // 207 finding). Doctrine pin: data NEVER
                        // used for production permit decisions.
                        Text("raw")
                            .tag(HybridBenchConfig.SmokeMode.rawLLM)
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.hybridBenchIsRunning)
                }
                // M742 chapter 一百九十七 — LLM timeout slider.
                HStack {
                    Text("LLM timeout:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchLLMTimeoutSeconds },
                            set: { model.updateLLMTimeoutSeconds($0) }
                        ),
                        in: 5.0...300.0,
                        step: 5.0
                    ) {
                        Text(String(
                            format: "%.0fs",
                            model.hybridBenchLLMTimeoutSeconds))
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                // M740 chapter 一百九十七 — pause-on-serious toggle.
                // iPhone smoke: 91% of 12-min run at .serious thermal.
                // Default false (chapter-192 baseline). Operator on
                // hot device can flip true for 10h survivability.
                Toggle(isOn: Binding(
                    get: { model.hybridBenchPauseOnSerious },
                    set: { model.hybridBenchPauseOnSerious = $0 }
                )) {
                    Text("Pause on .serious thermal")
                        .font(.caption)
                }
                .disabled(model.hybridBenchIsRunning)
                // M768 chapter 二百四 — workflowProfile picker.
                // Pre-this-batch hardcoded `.reflective`. Chapter 196
                // (heavy-tailed 4h51m) + chapter 204 prep
                // (canonical 45min) BOTH yielded 100% substrate-skip
                // / 0 LLM calls because reflective always routes
                // to .delay. Operator picks `.primary` for LLM-data
                // accumulation runs; default `.reflective` keeps
                // chapter 178+ doctrine baseline.
                HStack {
                    Text("Workflow:").font(.caption)
                    Picker("", selection: Binding(
                        get: { model.hybridBenchWorkflowProfile },
                        set: { model.hybridBenchWorkflowProfile = $0 }
                    )) {
                        Text("primary")
                            .tag(BASHostWorkflowProfile.primary)
                        Text("comparative")
                            .tag(BASHostWorkflowProfile.comparative)
                        Text("reflective")
                            .tag(BASHostWorkflowProfile.reflective)
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.hybridBenchIsRunning)
                }
                // M744 chapter 一百九十八 — active cooling sleep
                // every N iters when device is at .serious or worse.
                // 0 = disabled (default). 1000 = ~once every 55s
                // on 18 iter/sec iPhone — gives device time to cool
                // between iter clusters.
                HStack {
                    Text("Cool every:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.hybridBenchCoolingEveryNIters },
                            set: { model.updateCoolingEveryNIters($0) }
                        ),
                        in: 0...100_000,
                        step: 100
                    ) {
                        Text(model.hybridBenchCoolingEveryNIters == 0
                             ? "off" : "\(model.hybridBenchCoolingEveryNIters)")
                            .font(.caption.monospacedDigit())
                    }
                    .disabled(model.hybridBenchIsRunning)
                }
                if model.hybridBenchCoolingEveryNIters > 0 {
                    HStack {
                        Text("Cool sleep:").font(.caption)
                        Stepper(
                            value: Binding(
                                get: { model.hybridBenchCoolingSleepSeconds },
                                set: { model.updateCoolingSleepSeconds($0) }
                            ),
                            in: 5.0...60.0,
                            step: 1.0
                        ) {
                            Text(String(
                                format: "%.0fs",
                                model.hybridBenchCoolingSleepSeconds))
                                .font(.caption.monospacedDigit())
                        }
                        .disabled(model.hybridBenchIsRunning)
                    }
                }
            }

            if model.hybridBenchIsRunning {
                Text(liveStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.cyan)
            } else if model.hybridBenchIterations > 0 {
                Text(finalStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if !model.hybridBenchOutputPath.isEmpty {
                Text("→ \(model.hybridBenchOutputPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let err = model.hybridBenchLastError {
                Text("Bench error: \(err)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            // M654 chapter 一百八十二 — meridian network status.
            // Visualizes the 5 CoreML head outputs that are firing
            // alongside substrate. Pre-this-batch they accumulated
            // silently in JSONL only; UI now shows them live.
            if model.hybridBenchIterations > 0 {
                Divider().padding(.vertical, 2)
                Text("📡 Meridian (5 CoreML heads + substrate dispatch)")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                Text(meridianHeadsStatus)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                // M727 chapter 一百九十三 — live anomaly dashboard.
                Divider().padding(.vertical, 2)
                Text("🛡️ Safety kit (chapter 192 10h-readiness pack)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text(safetyKitStatus)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(safetyKitTint)
            }
        }
        .padding(12)
        .background(.thinMaterial,
                    in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status string helpers

    /// M654 chapter 一百八十二 — render 5 CoreML heads' running
    /// stats: PermitPredict agreement, Length head MAE, Latency
    /// head MAE, plus substrate dispatch counts (skip / dual-LLM /
    /// local-only / draft / post-LLM shifted).
    private var meridianHeadsStatus: String {
        let permitTotal = model.hybridBenchPermitPredictHits
            + model.hybridBenchPermitPredictMisses
        let permitAgreementPct = permitTotal > 0
            ? Double(model.hybridBenchPermitPredictHits)
                / Double(permitTotal) * 100
            : 0
        // M689 chapter 一百八十八 — B8 retire: read Welford
        // running mean directly (was: Sum/Count).
        let lengthMAE = model.hybridBenchLengthMAERunning
        let latencyMAE = model.hybridBenchLatencyMAERunningMs
        // M661 chapter 一百八十三 — 5th head accuracy.
        let verbosityTotal = model.hybridBenchVerbosityCorrect
            + model.hybridBenchVerbosityWrong
        let verbosityAccuracy = verbosityTotal > 0
            ? Double(model.hybridBenchVerbosityCorrect)
                / Double(verbosityTotal) * 100
            : 0
        return String(
            format:
                "  PermitPredict: agree=%d/%d (%.1f%%)\n" +
                "  Length MAE: %.0f chars (n=%d)\n" +
                "  Latency MAE: %.0f ms  (n=%d)\n" +
                "  Verbosity acc: %d/%d (%.1f%%) [5th head]\n" +
                "  Substrate dispatch: skip[block=%d replace=%d delay=%d]\n" +
                "                       both-LLM=%d local-only=%d draft=%d\n" +
                "  Post-LLM shifted: %d (closed-loop)\n" +
                "  Partition Δ: %+d (acct=%d / iter=%d) [B15]",
            model.hybridBenchPermitPredictHits, permitTotal,
            permitAgreementPct,
            lengthMAE, model.hybridBenchLengthMAECount,
            latencyMAE, model.hybridBenchLatencyMAECount,
            model.hybridBenchVerbosityCorrect, verbosityTotal,
            verbosityAccuracy,
            model.hybridBenchSubstrateSkipBlock,
            model.hybridBenchSubstrateSkipReplace,
            model.hybridBenchSubstrateSkipDelay,
            model.hybridBenchSubstrateBothLLMs,
            model.hybridBenchSubstrateLocalOnly,
            model.hybridBenchSubstrateDraftOnly,
            model.hybridBenchPostLLMShifted,
            model.hybridBenchPartitionDelta,
            model.hybridBenchAccountedTotal,
            model.hybridBenchIterations)
    }

    /// M727 chapter 一百九十三 — live safety-kit dashboard.
    /// Surfaces 5 chapter-192 cumulative counters so during a 10h
    /// run the operator sees thermal pauses / anomaly hits /
    /// adversarial fires / drift alarms in real time.
    /// M745 chapter 一百九十八 — added thermal current state +
    /// iter %% breakdown + cooling sleep count + LLM timeout count.
    private var safetyKitStatus: String {
        let smoke = model.hybridBenchSmokeMode.rawValue
        let thermalTotal = model.hybridBenchThermalNominalIters
            + model.hybridBenchThermalFairIters
            + model.hybridBenchThermalSeriousIters
            + model.hybridBenchThermalCriticalIters
        let pct: (Int) -> String = { count in
            if thermalTotal == 0 { return "0%" }
            return "\(count * 100 / thermalTotal)%"
        }
        return String(
            format:
                "  Smoke mode: %@\n" +
                "  Thermal NOW: %@ (n=%d/f=%d/s=%d/c=%d → " +
                "%@/%@/%@/%@)\n" +
                "  Cooling sleeps fired: %d (M744)\n" +
                "  LLM timeouts fired: %d (M735)\n" +
                "  Thermal/battery paused: %d\n" +
                "  Substrate stuck (entries): %d\n" +
                "  LLM stuck (entries): %d\n" +
                "  Adversarial fired: %d\n" +
                "  Drift > %@-sigma alarms: %d",
            smoke,
            model.hybridBenchLastThermalRaw,
            model.hybridBenchThermalNominalIters,
            model.hybridBenchThermalFairIters,
            model.hybridBenchThermalSeriousIters,
            model.hybridBenchThermalCriticalIters,
            pct(model.hybridBenchThermalNominalIters),
            pct(model.hybridBenchThermalFairIters),
            pct(model.hybridBenchThermalSeriousIters),
            pct(model.hybridBenchThermalCriticalIters),
            model.hybridBenchCoolingSleepCount,
            model.hybridBenchLLMTimeoutCount,
            model.hybridBenchPauseSkippedCount,
            model.hybridBenchStuckSubstrateCount,
            model.hybridBenchStuckLLMCount,
            model.hybridBenchAdversarialFiredCount,
            String(format: "%.1f",
                model.hybridBenchDriftSigmaThreshold),
            model.hybridBenchDriftAlarmCount)
    }

    /// M727 — tint changes color based on health:
    /// .red if .critical thermal NOW (immediate concern)
    /// .orange if any safety counter > 0 OR .serious thermal
    /// .secondary if all clean
    /// M745 chapter 一百九十八 — added thermal-state-based tint.
    private var safetyKitTint: Color {
        let now = model.hybridBenchLastThermalRaw
        if now == "critical" {
            return .red
        }
        let anyAlarm = model.hybridBenchPauseSkippedCount > 0
            || model.hybridBenchStuckSubstrateCount > 0
            || model.hybridBenchStuckLLMCount > 0
            || model.hybridBenchDriftAlarmCount > 0
            || model.hybridBenchLLMTimeoutCount > 0
            || model.hybridBenchCoolingSleepCount > 0
            || now == "serious"
        return anyAlarm ? .orange : .secondary
    }

    private var liveStatus: String {
        let elapsed = model.hybridBenchStartTime.map {
            Date().timeIntervalSince($0)
        } ?? 0
        let perSec = elapsed > 0
            ? Double(model.hybridBenchIterations) / elapsed
            : 0
        let totalOk = model.hybridBenchAFMOk
            + model.hybridBenchGemmaOk
            + model.hybridBenchAFMFallbackToGemmaOk
            + model.hybridBenchGemmaFallbackToAFMOk
        let routerHits = model.hybridBenchRouterHits
        let routerTotal = routerHits + model.hybridBenchRouterMisses
        let routerHitRate = routerTotal > 0
            ? Double(routerHits) / Double(routerTotal) * 100
            : 0
        return String(
            format:
                "RUN iter=%d elapsed=%.0fs %.2f/s\n" +
                "  afm=%d gemma=%d afm→gemma=%d gemma→afm=%d both-failed=%d\n" +
                "  router-hit=%d miss=%d (%.1f%%) total-ok=%d",
            model.hybridBenchIterations,
            elapsed,
            perSec,
            model.hybridBenchAFMOk,
            model.hybridBenchGemmaOk,
            model.hybridBenchAFMFallbackToGemmaOk,
            model.hybridBenchGemmaFallbackToAFMOk,
            model.hybridBenchBothFailed,
            routerHits,
            model.hybridBenchRouterMisses,
            routerHitRate,
            totalOk)
    }

    private var finalStatus: String {
        return String(
            format:
                "DONE iter=%d afm=%d gemma=%d fallback=%d both-failed=%d",
            model.hybridBenchIterations,
            model.hybridBenchAFMOk,
            model.hybridBenchGemmaOk,
            model.hybridBenchAFMFallbackToGemmaOk
                + model.hybridBenchGemmaFallbackToAFMOk,
            model.hybridBenchBothFailed)
    }
}
