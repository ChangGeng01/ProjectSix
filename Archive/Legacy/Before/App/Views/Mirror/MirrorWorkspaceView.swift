import SwiftUI

struct MirrorWorkspaceView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MirrorWorkspaceSession

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: session.entrySource.label,
                            title: session.workspaceTitle,
                            subtitle: session.workspaceSubtitle
                        )

                        workspaceStateCard

                        promptSection

                        mirrorLensSection(
                            eyebrow: "Inside the question",
                            title: "What is already true here",
                            subtitle: "Start with the parts you can name without forcing an answer.",
                            lenses: MirrorWorkspaceLens.openingLenses
                        )

                        mirrorLensSection(
                            eyebrow: "Further out",
                            title: "What this keeps doing over time",
                            subtitle: "The heavier lenses show what repeating this shape would cost.",
                            lenses: MirrorWorkspaceLens.closingLenses
                        )

                        revisitCueCard

                        DecisionSessionEngineResultActionsCard(
                            sessionID: session.sessionEngineSessionID,
                            headline: "Session Engine workspace line",
                            detail: "Open the local recovery line for this mirror, or split a correction branch before you reflect it back.",
                            correctionTitle: "Branch this mirror from here",
                            correctionPlaceholder: "Correction: continue this mirror from a new version line without overwriting the current path.",
                            correctionReason: "mirror workspace correction branch"
                        )

                        BeforeActionButton(
                            session.result == nil ? "Reflect it back" : "Reflect it back again",
                            isEnabled: session.canEvaluate,
                            accessibilityIdentifier: "mirror.evaluate"
                        ) {
                            Task {
                                await appModel.evaluateMirrorSessionWithIntelligence(session)
                            }
                        }
                        .disabled(!session.canEvaluate)

                        if let result = session.result {
                            if session.isRefiningWithModel {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(BeforeTheme.ember)
                                    Text("Clarifying the mirror on-device…")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            resultCard(result)
                            actionCard()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Mirror")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: session.prompt) { _, _ in invalidateReflectionIfNeeded() }
            .onChange(of: session.emotion) { _, _ in invalidateReflectionIfNeeded() }
            .onChange(of: session.relationship) { _, _ in invalidateReflectionIfNeeded() }
            .onChange(of: session.reality) { _, _ in invalidateReflectionIfNeeded() }
            .onChange(of: session.longTerm) { _, _ in invalidateReflectionIfNeeded() }
            .onChange(of: session.selfLens) { _, _ in invalidateReflectionIfNeeded() }
        }
    }

    private var workspaceStateCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.stage.title)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)
                        Text(session.stage.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(session.filledLensCount)/\(MirrorWorkspaceLens.allCases.count)")
                        .font(.title3.bold())
                        .foregroundStyle(BeforeTheme.ember)
                }

                ProgressView(value: session.progressFraction)
                    .tint(BeforeTheme.ember)

                HStack(alignment: .top, spacing: 12) {
                    statChip(title: "Filled", value: "\(session.filledLensCount)")
                    statChip(title: "Missing", value: "\(session.missingLensCount)")
                    statChip(title: "Ready", value: session.canEvaluate ? "Yes" : "Not yet")
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GuidedInputCard(
                title: "What are you facing?",
                subtitle: "Write the actual question before you try to solve it.",
                placeholder: "Should I stay? Should I leave? Do I still fit here?",
                accessibilityIdentifier: "mirror.prompt.input",
                text: $session.prompt
            )

            if session.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                PanelCard {
                    StarterPromptRow(
                        title: "Try a mirror starter",
                        suggestions: DecisionStarterLibrary.suggestions(for: .mirror)
                    ) { suggestion in
                        session.prompt = suggestion.prompt
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mirrorLensSection(
        eyebrow: String,
        title: String,
        subtitle: String,
        lenses: [MirrorWorkspaceLens]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)

            VStack(spacing: 14) {
                ForEach(lenses) { lens in
                    mirrorLensCard(for: lens)
                }
            }
        }
    }

    private func mirrorLensCard(for lens: MirrorWorkspaceLens) -> some View {
        GuidedInputCard(
            title: lens.title,
            subtitle: lens.subtitle,
            placeholder: lens.placeholder,
            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: mirrorField(for: lens)),
            accessibilityIdentifier: "mirror.\(mirrorField(for: lens).rawValue).input",
            text: binding(for: lens)
        )
    }

    private var revisitCueCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(session.revisitCueTitle, systemImage: session.stage.symbolName)
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ember)

                Text(session.revisitCueDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !session.filledLensTitles.isEmpty {
                    chipBlock(
                        title: "Already named",
                        values: session.filledLensTitles
                    )
                }

                if !session.missingLensTitles.isEmpty {
                    chipBlock(
                        title: "Still missing",
                        values: session.missingLensTitles
                    )
                }
            }
        }
    }

    private func resultCard(_ result: MirrorResult) -> some View {
        VStack(spacing: 12) {
            PanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.headline)
                        .font(.title3.bold())
                        .accessibilityIdentifier("mirror.result.headline")
                    Text(result.coreTension)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("mirror.result.tension")
                }
            }

            PanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.nextActionTitle)
                        .font(.headline)
                        .accessibilityIdentifier("mirror.result.nextActionTitle")
                    Text(result.nextAction)
                        .foregroundStyle(BeforeTheme.moss)
                        .accessibilityIdentifier("mirror.result.nextAction")
                }
            }
        }
    }

    private func actionCard() -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What happens next")
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                Text("You can save this mirror, send it into Tomorrow Box, or keep shaping it if the question still feels incomplete.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    BeforeActionButton("Save this mirror") {
                        appModel.saveMirrorWorkspace(session)
                        dismiss()
                    }

                    BeforeActionButton("Hold this with support", style: .secondary) {
                        appModel.sendMirrorSessionToSupport(session)
                        dismiss()
                    }

                    BeforeActionButton("Move this to Shared Life", style: .secondary) {
                        appModel.sendMirrorSessionToSharedLife(session)
                        dismiss()
                    }

                    BeforeActionButton("Move this to Tomorrow Box", style: .secondary) {
                        appModel.moveMirrorWorkspaceToTomorrow(session)
                        dismiss()
                    }

                    BeforeActionButton("Keep editing", style: .tertiary) {
                        session.result = nil
                    }
                }

                DecisionSessionEngineResultActionsCard(
                    sessionID: session.sessionEngineSessionID,
                    headline: "Session Engine recovery line",
                    detail: "Open the local recovery line for this mirror, or split into a correction branch if the pattern needs a new version line.",
                    correctionTitle: "Create mirror correction branch",
                    correctionPlaceholder: "Correction: continue this mirror from a new version line without overwriting the old branch.",
                    correctionReason: "mirror workspace correction branch"
                )
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(BeforeTheme.ink)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func chipBlock(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BeforeTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BeforeTheme.soft.opacity(0.8))
                            )
                    }
                }
            }
        }
    }

    private func binding(for lens: MirrorWorkspaceLens) -> Binding<String> {
        switch lens {
        case .emotion:
            return $session.emotion
        case .relationship:
            return $session.relationship
        case .reality:
            return $session.reality
        case .longTerm:
            return $session.longTerm
        case .selfLens:
            return $session.selfLens
        }
    }

    private func mirrorField(for lens: MirrorWorkspaceLens) -> MirrorField {
        switch lens {
        case .emotion:
            .emotion
        case .relationship:
            .relationship
        case .reality:
            .reality
        case .longTerm:
            .longTerm
        case .selfLens:
            .selfLens
        }
    }

    private func invalidateReflectionIfNeeded() {
        guard session.result != nil else { return }
        session.result = nil
    }
}
