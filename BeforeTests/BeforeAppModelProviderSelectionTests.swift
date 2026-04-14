import XCTest
import SwiftData
@testable import Before

final class BeforeAppModelProviderSelectionTests: XCTestCase {
    @MainActor
    func testSetPreferredIntelligenceProviderPublishesNotice() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.updatePreferences { $0.preferredIntelligenceProvider = .template }
        app.dismissStartupNotice()

        app.setPreferredIntelligenceProvider(.openModel)

        XCTAssertEqual(app.preferences.preferredIntelligenceProvider, .openModel)
        XCTAssertTrue(app.startupNotice?.contains("Preferred provider set to Open model runtime.") == true)
    }

    @MainActor
    func testSetAllowModelFallbacksPublishesNotice() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        app.updatePreferences { $0.allowModelFallbacks = false }
        app.dismissStartupNotice()

        app.setAllowModelFallbacks(true)

        XCTAssertTrue(app.preferences.allowModelFallbacks)
        XCTAssertTrue(app.startupNotice?.contains("Provider fallbacks are now enabled.") == true)
    }

    @MainActor
    func testImportOpenModelSelectsAssetAndRegistersConfiguredPreviewAdapter() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let sourceURL = try makeTemporaryOpenModelFile(named: "mistral-\(UUID().uuidString).gguf")

        let imported = try app.importOpenModel(from: sourceURL)
        defer { try? app.removeImportedOpenModel(named: imported.fileName) }

        XCTAssertEqual(app.preferences.preferredOpenModelAssetID, imported.assetID)
        XCTAssertEqual(app.openModelPreferredAsset?.assetID, imported.assetID)
        XCTAssertTrue(app.openModelImportedAssets.contains(where: { $0.assetID == imported.assetID }))
        XCTAssertEqual(
            DecisionIntelligenceProviderRegistry.shared.descriptor(for: .openModel)?.openModel?.stableID,
            imported.generatedStableID
        )
        XCTAssertTrue(app.startupNotice?.contains("Imported \(imported.fileName) into the open-model library slot.") == true)
    }

    @MainActor
    func testSetPreferredOpenModelAssetIDPublishesSelectionAndAutomaticNotices() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let firstSourceURL = try makeTemporaryOpenModelFile(named: "phi-\(UUID().uuidString).gguf")
        let secondSourceURL = try makeTemporaryOpenModelFile(named: "qwen-\(UUID().uuidString).gguf")

        let firstAsset = try app.importOpenModel(from: firstSourceURL)
        let secondAsset = try app.importOpenModel(from: secondSourceURL)
        defer {
            try? app.removeImportedOpenModel(named: firstAsset.fileName)
            try? app.removeImportedOpenModel(named: secondAsset.fileName)
        }

        app.dismissStartupNotice()
        app.setPreferredOpenModelAssetID(firstAsset.assetID)

        XCTAssertEqual(app.preferences.preferredOpenModelAssetID, firstAsset.assetID)
        XCTAssertTrue(app.startupNotice?.contains("Open model runtime will now prefer imported asset \(firstAsset.fileName).") == true)

        app.dismissStartupNotice()
        app.setPreferredOpenModelAssetID(nil)

        XCTAssertNil(app.preferences.preferredOpenModelAssetID)
        XCTAssertTrue(app.startupNotice?.contains("Open-model asset selection returned to automatic mode.") == true)
    }

    @MainActor
    func testRemoveImportedOpenModelClearsPreferenceAndRestoresReservedSlot() throws {
        let app = BeforeAppModel(modelContainer: try makeModelContainer(), startupNotice: nil)
        let sourceURL = try makeTemporaryOpenModelFile(named: "llama-\(UUID().uuidString).gguf")
        let imported = try app.importOpenModel(from: sourceURL)

        app.dismissStartupNotice()
        try app.removeImportedOpenModel(named: imported.fileName)

        XCTAssertNil(app.preferences.preferredOpenModelAssetID)
        XCTAssertFalse(app.openModelImportedAssets.contains(where: { $0.assetID == imported.assetID }))
        XCTAssertEqual(
            DecisionIntelligenceProviderRegistry.shared.descriptor(for: .openModel)?.openModel?.stableID,
            "before/open-model-slot"
        )
        XCTAssertTrue(app.startupNotice?.contains("Removed \(imported.fileName) from the open-model library slot.") == true)
    }

    private func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTemporaryOpenModelFile(named fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeforeAppModelProviderSelectionTests", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try Data("open-model".utf8).write(to: url)
        return url
    }
}
