import Foundation

struct GemmaModelAsset: Equatable, Sendable {
    let fileName: String
    let fileSizeBytes: Int64

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

enum GemmaModelAssetCatalog {
    static let modelSubdirectory = "Models"
    private static let supportedExtensions = ["litertlm"]

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
                fileSizeBytes: fileSize
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
