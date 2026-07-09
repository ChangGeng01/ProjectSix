import Foundation

/// audit x-sov #5 / #6 (Data Protection, 2026-07-09).
///
/// The session-KV snapshot got file Data Protection ("缝2",
/// MLXOrganAdapter+SessionPersist), but the MEMORY-ATOM SQLite DB — the
/// HIGHEST-sensitivity on-disk point (its `payload_json` holds the full
/// `BASGovernedMemory` including a `sensitivity` column) — had NONE: a
/// same-repo double standard. On iOS it relied on the container default; on
/// macOS hosts there was no file-level protection at all.
///
/// This pins `FileProtectionType.completeUntilFirstUserAuthentication` (the
/// class SessionPersist already uses: readable after first unlock so
/// background restores keep working, sealed in the pre-first-unlock window) on
/// a DB file AND its `-wal` / `-shm` sidecars. On iOS the kernel enforces
/// at-rest encryption; on macOS the attribute is stored but inert (macOS uses
/// FileVault, not per-file protection) — applied on BOTH so the code path is
/// unit-testable and the same-repo standard is uniform.
///
/// ADR-014: DEFAULT-ON, kill-switch `BAS_FILE_PROTECTION=0`. x-sov #6 — the
/// error is RETURNED (surfaced to the caller's diagnostic channel), never
/// `try?`-swallowed.
public enum BASSQLiteFileProtection {

    /// Default-on; only the explicit string "0" disables it.
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_FILE_PROTECTION"] != "0"
    }

    /// Apply the protection class to `path` and its `-wal` / `-shm` sidecars
    /// (each only if it exists on disk). Returns the FIRST error encountered
    /// (the caller surfaces it), or nil on success / kill-switch off.
    @discardableResult
    public static func apply(toDatabaseAt path: String) -> Error? {
        guard isEnabled else { return nil }
        #if os(iOS) || os(macOS)
        let attrs: [FileAttributeKey: Any] =
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        for p in [path, path + "-wal", path + "-shm"] {
            guard FileManager.default.fileExists(atPath: p) else { continue }
            do {
                try FileManager.default.setAttributes(attrs, ofItemAtPath: p)
            } catch {
                return error
            }
        }
        #endif
        return nil
    }
}
