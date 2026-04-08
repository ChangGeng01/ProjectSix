import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: QuickCheckSession
    let result: QuickCheckResult
    @State private var reminderText: String?

    private var displayedResult: QuickCheckResult {
        session.result ?? result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: displayedResult.verdict.title,
                            title: displayedResult.verdict.summary,
                            subtitle: "One honest view of now. One honest view of after."
                        )

                        if session.isRefiningWithModel {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(BeforeTheme.ember)
                                Text("Tightening the language on-device…")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let reminderText {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("You once told yourself")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text("“\(reminderText)”")
                                        .font(.headline)
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Current perspective", systemImage: "bolt.horizontal.fill")
                                    .font(.headline)
                                Text(displayedResult.currentPerspective)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("quick.result.current")
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("After perspective", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.headline)
                                Text(displayedResult.afterPerspective)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("quick.result.after")
                            }
                        }

                        VStack(spacing: 12) {
                            BeforeActionButton(displayedResult.primaryAction.title(using: appModel.preferences.quickBufferDuration)) {
                                Task { await handleAction(displayedResult.primaryAction) }
                            }

                            ForEach(displayedResult.secondaryActions) { action in
                                BeforeActionButton(action.title(using: appModel.preferences.quickBufferDuration), style: .secondary) {
                                    Task { await handleAction(action) }
                                }
                            }

                            BeforeActionButton("Ask for support", style: .tertiary) {
                                appModel.sendQuickSessionToSupport(session, result: displayedResult)
                                dismiss()
                            }

                            BeforeActionButton("Move this to Shared Life", style: .tertiary) {
                                appModel.sendQuickSessionToSharedLife(session, result: displayedResult)
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Verdict")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                reminderText = await appModel.bestReminder(
                    for: session.scenario,
                    prompt: session.note,
                    mode: .quick
                )
            }
        }
    }

    private func handleAction(_ action: CheckAction) async {
        switch action {
        case .wait90s:
            session.selectedAction = action
            session.result = nil
            session.isShowingWaitSheet = true
            dismiss()
        default:
            await appModel.completeCheck(using: session, action: action)
            dismiss()
        }
    }
}
