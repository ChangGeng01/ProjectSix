import SwiftUI
import BASHostKit

struct SelfPortraitView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var substrateConsoleSnapshot: BASHostConsoleSnapshot?
    @State private var substrateEBrainTurn: BASEBrainTurnResult?
    @State private var substrateReplayPresentations: [DecisionEvolutionReplayEntryPresentation] = []
    @State private var isLoadingSystemFlightDeck = false
    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.portrait

    private var evolutionSurfaceState: DecisionEvolutionSurfaceState {
        appModel.makeEvolutionSurfaceState(
            contract: evolutionSurfaceContract,
            flightDeck: systemFlightDeck
        )
    }

    private var currentEvolutionWorkspace: DecisionEvolutionWorkspaceSnapshot {
        evolutionSurfaceState.workspace
    }

    private var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        evolutionSurfaceContract.checkpointNavigationOptions
    }

    private var sessionEnginePresentation: DecisionSessionEnginePresentation {
        systemFlightDeck.sessionEnginePresentationOrUnattached
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
                        sessionEngineCard
                        localModelLibraryCard
                        substrateConsoleCard(substrateConsoleSnapshot)
                        eBrainTurnCard(substrateEBrainTurn)
                        replayLineageCard(substrateReplayPresentations)
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
                        let presentation = eBrain.presentation
                        VStack(alignment: .leading, spacing: 6) {
                            Text("13-layer path")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)

                            sourceBadge(presentation.sourceDescriptor)

                            Text(presentation.statusLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(presentation.routeLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(presentation.hostLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            DecisionEvolutionReleaseSummaryView(
                                releaseSummary: flightDeck.releaseControlSummary,
                                controlSurface: flightDeck.evolutionControlSurface,
                                surfaceContract: evolutionSurfaceContract,
                                presentationMode: evolutionSurfaceContract.releaseSummaryMode,
                                navigationOptions: checkpointNavigationOptions
                            )

                            Text(presentation.inspectionHeadline)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let primaryGuardrailText = presentation.primaryGuardrailText {
                                Text(primaryGuardrailText)
                                    .font(.caption2)
                                    .foregroundStyle(BeforeTheme.ember)
                            }
                        }
                    }

                    if flightDeck.sessionEngineSummary != nil {
                        DecisionSystemFlightDeckSessionEngineView(
                            presentation: flightDeck.sessionEnginePresentation
                        )
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
    private var localModelLibraryCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Local model library")
                    .font(.headline)

                if let localModelSummary = systemFlightDeck?.localModelLibrarySummary {
                    Text(localModelSummary.headline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DecisionLocalModelLibraryPanelView(
                    presentation: appModel.localModelLibraryPresentation,
                    showsTitle: false,
                    preferredGemmaAssetID: nil,
                    preferredOpenModelAssetID: nil,
                    importButtonTitle: nil,
                    downloadButtonTitle: nil,
                    importOpenModelButtonTitle: nil,
                    downloadOpenModelButtonTitle: nil,
                    onImportGemma: nil,
                    onDownloadGemma: nil,
                    onImportOpenModel: nil,
                    onDownloadOpenModel: nil,
                    onRemoveImportedGemma: nil,
                    onRemoveImportedOpenModel: nil
                )
            }
        }
    }

    @ViewBuilder
    private var sessionEngineCard: some View {
        PanelCard {
            DecisionSessionEngineSurfaceView(
                presentation: sessionEnginePresentation,
                showsTitle: true,
                maxRecentSessions: 3,
                correctionPlaceholder: "Describe the correction you want to branch from the active portrait-linked session line.",
                correctionReason: "portrait session engine correction branch"
            )
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
                    let diagnostics = turn.diagnosticsPresentation

                    sourceBadge(diagnostics.sourceDescriptor)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diagnostics.runModeTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BeforeTheme.ember)
                            Text(diagnostics.taskTitle)
                                .font(.subheadline.bold())
                                .foregroundStyle(BeforeTheme.ink)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(diagnostics.riskTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(healthColor(health(from: turn.riskCard.riskLevel)))
                            Text(diagnostics.permitTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(diagnostics.mirrorText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(diagnostics.routeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(diagnostics.hostText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(diagnostics.replayText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if !diagnostics.auditLines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Runtime audit")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.auditLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let activeKillSwitchesLine = diagnostics.activeKillSwitchesLine {
                                Text(activeKillSwitchesLine)
                                    .font(.caption2)
                                    .foregroundStyle(BeforeTheme.ember)
                            }
                            if let recommendedKillSwitchesLine = diagnostics.recommendedKillSwitchesLine {
                                Text(recommendedKillSwitchesLine)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.candidateTitles.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Candidates")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.candidateTitles, id: \.self) { title in
                                Text("• \(title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.memorySummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Retrieved memory")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.memorySummaries, id: \.self) { summary in
                                Text("• \(summary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.triScoreLines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tri-self scores")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.triScoreLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if diagnostics.riskFactorsLine != nil || diagnostics.reasonCodesLine != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Risk gate")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            if let riskFactorsLine = diagnostics.riskFactorsLine {
                                Text(riskFactorsLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let reasonCodesLine = diagnostics.reasonCodesLine {
                                Text(reasonCodesLine)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.alternativeActions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Safer next moves")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.alternativeActions, id: \.self) { action in
                                Text("• \(action)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.thoughtFoldLines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Thought fold")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.thoughtFoldLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !diagnostics.replayTraceLines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Replay trace")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)
                            ForEach(diagnostics.replayTraceLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let ticketSummary = diagnostics.ticketSummary {
                        Text("Ticket: \(ticketSummary)")
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
        _ entries: [DecisionEvolutionReplayEntryPresentation]
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
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.offset) { _, presentation in
                        DecisionReplayEntrySummaryView(
                            title: presentation.title,
                            presentation: presentation
                        ) {
                            DecisionReplayEntryHeaderRowView(
                                leadingText: presentation.modeTitle,
                                secondaryText: presentation.statusTitle,
                                trailingTimestamp: presentation.timestamp,
                                trailingTimestampStyle: .absoluteShort
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BeforeTheme.ember)
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
        let recoveryPresentation = workspace.recoveryPresentation(
            hasCurrentBrainState: state != nil
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Safe evolution")
                    .font(.headline)

                if let state {
                    Text("Checkpoints: \(state.evolutionState.checkpointCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(workspace.effectiveCanRollbackActiveCheckpoint ? "Rollback ready" : "Rollback unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(recoveryPresentation.availabilityText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if controlSurface.hasAnyCheckpoint || state != nil {
                    DecisionEvolutionPilotControlPanel(
                        controlSurface: controlSurface,
                        releaseSummary: workspace.releaseSummary,
                        surfaceContract: evolutionSurfaceContract,
                        showEmbeddedReleaseSummary: evolutionSurfaceContract.showsEmbeddedReleaseSummaryInPilotPanel,
                        navigationOptions: checkpointNavigationOptions,
                        afterMutation: {
                            Task {
                                await refreshSystemFlightDeck()
                            }
                        }
                    )
                }

                if controlSurface.hasAnyCheckpoint {
                    if let recoveryDescriptor = recoveryPresentation.sourceDescriptor {
                        sourceBadge(recoveryDescriptor)
                    }

                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: controlSurface,
                        surfaceContract: evolutionSurfaceContract,
                        emptyMessage: recoveryPresentation.emptyMessage,
                        navigationOptions: checkpointNavigationOptions,
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
                            surfaceContract: evolutionSurfaceContract,
                            navigationOptions: checkpointNavigationOptions,
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
                            surfaceContract: evolutionSurfaceContract,
                            navigationOptions: checkpointNavigationOptions,
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

    @ViewBuilder
    private func sourceBadge(_ descriptor: DecisionEvolutionSourceDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(descriptor.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(sourceTint(for: descriptor))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(sourceTint(for: descriptor).opacity(0.12), in: Capsule())

            Text(descriptor.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func sourceTint(for descriptor: DecisionEvolutionSourceDescriptor) -> Color {
        switch descriptor.kind {
        case .liveRuntime:
            .mint
        case .checkpointRecovery:
            BeforeTheme.ember
        }
    }

    @MainActor
    private func refreshSystemFlightDeck() async {
        isLoadingSystemFlightDeck = true
        let inspection = await appModel.substrateInspectionSnapshot()
        systemFlightDeck = inspection.flightDeck
        substrateConsoleSnapshot = inspection.consoleSnapshot(currentBrainState: appModel.currentBrainState)
        substrateEBrainTurn = inspection.eBrainTurn
        substrateReplayPresentations = await appModel.recentReplayDiagnosticsPresentations(limit: 3)
        isLoadingSystemFlightDeck = false
    }
}
