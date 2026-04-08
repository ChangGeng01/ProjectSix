import Foundation

struct GemmaRuntimeLibraryAsset: Equatable, Sendable {
    let fileName: String
    let path: String
}

enum GemmaRuntimeLibraryCatalog {
    private static let candidateKeywords = ["litert", "gemma", "lm"]

    static func bundledLibraries(in bundle: Bundle = .main) -> [GemmaRuntimeLibraryAsset] {
        assets(from: rootURLs(in: bundle))
    }

    static func preferredLibrary(in bundle: Bundle = .main) -> GemmaRuntimeLibraryAsset? {
        bundledLibraries(in: bundle).first
    }

    static func assets(from roots: [URL]) -> [GemmaRuntimeLibraryAsset] {
        roots.flatMap { root in
            libraries(in: root)
        }
        .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    private static func rootURLs(in bundle: Bundle) -> [URL] {
        [
            bundle.privateFrameworksURL,
            bundle.bundleURL.appendingPathComponent("Frameworks", isDirectory: true),
            bundle.resourceURL?.appendingPathComponent("Models", isDirectory: true)
        ]
        .compactMap { $0 }
    }

    private static func libraries(in root: URL) -> [GemmaRuntimeLibraryAsset] {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            let lowercasedName = url.lastPathComponent.lowercased()
            guard candidateKeywords.contains(where: lowercasedName.contains) else {
                return nil
            }

            if url.pathExtension == "framework" {
                let binaryURL = url.appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                guard fileManager.fileExists(atPath: binaryURL.path) else { return nil }
                return GemmaRuntimeLibraryAsset(
                    fileName: binaryURL.lastPathComponent,
                    path: binaryURL.path
                )
            }

            if url.pathExtension == "dylib" {
                return GemmaRuntimeLibraryAsset(
                    fileName: url.lastPathComponent,
                    path: url.path
                )
            }

            return nil
        }
    }
}
