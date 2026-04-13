import SwiftUI
import BASHostKit

struct SelfPortraitView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var substrateConsoleSnapshot: BASHostConsoleSnapshot?
    @State private var substrateEBrainTurn: BASEBrainTurnResult?
    @State private var substrateReplayEntries: [DeveloperDecisionReplayEntry] = []
    @State private var isLoadingSystemFlightDeck = false
    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.portrait

    private var currentEvolutionWorkspace: DecisionEvolutionWorkspaceSnapshot {
        DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: systemFlightDeck?.evolutionControlSurface ?? appModel.makeEvolutionControlSurface(),
            releaseSummary: systemFlightDeck?.releaseControlSummary
        )
    }

    var body: some View {
        let panel = appModel.portraitPanelState()
        let evolutionWorkspace = currentEvolutionWorkspace

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
                        eBrainTurnCard(substrateEBrainTurn)
                        replayLineageCard(substrateReplayEntries)
                        currentBrainCard(panel.currentBrainState)
                        boundaryCard(panel.currentBrainState)
                        calibrationCard(panel.currentBrainState)
                        evolutionCard(panel.currentBrainState, workspace: evolutionWorkspace)

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
            .onChange(of: appModel.evolutionControlMutationEpoch) { _, _ in
                Task {
                    await refreshSystemFlightDeck()
                }
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

                    if let eBrain = flightDeck.eBrainSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("13-layer path")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)

                            sourceBadge(sourceDescriptor(for: eBrain))

                            Text("\(eBrain.runMode.uppercased()) • \(eBrain.taskType.replacingOccurrences(of: "_", with: " ")) • \(eBrain.riskLevel.uppercased()) → \(eBrain.permitMode.uppercased())")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Route \(eBrain.deviceRoute) • Loops \(eBrain.loopCount) • Cache \(eBrain.cacheHitRate)% • Tickets \(eBrain.updateTicketCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("Host gate \(eBrain.hostGatePercent)% • Fold \(eBrain.foldChecksum) • Audit \(eBrain.auditFindingCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            DecisionEvolutionReleaseSummaryView(
                                releaseSummary: flightDeck.releaseControlSummary,
                                controlSurface: flightDeck.evolutionControlSurface,
                                presentationMode: evolutionSurfaceContract.releaseSummaryMode
                            )

                            Text(eBrain.inspectionHeadline)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let firstBlocker = eBrain.blockers.first {
                                Text("Guardrail: \(firstBlocker)")
                                    .font(.caption2)
                                    .foregroundStyle(BeforeTheme.ember)
                            }
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
        _ snapshot: BASHostConsoleSnapshot?
    ) -> some View {
        if let snapshot {
            PanelCard {
                BASHostConsoleView(snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func eBrainTurnCard(_ turn: BASEBrainTurnResult?) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("13-layer turn")
                    .font(.headline)

                if let turn {
                    sourceBadge(.liveRuntime)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(turn.budgetFrame.runMode.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BeforeTheme.ember)
                            Text(turn.contextFrame.taskType.rawValue.replacingOccurrences(of: "_", with: " "))
                                .font(.subheadline.bold())
                                .foregroundStyle(BeforeTheme.ink)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(turn.riskCard.riskLevel.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(healthColor(health(from: turn.riskCard.riskLevel)))
                            Text(turn.actionPermit.mode.rawValue.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(turn.decomposeFrame.mirrorText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Route: \(turn.runtimeTrace.modelRoute) • Loops: \(turn.runtimeTrace.loopCount) • Power: \(Int((turn.runtimeTrace.powerEstimate * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Host gate \(Int((turn.hostGateValue * 100).rounded()))% • Fold \(turn.thoughtFold.checksum.prefix(12)) • Device \(turn.deviceState.thermalLevel.rawValue)/\(turn.deviceState.memoryFreeMB)MB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Replay session \(turn.runtimeTrace.sessionID) • Recorded \(turn.runtimeTrace.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if !turn.runtimeTrace.guardrailFindings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Runtime audit")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(Array(turn.runtimeTrace.guardrailFindings.prefix(4)), id: \.id) { finding in
                                Text("• \(finding.layerID) \(finding.code): \(finding.summary)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.runtimeTrace.recommendedKillSwitches.isEmpty {
                                Text("Kill switches: \(turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue).joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.thoughtFrame.candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Candidates")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(Array(turn.thoughtFrame.candidates.prefix(3)), id: \.candidateID) { candidate in
                                Text("• \(candidate.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.memoryBundle.atoms.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Retrieved memory")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(Array(turn.memoryBundle.atoms.prefix(3)), id: \.memoryID) { atom in
                                Text("• \(atom.summary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.triScores.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tri-self scores")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(Array(turn.triScores.prefix(3)), id: \.candidateID) { score in
                                Text("• \(score.candidateID): id \(Int((score.idScore * 100).rounded())) / ego \(Int((score.egoScore * 100).rounded())) / superego \(Int((score.superegoScore * 100).rounded()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.riskCard.factors.isEmpty || !turn.actionPermit.reasonCodes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Risk gate")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            if !turn.riskCard.factors.isEmpty {
                                Text("Factors: \(turn.riskCard.factors.joined(separator: " • "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !turn.actionPermit.reasonCodes.isEmpty {
                                Text("Reason codes: \(turn.actionPermit.reasonCodes.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.renderedOutput.alternativeActions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Safer next moves")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(turn.renderedOutput.alternativeActions, id: \.self) { action in
                                Text("• \(action)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !turn.thoughtFold.compactSlots.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Thought fold")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(turn.thoughtFold.compactSlots.keys.sorted(), id: \.self) { key in
                                if let value = turn.thoughtFold.compactSlots[key], !value.isEmpty {
                                    Text("• \(key): \(value)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !turn.runtimeTrace.layerEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Replay trace")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(Array(turn.runtimeTrace.layerEvents.prefix(6).enumerated()), id: \.offset) { _, event in
                                Text("• \(event.layerID) \(event.event): \(event.detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let ticket = turn.updateTickets.first {
                        Text("Ticket: \(ticket.summary)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No 13-layer turn has been synthesized for the current brain yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func replayLineageCard(
        _ entries: [DeveloperDecisionReplayEntry]
    ) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Replay lineage")
                    .font(.headline)

                if entries.isEmpty {
                    Text("No replay lineage has been captured yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entries.prefix(3))) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.mode.shortTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BeforeTheme.ember)
                                Text(entry.statusTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ink)

                            Text(entry.summaryLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let eBrain = entry.eBrain {
                                Text("\(eBrain.source.title) • \(eBrain.riskLevel.uppercased()) → \(eBrain.permitMode.uppercased()) • host gate \(eBrain.hostGatePercent)% • fold \(eBrain.thoughtFoldChecksum)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if !eBrain.guardrailFindings.isEmpty {
                                    Text("Audit: \(eBrain.guardrailFindings.prefix(2).joined(separator: " • "))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if !eBrain.killSwitches.isEmpty {
                                    Text("Kill switches: \(eBrain.killSwitches.joined(separator: " • "))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let trace = entry.trace {
                                Text("Trace: \(trace.kind.title) • \(trace.activeProvider?.title ?? trace.preferredProvider.title)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
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
    private func evolutionCard(
        _ state: CurrentBrainState?,
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> some View {
        let controlSurface = workspace.controlSurface
        let spotlightSet = workspace.spotlightSet
        let activePresentation = spotlightSet.activePresentation
        let reviewPresentation = spotlightSet.reviewPresentation

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Safe evolution")
                    .font(.headline)

                if let state {
                    Text("Checkpoints: \(state.evolutionState.checkpointCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(controlSurface.canRollbackActiveCheckpoint ? "Rollback ready" : "Rollback unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if controlSurface.hasAnyCheckpoint {
                    Text("Live brain state is unavailable right now, but persisted checkpoints remain reviewable and restorable from local lineage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Evolution checkpoints appear after the current brain is loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if controlSurface.hasAnyCheckpoint || state != nil {
                    DecisionEvolutionPilotControlPanel(
                        controlSurface: controlSurface,
                        releaseSummary: workspace.releaseSummary,
                        interactionMode: evolutionSurfaceContract.interactionMode,
                        showEmbeddedReleaseSummary: evolutionSurfaceContract.showsEmbeddedReleaseSummaryInPilotPanel,
                        showHistoryShortcut: true,
                        showControlCenterShortcut: true,
                        afterMutation: {
                            Task {
                                await refreshSystemFlightDeck()
                            }
                        }
                    )
                }

                if controlSurface.hasAnyCheckpoint {
                    if controlSurface.activePresentation?.hasLineage == true
                        || controlSurface.reviewPresentation?.hasLineage == true {
                        sourceBadge(
                            .checkpointRecovery(
                                detail: "Recovered lineage stored in persisted checkpoints remains visible even when no live runtime turn is attached."
                            )
                        )
                    }

                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: controlSurface,
                        emptyMessage: state == nil
                            ? "Recovered checkpoints remain visible here even without a live current brain."
                            : "Evolution checkpoints will surface here after the current brain is loaded.",
                        interactionMode: evolutionSurfaceContract.interactionMode,
                        showCheckpointActionBar: evolutionSurfaceContract.showsCheckpointActionBarInSummary,
                        showControlCenterShortcut: true,
                        showHistoryShortcut: true,
                        afterMutation: {
                            Task {
                                await refreshSystemFlightDeck()
                            }
                        }
                    )

                    if let activePresentation {
                        DecisionEvolutionCheckpointPanelView(
                            title: "Active checkpoint",
                            checkpoint: activePresentation,
                            controlSurface: controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
                            showControlCenterShortcut: true,
                            showHistoryShortcut: true,
                            afterMutation: {
                                Task {
                                    await refreshSystemFlightDeck()
                                }
                            }
                        )
                    }

                    if let reviewPresentation {
                        DecisionEvolutionCheckpointPanelView(
                            title: "Review head",
                            checkpoint: reviewPresentation,
                            controlSurface: controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
                            showControlCenterShortcut: true,
                            showHistoryShortcut: true,
                            afterMutation: {
                                Task {
                                    await refreshSystemFlightDeck()
                                }
                            }
                        )
                    }
                }

                if let state, !state.evolutionState.recentDiffSummary.isEmpty {
                    ForEach(state.evolutionState.recentDiffSummary, id: \.self) { diff in
                        Text("• \(diff)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    private func health(from riskLevel: BASBrainRiskLevel) -> DecisionSystemLayerHealth {
        switch riskLevel {
        case .low:
            .strong
        case .medium:
            .watch
        case .high, .extreme:
            .critical
        }
    }

    private enum EBrainSourceDescriptor {
        case liveRuntime
        case checkpointRecovery(detail: String)

        var title: String {
            switch self {
            case .liveRuntime:
                "Live runtime"
            case .checkpointRecovery:
                "Checkpoint recovery"
            }
        }

        var detail: String {
            switch self {
            case .liveRuntime:
                "Showing the active 13-layer turn synthesized from the current local runtime."
            case .checkpointRecovery(let detail):
                detail
            }
        }

        var tint: Color {
            switch self {
            case .liveRuntime:
                .mint
            case .checkpointRecovery:
                BeforeTheme.ember
            }
        }
    }

    private func sourceDescriptor(
        for summary: DecisionSystemEBrainSummary
    ) -> EBrainSourceDescriptor {
        if summary.source == .persistedCheckpoint {
            return .checkpointRecovery(
                detail: "The flight deck is using recovered lineage from a persisted checkpoint because no live runtime turn is currently attached."
            )
        }

        return .liveRuntime
    }

    @ViewBuilder
    private func sourceBadge(_ descriptor: EBrainSourceDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(descriptor.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(descriptor.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(descriptor.tint.opacity(0.12), in: Capsule())

            Text(descriptor.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func refreshSystemFlightDeck() async {
        isLoadingSystemFlightDeck = true
        let inspection = await appModel.substrateInspectionSnapshot()
        systemFlightDeck = inspection.flightDeck
        substrateConsoleSnapshot = inspection.consoleSnapshot(currentBrainState: appModel.currentBrainState)
        substrateEBrainTurn = inspection.eBrainTurn
        substrateReplayEntries = inspection.synchronizedExport.recentReplay
        isLoadingSystemFlightDeck = false
    }
}
