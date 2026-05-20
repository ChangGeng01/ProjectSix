import XCTest
@testable import Before

final class GemmaModelAssetCatalogTests: XCTestCase {
    func testAssetsAreSortedAndExposeHumanReadableSize() {
        let directory = temporaryDirectoryURL()
        let urls = [
            temporaryFileURL(in: directory, name: "gemma-4-E4B-it-int4.litertlm", size: 2_680_000_000),
            temporaryFileURL(in: directory, name: "gemma-4-E2B-it-int4.litertlm", size: 1_340_000_000)
        ]

        let assets = GemmaModelAssetCatalog.assets(from: urls)

        XCTAssertEqual(
            assets.map(\.fileName),
            ["gemma-4-E2B-it-int4.litertlm", "gemma-4-E4B-it-int4.litertlm"]
        )
        XCTAssertFalse(assets[0].displaySize.isEmpty)
        XCTAssertTrue(assets.allSatisfy(\.isComplete))
    }

    func testKnownGemmaAssetReportsIncompleteWhileDownloading() {
        let directory = temporaryDirectoryURL()
        let urls = [
            temporaryFileURL(in: directory, name: "gemma-4-E4B-it.litertlm", size: 500_000_000)
        ]

        let asset = try! XCTUnwrap(GemmaModelAssetCatalog.assets(from: urls).first)

        XCTAssertFalse(asset.isComplete)
        XCTAssertEqual(asset.expectedSizeBytes, 3_654_467_584)
        XCTAssertEqual(asset.progressDescription, "13%")
    }

    func testPreferredAssetPrefersReadyImportedAssetOverBundledFallback() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .bundled
        )

        let preferred = GemmaModelAssetCatalog.preferredAsset(
            importedAssets: [imported],
            bundledAssets: [bundled]
        )

        XCTAssertEqual(preferred?.source, .imported)
    }

    func testPreferredAssetPrefersCompleteBundledAssetOverIncompleteImportedAsset() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 500_000_000,
            expectedSizeBytes: 3_654_467_584,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .bundled
        )

        let preferred = GemmaModelAssetCatalog.preferredAsset(
            importedAssets: [imported],
            bundledAssets: [bundled]
        )

        XCTAssertEqual(preferred?.source, .bundled)
    }

    func testPreferredAssetIDOverridesAutomaticOrderingWhenAssetExists() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .bundled
        )

        let preferred = GemmaModelAssetCatalog.preferredAsset(
            importedAssets: [imported],
            bundledAssets: [bundled],
            preferredAssetID: bundled.assetID
        )

        XCTAssertEqual(preferred?.assetID, bundled.assetID)
        XCTAssertEqual(preferred?.source, .bundled)
    }

    func testAssetIDDifferentiatesImportedAndBundledAssetsWithSameFileName() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584,
            source: .bundled
        )

        XCTAssertNotEqual(imported.assetID, bundled.assetID)
        XCTAssertEqual(imported.assetID, "imported:gemma-4-E4B-it.litertlm")
        XCTAssertEqual(bundled.assetID, "bundled:gemma-4-E4B-it.litertlm")
    }

    func testImportModelCopiesAssetIntoImportedLibrary() throws {
        let sourceDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let sourceURL = temporaryFileURL(
            in: sourceDirectory,
            name: "gemma-4-E4B-it.litertlm",
            size: 3_654_467_584
        )

        let imported = try GemmaModelAssetCatalog.importModel(
            from: sourceURL,
            baseDirectoryURL: libraryDirectory
        )

        XCTAssertEqual(imported.source, .imported)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path))
        XCTAssertTrue(imported.fileURL.path.contains("GemmaModels"))
    }

    func testRemoveImportedModelDeletesImportedAsset() throws {
        let sourceDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let sourceURL = temporaryFileURL(
            in: sourceDirectory,
            name: "gemma-4-E4B-it.litertlm",
            size: 3_654_467_584
        )

        let imported = try GemmaModelAssetCatalog.importModel(
            from: sourceURL,
            baseDirectoryURL: libraryDirectory
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path))

        try GemmaModelAssetCatalog.removeImportedModel(
            named: imported.fileName,
            baseDirectoryURL: libraryDirectory
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.fileURL.path))
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
