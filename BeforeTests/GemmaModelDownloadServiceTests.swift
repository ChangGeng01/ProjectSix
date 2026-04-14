import XCTest
@testable import Before

final class GemmaModelDownloadServiceTests: XCTestCase {
    func testDownloadModelImportsFetchedLitertlmAssetUsingSuggestedFilename() async throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/download"))
        let fetchDirectory = temporaryDirectoryURL()
        let libraryDirectory = temporaryDirectoryURL()
        let downloadedURL = temporaryFileURL(
            in: fetchDirectory,
            name: UUID().uuidString,
            size: 3_654_467_584
        )

        let asset = try await GemmaModelDownloadService.downloadModel(
            from: remoteURL,
            baseDirectoryURL: libraryDirectory,
            fetcher: { url in
                XCTAssertEqual(url, remoteURL)
                return GemmaModelRemoteFetchResult(
                    temporaryFileURL: downloadedURL,
                    suggestedFilename: "gemma-4-E4B-it.litertlm",
                    statusCode: 200
                )
            }
        )

        XCTAssertEqual(asset.source, .imported)
        XCTAssertEqual(asset.fileName, "gemma-4-E4B-it.litertlm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.fileURL.path))
    }

    func testDownloadModelRejectsUnsupportedURLScheme() async {
        let remoteURL = URL(fileURLWithPath: "/tmp/gemma-4-E4B-it.litertlm")

        do {
            _ = try await GemmaModelDownloadService.downloadModel(
                from: remoteURL,
                fetcher: { _ in
                    XCTFail("Fetcher should not be called for unsupported schemes.")
                    throw CancellationError()
                }
            )
            XCTFail("Expected an unsupported scheme error.")
        } catch let error as GemmaModelDownloadServiceError {
            XCTAssertEqual(error.errorDescription, "Before can only download Gemma files from http or https URLs, not file.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadModelRejectsUnsuccessfulHTTPStatus() async {
        let remoteURL = try! XCTUnwrap(URL(string: "https://example.com/gemma-4-E4B-it.litertlm"))
        let fetchDirectory = temporaryDirectoryURL()
        let downloadedURL = temporaryFileURL(
            in: fetchDirectory,
            name: "gemma-4-E4B-it.litertlm",
            size: 3_654_467_584
        )

        do {
            _ = try await GemmaModelDownloadService.downloadModel(
                from: remoteURL,
                fetcher: { _ in
                    GemmaModelRemoteFetchResult(
                        temporaryFileURL: downloadedURL,
                        suggestedFilename: "gemma-4-E4B-it.litertlm",
                        statusCode: 404
                    )
                }
            )
            XCTFail("Expected an HTTP status failure.")
        } catch let error as GemmaModelDownloadServiceError {
            XCTAssertEqual(error.errorDescription, "Before couldn't download the Gemma model because the server returned HTTP 404.")
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
