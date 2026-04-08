import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.openURL) private var openURL
    @Query private var events: [CheckEvent]
    @Query private var balanceBoards: [BalanceDecisionRecord]
    @Query private var mirrorRecords: [MirrorDecisionRecord]
    @Query private var reminders: [SelfReminder]
    @Query private var tomorrowItems: [TomorrowBoxItem]
    @State private var destructiveAction: DestructiveAction?

    private enum DestructiveAction: Identifiable {
        case history
        case reminders
        case tomorrowBox
        case all

        var id: Self { self }

        var title: String {
            switch self {
            case .history: "Clear history?"
            case .reminders: "Clear reminders?"
            case .tomorrowBox: "Clear Tomorrow Box?"
            case .all: "Reset all local data?"
            }
        }

        var message: String {
            switch self {
            case .history: "This removes saved checks and their reflections from this device."
            case .reminders: "This removes every reminder you wrote to your future self on this device."
            case .tomorrowBox: "This removes every pending item from Tomorrow Box on this device."
            case .all: "This clears checks, reminders, Tomorrow Box items, pending reflections, and local widget state from this device."
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Positioning") {
                    Text("Before is a local decision system: quick calls get a stoplight, trade-offs get a balance board, heavier questions get a mirror.")
                }

                Section("System surfaces") {
                    Label("Widget-first entry", systemImage: "square.grid.2x2")
                    Label("Siri connected but not primary", systemImage: "waveform")
                    Label("App Intents ready for Shortcuts and Spotlight", systemImage: "bolt.horizontal.circle")
                }

                Section("Notifications") {
                    Button("Open Notification Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                }

                Section("Memory") {
                    LabeledContent("Saved quick checks", value: "\(events.count)")
                    LabeledContent("Saved balance boards", value: "\(balanceBoards.count)")
                    LabeledContent("Saved mirrors", value: "\(mirrorRecords.count)")
                    LabeledContent("Saved reminders", value: "\(reminders.count)")
                    LabeledContent("Tomorrow Box items", value: "\(tomorrowItems.count)")
                    Button("Show onboarding again") {
                        appModel.hasSeenOnboarding = false
                    }
                }

                Section("Privacy & safety") {
                    Label("Widgets only show generic safe text", systemImage: "lock.shield")
                    Text("Your own reminder lines stay inside the app and never appear on the Home or Lock Screen. Heavier decisions also stay local to this device unless you explicitly share them later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data controls") {
                    Button("Clear history", role: .destructive) {
                        destructiveAction = .history
                    }
                    Button("Clear reminders", role: .destructive) {
                        destructiveAction = .reminders
                    }
                    Button("Clear Tomorrow Box", role: .destructive) {
                        destructiveAction = .tomorrowBox
                    }
                    Button("Reset all local data", role: .destructive) {
                        destructiveAction = .all
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BeforeBackground())
            .navigationTitle("Settings")
            .confirmationDialog(
                destructiveAction?.title ?? "",
                isPresented: Binding(
                    get: { destructiveAction != nil },
                    set: { if !$0 { destructiveAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let destructiveAction {
                    Button("Continue", role: .destructive) {
                        switch destructiveAction {
                        case .history:
                            appModel.clearHistory()
                        case .reminders:
                            appModel.clearReminders()
                        case .tomorrowBox:
                            appModel.clearTomorrowBox()
                        case .all:
                            appModel.resetLocalData()
                        }
                        self.destructiveAction = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    destructiveAction = nil
                }
            } message: {
                if let destructiveAction {
                    Text(destructiveAction.message)
                }
            }
        }
    }
}
