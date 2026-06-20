// MARK: - BASProbeCommon — shared probe utilities (Tier-B consolidation of the duplicated per-probe FileLog)
//
// The DeviceTestApp accumulated ~13 copy-pasted private `FileLog` classes across its probes, each writing a
// timestamped `<prefix>-<stamp>.log` into the app's Documents dir (pullable via devicectl) plus an os_log line,
// with minor per-probe variation (some also `print` to stdout, a few `fflush(stdout)` for crash-survival).
//
// `ProbeFileLog` is the faithful SUPERSET of those variants, behind flags, so a probe can migrate to it with
// IDENTICAL observable behavior:
//   • `ProbeFileLog(filePrefix:category:)`                      → os_log + stdout print + Documents file (the common case)
//   • `ProbeFileLog(filePrefix:category:alsoPrint:false)`       → os_log + file only (matches the FileHandle-only variants)
//   • `ProbeFileLog(filePrefix:category:alsoFlush:true)`        → adds fflush(stdout) (matches the crash-survival variants)
//
// This file is ADDITIVE: it introduces the shared type but migrates no probe. Each probe is migrated in its own
// commit (Tier B2…), replacing its local FileLog with this one while preserving its exact flags.

import Foundation
import os

/// Thread-safe probe logger: a timestamped Documents log file + an os_log line, optionally also stdout.
/// `@unchecked Sendable` mirrors the per-probe FileLog classes (an `NSLock` guards the file handle).
final class ProbeFileLog: @unchecked Sendable {
    private let handle: FileHandle?
    private let lock = NSLock()
    private let logger: Logger
    private let alsoPrint: Bool
    private let alsoFlush: Bool

    /// - Parameters:
    ///   - filePrefix: the Documents log filename prefix (file becomes `<filePrefix>-<yyyyMMdd-HHmmss>.log`).
    ///   - category: the os_log category (subsystem is always `com.bas.devicetest`).
    ///   - alsoPrint: also `print(line)` to stdout (default true — matches the majority variant).
    ///   - alsoFlush: also `fflush(stdout)` after each line (default false — set true for crash-survival probes).
    init(filePrefix: String, category: String, alsoPrint: Bool = true, alsoFlush: Bool = false) {
        self.logger = Logger(subsystem: "com.bas.devicetest", category: category)
        self.alsoPrint = alsoPrint
        self.alsoFlush = alsoFlush
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        let stamp = f.string(from: Date())
        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            handle = nil
            return
        }
        let url = docs.appendingPathComponent("\(filePrefix)-\(stamp).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
    }

    func emit(_ line: String) {
        logger.info("\(line, privacy: .public)")
        if alsoPrint { print(line) }
        if alsoFlush { fflush(stdout) }
        guard let data = (line + "\n").data(using: .utf8) else { return }
        lock.lock()
        defer { lock.unlock() }
        try? handle?.write(contentsOf: data)
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        try? handle?.close()
    }
}
