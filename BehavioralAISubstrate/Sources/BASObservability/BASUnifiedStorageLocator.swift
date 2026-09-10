import Foundation

/// M283 — canonical-path helper for the substrate's two SQLite
/// stores.
///
/// ## Why this exists
///
/// M91 added SQLite persistence for `BASSovereignAuditLedger`
/// (in BASSovereign). M270 added SQLite persistence for
/// `BASUpdateTicketLifecycleStorage` (in BASObservability).
/// Both use SQLite, but each picks its own file path. Hosts
/// deploying the substrate in production wanted a single
/// "root directory" they could point at and have the substrate
/// figure out per-store sub-paths consistently.
///
/// `BASUnifiedStorageLocator` is the deployment convention:
/// hand it a root URL, get back the canonical paths for the
/// two stores. No file merge happens — keeping the stores in
/// separate `.sqlite` files preserves M91's chain-integrity
/// boundary (the audit ledger's hash chain is independent of
/// any other table) and lets each store evolve its schema
/// without coupling.
///
/// ## Layout
///
/// Given root URL `<root>/`:
///
/// ```
/// <root>/sovereign-audit.sqlite       — M91 audit ledger
/// <root>/sovereign-audit.sqlite-wal   — WAL sidecar (M274 mode)
/// <root>/sovereign-audit.sqlite-shm   — shared memory
/// <root>/lifecycle.sqlite             — M270 ticket lifecycle
/// <root>/lifecycle.sqlite-wal         — WAL sidecar
/// <root>/lifecycle.sqlite-shm         — shared memory
/// ```
///
/// Hosts call `ensureRootDirectory(at:)` once at startup to
/// create the root if missing, then use the per-store
/// accessors to construct each storage instance.
public enum BASUnifiedStorageLocator {

    /// Canonical filename for the L14 sovereign audit ledger
    /// SQLite store (M91).
    public static let auditLedgerFilename = "sovereign-audit.sqlite"

    /// Canonical filename for the L13 ticket lifecycle SQLite
    /// store (M270).
    public static let lifecycleFilename = "lifecycle.sqlite"

    /// Compute the audit ledger file URL inside the given root.
    /// Does NOT create the file or directory; callers must run
    /// `ensureRootDirectory(at:)` first if the path may not
    /// exist.
    public static func auditLedgerURL(
        in root: URL
    ) -> URL {
        root.appendingPathComponent(auditLedgerFilename)
    }

    /// Compute the ticket lifecycle file URL inside the given
    /// root.
    public static func lifecycleURL(
        in root: URL
    ) -> URL {
        root.appendingPathComponent(lifecycleFilename)
    }

    /// Create the root directory if it doesn't exist.
    /// Idempotent — safe to call multiple times. Throws on
    /// filesystem failures (permission denied, read-only
    /// volume, etc.).
    public static func ensureRootDirectory(
        at root: URL
    ) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(
            atPath: root.path, isDirectory: &isDir)
        {
            if !isDir.boolValue {
                throw NSError(
                    domain: "BASUnifiedStorageLocator",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "root path exists but is not " +
                            "a directory: \(root.path)"
                    ])
            }
            return
        }
        try fm.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: nil)
    }

    /// Convenience bundle returning both URLs for a root.
    /// Hosts wire it into their storage construction:
    ///
    /// ```swift
    /// let locator = try BASUnifiedStorageLocator.locate(
    ///     in: rootURL)
    /// let ledger = try BASSovereignLedgerSQLiteStorage(
    ///     url: locator.auditLedgerURL)
    /// let lifecycle = try
    ///     BASUpdateTicketLifecycleSQLiteStorage(
    ///         url: locator.lifecycleURL)
    /// ```
    public struct Locations: Codable, Sendable, Equatable, Hashable {
        public let root: URL
        public let auditLedgerURL: URL
        public let lifecycleURL: URL
    }

    public static func locate(
        in root: URL
    ) throws -> Locations {
        try ensureRootDirectory(at: root)
        return Locations(
            root: root,
            auditLedgerURL: auditLedgerURL(in: root),
            lifecycleURL: lifecycleURL(in: root))
    }
}
