import XCTest
@testable import Before

final class GemmaRuntimeLibraryCatalogTests: XCTestCase {
    func testCatalogFindsFrameworkBinaryAndDylibCandidates() throws {
        let root = temporaryDirectoryURL()
        let frameworks = root.appendingPathComponent("Frameworks", isDirectory: true)
        let models = root.appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: frameworks, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)

        let framework = frameworks.appendingPathComponent("LiteRTLM.framework", isDirectory: true)
        try FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: framework.appendingPathComponent("LiteRTLM").path,
            contents: Data()
        )
        FileManager.default.createFile(
            atPath: models.appendingPathComponent("libgemma_runtime.dylib").path,
            contents: Data()
        )

        let assets = GemmaRuntimeLibraryCatalog.assets(from: [frameworks, models])

        XCTAssertEqual(
            assets.map(\.fileName),
            ["libgemma_runtime.dylib", "LiteRTLM"]
        )
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
}
