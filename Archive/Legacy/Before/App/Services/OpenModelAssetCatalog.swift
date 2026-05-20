import Foundation

enum OpenModelAssetSource: String, Equatable, Sendable {
    case imported

    var title: String {
        switch self {
        case .imported: "Imported"
        }
    }
}

struct OpenModelAsset: Equatable, Sendable {
    let fileName: String
    let fileSizeBytes: Int64
    let source: OpenModelAssetSource
    let fileURL: URL

    init(
        fileName: String,
        fileSizeBytes: Int64,
        source: OpenModelAssetSource = .imported,
        fileURL: URL? = nil
    ) {
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.source = source
        self.fileURL = fileURL ?? URL(fileURLWithPath: fileName)
    }

    var assetID: String {
        "\(source.rawValue):\(fileName)"
    }

    var sourceTitle: String {
        source.title
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var isImported: Bool {
        source == .imported
    }

    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }

    var displayTitle: String {
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let withSpaces = stem.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return withSpaces
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var generatedStableID: String {
        let stem = fileURL.deletingPathExtension().lastPathComponent.lowercased()
        let slug = stem.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        let cleaned = String(slug)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "local/open-model/\(cleaned.isEmpty ? "runtime" : cleaned)"
    }
}

enum OpenModelAssetCatalogError: LocalizedError {
    case unsupportedFileExtension(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFileExtension(extensionName):
            "Before only accepts open-model files ending in .\(extensionName) for this local runtime slot."
        }
    }
}

enum OpenModelAssetCatalog {
    static let importedModelDirectoryName = "OpenModels"
    static let supportedExtensions = ["gguf", "onnx", "safetensors", "litertlm", "bin"]

    static func importedAssets(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) -> [OpenModelAsset] {
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
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        preferredAssetID: String? = nil
    ) -> OpenModelAsset? {
        preferredAsset(
            importedAssets: importedAssets(
                fileManager: fileManager,
                baseDirectoryURL: baseDirectoryURL
            ),
            preferredAssetID: preferredAssetID
        )
    }

    static func preferredAsset(
        importedAssets: [OpenModelAsset],
        preferredAssetID: String? = nil
    ) -> OpenModelAsset? {
        if let preferredAssetID,
           let preferredAsset = importedAssets.first(where: { $0.assetID == preferredAssetID }) {
            return preferredAsset
        }
        return importedAssets.sorted {
            $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
        }.first
    }

    static func assets(
        from urls: [URL],
        source: OpenModelAssetSource = .imported
    ) -> [OpenModelAsset] {
        urls.compactMap { url in
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues?.fileSize ?? 0)
            return OpenModelAsset(
                fileName: url.lastPathComponent,
                fileSizeBytes: fileSize,
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
    ) throws -> OpenModelAsset {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw OpenModelAssetCatalogError.unsupportedFileExtension(fileExtension.isEmpty ? "gguf" : fileExtension)
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
}
