import Foundation
import OSLog

enum SharedProtectedStateStore {
    private static let directoryName = "ProtectedSharedRuntimeState"
    private static let fallbackDirectoryName = "ProtectedSharedRuntimeStateFallback"
    private static let quarantineDirectoryName = "ProtectedSharedRuntimeStateQuarantine"
    private static let logger = Logger(subsystem: "Before", category: "SharedProtectedStateStore")

    static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let fileURL = try? fileURL(for: key) else { return nil }
        guard let data = loadData(from: fileURL, key: key) else { return nil }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            quarantineCorruptedFile(
                at: fileURL,
                key: key,
                operation: "decoding shared protected state",
                underlyingError: error
            )
            return nil
        }
    }

    static func loadData(key: String) -> Data? {
        guard let fileURL = try? fileURL(for: key) else { return nil }
        return loadData(from: fileURL, key: key)
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

    static func quarantinedData(key: String) -> Data? {
        guard
            let fileURL = try? quarantineFileURL(for: key),
            let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        return data
    }

    static func clearQuarantine(key: String) {
        guard let fileURL = try? quarantineFileURL(for: key) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            logger.error("Failed to clear shared protected quarantine: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func quarantineData(_ data: Data, key: String, operation: String, reason: String) {
        let noticeError = NSError(
            domain: "Before.SharedProtectedStateStore",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: reason]
        )
        _ = StateStorageIssueRecorder.record(error: noticeError, operation: operation)

        do {
            let destination = try quarantineFileURL(for: key)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: destination.path
            )
        } catch {
            logger.error("Failed to quarantine shared protected payload: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        let baseDirectory = try baseDirectoryURL()

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

    private static func quarantineFileURL(for key: String) throws -> URL {
        let baseDirectory = try baseDirectoryURL()

        let directory = baseDirectory.appendingPathComponent(quarantineDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
        }

        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }

    private static func baseDirectoryURL() throws -> URL {
        if let containerURL = SharedContainer.containerURL {
            return containerURL
        }

        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let fallbackDirectory = applicationSupport
            .appendingPathComponent("Before", isDirectory: true)
            .appendingPathComponent(fallbackDirectoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: fallbackDirectory.path) {
            try FileManager.default.createDirectory(
                at: fallbackDirectory,
                withIntermediateDirectories: true
            )
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fallbackDirectory.path
            )
        }

        return fallbackDirectory
    }

    private static func loadData(from fileURL: URL, key: String) -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            quarantineCorruptedFile(
                at: fileURL,
                key: key,
                operation: "reading shared protected state",
                underlyingError: error
            )
            return nil
        }
    }

    private static func quarantineCorruptedFile(
        at fileURL: URL,
        key: String,
        operation: String,
        underlyingError: Error
    ) {
        let noticeError = NSError(
            domain: "Before.SharedProtectedStateStore",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Corrupted shared protected state was isolated for \(key)."
            ]
        )
        _ = StateStorageIssueRecorder.record(error: noticeError, operation: operation)

        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let destination = try quarantineFileURL(for: key)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: fileURL, to: destination)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: destination.path
            )
        } catch {
            logger.error("Failed to quarantine shared protected state: \(error.localizedDescription, privacy: .public)")
        }

        logger.error(
            "Quarantined shared protected state for key \(key, privacy: .public): \(underlyingError.localizedDescription, privacy: .public)"
        )
    }
}
