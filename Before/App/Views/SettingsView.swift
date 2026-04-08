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
    @AppStorage("before.developerCenterUnlocked") private var developerCenterUnlocked = false
    @State private var destructiveAction: DestructiveAction?
    @State private var developerCenterTapCount = 0
    @State private var isDeveloperCenterPresented = false

    private let developerCenterAccessGate = DeveloperCenterAccessGate()

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

                Section("Decision behavior") {
                    Picker("Prompt action", selection: promptActionBinding) {
                        ForEach(HomePromptAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }

                    Picker("Quick buffer", selection: quickBufferBinding) {
                        ForEach(QuickBufferDuration.allCases) { duration in
                            Text(duration.title).tag(duration)
                        }
                    }

                    Toggle("Restore in-progress workspaces", isOn: restoreWorkspacesBinding)
                    Toggle("Show review insights", isOn: reviewInsightsBinding)
                }

                Section("On-device intelligence") {
                    Picker("Assistive intelligence", selection: intelligenceModeBinding) {
                        ForEach(OnDeviceIntelligenceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Text(appModel.preferences.onDeviceIntelligenceMode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Current behavior", value: userFacingIntelligenceTitle)
                    Text(userFacingIntelligenceDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("System surfaces") {
                    Label("Widget-first entry", systemImage: "square.grid.2x2")
                    Label("Siri connected but not primary", systemImage: "waveform")
                    Label("App Intents ready for Shortcuts and Spotlight", systemImage: "bolt.horizontal.circle")
                }

                Section("About") {
                    Button(action: handleDeveloperCenterAccessTap) {
                        LabeledContent("Version", value: appVersionLabel)
                    }
                    .buttonStyle(.plain)

                    if developerCenterUnlocked {
                        Button("Open Developer Center") {
                            isDeveloperCenterPresented = true
                        }
                    }
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
                    LabeledContent("Buddy requests", value: "\(appModel.supportInbox.requests.count)")
                    LabeledContent("Shared rules", value: "\(appModel.sharedLifeStore.rules.count)")
                    LabeledContent("Shared box items", value: "\(appModel.sharedLifeStore.boxItems.count)")
                    Button("Show onboarding again") {
                        appModel.hasSeenOnboarding = false
                    }
                }

                Section("Privacy & safety") {
                    Label("Widgets only show generic safe text", systemImage: "lock.shield")
                    Text("Your own reminder lines stay inside the app and never appear on the Home or Lock Screen. Buddy and Shared Life are still local-first in this version, so nothing leaves this device unless you add a real sync layer later.")
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
            .sheet(isPresented: $isDeveloperCenterPresented) {
                DeveloperCenterView()
                    .environmentObject(appModel)
            }
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

    private var promptActionBinding: Binding<HomePromptAction> {
        Binding(
            get: { appModel.preferences.homePromptAction },
            set: { newValue in
                appModel.updatePreferences { $0.homePromptAction = newValue }
            }
        )
    }

    private var restoreWorkspacesBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.restoreInProgressWorkspaces },
            set: { newValue in
                appModel.updatePreferences { $0.restoreInProgressWorkspaces = newValue }
            }
        )
    }

    private var quickBufferBinding: Binding<QuickBufferDuration> {
        Binding(
            get: { appModel.preferences.quickBufferDuration },
            set: { newValue in
                appModel.updatePreferences { $0.quickBufferDuration = newValue }
            }
        )
    }

    private var reviewInsightsBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.showReviewInsights },
            set: { newValue in
                appModel.updatePreferences { $0.showReviewInsights = newValue }
            }
        )
    }

    private var intelligenceModeBinding: Binding<OnDeviceIntelligenceMode> {
        Binding(
            get: { appModel.preferences.onDeviceIntelligenceMode },
            set: { newValue in
                appModel.updatePreferences { $0.onDeviceIntelligenceMode = newValue }
            }
        )
    }

    private var userFacingIntelligenceTitle: String {
        if !appModel.preferences.onDeviceIntelligenceMode.isEnabled {
            return "Deterministic local copy"
        }

        if appModel.intelligenceRuntimeStatus.active == .template {
            return "Deterministic fallback"
        }

        return "Local assistive intelligence"
    }

    private var userFacingIntelligenceDetail: String {
        if !appModel.preferences.onDeviceIntelligenceMode.isEnabled {
            return "Before is using the deterministic decision system only."
        }

        if appModel.intelligenceRuntimeStatus.active == .template {
            return "Local intelligence is unavailable right now, so Before is using deterministic local copy instead."
        }

        return "Before is refining routes, summaries, and reminder recall locally on this device while keeping verdicts deterministic."
    }

    private var appVersionLabel: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func handleDeveloperCenterAccessTap() {
        switch developerCenterAccessGate.handleTap(
            currentCount: developerCenterTapCount,
            unlocked: developerCenterUnlocked
        ) {
        case .openExisting:
            isDeveloperCenterPresented = true
        case .unlocked:
            developerCenterUnlocked = true
            developerCenterTapCount = 0
            isDeveloperCenterPresented = true
        case .progress:
            developerCenterTapCount += 1
        }
    }
}
