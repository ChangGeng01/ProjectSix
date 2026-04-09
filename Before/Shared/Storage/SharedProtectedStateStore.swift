import Foundation
import OSLog

enum SharedProtectedStateStore {
    private static let directoryName = "ProtectedSharedRuntimeState"
    private static let logger = Logger(subsystem: "Before", category: "SharedProtectedStateStore")

    static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard
            let data = loadData(key: key),
            let value = try? JSONDecoder().decode(type, from: data)
        else {
            return nil
        }

        return value
    }

    static func loadData(key: String) -> Data? {
        guard
            let fileURL = try? fileURL(for: key),
            let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        return data
    }

    static func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        saveData(data, key: key)
    }

    static func saveData(_ data: Data, key: String) {
        guard let fileURL = try? fileURL(for: key) else { return }

        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            logger.error("Failed to save shared protected state: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func clear(key: String) {
        guard let fileURL = try? fileURL(for: key) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            logger.error("Failed to clear shared protected state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        guard let baseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainer.appGroupID
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
        }

        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }
}
