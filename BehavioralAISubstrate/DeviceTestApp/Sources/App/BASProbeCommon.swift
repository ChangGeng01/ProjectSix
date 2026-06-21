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

// MARK: - BASModelPurgeProbe — surgical device cleanup of the 2026-06-22 decode-TEST models (BAS_PURGE_TEST_MODELS=1)
//
// devicectl has NO per-file delete, so clearing the staged test models needs an in-app FileManager pass. SAFETY:
// a HARDCODED allowlist (`deletable`) — only those exact subdirs under Documents/models are removed, plus loose
// root-orphan FILES (the first-mxfp4 mis-stage); ALL other subdirs (the pre-existing Llama-3.2-3B-Instruct-3bit +
// gemma-4-e4b-it-4bit) are NEVER touched. DRYRUN is the DEFAULT (lists what WOULD be deleted, deletes nothing);
// pass BAS_PURGE_DRYRUN=0 to actually delete. Everything removed is re-stageable via
// scripts/restage-decode-test-models.sh (STAGE=1), so this is fully reversible.
enum BASModelPurgeProbe {
    /// EXACT this-session test-model subdir names that are safe to delete (re-stageable). Nothing else is removed.
    static let deletable = [
        "Llama-3.2-3B-Instruct-mxfp4",
        "Llama-3.2-3B-Instruct-g128",
        "Granite-4.0-H-Micro-4bit",
        "Granite-4.0-H-Tiny-4bit-DWQ",
        "Llama-3.2-1B-Instruct-4bit",
    ]

    static func run() async {
        let log = ProbeFileLog(filePrefix: "model-purge", category: "model-purge", alsoPrint: true)
        defer { log.close() }
        let env = ProcessInfo.processInfo.environment
        let dryRun = (env["BAS_PURGE_DRYRUN"] ?? "1") != "0"     // DEFAULT dry — must opt OUT to delete
        let purgeOrphans = (env["BAS_PURGE_ROOT_ORPHANS"] ?? "1") != "0"
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            log.emit("📊 model-purge ERROR=no-documents-dir"); return
        }
        let models = docs.appendingPathComponent("models")
        log.emit("📊 model-purge START dryrun=\(dryRun) purgeOrphans=\(purgeOrphans) allowlist=\(deletable.count) models_dir=\(models.path)")
        var freed: Int64 = 0

        // 1) named test-model subdirs (allowlist only)
        for name in deletable {
            let url = models.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                log.emit("   skip (absent): \(name)"); continue
            }
            let sz = Self.dirSize(url, fm)
            freed += sz
            if dryRun { log.emit(String(format: "   [DRYRUN] would delete subdir %@ (%dMB)", name, sz / 1_000_000)); continue }
            do { try fm.removeItem(at: url); log.emit(String(format: "   deleted subdir %@ (%dMB)", name, sz / 1_000_000)) }
            catch { log.emit("   ERROR deleting \(name): \(error)"); freed -= sz }
        }

        // 2) loose ROOT-ORPHAN files directly under models/ (the mis-stage artifacts) — NEVER subdirs
        if purgeOrphans {
            let items = (try? fm.contentsOfDirectory(
                at: models, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])) ?? []
            for item in items {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? true
                if isDir { continue }   // keep EVERY subdir (incl. the pre-existing 3bit/gemma)
                let sz = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                freed += sz
                if dryRun { log.emit(String(format: "   [DRYRUN] would delete root-orphan %@ (%dMB)", item.lastPathComponent, sz / 1_000_000)); continue }
                do { try fm.removeItem(at: item); log.emit(String(format: "   deleted root-orphan %@ (%dMB)", item.lastPathComponent, sz / 1_000_000)) }
                catch { log.emit("   ERROR deleting orphan \(item.lastPathComponent): \(error)"); freed -= sz }
            }
        }

        let remaining = ((try? fm.contentsOfDirectory(atPath: models.path)) ?? []).sorted()
        log.emit(String(format: "📊 model-purge DONE%@ freed≈%dMB KEPT=[%@]",
            dryRun ? " (DRYRUN — nothing deleted)" : "", freed / 1_000_000, remaining.joined(separator: ", ")))
    }

    private static func dirSize(_ url: URL, _ fm: FileManager) -> Int64 {
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let f as URL in en {
                total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return total
    }
}
