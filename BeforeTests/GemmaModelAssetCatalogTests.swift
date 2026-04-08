import XCTest
@testable import Before

final class GemmaModelAssetCatalogTests: XCTestCase {
    func testAssetsAreSortedAndExposeHumanReadableSize() {
        let urls = [
            temporaryFileURL(name: "gemma-4-E4B-it-int4.litertlm", size: 2_680_000_000),
            temporaryFileURL(name: "gemma-4-E2B-it-int4.litertlm", size: 1_340_000_000)
        ]

        let assets = GemmaModelAssetCatalog.assets(from: urls)

        XCTAssertTrue(assets[0].fileName.hasSuffix("gemma-4-E2B-it-int4.litertlm"))
        XCTAssertTrue(assets[1].fileName.hasSuffix("gemma-4-E4B-it-int4.litertlm"))
        XCTAssertFalse(assets[0].displaySize.isEmpty)
    }

    private func temporaryFileURL(name: String, size: Int) -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: UInt64(size))
            try? handle.close()
        }
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
