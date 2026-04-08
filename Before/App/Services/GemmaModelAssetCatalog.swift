import Foundation

struct GemmaModelAsset: Equatable, Sendable {
    let fileName: String
    let fileSizeBytes: Int64
    let expectedSizeBytes: Int64?

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
}

enum GemmaModelAssetCatalog {
    static let modelSubdirectory = "Models"
    private static let supportedExtensions = ["litertlm"]
    private static let expectedFileSizesByName: [String: Int64] = [
        "gemma-4-E4B-it.litertlm": 3_654_467_584
    ]

    static func bundledAssets(in bundle: Bundle = .main) -> [GemmaModelAsset] {
        assets(from: resourceURLs(in: bundle))
    }

    static func preferredAsset(in bundle: Bundle = .main) -> GemmaModelAsset? {
        bundledAssets(in: bundle).first
    }

    static func assets(from urls: [URL]) -> [GemmaModelAsset] {
        urls.compactMap { url in
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resourceValues?.fileSize ?? 0)
            return GemmaModelAsset(
                fileName: url.lastPathComponent,
                fileSizeBytes: fileSize,
                expectedSizeBytes: expectedFileSizesByName[url.lastPathComponent]
            )
        }
        .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    private static func resourceURLs(in bundle: Bundle) -> [URL] {
        supportedExtensions.flatMap { fileExtension in
            bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: modelSubdirectory) ?? []
        }
    }
}
