import SwiftData
import SwiftUI

@main
struct BeforeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bootstrapState = AppBootstrapState()
    private let isHostedUnitTest = DecisionTestingInterface.runtimeTestingContextDetected()

    var body: some Scene {
        WindowGroup {
            Group {
                if let appModel = bootstrapState.appModel {
                    RootTabView()
                        .environmentObject(appModel)
                        .modelContainer(appModel.modelContainer)
                        .onAppear {
                            guard !isHostedUnitTest else { return }
                            appModel.handleInitialAppearance()
                        }
                        .onChange(of: scenePhase) { _, newValue in
                            guard !isHostedUnitTest else { return }
                            appModel.handleScenePhase(newValue)
                        }
                } else {
                    PersistenceRecoveryView(
                        message: bootstrapState.bootstrap.recoveryMessage ??
                            "Before could not start its local storage runtime."
                    )
                }
            }
        }
    }
}

@MainActor
private final class AppBootstrapState: ObservableObject {
    let bootstrap: PersistenceBootstrap
    let appModel: BeforeAppModel?

    init() {
        let bootstrap = PersistenceBootstrap.loadAppContainer()
        self.bootstrap = bootstrap

        let startupMessages = [
            bootstrap.recoveryMessage,
            SharedContainer.notice
        ]
        .compactMap { $0 }
        let startupNotice = startupMessages.isEmpty
            ? nil
            : startupMessages.joined(separator: "\n\n")

        if let container = bootstrap.container {
            let appModel = BeforeAppModel(
                modelContainer: container,
                startupNotice: startupNotice
            )
            if DecisionTestingInterface.runtimeTestingContextDetected() {
                appModel.suppressHostedTestPresentations()
            }
            self.appModel = appModel
        } else {
            appModel = nil
        }
    }
}

private struct PersistenceRecoveryView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(BeforeTheme.ember)

            Text("Before needs to rebuild its local brain.")
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            Text(message)
                .font(.body)
                .foregroundStyle(BeforeTheme.ink.opacity(0.78))

            Text("Close and reopen the app. Before will stay private, but recent local state may need to be rebuilt.")
                .font(.footnote)
                .foregroundStyle(BeforeTheme.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(BeforeTheme.background.ignoresSafeArea())
    }
}
