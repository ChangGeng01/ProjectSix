import SwiftUI
import BASHostKit

enum SampleHostWindGatePresentationSupport {
    static func modeLabel(_ mode: BASActionPermitMode) -> String {
        humanizedToken(mode.rawValue)
    }

    static func modeLabels(_ modes: [BASActionPermitMode]) -> String {
        modes.map(modeLabel).joined(separator: " • ")
    }

    static func domainList(_ domains: [String], limit: Int = 3) -> String {
        Array(domains.prefix(limit)).map(humanizedToken).joined(separator: " • ")
    }

    static func humanizedToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SampleHostView: View {
    @ObservedObject var model: SampleHostModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SampleHost")
                            .font(.largeTitle.weight(.bold))
                        Text("Minimal private SDK integration proving lifecycle bootstrap, session start, reopen, current-brain render, and console inspection through BASHostKit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Bootstrap") { model.bootstrap() }
                        Button("Rapid") { model.start(.primary) }
                        Button("Deliberate") { model.start(.comparative) }
                        Button("Reflective") { model.start(.reflective) }
                        Button("Reopen") { model.reopen() }
                    }
                    .buttonStyle(.borderedProminent)

                    // M726 chapter 一百九十三 — resume banner.
                    // Surfaces a previous (possibly crashed) bench's
                    // last-known state so the user can decide whether
                    // to start fresh or treat the existing JSONL as
                    // continuing data. UI is hint-only — no auto-resume.
                    if let cp = model.hybridBenchResumableCheckpoint {
                        resumeBannerPanel(cp)
                    }

                    benchPanel

                    SampleHostAFMTestPanel(model: model)

                    SampleHostAFMBenchPanel(model: model)

                    SampleHostHybridTestPanel(model: model)

                    hybridBenchPanel

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.result.activeSessionTitle)
                            .font(.headline)
                        if let lastError = model.lastError {
                            Text(lastError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Text("Workflow: \(model.result.currentBrain.workflowTitle)")
                            .font(.subheadline.weight(.medium))
                        Text("Posture \(model.result.currentBrain.identityPosture.rawValue) • initiative \(model.result.currentBrain.identityInitiative.rawValue) • boundary \(model.result.currentBrain.boundaryMode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Calibration \(model.result.currentBrain.calibrationStatus.rawValue) • confidence \(Int((model.result.currentBrain.confidenceCeiling * 100).rounded()))% • pending review \(model.result.currentBrain.evolutionPendingReviewCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !model.result.currentBrain.dominantGoals.isEmpty {
                            Text(model.result.currentBrain.dominantGoals.joined(separator: " • "))
                                .font(.subheadline)
                        }
                        if !model.result.currentBrain.activeConstraints.isEmpty {
                            Text(model.result.currentBrain.activeConstraints.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !model.result.notices.isEmpty {
                            Text(model.result.notices.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let turn = model.result.eBrainTurn {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("13-layer turn")
                                .font(.headline)
                            sourceBadge(
                                title: "Live runtime",
                                detail: "SampleHost is currently rendering the active 13-layer runtime turn returned by BASHostKit."
                            )
                            Text("Mode \(turn.budgetFrame.runMode.rawValue) • task \(turn.contextFrame.taskType.rawValue) • risk \(turn.riskCard.riskLevel.rawValue) • permit \(SampleHostWindGatePresentationSupport.modeLabel(turn.actionPermit.mode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !turn.actionPermit.stackedModes.isEmpty {
                                Text("Stacked: \(SampleHostWindGatePresentationSupport.modeLabels(turn.actionPermit.stackedModes))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Assertion \(turn.actionPermit.assertionCeiling) • tool \(turn.actionPermit.toolScope) • memory \(turn.actionPermit.memoryScope)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !turn.actionPermit.allowedDomains.isEmpty {
                                Text("Allowed: \(SampleHostWindGatePresentationSupport.domainList(turn.actionPermit.allowedDomains))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.actionPermit.blockedDomains.isEmpty {
                                Text("Blocked: \(SampleHostWindGatePresentationSupport.domainList(turn.actionPermit.blockedDomains))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let delayType = turn.riskDecisionPackage?.delayReservation?.delayType ?? turn.actionPermit.delayWindow {
                                Text("Delay: \(SampleHostWindGatePresentationSupport.humanizedToken(delayType))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let substituteType = turn.riskDecisionPackage?.protectiveSubstitute?.substituteType ?? turn.riskCard.substituteType {
                                Text("Protective substitute: \(SampleHostWindGatePresentationSupport.humanizedToken(substituteType))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let sovereignHint = turn.riskDecisionPackage?.sovereignEscalationHint?.urgency ?? turn.riskCard.sovereignHintLevel ?? turn.actionPermit.escalationHintRef {
                                Text("Sovereign hint: \(SampleHostWindGatePresentationSupport.humanizedToken(sovereignHint))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Fold \(turn.thoughtFold.checksum.prefix(12)) • gate \(Int((turn.hostGateValue * 100).rounded()))% • route \(turn.runtimeTrace.modelRoute)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !turn.runtimeTrace.guardrailFindings.isEmpty {
                                Text("Audit: \(turn.runtimeTrace.guardrailFindings.prefix(3).map { "\($0.layerID):\($0.code)" }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.runtimeTrace.recommendedKillSwitches.isEmpty {
                                Text("Kill switches: \(turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue).joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(turn.decomposeFrame.mirrorText)
                                .font(.subheadline)
                            if !turn.memoryBundle.atoms.isEmpty {
                                Text("Memory: \(turn.memoryBundle.atoms.prefix(3).map(\.summary).joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.thoughtFrame.candidates.isEmpty {
                                Text("Candidates: \(turn.thoughtFrame.candidates.map(\.title).joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.renderedOutput.alternativeActions.isEmpty {
                                Text("Alternatives: \(turn.renderedOutput.alternativeActions.joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let guidance = turn.renderedOutput.deliveryFallbackGuidance {
                                Text("Guidance: \(guidance)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.thoughtFold.compactSlots.isEmpty {
                                Text("Slots: \(turn.thoughtFold.compactSlots.keys.sorted().compactMap { key in turn.thoughtFold.compactSlots[key].map { "\(key)=\($0)" } }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.runtimeTrace.layerEvents.isEmpty {
                                Text("Trace: \(turn.runtimeTrace.layerEvents.prefix(4).map { "\($0.layerID):\($0.event)" }.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.updateTickets.isEmpty {
                                Text("Tickets: \(turn.updateTickets.map(\.summary).joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    BASHostConsoleView(snapshot: model.result.consoleSnapshot)
                }
                .padding(24)
            }
            .navigationTitle("BASHostKit")
            // M726 chapter 一百九十三 — load resumable checkpoint
            // (if any) on first appear. Surfaces banner if a
            // previous bench crashed mid-run.
            .task { await model.loadResumableCheckpoint() }
        }
    }

    // MARK: - M726 chapter 一百九十三 — resume banner

    @ViewBuilder
    private func resumeBannerPanel(
        _ cp: SampleHostBenchCheckpoint
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚠️ Previous bench did not finish cleanly")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                // M748 chapter 一百九十九 — actual Resume button.
                // Restores smokeMode / duration / mutation /
                // stride from checkpoint, clears banner, starts
                // bench. Counter state NOT restored (fresh).
                Button("Resume Settings") {
                    Task { await model.resumeBenchFromCheckpoint() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
                Button("Dismiss") {
                    Task { await model.clearResumableCheckpoint() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Text("Last known state:")
                .font(.caption.bold())
            Text("• iter \(cp.iter) of "
                + "\(String(format: "%.1f", cp.durationHours))h target "
                + "(\(cp.smokeMode))")
                .font(.caption.monospacedDigit())
            Text("• AFM ok \(cp.afmOk) / Gemma ok \(cp.gemmaOk) / "
                + "both-failed \(cp.bothFailed)")
                .font(.caption.monospacedDigit())
            if cp.stuckSubstrates > 0 || cp.stuckLLMs > 0 {
                Text("• stuck-substrates \(cp.stuckSubstrates) / "
                    + "stuck-LLMs \(cp.stuckLLMs)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Text("• last update: \(cp.lastUpdatedIso)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("Starting a new bench will overwrite the checkpoint.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - M573 (chapter 一百四十七 part 2) — bench panel

    @ViewBuilder
    private var benchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Real-device substrate bench")
                    .font(.headline)
                Spacer()
                Button(model.benchIsRunning ? "Stop" : "Run Bench") {
                    model.toggleBench()
                }
                .buttonStyle(.bordered)
                .tint(model.benchIsRunning ? .red : .green)
            }

            Text(
                "Loops BASHostRuntime.startSession() with rotating " +
                "synthetic prompts (5 personas × 3 scenarios). " +
                "Per-iteration audit code count + permit mode + " +
                "duration written to Documents/iphone-bench/" +
                "iterations.jsonl. Keep app in foreground (iOS " +
                "suspends backgrounded apps after ~30s)."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if model.benchIsRunning {
                Text(benchLiveStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
            } else if model.benchIterationsCompleted > 0 {
                Text(benchFinalStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if !model.benchOutputPath.isEmpty {
                Text("→ \(model.benchOutputPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let benchError = model.benchLastError {
                Text("Bench error: \(benchError)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // M805 chapter 二百二十四 — `afmTestPanel` + `hybridTestPanel`
    // extracted to dedicated standalone SwiftUI structs in
    // `SampleHostTestPanels.swift`. View body composes via
    // `SampleHostAFMTestPanel(model: model)` + `SampleHostHybrid-
    // TestPanel(model: model)`.

    private var hybridBenchPanel: some View {
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
                Text(hybridBenchLiveStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.cyan)
            } else if model.hybridBenchIterations > 0 {
                Text(hybridBenchFinalStatus)
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

    private var hybridBenchLiveStatus: String {
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

    private var hybridBenchFinalStatus: String {
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

    // M806 chapter 二百二十五 — `afmBenchPanel` + 2 status helpers
    // extracted to `SampleHostAFMBenchPanel.swift` standalone struct.

    private var benchLiveStatusText: String {
        let elapsed: TimeInterval
        if let start = model.benchStartTime {
            elapsed = Date().timeIntervalSince(start)
        } else {
            elapsed = 0
        }
        let perSec = elapsed > 0
            ? Double(model.benchIterationsCompleted) / elapsed
            : 0
        return String(
            format: "RUNNING • iter=%d • %.1fs • %.2f/s • audit=%d",
            model.benchIterationsCompleted,
            elapsed,
            perSec,
            model.benchAuditCodesTotal)
    }

    private var benchFinalStatusText: String {
        return String(
            format: "DONE • iter=%d • audit=%d total • last error=%@",
            model.benchIterationsCompleted,
            model.benchAuditCodesTotal,
            model.benchLastError ?? "none")
    }

    @ViewBuilder
    private func sourceBadge(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.mint.opacity(0.12), in: Capsule())

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
