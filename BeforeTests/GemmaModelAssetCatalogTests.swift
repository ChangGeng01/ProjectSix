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
