#if os(macOS)
import Foundation

enum BASJournalCLIBinaryLocator {
    static func binaryURL(testBundleURL: URL, workingDirectory: URL) -> URL? {
        let sibling = testBundleURL.deletingLastPathComponent()
            .appendingPathComponent("BASJournalCLI")
        let legacy = [
            ".build/debug/BASJournalCLI",
            ".build/release/BASJournalCLI",
            ".build/arm64-apple-macosx/debug/BASJournalCLI",
            ".build/x86_64-apple-macosx/debug/BASJournalCLI",
        ].map { workingDirectory.appendingPathComponent($0) }

        return ([sibling] + legacy).first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
                && FileManager.default.isExecutableFile(atPath: url.path)
        }
    }
}
#endif
