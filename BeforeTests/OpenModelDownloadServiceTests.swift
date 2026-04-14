import XCTest
@testable import Before

final class OpenModelDownloadServiceTests: XCTestCase {
    func testDownloadModelImportsFetchedAssetUsingSuggestedFilename() async throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/download"))
        let fetchDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let downloadedURL = temporaryFileURL(
            in: fetchDirectory,
            name: UUID().uuidString,
            size: 4_200
        )

        let asset = try await OpenModelDownloadService.downloadModel(
            from: remoteURL,
            baseDirectoryURL: libraryDirectory,
            fetcher: { url in
                XCTAssertEqual(url, remoteURL)
                return OpenModelRemoteFetchResult(
                    temporaryFileURL: downloadedURL,
                    suggestedFilename: "mistral-7b.gguf",
                    statusCode: 200
                )
            }
        )

        XCTAssertEqual(asset.source, .imported)
        XCTAssertEqual(asset.fileName, "mistral-7b.gguf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.fileURL.path))
    }

    func testDownloadModelRejectsUnsupportedURLScheme() async {
        let remoteURL = URL(fileURLWithPath: "/tmp/model.gguf")

        do {
            _ = try await OpenModelDownloadService.downloadModel(
                from: remoteURL,
                fetcher: { _ in
                    XCTFail("Fetcher should not be called for unsupported schemes.")
                    throw CancellationError()
                }
            )
            XCTFail("Expected an unsupported scheme error.")
        } catch let error as OpenModelDownloadServiceError {
            XCTAssertEqual(error.errorDescription, "Before can only download open-model files from http or https URLs, not file.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
