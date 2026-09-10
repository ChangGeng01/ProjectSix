import SwiftUI
import UniformTypeIdentifiers

struct DecisionSessionEngineActionBarView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    let sessionID: String?
    let openButtonTitle: String
    let importButtonTitle: String
    let exportButtonTitle: String
    let recoverButtonTitle: String?
    let canRecover: Bool
    let correctionButtonTitle: String?
    let correctionPlaceholder: String
    let correctionReason: String

    @State private var isImportingBundle = false
    @State private var exportedBundleURL: URL?
    @State private var activeSheet: ActiveSheet?

    init(
        sessionID: String?,
        openButtonTitle: String = "Open session engine",
        importButtonTitle: String = "Import bundle",
        exportButtonTitle: String = "Export active line",
        recoverButtonTitle: String? = nil,
        canRecover: Bool = false,
        correctionButtonTitle: String? = nil,
        correctionPlaceholder: String = "Describe the correction you want to branch from here.",
        correctionReason: String = "shared session engine correction branch"
    ) {
        self.sessionID = sessionID
        self.openButtonTitle = openButtonTitle
        self.importButtonTitle = importButtonTitle
        self.exportButtonTitle = exportButtonTitle
        self.recoverButtonTitle = recoverButtonTitle
        self.canRecover = canRecover
        self.correctionButtonTitle = correctionButtonTitle
        self.correctionPlaceholder = correctionPlaceholder
        self.correctionReason = correctionReason
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BeforeActionButton(openButtonTitle, style: .secondary) {
                    appModel.presentSessionEngineControlCenter()
                }

                BeforeActionButton(importButtonTitle, style: .tertiary) {
                    isImportingBundle = true
                }

                if let sessionID {
                    if canRecover, let recoverButtonTitle {
                        BeforeActionButton(recoverButtonTitle, style: .primary) {
                            Task {
                                await appModel.recoverSessionEngineSession(sessionID)
                            }
                        }
                    }

                    BeforeActionButton(exportButtonTitle, style: .tertiary) {
                        Task {
                            let exportURL = await appModel.exportSessionEngineSession(sessionID)
                            await MainActor.run {
                                exportedBundleURL = exportURL
                                if exportURL == nil {
                                    appModel.presentSessionEngineBundleIssue("Session Engine could not export the active recovery line.")
                                }
                            }
                        }
                    }

                    if let correctionButtonTitle {
                        BeforeActionButton(correctionButtonTitle, style: .tertiary) {
                            activeSheet = .correction(sessionID)
                        }
                    }
                }
            }

            if let exportedBundleURL {
                HStack(spacing: 8) {
                    Text("Bundle \(exportedBundleURL.lastPathComponent)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    ShareLink(item: exportedBundleURL) {
                        Label("Share bundle", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingBundle,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    appModel.presentSessionEngineBundleIssue("Choose a Session Engine bundle to import.")
                    return
                }

                Task {
                    guard await appModel.stageSessionEngineBundleImport(from: url) != nil else {
                        return
                    }
                    await MainActor.run {
                        activeSheet = .importPreview
                    }
                }
            case let .failure(error):
                appModel.presentSessionEngineBundleIssue(error.localizedDescription)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .importPreview:
                    if let draft = appModel.pendingSessionEngineImportDraft {
                        DecisionSessionEngineImportPreviewSheetView(draft: draft) { _ in
                            activeSheet = nil
                        }
                        .environmentObject(appModel)
                    } else {
                        PanelCard {
                            Text("Session Engine import preview is no longer available.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                case let .correction(sessionID):
                    DecisionSessionEngineCorrectionComposerView(
                        sessionID: sessionID,
                        title: correctionButtonTitle ?? "Create correction branch",
                        placeholder: correctionPlaceholder,
                        reason: correctionReason
                    ) {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            activeSheet = nil
                            appModel.presentSessionEngineControlCenter()
                        }
                    }
                    .environmentObject(appModel)
                }
            }
        }
        .onChange(of: appModel.pendingSessionEngineImportDraft?.id) { _, draftID in
            if draftID == nil, activeSheet == .importPreview {
                activeSheet = nil
            }
        }
        .alert(
            "Session Engine bundle",
            isPresented: Binding(
                get: { appModel.sessionEngineBundleIssue != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.dismissSessionEngineBundleIssue()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.sessionEngineBundleIssue ?? "Session Engine bundle action failed.")
        }
    }

    private enum ActiveSheet: Identifiable, Equatable {
        case importPreview
        case correction(String)

        var id: String {
            switch self {
            case .importPreview:
                return "import-preview"
            case let .correction(sessionID):
                return "correction-\(sessionID)"
            }
        }
    }
}
