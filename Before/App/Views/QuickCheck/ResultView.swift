import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: QuickCheckSession
    let result: QuickCheckResult
    @State private var reminderText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: result.verdict.title,
                            title: result.verdict.summary,
                            subtitle: "One honest view of now. One honest view of after."
                        )

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
                                Text(result.currentPerspective)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("After perspective", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.headline)
                                Text(result.afterPerspective)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(spacing: 12) {
                            BeforeActionButton(result.primaryAction.title) {
                                Task { await handleAction(result.primaryAction) }
                            }

                            ForEach(result.secondaryActions) { action in
                                BeforeActionButton(action.title, style: .secondary) {
                                    Task { await handleAction(action) }
                                }
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
                reminderText = appModel.bestReminder(for: session.scenario)
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
