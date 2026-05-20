import Foundation

enum GemmaModelAssetSource: String, Equatable, Sendable {
    case bundled
    case imported

    var title: String {
        switch self {
        case .bundled: "Bundled"
        case .imported: "Imported"
        }
    }
}

struct GemmaModelAsset: Equatable, Sendable {
    let fileName: String
    let fileSizeBytes: Int64
    let expectedSizeBytes: Int64?
    let source: GemmaModelAssetSource
    let fileURL: URL

    init(
        fileName: String,
        fileSizeBytes: Int64,
        expectedSizeBytes: Int64?,
        source: GemmaModelAssetSource = .bundled,
        fileURL: URL? = nil
    ) {
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.expectedSizeBytes = expectedSizeBytes
        self.source = source
        self.fileURL = fileURL ?? URL(fileURLWithPath: fileName)
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var expectedDisplaySize: String? {
        guard let expectedSizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: expectedSizeBytes, countStyle: .file)
    }

    var isComplete: Bool {
        guard let expectedSizeBytes else { return fileSizeBytes > 0 }
        return fileSizeBytes >= expectedSizeBytes
    }

    var progressDescription: String? {
        guard let expectedSizeBytes, expectedSizeBytes > 0, !isComplete else { return nil }
        let progress = Double(fileSizeBytes) / Double(expectedSizeBytes)
        return "\(Int(progress * 100))%"
    }

    var isImported: Bool {
        source == .imported
    }

    var assetID: String {
        "\(source.rawValue):\(fileName)"
    }

    var sourceTitle: String {
        source.title
    }

    var fileURLPath: String {
        fileURL.path
    }
}

enum GemmaModelAssetCatalogError: LocalizedError {
    case unsupportedFileExtension(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFileExtension(extensionName):
            "Before only accepts Gemma model files ending in .\(extensionName)."
        }
    }
}

enum GemmaModelAssetCatalog {
    static let modelSubdirectory = "Models"
    static let importedModelDirectoryName = "GemmaModels"
    static let supportedExtensions = ["litertlm"]
    private static let expectedFileSizesByName: [String: Int64] = [
        "gemma-4-E4B-it.litertlm": 3_654_467_584
    ]

    static func bundledAssets(in bundle: Bundle = .main) -> [GemmaModelAsset] {
        assets(from: resourceURLs(in: bundle), source: .bundled)
    }

    static func importedAssets(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) -> [GemmaModelAsset] {
        guard let directoryURL = try? importedDirectoryURL(
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL,
            createIfNeeded: false
        ) else {
            return []
        }
        let urls = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return assets(
            from: urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) },
            source: .imported
        )
    }

    static func preferredAsset(
        in bundle: Bundle = .main,
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        preferredAssetID: String? = nil
    ) -> GemmaModelAsset? {
        preferredAsset(
            importedAssets: importedAssets(fileManager: fileManager, baseDirectoryURL: baseDirectoryURL),
            bundledAssets: bundledAssets(in: bundle),
            preferredAssetID: preferredAssetID
        )
    }

    static func preferredAsset(
        importedAssets: [GemmaModelAsset],
        bundledAssets: [GemmaModelAsset],
        preferredAssetID: String? = nil
    ) -> GemmaModelAsset? {
        let allAssets = (importedAssets + bundledAssets)
        if let preferredAssetID,
           let explicitlyPreferred = allAssets.first(where: { $0.assetID == preferredAssetID }) {
            return explicitlyPreferred
        }
        return allAssets.sorted(by: preferredSort).first
    }

    static func assets(
        from urls: [URL],
        source: GemmaModelAssetSource = .bundled
    ) -> [GemmaModelAsset] {
        urls.compactMap { url in
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues?.fileSize ?? 0)
            return GemmaModelAsset(
                fileName: url.lastPathComponent,
                fileSizeBytes: fileSize,
                expectedSizeBytes: expectedFileSizesByName[url.lastPathComponent],
                source: source,
                fileURL: url
            )
        }
        .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    @discardableResult
    static func importModel(
        from sourceURL: URL,
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) throws -> GemmaModelAsset {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw GemmaModelAssetCatalogError.unsupportedFileExtension(fileExtension.isEmpty ? "litertlm" : fileExtension)
        }

        let destinationDirectory = try importedDirectoryURL(
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL,
            createIfNeeded: true
        )
        let destinationURL = destinationDirectory.appendingPathComponent(
            sourceURL.lastPathComponent,
            isDirectory: false
        )

        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            let temporaryURL = destinationDirectory.appendingPathComponent(
                ".\(UUID().uuidString).\(sourceURL.lastPathComponent)",
                isDirectory: false
            )
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }

        guard let asset = assets(from: [destinationURL], source: .imported).first else {
            throw CocoaError(.fileReadUnknown)
        }
        return asset
    }

    static func removeImportedModel(
        named fileName: String,
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) throws {
        let destinationDirectory = try importedDirectoryURL(
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL,
            createIfNeeded: false
        )
        let destinationURL = destinationDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: destinationURL.path) else { return }
        try fileManager.removeItem(at: destinationURL)
    }

    private static func resourceURLs(in bundle: Bundle) -> [URL] {
        supportedExtensions.flatMap { fileExtension in
            bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: modelSubdirectory) ?? []
        }
    }

    private static func importedDirectoryURL(
        fileManager: FileManager,
        baseDirectoryURL: URL?,
        createIfNeeded: Bool
    ) throws -> URL {
        let baseDirectory = try baseDirectoryURL ?? beforeStorageDirectory(fileManager: fileManager)
        let importedDirectory = baseDirectory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(importedModelDirectoryName, isDirectory: true)
        if createIfNeeded && !fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.createDirectory(
                at: importedDirectory,
                withIntermediateDirectories: true
            )
        }
        return importedDirectory
    }

    private static func beforeStorageDirectory(fileManager: FileManager) throws -> URL {
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let beforeDirectory = applicationSupportDirectory.appendingPathComponent("Before", isDirectory: true)
        if !fileManager.fileExists(atPath: beforeDirectory.path) {
            try fileManager.createDirectory(at: beforeDirectory, withIntermediateDirectories: true)
        }
        return beforeDirectory
    }

    private static func preferredSort(lhs: GemmaModelAsset, rhs: GemmaModelAsset) -> Bool {
        if lhs.isComplete != rhs.isComplete {
            return lhs.isComplete && !rhs.isComplete
        }
        if lhs.source != rhs.source {
            return lhs.source == .imported
        }
        return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
    }
}
