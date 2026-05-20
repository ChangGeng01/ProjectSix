import Foundation

struct GemmaModelRemoteFetchResult: Sendable {
    let temporaryFileURL: URL
    let suggestedFilename: String?
    let statusCode: Int?
}

typealias GemmaModelRemoteFetcher = @Sendable (URL) async throws -> GemmaModelRemoteFetchResult

enum GemmaModelDownloadServiceError: LocalizedError {
    case unsupportedURLScheme(String)
    case unsuccessfulHTTPStatus(Int)
    case missingFilename
    case emptyDownload

    var errorDescription: String? {
        switch self {
        case let .unsupportedURLScheme(scheme):
            "Before can only download Gemma files from http or https URLs, not \(scheme)."
        case let .unsuccessfulHTTPStatus(statusCode):
            "Before couldn't download the Gemma model because the server returned HTTP \(statusCode)."
        case .missingFilename:
            "Before couldn't determine a filename for the downloaded Gemma model."
        case .emptyDownload:
            "The downloaded Gemma file was empty, so Before didn't import it."
        }
    }
}

enum GemmaModelDownloadService {
    static func downloadModel(
        from remoteURL: URL,
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        workingDirectoryURL: URL? = nil,
        fetcher: GemmaModelRemoteFetcher = liveRemoteFetcher
    ) async throws -> GemmaModelAsset {
        let validatedURL = try validatedRemoteURL(remoteURL)
        let fetched = try await fetcher(validatedURL)

        if let statusCode = fetched.statusCode,
           !(200 ... 299).contains(statusCode) {
            throw GemmaModelDownloadServiceError.unsuccessfulHTTPStatus(statusCode)
        }

        let filename = resolvedFilename(
            suggestedFilename: fetched.suggestedFilename,
            remoteURL: validatedURL
        )
        guard !filename.isEmpty else {
            throw GemmaModelDownloadServiceError.missingFilename
        }

        let stagingDirectory = try workingDirectoryURL ?? temporaryWorkingDirectory(fileManager: fileManager)
        if !fileManager.fileExists(atPath: stagingDirectory.path) {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        }

        let requestDirectory = stagingDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: requestDirectory.path) {
            try fileManager.createDirectory(at: requestDirectory, withIntermediateDirectories: true)
        }
        let stagedURL = requestDirectory.appendingPathComponent(filename, isDirectory: false)
        try fileManager.copyItem(at: fetched.temporaryFileURL, to: stagedURL)

        defer {
            try? fileManager.removeItem(at: requestDirectory)
        }

        let fileSize = (try? stagedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fileSize > 0 else {
            throw GemmaModelDownloadServiceError.emptyDownload
        }

        return try GemmaModelAssetCatalog.importModel(
            from: stagedURL,
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    static func validatedRemoteURL(_ remoteURL: URL) throws -> URL {
        let scheme = remoteURL.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            throw GemmaModelDownloadServiceError.unsupportedURLScheme(scheme.isEmpty ? "unknown" : scheme)
        }
        return remoteURL
    }

    static func liveRemoteFetcher(_ remoteURL: URL) async throws -> GemmaModelRemoteFetchResult {
        let (temporaryFileURL, response) = try await URLSession.shared.download(from: remoteURL)
        let httpResponse = response as? HTTPURLResponse
        return GemmaModelRemoteFetchResult(
            temporaryFileURL: temporaryFileURL,
            suggestedFilename: response.suggestedFilename,
            statusCode: httpResponse?.statusCode
        )
    }

    private static func resolvedFilename(
        suggestedFilename: String?,
        remoteURL: URL
    ) -> String {
        if let suggestedFilename,
           !suggestedFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return suggestedFilename
        }
        return remoteURL.lastPathComponent
    }

    private static func temporaryWorkingDirectory(fileManager: FileManager) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("BeforeGemmaDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
