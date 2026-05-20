import Foundation
import OSLog

enum SharedPublicStateStore {
    private static let directoryName = "SharedRuntimeState"
    private static let fallbackDirectoryName = "SharedRuntimeStateFallback"
    private static let quarantineDirectoryName = "SharedRuntimeStateQuarantine"
    private static let logger = Logger(subsystem: "Before", category: "SharedPublicStateStore")

    static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared public state for \(key)")
            return nil
        }
        guard let data = loadData(from: targetURL, key: key) else { return nil }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            quarantineCorruptedFile(
                at: targetURL,
                key: key,
                operation: "decoding shared public state",
                underlyingError: error
            )
            return nil
        }
    }

    static func loadData(key: String) -> Data? {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared public state for \(key)")
            return nil
        }
        return loadData(from: targetURL, key: key)
    }

    @discardableResult
    static func save<Value: Encodable>(_ value: Value, key: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            return saveData(data, key: key)
        } catch {
            recordStorageIssue(error, operation: "encoding shared public state for \(key)")
            return false
        }
    }

    @discardableResult
    static func saveData(_ data: Data, key: String) -> Bool {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared public state for \(key)")
            return false
        }

        do {
            try data.write(to: targetURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: targetURL.path
            )
            return true
        } catch {
            recordStorageIssue(error, operation: "saving shared public state for \(key)")
            logger.error("Failed to save shared public state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func clear(key: String) {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared public state for \(key)")
            return
        }
        do {
            try FileManager.default.removeItem(at: targetURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            recordStorageIssue(error, operation: "clearing shared public state for \(key)")
            logger.error("Failed to clear shared public state: \(error.localizedDescription, privacy: .public)")
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
        let fileURL: URL
        do {
            fileURL = try quarantineFileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared public quarantine for \(key)")
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            recordStorageIssue(error, operation: "clearing shared public quarantine for \(key)")
            logger.error("Failed to clear shared public quarantine: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        let baseDirectory = try baseDirectoryURL()

        let directory = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )

        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }

    private static func quarantineFileURL(for key: String) throws -> URL {
        let baseDirectory = try baseDirectoryURL()

        let directory = baseDirectory.appendingPathComponent(quarantineDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )

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
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fallbackDirectory.path
        )

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
                operation: "reading shared public state",
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
            domain: "Before.SharedPublicStateStore",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Corrupted shared public state was isolated for \(key)."
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
            logger.error("Failed to quarantine shared public state: \(error.localizedDescription, privacy: .public)")
        }

        logger.error(
            "Quarantined shared public state for key \(key, privacy: .public): \(underlyingError.localizedDescription, privacy: .public)"
        )
    }

    private static func recordStorageIssue(_ error: Error, operation: String) {
        _ = StateStorageIssueRecorder.record(error: error, operation: operation)
        logger.error("Shared public state issue while \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}
