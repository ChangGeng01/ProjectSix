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

                    benchPanel

                    afmTestPanel

                    afmBenchPanel

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
        }
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

    // MARK: - M609 chapter 一百七十六 §176.13 — AFM direct foreground test panel

    private var afmTestPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AFM (Apple Foundation Models) direct test")
                    .font(.headline)
                Spacer()
                Button(model.afmIsRunning ? "Running…" : "Run AFM") {
                    model.runAFMTestNow()
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(model.afmIsRunning)
            }

            Text(
                "Bypasses BAS substrate (which has L2 organ stubbed). " +
                "Calls FoundationModels.LanguageModelSession directly " +
                "from foreground UI — only path that satisfies macOS 26 " +
                "/ iOS 26 modelmanagerd's foreground-only policy. " +
                "Requires Apple Intelligence enabled."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                Text("Prompt:").font(.caption.bold())
                Spacer()
            }
            TextField("AFM prompt", text: Binding(
                get: { model.afmTestPrompt },
                set: { model.updateAFMTestPrompt($0) }
            ))
            .font(.caption)
            .textFieldStyle(.roundedBorder)
            .disabled(model.afmIsRunning)

            Text("Status: \(model.afmTestStatus)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(model.afmTestStatus.hasPrefix("ok") ? .green : (model.afmTestStatus.hasPrefix("error") ? .red : .secondary))

            if !model.afmTestOutput.isEmpty {
                Text("Response:")
                    .font(.caption.bold())
                Text(model.afmTestOutput)
                    .font(.caption.monospaced())
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - M610 chapter 一百七十六 §176.14 — AFM 8h long-running bench panel

    private var afmBenchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AFM 8-hour bench (flexible config)")
                    .font(.headline)
                Spacer()
                Button(model.afmBenchIsRunning ? "Stop" : "Start") {
                    if model.afmBenchIsRunning {
                        model.stopAFMBench()
                    } else {
                        model.startAFMBench()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(model.afmBenchIsRunning ? .red : .indigo)
            }

            Text(
                "Substrate routes 14 layers per turn (audit codes), " +
                "then AFM body call (foreground policy satisfied). " +
                "All numeric params below are flexible (not hard-coded)."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            // Flexible config grid
            Group {
                HStack {
                    Text("Hours:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchDurationHours },
                            set: { model.updateAFMBenchDurationHours($0) }
                        ),
                        in: 0.1...24.0,
                        step: 0.5
                    ) {
                        Text(String(format: "%.1f h", model.afmBenchDurationHours))
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Text("Stride CSV:").font(.caption)
                    TextField("coprime to 40320", text: Binding(
                        get: { model.afmBenchStrideRotationCSV },
                        set: { model.updateAFMBenchStrideCSV($0) }
                    ))
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.afmBenchIsRunning)
                }
                HStack {
                    Text("Rotation iter:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchRotationPeriodIter },
                            set: { model.updateAFMBenchRotationPeriod($0) }
                        ),
                        in: 1_000...100_000,
                        step: 1_000
                    ) {
                        Text("\(model.afmBenchRotationPeriodIter)")
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Text("Mutations:").font(.caption)
                    Stepper(
                        value: Binding(
                            get: { model.afmBenchMutationSeedCount },
                            set: { model.updateAFMBenchMutationCount($0) }
                        ),
                        in: 1...5,
                        step: 1
                    ) {
                        Text("\(model.afmBenchMutationSeedCount)")
                            .font(.caption.monospacedDigit())
                    }
                }
                HStack {
                    Toggle("Skip AFM on .block/.delay (saves AFM calls)", isOn: Binding(
                        get: { model.afmBenchSkipBlocked },
                        set: { model.updateAFMBenchSkipBlocked($0) }
                    ))
                    .font(.caption)
                    .disabled(model.afmBenchIsRunning)
                }
            }

            if model.afmBenchIsRunning {
                Text(afmBenchLiveStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.indigo)
            } else if model.afmBenchIterations > 0 {
                Text(afmBenchFinalStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if !model.afmBenchOutputPath.isEmpty {
                Text("→ \(model.afmBenchOutputPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let err = model.afmBenchLastError {
                Text("Bench error: \(err)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var afmBenchLiveStatus: String {
        let elapsed = model.afmBenchStartTime.map {
            Date().timeIntervalSince($0)
        } ?? 0
        let perSec = elapsed > 0
            ? Double(model.afmBenchIterations) / elapsed
            : 0
        return String(
            format:
                "RUN • iter=%d • %.0fs/%.0fs • %.2f/s • " +
                "afm ok=%d skip=%d err=%d",
            model.afmBenchIterations,
            elapsed,
            model.afmBenchDurationHours * 3600,
            perSec,
            model.afmBenchAFMSuccessCount,
            model.afmBenchAFMSkippedCount,
            model.afmBenchAFMErrorCount)
    }

    private var afmBenchFinalStatus: String {
        return String(
            format:
                "DONE • iter=%d • afm ok=%d skip=%d err=%d",
            model.afmBenchIterations,
            model.afmBenchAFMSuccessCount,
            model.afmBenchAFMSkippedCount,
            model.afmBenchAFMErrorCount)
    }

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
