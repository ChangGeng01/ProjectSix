import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.openURL) private var openURL
    @Query private var events: [CheckEvent]
    @Query private var reminders: [SelfReminder]
    @State private var destructiveAction: DestructiveAction?

    private enum DestructiveAction: Identifiable {
        case history
        case reminders
        case all

        var id: Self { self }

        var title: String {
            switch self {
            case .history: "Clear history?"
            case .reminders: "Clear reminders?"
            case .all: "Reset all local data?"
            }
        }

        var message: String {
            switch self {
            case .history: "This removes saved checks and their reflections from this device."
            case .reminders: "This removes every reminder you wrote to your future self on this device."
            case .all: "This clears checks, reminders, pending reflections, and local widget state from this device."
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Positioning") {
                    Text("Before is not here to shame or block you. It is here to slow down blurry decisions.")
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
                    LabeledContent("Saved checks", value: "\(events.count)")
                    LabeledContent("Saved reminders", value: "\(reminders.count)")
                    Button("Show onboarding again") {
                        appModel.hasSeenOnboarding = false
                    }
                }

                Section("Privacy & safety") {
                    Label("Widgets only show generic safe text", systemImage: "lock.shield")
                    Text("Your own reminder lines stay inside the app and never appear on the Home or Lock Screen.")
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
