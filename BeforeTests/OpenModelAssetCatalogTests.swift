import XCTest
@testable import Before

final class OpenModelAssetCatalogTests: XCTestCase {
    func testImportModelCopiesAssetIntoImportedLibrary() throws {
        let sourceDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let sourceURL = temporaryFileURL(
            in: sourceDirectory,
            name: "mistral-7b.gguf",
            size: 4_200
        )

        let imported = try OpenModelAssetCatalog.importModel(
            from: sourceURL,
            baseDirectoryURL: libraryDirectory
        )

        XCTAssertEqual(imported.source, .imported)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path))
        XCTAssertTrue(imported.fileURL.path.contains("OpenModels"))
    }

    func testPreferredAssetIDOverridesAutomaticOrderingWhenAssetExists() {
        let first = OpenModelAsset(
            fileName: "alpha.gguf",
            fileSizeBytes: 100,
            source: .imported
        )
        let second = OpenModelAsset(
            fileName: "beta.gguf",
            fileSizeBytes: 200,
            source: .imported
        )

        let preferred = OpenModelAssetCatalog.preferredAsset(
            importedAssets: [first, second],
            preferredAssetID: second.assetID
        )

        XCTAssertEqual(preferred?.assetID, second.assetID)
    }

    func testGeneratedStableIDUsesNormalizedStem() {
        let asset = OpenModelAsset(
            fileName: "Mistral_7B-Instruct-v0.3.gguf",
            fileSizeBytes: 42,
            source: .imported
        )

        XCTAssertEqual(asset.generatedStableID, "local/open-model/mistral-7b-instruct-v0-3")
    }

    private func temporaryDirectoryURL() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func temporaryFileURL(in directory: URL, name: String, size: Int) -> URL {
        let url = directory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: UInt64(size))
            try? handle.close()
        }
        return url
    }
}
