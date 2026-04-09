import Foundation
import SwiftData

struct PersistenceBootstrap {
    enum LoadMode: Equatable {
        case persistent
        case recoveredPersistent
        case temporaryPersistent
        case inMemoryRecovery
        case unavailable
    }

    let container: ModelContainer?
    let recoveryMessage: String?
    let loadMode: LoadMode

    static func loadAppContainer() -> PersistenceBootstrap {
        loadAppContainer(
            createContainer: makeContainer(for:),
            quarantinePrimaryStore: quarantinePrimaryStoreArtifacts
        )
    }

    static func loadAppContainer(
        createContainer: (LoadMode) throws -> ModelContainer,
        quarantinePrimaryStore: () -> Void
    ) -> PersistenceBootstrap {
        do {
            return PersistenceBootstrap(
                container: try createContainer(.persistent),
                recoveryMessage: nil,
                loadMode: .persistent
            )
        } catch {
            quarantinePrimaryStore()

            if let recovered = tryRecovery(
                mode: .recoveredPersistent,
                message: "Stored data needed repair, and Before reopened with a clean local store.",
                createContainer: createContainer
            ) {
                return recovered
            }

            if let temporary = tryRecovery(
                mode: .temporaryPersistent,
                message: "Stored data could not be repaired, so Before reopened with a temporary recovery store.",
                createContainer: createContainer
            ) {
                return temporary
            }

            if let inMemory = tryRecovery(
                mode: .inMemoryRecovery,
                message: "Stored data could not be opened, so Before is running in temporary recovery mode.",
                createContainer: createContainer
            ) {
                return inMemory
            }

            let finalMessage = "Before could not start its local storage runtime. Please relaunch the app to rebuild a clean local store."
            PersistenceIssueRecorder.record(
                error: CocoaError(.fileReadUnknown),
                operation: "initializing the local storage runtime"
            )
            return PersistenceBootstrap(
                container: nil,
                recoveryMessage: finalMessage,
                loadMode: .unavailable
            )
        }
    }

    private static func tryRecovery(
        mode: LoadMode,
        message: String,
        createContainer: (LoadMode) throws -> ModelContainer
    ) -> PersistenceBootstrap? {
        guard let container = try? createContainer(mode) else {
            return nil
        }

        return PersistenceBootstrap(
            container: container,
            recoveryMessage: message,
            loadMode: mode
        )
    }

    private static func makeContainer(for mode: LoadMode) throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            SelfReminder.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            BrainStateUpdate.self,
            InterventionTrigger.self,
            InterventionTemplateRecord.self,
            FailurePatternRecord.self,
            TomorrowBoxItem.self,
            configurations: configuration(for: mode)
        )
    }

    private static func configuration(for mode: LoadMode) -> ModelConfiguration {
        switch mode {
        case .persistent, .recoveredPersistent:
            return ModelConfiguration(url: primaryStoreURL())
        case .temporaryPersistent:
            return ModelConfiguration(url: temporaryRecoveryStoreURL())
        case .inMemoryRecovery:
            return ModelConfiguration(isStoredInMemoryOnly: true)
        case .unavailable:
            return ModelConfiguration(
                "BeforeUnavailable",
                isStoredInMemoryOnly: true,
                allowsSave: false
            )
        }
    }

    private static func quarantinePrimaryStoreArtifacts() {
        let fileManager = FileManager.default
        let storeURL = primaryStoreURL()
        let directory = storeURL.deletingLastPathComponent()
        let basename = storeURL.deletingPathExtension().lastPathComponent

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in urls where url.lastPathComponent.hasPrefix(basename) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func primaryStoreURL() -> URL {
        beforeStorageDirectory()
            .appendingPathComponent("Before.store", isDirectory: false)
    }

    private static func temporaryRecoveryStoreURL() -> URL {
        beforeStorageDirectory()
            .appendingPathComponent("Recovery", isDirectory: true)
            .appendingPathComponent("Before-recovery.store", isDirectory: false)
    }

    private static func beforeStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let beforeDirectory = baseDirectory.appendingPathComponent("Before", isDirectory: true)
        if !fileManager.fileExists(atPath: beforeDirectory.path) {
            try? fileManager.createDirectory(
                at: beforeDirectory,
                withIntermediateDirectories: true
            )
        }
        return beforeDirectory
    }
}
