import Foundation

struct OpenModelRemoteFetchResult: Sendable {
    let temporaryFileURL: URL
    let suggestedFilename: String?
    let statusCode: Int?
}

typealias OpenModelRemoteFetcher = @Sendable (URL) async throws -> OpenModelRemoteFetchResult

enum OpenModelDownloadServiceError: LocalizedError {
    case unsupportedURLScheme(String)
    case unsuccessfulHTTPStatus(Int)
    case missingFilename
    case emptyDownload

    var errorDescription: String? {
        switch self {
        case let .unsupportedURLScheme(scheme):
            "Before can only download open-model files from http or https URLs, not \(scheme)."
        case let .unsuccessfulHTTPStatus(statusCode):
            "Before couldn't download the open-model file because the server returned HTTP \(statusCode)."
        case .missingFilename:
            "Before couldn't determine a filename for the downloaded open-model file."
        case .emptyDownload:
            "The downloaded open-model file was empty, so Before didn't import it."
        }
    }
}

enum OpenModelDownloadService {
    static func downloadModel(
        from remoteURL: URL,
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        workingDirectoryURL: URL? = nil,
        fetcher: OpenModelRemoteFetcher = liveRemoteFetcher
    ) async throws -> OpenModelAsset {
        let validatedURL = try validatedRemoteURL(remoteURL)
        let fetched = try await fetcher(validatedURL)

        if let statusCode = fetched.statusCode,
           !(200 ... 299).contains(statusCode) {
            throw OpenModelDownloadServiceError.unsuccessfulHTTPStatus(statusCode)
        }

        let filename = resolvedFilename(
            suggestedFilename: fetched.suggestedFilename,
            remoteURL: validatedURL
        )
        guard !filename.isEmpty else {
            throw OpenModelDownloadServiceError.missingFilename
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
            throw OpenModelDownloadServiceError.emptyDownload
        }

        return try OpenModelAssetCatalog.importModel(
            from: stagedURL,
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    static func validatedRemoteURL(_ remoteURL: URL) throws -> URL {
        let scheme = remoteURL.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            throw OpenModelDownloadServiceError.unsupportedURLScheme(scheme.isEmpty ? "unknown" : scheme)
        }
        return remoteURL
    }

    static func liveRemoteFetcher(_ remoteURL: URL) async throws -> OpenModelRemoteFetchResult {
        let (temporaryFileURL, response) = try await URLSession.shared.download(from: remoteURL)
        let httpResponse = response as? HTTPURLResponse
        return OpenModelRemoteFetchResult(
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
            .appendingPathComponent("BeforeOpenModelDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
