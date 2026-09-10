import Foundation
import OSLog

enum SharedProtectedStateStore {
    private static let directoryName = "ProtectedSharedRuntimeState"
    private static let fallbackDirectoryName = "ProtectedSharedRuntimeStateFallback"
    private static let quarantineDirectoryName = "ProtectedSharedRuntimeStateQuarantine"
    private static let logger = Logger(subsystem: "Before", category: "SharedProtectedStateStore")

    private enum StorageKind {
        case primary
        case quarantine
    }

    private struct StorageContext {
        let baseDirectory: URL
        let protection: FileProtectionType
    }

    static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared protected state for \(key)")
            return nil
        }

        guard let data = loadData(from: targetURL, key: key) else { return nil }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            quarantineCorruptedFile(
                at: targetURL,
                key: key,
                operation: "decoding shared protected state",
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
            recordStorageIssue(error, operation: "preparing shared protected state for \(key)")
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
            recordStorageIssue(error, operation: "encoding shared protected state for \(key)")
            return false
        }
    }

    @discardableResult
    static func saveData(_ data: Data, key: String) -> Bool {
        let targetURL: URL
        let context: StorageContext
        do {
            context = try storageContext()
            targetURL = try fileURL(for: key, storageContext: context)
        } catch {
            recordStorageIssue(error, operation: "preparing shared protected state for \(key)")
            return false
        }

        do {
            try data.write(to: targetURL, options: writeOptions(for: context.protection))
            try FileManager.default.setAttributes(
                [.protectionKey: context.protection],
                ofItemAtPath: targetURL.path
            )
            return true
        } catch {
            recordStorageIssue(error, operation: "saving shared protected state for \(key)")
            logger.error("Failed to save shared protected state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func clear(key: String) {
        let targetURL: URL
        do {
            targetURL = try fileURL(for: key)
        } catch {
            recordStorageIssue(error, operation: "preparing shared protected state for \(key)")
            return
        }

        do {
            try FileManager.default.removeItem(at: targetURL)
        } catch {
            guard (error as NSError).code != NSFileNoSuchFileError else { return }
            recordStorageIssue(error, operation: "clearing shared protected state for \(key)")
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
            recordStorageIssue(error, operation: "clearing shared protected quarantine for \(key)")
            logger.error("Failed to clear shared protected quarantine: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func storedKeys(withPrefix prefix: String) -> [String] {
        do {
            let context = try storageContext()
            let directory = try directoryURL(for: .primary, storageContext: context)
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            return urls
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .filter { $0.hasPrefix(prefix) }
        } catch {
            recordStorageIssue(error, operation: "enumerating shared protected state keys for \(prefix)")
            return []
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
            let context = try storageContext()
            let destination = try quarantineFileURL(for: key, storageContext: context)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try data.write(to: destination, options: writeOptions(for: context.protection))
            try FileManager.default.setAttributes(
                [.protectionKey: context.protection],
                ofItemAtPath: destination.path
            )
        } catch {
            logger.error("Failed to quarantine shared protected payload: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        let context = try storageContext()
        return try fileURL(for: key, storageContext: context)
    }

    private static func fileURL(for key: String, storageContext: StorageContext) throws -> URL {
        let directory = try directoryURL(for: .primary, storageContext: storageContext)
        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }

    private static func quarantineFileURL(for key: String) throws -> URL {
        let context = try storageContext()
        return try quarantineFileURL(for: key, storageContext: context)
    }

    private static func quarantineFileURL(for key: String, storageContext: StorageContext) throws -> URL {
        let directory = try directoryURL(for: .quarantine, storageContext: storageContext)
        return directory.appendingPathComponent("\(key).json", isDirectory: false)
    }

    private static func storageContext() throws -> StorageContext {
        if let containerURL = SharedContainer.containerURL {
            return StorageContext(
                baseDirectory: containerURL,
                protection: .completeUntilFirstUserAuthentication
            )
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

        return StorageContext(
            baseDirectory: fallbackDirectory,
            protection: .complete
        )
    }

    private static func directoryURL(
        for kind: StorageKind,
        storageContext: StorageContext
    ) throws -> URL {
        let targetName: String
        switch kind {
        case .primary:
            targetName = directoryName
        case .quarantine:
            targetName = quarantineDirectoryName
        }

        let directory = storageContext.baseDirectory.appendingPathComponent(targetName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.protectionKey: storageContext.protection],
            ofItemAtPath: directory.path
        )
        return directory
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
            let context = try storageContext()
            let destination = try quarantineFileURL(for: key, storageContext: context)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: fileURL, to: destination)
            try FileManager.default.setAttributes(
                [.protectionKey: context.protection],
                ofItemAtPath: destination.path
            )
        } catch {
            logger.error("Failed to quarantine shared protected state: \(error.localizedDescription, privacy: .public)")
        }

        logger.error(
            "Quarantined shared protected state for key \(key, privacy: .public): \(underlyingError.localizedDescription, privacy: .public)"
        )
    }

    private static func recordStorageIssue(_ error: Error, operation: String) {
        _ = StateStorageIssueRecorder.record(error: error, operation: operation)
        logger.error("Shared protected state issue while \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    private static func writeOptions(for protection: FileProtectionType) -> Data.WritingOptions {
        switch protection {
        case .complete:
            [.atomic, .completeFileProtection]
        default:
            [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        }
    }
}
