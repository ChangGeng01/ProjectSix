import SwiftUI
import BASAdmin

struct SelfPortraitView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var substrateConsoleSnapshot: BASConsoleSnapshot?
    @State private var isLoadingSystemFlightDeck = false

    var body: some View {
        let panel = appModel.portraitPanelState()

        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: "Self Portrait",
                            title: "What Before thinks is true right now.",
                            subtitle: "The goal is not mystery. It is a visible, editable picture of how the local brain is loading you."
                        )

                        systemFlightDeckCard(systemFlightDeck)
                        substrateConsoleCard(substrateConsoleSnapshot)
                        currentBrainCard(panel.currentBrainState)
                        boundaryCard(panel.currentBrainState)
                        calibrationCard(panel.currentBrainState)
                        evolutionCard(panel.currentBrainState)

                        if let candidate = appModel.interventionCandidate {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Current intervention")
                                        .font(.headline)
                                    Text(candidate.title)
                                        .font(.title3.bold())
                                        .foregroundStyle(BeforeTheme.ink)
                                    Text(candidate.reason)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        templatesCard(panel.templates)
                        failurePatternsCard(panel.failurePatterns)
                        memoryCard(panel.memories)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Portrait")
            .task {
                await refreshSystemFlightDeck()
            }
        }
    }

    @ViewBuilder
    private func systemFlightDeckCard(_ flightDeck: DecisionSystemFlightDeck?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System flight deck")
                            .font(.headline)
                        Text("The local cognition stack across runtime, memory, safety, orchestration, and delivery.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    BeforeActionButton(
                        isLoadingSystemFlightDeck ? "Refreshing…" : "Refresh",
                        style: .secondary
                    ) {
                        Task {
                            await refreshSystemFlightDeck()
                        }
                    }
                    .disabled(isLoadingSystemFlightDeck)
                }

                if let flightDeck {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(flightDeck.overallScore)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(BeforeTheme.ink)
                        Text("/ 100")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(flightDeck.overallHealth.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(healthColor(flightDeck.overallHealth))
                            Text(flightDeck.isPureLocalClosedLoop ? "Pure local" : "Mixed runtime")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(flightDeck.layerReports) { report in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(report.layer.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(report.score)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(healthColor(report.health))
                            }

                            Text(report.headline)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let firstBlocker = report.blockers.first {
                                Text("Blocker: \(firstBlocker)")
                                    .font(.caption2)
                                    .foregroundStyle(healthColor(report.health))
                            } else if let firstSignal = report.signals.first {
                                Text(firstSignal)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Text("The flight deck has not been generated yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func substrateConsoleCard(
        _ snapshot: BASConsoleSnapshot?
    ) -> some View {
        if let snapshot {
            PanelCard {
                BASConsoleView(snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func currentBrainCard(_ state: CurrentBrainState?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current brain")
                    .font(.headline)

                if let state {
                    Label(state.mode.title, systemImage: state.mode.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(state.identityProfile.role.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let dominantGoal = state.dominantGoal, !dominantGoal.isEmpty {
                        Text(dominantGoal)
                            .font(.title3.bold())
                            .foregroundStyle(BeforeTheme.ink)
                    }

                    Text("Dominant reaction: \(readableReactionLabel(state.dominantReactionWeight))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !state.activeConstraints.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active constraints")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(state.activeConstraints, id: \.self) { constraint in
                                Text("• \(constraint)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("Fingerprint: \(state.verificationSnapshot.fingerprint)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("The brain has not been bootstrapped yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func boundaryCard(_ state: CurrentBrainState?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Boundary policy")
                    .font(.headline)

                if let state {
                    Text(state.boundaryPolicy.auditHeadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(state.boundaryPolicy.mode.rawValue.replacingOccurrences(of: "_", with: " "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    if !state.boundaryPolicy.activeConstraints.isEmpty {
                        ForEach(state.boundaryPolicy.activeConstraints, id: \.rawValue) { constraint in
                            Text("• \(constraint.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !state.boundaryPolicy.requiredConfirmations.isEmpty {
                        Text("Requires confirmation: \(state.boundaryPolicy.requiredConfirmations.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Boundary policy appears after the current brain is loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func calibrationCard(_ state: CurrentBrainState?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calibration")
                    .font(.headline)

                if let state {
                    Text(state.calibrationState.status.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(healthColor(health(from: state.calibrationState.status)))

                    Text("Drift score: \(Int((state.calibrationState.driftScore * 100).rounded()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if state.calibrationState.alerts.isEmpty {
                        Text("No active calibration alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(state.calibrationState.alerts, id: \.rawValue) { alert in
                            Text("• \(alert.rawValue.replacingOccurrences(of: "_", with: " "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !state.calibrationState.suggestedAdjustments.isEmpty {
                        Text(state.calibrationState.suggestedAdjustments.first ?? "")
                            .font(.caption2)
                            .foregroundStyle(BeforeTheme.ember)
                    }
                } else {
                    Text("Calibration state appears after the current brain is loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func evolutionCard(_ state: CurrentBrainState?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Safe evolution")
                    .font(.headline)

                if let state {
                    Text("Checkpoints: \(state.evolutionState.checkpointCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(state.evolutionState.rollbackReady ? "Rollback ready" : "Rollback unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let checkpoint = state.evolutionState.latestCheckpoint {
                        Text("Latest checkpoint: \(checkpoint.id)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if !state.evolutionState.recentDiffSummary.isEmpty {
                        ForEach(state.evolutionState.recentDiffSummary, id: \.self) { diff in
                            Text("• \(diff)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Evolution checkpoints appear after the current brain is loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func templatesCard(_ templates: [BrainPortraitTemplateItem]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Effective templates")
                    .font(.headline)

                if templates.isEmpty {
                    Text("No intervention templates are active yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(template.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(template.riskLevel.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BeforeTheme.ember)
                            }

                            Text(template.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !template.body.isEmpty {
                                ForEach(template.body, id: \.self) { line in
                                    Text("• \(line)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if !template.isPinned {
                                BeforeActionButton("Pin template", style: .secondary) {
                                    appModel.pinInterventionTemplate(id: template.id)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func failurePatternsCard(_ failures: [BrainPortraitFailurePatternItem]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Failure archive")
                    .font(.headline)

                if failures.isEmpty {
                    Text("No strong failure patterns are suppressing behavior yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(failures) { failure in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(failure.title)
                                .font(.subheadline.bold())
                            Text(failure.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Suppression \(Int((failure.suppressionWeight * 100).rounded()))% • \(failure.evidenceCount) pieces of evidence")
                                .font(.caption2)
                                .foregroundStyle(BeforeTheme.ember)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memoryCard(_ memories: [BrainPortraitMemoryItem]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Governed memories")
                    .font(.headline)

                if memories.isEmpty {
                    Text("No durable memory objects have been admitted yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memories) { memory in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(memory.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(BeforeTheme.ink)
                                    Text(memory.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(memory.tier.rawValue.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text("\(Int((memory.confidence * 100).rounded()))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("\(memory.source.rawValue) • \(memory.governanceStatus.rawValue) • \(memory.lastConfirmedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                BeforeActionButton("Downgrade", style: .secondary) {
                                    appModel.downgradeBrainPortraitMemory(id: memory.id)
                                }
                                BeforeActionButton("Not me", style: .secondary) {
                                    appModel.markBrainPortraitMemoryAsNotMe(id: memory.id)
                                }
                                BeforeActionButton("Delete", style: .tertiary) {
                                    appModel.deleteBrainPortraitMemory(id: memory.id)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func readableReactionLabel(_ key: DecisionReactionWeightKey) -> String {
        key.rawValue.replacingOccurrences(of: "_", with: " ")
    }

    private func healthColor(_ health: DecisionSystemLayerHealth) -> Color {
        switch health {
        case .strong:
            BeforeTheme.ember
        case .watch:
            .orange
        case .critical:
            .red
        }
    }

    private func health(from status: DecisionCalibrationStatus) -> DecisionSystemLayerHealth {
        switch status {
        case .stable:
            .strong
        case .watch:
            .watch
        case .drifting:
            .critical
        }
    }

    @MainActor
    private func refreshSystemFlightDeck() async {
        isLoadingSystemFlightDeck = true
        systemFlightDeck = await appModel.systemFlightDeck()
        substrateConsoleSnapshot = await appModel.substrateConsoleSnapshot()
        isLoadingSystemFlightDeck = false
    }
}
