import SwiftUI

struct DecisionSessionEngineCorrectionComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: BeforeAppModel

    let sessionID: String
    let title: String
    let placeholder: String
    let reason: String
    let onCreated: () -> Void

    @State private var correctionText = ""
    @State private var isSubmitting = false
    @State private var isLoadingTargets = false
    @State private var targetSnapshot = DecisionSessionEngineControlSnapshot.build(
        runtimeSnapshot: nil,
        sessions: [],
        inspectionBySessionID: [:],
        selectedSessionID: nil,
        selectedBranchID: nil,
        selectedBranches: [],
        selectedCheckpoint: nil,
        selectedTimeline: nil
    )
    @State private var selectedTargetEventID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.title3.bold())
                            .foregroundStyle(BeforeTheme.ink)

                        Text("This adds a correction event and, when needed, continues on a new branch without rewriting the old history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField(placeholder, text: $correctionText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }

                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Correction target")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)

                            if isLoadingTargets {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Text("Pick a history point if this correction should branch from a specific event. Leave it on automatic to branch from the latest stable event on the current head line.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let selectedTarget {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Selected target")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BeforeTheme.ember)
                                Text(selectedTarget.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BeforeTheme.ink)
                                Text(selectedTarget.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let seqLine = selectedTarget.seqLine {
                                    Text(seqLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            BeforeActionButton("Use automatic target", style: .secondary) {
                                selectedTargetEventID = nil
                            }
                        } else {
                            Text("Automatic target: the latest stable event on the current head branch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if targetableTimelineItems.isEmpty {
                            Text("No targetable history events are available yet. The correction will branch from the latest stable event automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(targetableTimelineItems.prefix(6)) { item in
                                    Button {
                                        selectedTargetEventID = item.eventID
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                                Text(item.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(BeforeTheme.ink)
                                                Spacer()
                                                if item.eventID == selectedTargetEventID {
                                                    Text("Selected")
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(BeforeTheme.ember)
                                                }
                                            }

                                            Text(item.detail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            if let seqLine = item.seqLine {
                                                Text(seqLine)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(item.eventID == selectedTargetEventID ? BeforeTheme.ember.opacity(0.10) : Color.secondary.opacity(0.08))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(item.eventID == selectedTargetEventID ? BeforeTheme.ember.opacity(0.45) : Color.secondary.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    BeforeActionButton("Create correction branch", style: .primary) {
                        Task { await createCorrectionBranch() }
                    }
                    .disabled(correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    BeforeActionButton("Cancel", style: .tertiary) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .padding(20)
        }
        .navigationTitle("Correction Branch")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .task {
            await loadTargetSnapshot()
        }
    }

    private func createCorrectionBranch() async {
        let text = correctionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        isSubmitting = true
        await appModel.appendSessionEngineCorrection(
            sessionID,
            targetEventID: selectedTargetEventID,
            newText: text,
            reason: reason
        )
        isSubmitting = false
        dismiss()
        onCreated()
    }

    private func loadTargetSnapshot() async {
        isLoadingTargets = true
        let snapshot = await appModel.sessionEngineControlSnapshot(selectedSessionID: sessionID)
        targetSnapshot = snapshot
        if targetableTimelineItems.contains(where: { $0.eventID == selectedTargetEventID }) == false {
            selectedTargetEventID = nil
        }
        isLoadingTargets = false
    }

    private var targetableTimelineItems: [DecisionSessionEngineControlTimelinePresentation] {
        targetSnapshot.timelineItems.filter(\.canTargetCorrection)
    }

    private var selectedTarget: DecisionSessionEngineControlTimelinePresentation? {
        guard let selectedTargetEventID else { return nil }
        return targetableTimelineItems.first(where: { $0.eventID == selectedTargetEventID })
    }
}
