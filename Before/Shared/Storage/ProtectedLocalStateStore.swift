import Foundation
import OSLog

enum ProtectedLocalStateStore {
    private static let directoryName = "ProtectedRuntimeState"
    private static let logger = Logger(subsystem: "Before", category: "ProtectedLocalStateStore")

    static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard
            let fileURL = try? fileURL(for: key),
            let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<Value: Encodable>(_ value: Value, key: String) {
        guard
            let fileURL = try? fileURL(for: key),
            let data = try? JSONEncoder().encode(value)
        else {
            return
        }

        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            logger.error("Failed to save protected local state: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func clear(key: String) {
        guard let fileURL = try? fileURL(for: key) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            logger.error("Failed to clear protected local state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory
            .appendingPathComponent("Before", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: directory.path
            )
        }

        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }
}
