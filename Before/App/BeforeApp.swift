import SwiftData
import SwiftUI

@main
struct BeforeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel: BeforeAppModel

    init() {
        let bootstrap = PersistenceBootstrap.loadAppContainer()
        let startupMessages = [
            bootstrap.recoveryMessage,
            SharedContainer.notice
        ]
        .compactMap { $0 }
        let startupNotice = startupMessages.isEmpty
            ? nil
            : startupMessages.joined(separator: "\n\n")

        _appModel = StateObject(
            wrappedValue: BeforeAppModel(
                modelContainer: bootstrap.container,
                startupNotice: startupNotice
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .modelContainer(appModel.modelContainer)
                .onAppear {
                    appModel.handleInitialAppearance()
                }
                .onChange(of: scenePhase) { _, newValue in
                    appModel.handleScenePhase(newValue)
                }
        }
    }
}
