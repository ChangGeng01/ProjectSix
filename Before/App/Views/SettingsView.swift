import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.openURL) private var openURL
    @Query private var events: [CheckEvent]
    @Query private var balanceBoards: [BalanceDecisionRecord]
    @Query private var mirrorRecords: [MirrorDecisionRecord]
    @Query private var reminders: [SelfReminder]
    @Query private var tomorrowItems: [TomorrowBoxItem]
    @State private var destructiveAction: DestructiveAction?
    @State private var cachedEvolutionSurfaceState: DecisionEvolutionSurfaceState?
    @State private var cachedSystemFlightDeck: DecisionSystemFlightDeck?
    @State private var isRefreshingEvolutionStatus = false
    @State private var isImportingGemmaModel = false
    @State private var isShowingGemmaDownloadSheet = false
    @State private var gemmaDownloadURLString = ""
    @State private var gemmaImportIssue: String?
    @State private var importedGemmaRemovalCandidate: GemmaModelAsset?
    @State private var isImportingOpenModel = false
    @State private var isShowingOpenModelDownloadSheet = false
    @State private var openModelDownloadURLString = ""
    @State private var openModelImportIssue: String?
    @State private var importedOpenModelRemovalCandidate: OpenModelAsset?

    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.settings
    private let preferredProviderOptions: [DecisionModelProviderPreference] = [
        .foundationModels,
        .gemmaE4B,
        .openModel,
        .template
    ]

    private var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        evolutionSurfaceContract.checkpointNavigationOptions
    }

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

                    Picker("Preferred provider", selection: preferredProviderBinding) {
                        ForEach(preferredProviderOptions) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    Toggle("Allow provider fallbacks", isOn: allowFallbacksBinding)

                    Text(appModel.preferences.preferredIntelligenceProvider.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if appModel.preferences.preferredIntelligenceProvider == .gemmaE4B {
                        Text(appModel.gemmaBundleStatus.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Preferred provider", value: appModel.preferences.preferredIntelligenceProvider.title)
                    LabeledContent("Current behavior", value: userFacingIntelligenceTitle)
                    LabeledContent("Active provider", value: appModel.intelligenceRuntimeStatus.active.title)
                    Text(userFacingIntelligenceDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        providerAvailabilityRow(
                            label: "Apple Foundation Model",
                            status: appModel.foundationModelStatus,
                            isSelected: appModel.preferences.preferredIntelligenceProvider == .foundationModels,
                            isActive: appModel.intelligenceRuntimeStatus.active == .foundationModels
                        )
                        providerAvailabilityRow(
                            label: "Gemma 4 E4B",
                            status: appModel.gemmaModelStatus,
                            isSelected: appModel.preferences.preferredIntelligenceProvider == .gemmaE4B,
                            isActive: appModel.intelligenceRuntimeStatus.active == .gemmaE4B
                        )
                        providerAvailabilityRow(
                            label: "Open model runtime",
                            status: appModel.openModelStatus,
                            isSelected: appModel.preferences.preferredIntelligenceProvider == .openModel,
                            isActive: appModel.intelligenceRuntimeStatus.active == .openModel
                        )
                    }
                    .padding(.top, 4)

                    if !appModel.registeredProviderDescriptors.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Registered model adapters")
                                .font(.subheadline.weight(.semibold))

                            Text("Apple stays the default. Gemma and the open-model slot are shown here as real registered adapters, not just preference labels.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            ForEach(appModel.registeredProviderDescriptors, id: \.kind) { descriptor in
                                providerDescriptorRow(
                                    descriptor: descriptor,
                                    isSelected: appModel.preferences.preferredIntelligenceProvider.kind == descriptor.kind,
                                    isActive: appModel.intelligenceRuntimeStatus.active == descriptor.kind
                                )
                            }
                        }
                        .padding(.top, 6)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        DecisionLocalModelLibraryPanelView(
                            presentation: localModelLibraryPresentation,
                            showsTitle: true,
                            preferredGemmaAssetID: preferredGemmaAssetBinding,
                            preferredOpenModelAssetID: preferredOpenModelAssetBinding,
                            importButtonTitle: "Import Gemma .litertlm",
                            downloadButtonTitle: appModel.isDownloadingGemmaModel
                                ? "Downloading Gemma…"
                                : "Download Gemma from URL",
                            importOpenModelButtonTitle: "Import open-model file",
                            downloadOpenModelButtonTitle: appModel.isDownloadingOpenModel
                                ? "Downloading open model…"
                                : "Download open-model from URL",
                            onImportGemma: {
                                isImportingGemmaModel = true
                            },
                            onDownloadGemma: {
                                isShowingGemmaDownloadSheet = true
                            },
                            onImportOpenModel: {
                                isImportingOpenModel = true
                            },
                            onDownloadOpenModel: {
                                isShowingOpenModelDownloadSheet = true
                            },
                            onRemoveImportedGemma: { asset in
                                importedGemmaRemovalCandidate = asset
                            },
                            onRemoveImportedOpenModel: { asset in
                                importedOpenModelRemovalCandidate = asset
                            }
                        )
                    }
                    .padding(.top, 6)
                }

                Section("System surfaces") {
                    Label("Widget-first entry", systemImage: "square.grid.2x2")
                    Label("Siri connected but not primary", systemImage: "waveform")
                    Label("App Intents ready for Shortcuts and Spotlight", systemImage: "bolt.horizontal.circle")
                }

                Section("Session engine") {
                    DecisionSessionEngineSurfaceView(
                        presentation: sessionEnginePresentation,
                        showsTitle: false,
                        maxRecentSessions: 2,
                        correctionPlaceholder: "Describe the correction you want to branch from the active session line.",
                        correctionReason: "settings session engine correction branch"
                    )
                }

                Section("Evolution control") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Read-first evolution control")
                                    .font(.headline)
                                Text("Settings mirrors the shared evolution workspace, but routes any mutation work to the control center.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isRefreshingEvolutionStatus {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button("Refresh") {
                                    Task {
                                        await refreshEvolutionStatus()
                                    }
                                }
                            }
                        }

                        DecisionEvolutionNavigationActionRow(
                            navigationOptions: checkpointNavigationOptions,
                            routesMutationsToControlCenter: evolutionSurfaceContract.routesMutationsToControlCenter,
                            controlCenterStyle: .primary,
                            adjacentShortcutStyle: .secondary
                        )
                    }
                    .padding(.vertical, 4)

                    if let releaseSummary = evolutionWorkspace.releaseSummary {
                        DecisionEvolutionReleaseSummaryView(
                            releaseSummary: releaseSummary,
                            controlSurface: evolutionSurfaceState.controlSurface,
                            surfaceContract: evolutionSurfaceContract,
                            presentationMode: evolutionSurfaceContract.releaseSummaryMode,
                            navigationOptions: checkpointNavigationOptions,
                            afterMutation: {
                                Task {
                                    await refreshEvolutionStatus()
                                }
                            }
                        )
                    }

                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: evolutionSurfaceState.controlSurface,
                        surfaceContract: evolutionSurfaceContract,
                        emptyMessage: "No persisted checkpoint lineage is attached yet. Once review traffic appears, Settings will mirror the shared evolution workspace here.",
                        navigationOptions: checkpointNavigationOptions
                    )
                }

                Section("Kill-switch policy") {
                    DecisionEvolutionKillSwitchPanelView(
                        activeKillSwitches: appModel.activeEvolutionKillSwitches,
                        recommendedKillSwitchIDs: evolutionRecommendedKillSwitchIDs,
                        surfaceContract: evolutionSurfaceContract,
                        navigationOptions: checkpointNavigationOptions
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersionLabel)
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
            .task {
                await refreshEvolutionStatus()
            }
            .onChange(of: appModel.evolutionControlMutationEpoch) { _, _ in
                Task {
                    await refreshEvolutionStatus()
                }
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
            .confirmationDialog(
                "Remove imported Gemma model?",
                isPresented: Binding(
                    get: { importedGemmaRemovalCandidate != nil },
                    set: { if !$0 { importedGemmaRemovalCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let importedGemmaRemovalCandidate {
                    Button("Remove", role: .destructive) {
                        do {
                            try appModel.removeImportedGemmaModel(named: importedGemmaRemovalCandidate.fileName)
                        } catch {
                            gemmaImportIssue = error.localizedDescription
                        }
                        self.importedGemmaRemovalCandidate = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    importedGemmaRemovalCandidate = nil
                }
            } message: {
                if let importedGemmaRemovalCandidate {
                    Text("This removes \(importedGemmaRemovalCandidate.fileName) from Before's local Gemma library.")
                }
            }
            .confirmationDialog(
                "Remove imported open-model asset?",
                isPresented: Binding(
                    get: { importedOpenModelRemovalCandidate != nil },
                    set: { if !$0 { importedOpenModelRemovalCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let importedOpenModelRemovalCandidate {
                    Button("Remove", role: .destructive) {
                        do {
                            try appModel.removeImportedOpenModel(named: importedOpenModelRemovalCandidate.fileName)
                        } catch {
                            openModelImportIssue = error.localizedDescription
                        }
                        self.importedOpenModelRemovalCandidate = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    importedOpenModelRemovalCandidate = nil
                }
            } message: {
                if let importedOpenModelRemovalCandidate {
                    Text("This removes \(importedOpenModelRemovalCandidate.fileName) from Before's local open-model library slot.")
                }
            }
            .fileImporter(
                isPresented: $isImportingGemmaModel,
                allowedContentTypes: [gemmaImportContentType]
            ) { result in
                switch result {
                case let .success(url):
                    do {
                        try appModel.importGemmaModel(from: url)
                    } catch {
                        gemmaImportIssue = error.localizedDescription
                    }
                case let .failure(error):
                    gemmaImportIssue = error.localizedDescription
                }
            }
            .alert(
                "Gemma import",
                isPresented: Binding(
                    get: { gemmaImportIssue != nil },
                    set: { if !$0 { gemmaImportIssue = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    gemmaImportIssue = nil
                }
            } message: {
                Text(gemmaImportIssue ?? "Before couldn't finish the Gemma import.")
            }
            .fileImporter(
                isPresented: $isImportingOpenModel,
                allowedContentTypes: openModelImportContentTypes
            ) { result in
                switch result {
                case let .success(url):
                    do {
                        try appModel.importOpenModel(from: url)
                    } catch {
                        openModelImportIssue = error.localizedDescription
                    }
                case let .failure(error):
                    openModelImportIssue = error.localizedDescription
                }
            }
            .alert(
                "Open-model import",
                isPresented: Binding(
                    get: { openModelImportIssue != nil },
                    set: { if !$0 { openModelImportIssue = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    openModelImportIssue = nil
                }
            } message: {
                Text(openModelImportIssue ?? "Before couldn't finish the open-model import.")
            }
            .sheet(isPresented: $isShowingGemmaDownloadSheet) {
                NavigationStack {
                    Form {
                        Section("Remote Gemma file") {
                            TextField(
                                "https://example.com/gemma-4-E4B-it.litertlm",
                                text: $gemmaDownloadURLString
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                            Text("Paste a direct `http` or `https` link to a `.litertlm` file. Before will download it into the local Gemma library and pin it as the preferred Gemma asset.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if appModel.isDownloadingGemmaModel {
                            Section("Download") {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Downloading and importing the Gemma model…")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Download Gemma")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingGemmaDownloadSheet = false
                            }
                            .disabled(appModel.isDownloadingGemmaModel)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Download") {
                                startGemmaDownload()
                            }
                            .disabled(
                                appModel.isDownloadingGemmaModel
                                    || gemmaDownloadURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingOpenModelDownloadSheet) {
                NavigationStack {
                    Form {
                        Section("Remote open-model file") {
                            TextField(
                                "https://example.com/model.gguf",
                                text: $openModelDownloadURLString
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                            Text("Paste a direct `http` or `https` link to a supported local model file such as `.gguf`, `.onnx`, `.safetensors`, `.bin`, or `.litertlm`. Before will download it into the open-model slot and register it as the current preview adapter.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if appModel.isDownloadingOpenModel {
                            Section("Download") {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Downloading and importing the open-model asset…")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Download Open Model")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingOpenModelDownloadSheet = false
                            }
                            .disabled(appModel.isDownloadingOpenModel)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Download") {
                                startOpenModelDownload()
                            }
                            .disabled(
                                appModel.isDownloadingOpenModel
                                    || openModelDownloadURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }
                    }
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

    private var preferredProviderBinding: Binding<DecisionModelProviderPreference> {
        Binding(
            get: { appModel.preferences.preferredIntelligenceProvider },
            set: { newValue in
                appModel.setPreferredIntelligenceProvider(newValue)
            }
        )
    }

    private var allowFallbacksBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.allowModelFallbacks },
            set: { newValue in
                appModel.setAllowModelFallbacks(newValue)
            }
        )
    }

    private var preferredGemmaAssetBinding: Binding<String?> {
        Binding(
            get: { appModel.preferredGemmaAssetID },
            set: { newValue in
                appModel.setPreferredGemmaAssetID(newValue)
            }
        )
    }

    private var preferredOpenModelAssetBinding: Binding<String?> {
        Binding(
            get: { appModel.preferredOpenModelAssetID },
            set: { newValue in
                appModel.setPreferredOpenModelAssetID(newValue)
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

        return appModel.intelligenceRuntimeStatus.active.title
    }

    private var userFacingIntelligenceDetail: String {
        if !appModel.preferences.onDeviceIntelligenceMode.isEnabled {
            return "Before is using the deterministic decision system only."
        }

        return appModel.intelligenceRuntimeStatus.detail
    }

    private var appVersionLabel: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var gemmaImportContentType: UTType {
        UTType(filenameExtension: "litertlm") ?? .data
    }

    private var openModelImportContentTypes: [UTType] {
        let dynamicTypes = OpenModelAssetCatalog.supportedExtensions.compactMap { extensionName in
            UTType(filenameExtension: extensionName)
        }
        if dynamicTypes.isEmpty {
            return [.data]
        }
        return dynamicTypes
    }

    private var localModelLibraryPresentation: DecisionLocalModelLibraryPresentation {
        appModel.localModelLibraryPresentation
    }

    private var evolutionSurfaceState: DecisionEvolutionSurfaceState {
        cachedEvolutionSurfaceState
            ?? appModel.makeEvolutionSurfaceState(contract: evolutionSurfaceContract)
    }

    private var evolutionWorkspace: DecisionEvolutionWorkspaceSnapshot {
        evolutionSurfaceState.workspace
    }

    private var evolutionRecommendedKillSwitchIDs: [String] {
        evolutionWorkspace.releaseSummary?.recommendedKillSwitches
            ?? evolutionSurfaceState.controlSurface.reviewKillSwitches
    }

    private var sessionEnginePresentation: DecisionSessionEnginePresentation {
        cachedSystemFlightDeck.sessionEnginePresentationOrUnattached
    }

    @MainActor
    private func refreshEvolutionStatus() async {
        guard !isRefreshingEvolutionStatus else { return }
        isRefreshingEvolutionStatus = true
        defer { isRefreshingEvolutionStatus = false }
        let flightDeck = await appModel.systemFlightDeck()
        cachedSystemFlightDeck = flightDeck
        cachedEvolutionSurfaceState = appModel.makeEvolutionSurfaceState(
            contract: evolutionSurfaceContract,
            flightDeck: flightDeck
        )
    }

    @ViewBuilder
    private func providerAvailabilityRow(
        label: String,
        status: DecisionModelProviderStatus,
        isSelected: Bool,
        isActive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                if isSelected {
                    Text("Default")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
                Spacer()
                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.isAvailable ? .green : .secondary)
            }
            Text(status.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func providerDescriptorRow(
        descriptor: DecisionModelProviderDescriptor,
        isSelected: Bool,
        isActive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(descriptor.title)
                    .font(.subheadline.weight(.semibold))

                Text(providerTrackTitle(descriptor.track))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if isSelected {
                    Text("Default")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Spacer()
            }

            if let openModel = descriptor.openModel {
                Text("\(openModel.family) \(openModel.version) • \(openModel.stableID)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(providerCapabilitySummary(descriptor.capabilityProfile))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(descriptor.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func providerTrackTitle(_ track: DecisionModelProviderTrack) -> String {
        switch track {
        case .builtInSystem:
            "System"
        case .builtInOpenModel:
            "Open model"
        case .deterministic:
            "Deterministic"
        case .testingOnly:
            "Testing"
        }
    }

    private func providerCapabilitySummary(_ profile: DecisionModelCapabilityProfile) -> String {
        let languages = profile.supportedResponseLanguages.map { providerLanguageTitle($0.rawValue) }.joined(separator: ", ")
        let bestFor = profile.bestFor.map { providerTaskTitle($0.rawValue) }.joined(separator: ", ")
        let thinking = profile.supportsThinking ? "thinking" : "no thinking"
        let tools = profile.supportsToolUse ? "tools" : "no tools"
        return "Latency \(providerClassTitle(profile.latencyClass)) • Memory \(providerClassTitle(profile.memoryClass)) • \(thinking) • \(tools) • Languages: \(languages) • Best for: \(bestFor)"
    }

    private func providerLanguageTitle(_ language: String) -> String {
        switch language {
        case "english":
            "English"
        case "chinese":
            "Chinese"
        case "mixed":
            "Mixed"
        default:
            language.capitalized
        }
    }

    private func providerTaskTitle(_ task: String) -> String {
        switch task {
        case "primary":
            "quick calls"
        case "comparative":
            "trade-offs"
        case "reflective":
            "mirror work"
        case "selection":
            "reminder picks"
        default:
            task
        }
    }

    private func providerClassTitle(_ value: DecisionModelLatencyClass) -> String {
        switch value {
        case .low:
            "low"
        case .medium:
            "medium"
        case .high:
            "high"
        }
    }

    private func providerClassTitle(_ value: DecisionModelMemoryClass) -> String {
        switch value {
        case .low:
            "low"
        case .medium:
            "medium"
        case .high:
            "high"
        }
    }

    private func startGemmaDownload() {
        let trimmedURLString = gemmaDownloadURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = URL(string: trimmedURLString) else {
            gemmaImportIssue = "Before couldn't read that Gemma download URL."
            return
        }

        Task {
            do {
                try await appModel.downloadGemmaModel(from: remoteURL)
                gemmaDownloadURLString = ""
                isShowingGemmaDownloadSheet = false
            } catch {
                gemmaImportIssue = error.localizedDescription
            }
        }
    }

    private func startOpenModelDownload() {
        let trimmedURLString = openModelDownloadURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = URL(string: trimmedURLString) else {
            openModelImportIssue = "Before couldn't read that open-model download URL."
            return
        }

        Task {
            do {
                try await appModel.downloadOpenModel(from: remoteURL)
                openModelDownloadURLString = ""
                isShowingOpenModelDownloadSheet = false
            } catch {
                openModelImportIssue = error.localizedDescription
            }
        }
    }
}
