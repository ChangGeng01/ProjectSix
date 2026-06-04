// MARK: - BASHostStorageOptions — chapter 三百〇三 / M790
//
// Phase Gamma 第二刀 (chapter 三百〇二 was ADR-013 + ADR-014 doctrine
// docs;this is the first code cut). 抽出一个 typed config
// primitive that future chapters can wire into `BASHostConfiguration`
// without each one having to introduce a new field name conflict-free.
//
// ## 这一刀 ship 什么
//
// 4 个 typed value-types:
//
//   - `BASHostStorageOptions` (BASSchemaVersioned 1.0.0) — opaque
//     storage URL bundle for L5 host vault / L8 memory atoms /
//     L13 update-ticket lifecycle / L14 audit ledger
//   - `BASHostStoragePreference` (3-case enum) — chooses default
//     storage path: inMemoryDefault / sqliteWhenURLProvided /
//     sqliteRequired
//   - `BASHostStorageRoot` — typed wrapper around root directory
//     URL with subdirectory derivation (atoms / vault / lifecycle
//     / audit)
//   - `BASHostStorageWireReport` (BASSchemaVersioned 1.0.0) —
//     post-construction report describing which storage paths
//     fired in which mode (in-memory vs sqlite) for audit trail
//
// ## Why now
//
// 附录 V chapter 二百七十四 honesty corrigendum identified 6 OPT-IN
// gaps in production-path wiring. ADR-014 (chapter 三百〇二)
// committed Phase Gamma (chapters 三百〇三-三百一三) to convert them
// to PROD with backward-compat opt-out flags + integration test
// per chapter.
//
// Before each chapter changes BASHostConfiguration / BASHostRuntime
// with a new field, this typed primitive provides a stable schema
// for all storage-related configuration. Each Phase Gamma cut
// references `BASHostStorageOptions.atomStoreURL` / `.vaultURL` /
// `.ticketLifecycleURL` / `.auditLedgerURL` from a single typed
// source.
//
// **0 behavior change**:purely additive new file, no existing
// runtime path changes。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only:storage options is config plane,
//     not verdict logic
//   - 单提交口 (L11/L14) 不变 — storage choice doesn't alter
//     permit/verdict authority
//   - chapter 二百一一 single-source-of-truth: every storage URL
//     owned by exactly one field in this primitive
//   - chapter 一百八十五 anti-magic-number: 3-case preference enum,
//     all options typed
//   - chapter 一百三 schema-version: 1.0.0 invariants
//   - ADR-014 (chapter 三百〇二): supports backward-compat via
//     `inMemoryDefault` preference (legacy callers unchanged)

import Foundation

// MARK: - Storage preference taxonomy

/// 3-case preference for how the substrate selects storage backend
/// when both in-memory and SQLite implementations are available。
///
/// ## Doctrine note
///
/// `inMemoryDefault` is the **pre-Phase-Gamma legacy default** —
/// preserves existing behavior for hosts that don't opt in.
/// `sqliteWhenURLProvided` is the **Phase Gamma migration default**:
/// uses SQLite if URL is set, else in-memory. `sqliteRequired` is
/// for production deployments that demand persistence and want
/// fail-fast on missing URL.
public enum BASHostStoragePreference:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    /// Always use in-memory store (pre-Phase-Gamma legacy default).
    /// SQLite URLs are ignored even if provided. Use this for
    /// isolated test fixtures + ephemeral throwaway runs.
    case inMemoryDefault = "in-memory-default"

    /// Use SQLite when URL is provided in `BASHostStorageOptions`,
    /// fall back to in-memory when URL is nil. This is the Phase
    /// Gamma migration default — preserves backward compat for
    /// callers that don't set URLs but enables SQLite for callers
    /// that do.
    case sqliteWhenURLProvided = "sqlite-when-url-provided"

    /// Require SQLite — fail-fast at construction if URL is nil.
    /// Use this in production deployments where in-memory store
    /// would silently lose data.
    case sqliteRequired = "sqlite-required"
}

// MARK: - Typed root directory wrapper

/// Typed wrapper around a single root directory URL that derives
/// stable subdirectory paths for each storage class。Lets hosts
/// pass a single `documentsDirectory` and get four typed sub-URLs
/// without manually concatenating paths.
public struct BASHostStorageRoot:
    Sendable, Equatable, Hashable, Codable
{
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    /// L8 memory atoms SQLite database file URL.
    public var atomsURL: URL {
        rootURL.appendingPathComponent("memory-atoms.sqlite")
    }

    /// L5 host constitution vault SQLite database file URL.
    public var vaultURL: URL {
        rootURL.appendingPathComponent("host-vault.sqlite")
    }

    /// L13 update-ticket lifecycle SQLite database file URL.
    public var ticketLifecycleURL: URL {
        rootURL.appendingPathComponent(
            "ticket-lifecycle.sqlite")
    }

    /// L14 sovereign audit ledger SQLite database file URL.
    public var auditLedgerURL: URL {
        rootURL.appendingPathComponent("audit-ledger.sqlite")
    }

    /// chapter 四百二 / M947:event log SQLite database file URL。
    /// Used by event-sourced atom store + future event-sourced
    /// state projections。
    public var eventLogURL: URL {
        rootURL.appendingPathComponent("event-log.sqlite")
    }

    /// L8 routed vector-index SQLite database file URL。Durable
    /// embeddings (BLOB) for `BASSQLiteVectorIndexStorage`, keyed by
    /// atom ID — lets the routed memory load persisted vectors on
    /// restart instead of re-embedding every atom (the cross-restart
    /// durable-memory path).
    public var vectorIndexURL: URL {
        rootURL.appendingPathComponent("vector-index.sqlite")
    }
}

// MARK: - Storage options bundle

/// Typed bundle of storage URLs + preference for the substrate's
/// 4 PERSISTENT components: L8 atom store / L5 host vault / L13
/// ticket lifecycle / L14 audit ledger。
///
/// All URL fields are optional — hosts can opt in per-component
/// (e.g. SQLite atom store + in-memory vault). Phase Gamma cuts
/// (chapters 三百〇三-三百一三) consume this typed primitive
/// instead of inventing their own field names.
public struct BASHostStorageOptions:
    BASSchemaVersioned,
    Sendable,
    Equatable,
    Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Storage backend selection preference. Default
    /// `.inMemoryDefault` preserves pre-Phase-Gamma behavior
    /// (chapter 二百四十八-二百五十 OPT-IN status).
    public var preference: BASHostStoragePreference

    /// Optional unified root directory. If set, individual URLs
    /// (`atomStoreURL` etc.) below default to subdirectories of
    /// this root. Individual URLs override the root if both are
    /// set.
    public var unifiedRoot: BASHostStorageRoot?

    /// L8 memory atom store SQLite URL. Nil = use in-memory store
    /// (or fail if `preference == .sqliteRequired`).
    public var atomStoreURL: URL?

    /// L5 host constitution vault SQLite URL. Nil = use in-memory
    /// vault (or fail if `preference == .sqliteRequired`).
    public var vaultURL: URL?

    /// L13 update-ticket lifecycle coordinator SQLite URL. Nil =
    /// use in-memory coordinator (or fail if `preference ==
    /// .sqliteRequired`).
    public var ticketLifecycleURL: URL?

    /// L14 sovereign audit ledger SQLite URL. Nil = use in-memory
    /// ledger (or fail if `preference == .sqliteRequired`).
    public var auditLedgerURL: URL?

    /// chapter 四百二 / M947:typed flag to opt into event-sourced
    /// atom storage。When true,`BASHostStorageWireBuilder
    /// .makeAtomStore` returns a `BASEventSourcedMemoryAtomStore`
    /// instead of `BASInMemoryMemoryAtomStore` /
    /// `BASSQLiteMemoryAtomStore`。Default false preserves
    /// pre-Phase-1 behavior (legacy direct-store path)。
    public var useEventSourcedAtomStore: Bool

    /// chapter 四百二 / M947:event log SQLite URL。Nil = use
    /// in-memory event log (or fail if `preference ==
    /// .sqliteRequired`)。Mirrors the existing per-component URL
    /// fields'。
    public var eventLogURL: URL?

    public init(
        schemaVersion: String
            = BASHostStorageOptions.currentSchemaVersion,
        preference: BASHostStoragePreference = .inMemoryDefault,
        unifiedRoot: BASHostStorageRoot? = nil,
        atomStoreURL: URL? = nil,
        vaultURL: URL? = nil,
        ticketLifecycleURL: URL? = nil,
        auditLedgerURL: URL? = nil,
        useEventSourcedAtomStore: Bool = false,
        eventLogURL: URL? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.preference = preference
        self.unifiedRoot = unifiedRoot
        self.atomStoreURL = atomStoreURL
        self.vaultURL = vaultURL
        self.ticketLifecycleURL = ticketLifecycleURL
        self.auditLedgerURL = auditLedgerURL
        self.useEventSourcedAtomStore = useEventSourcedAtomStore
        self.eventLogURL = eventLogURL
    }
}

public extension BASHostStorageOptions {
    /// All-defaults: legacy in-memory across all 4 components.
    /// Equivalent to pre-Phase-Gamma behavior for every Phase
    /// Gamma cut.
    static let legacyInMemory = BASHostStorageOptions()

    /// Resolve effective `atomStoreURL` honoring `unifiedRoot` as
    /// fallback. Returns nil when neither explicit URL nor unified
    /// root is set.
    var effectiveAtomStoreURL: URL? {
        atomStoreURL ?? unifiedRoot?.atomsURL
    }

    /// Resolve effective `vaultURL` honoring `unifiedRoot`.
    var effectiveVaultURL: URL? {
        vaultURL ?? unifiedRoot?.vaultURL
    }

    /// Resolve effective `ticketLifecycleURL` honoring `unifiedRoot`.
    var effectiveTicketLifecycleURL: URL? {
        ticketLifecycleURL ?? unifiedRoot?.ticketLifecycleURL
    }

    /// Resolve effective `auditLedgerURL` honoring `unifiedRoot`.
    var effectiveAuditLedgerURL: URL? {
        auditLedgerURL ?? unifiedRoot?.auditLedgerURL
    }

    /// chapter 四百二 / M947:resolve effective `eventLogURL`
    /// honoring `unifiedRoot`。Returns nil when neither explicit
    /// URL nor unified root is set。
    var effectiveEventLogURL: URL? {
        eventLogURL ?? unifiedRoot?.eventLogURL
    }

    /// Whether SQLite-backed event log should be used given
    /// preference + URL availability。Mirrors atom-store pattern。
    var shouldUseSQLiteEventLog: Bool {
        switch preference {
        case .inMemoryDefault: return false
        case .sqliteWhenURLProvided:
            return effectiveEventLogURL != nil
        case .sqliteRequired: return true
        }
    }

    /// Whether SQLite-backed atom store should be used given
    /// preference + URL availability。
    var shouldUseSQLiteAtomStore: Bool {
        switch preference {
        case .inMemoryDefault: return false
        case .sqliteWhenURLProvided:
            return effectiveAtomStoreURL != nil
        case .sqliteRequired: return true
        }
    }

    /// Whether SQLite-backed vault should be used.
    var shouldUseSQLiteVault: Bool {
        switch preference {
        case .inMemoryDefault: return false
        case .sqliteWhenURLProvided:
            return effectiveVaultURL != nil
        case .sqliteRequired: return true
        }
    }

    /// Whether SQLite-backed ticket lifecycle should be used.
    var shouldUseSQLiteTicketLifecycle: Bool {
        switch preference {
        case .inMemoryDefault: return false
        case .sqliteWhenURLProvided:
            return effectiveTicketLifecycleURL != nil
        case .sqliteRequired: return true
        }
    }

    /// Whether SQLite-backed audit ledger should be used.
    var shouldUseSQLiteAuditLedger: Bool {
        switch preference {
        case .inMemoryDefault: return false
        case .sqliteWhenURLProvided:
            return effectiveAuditLedgerURL != nil
        case .sqliteRequired: return true
        }
    }
}

// MARK: - Storage wire report

/// Post-construction report describing which storage backends
/// fired and in which mode。Phase Gamma's ADR-014 requires per-
/// chapter integration test;reports are how those tests assert
/// the wire fired without inspecting actor state directly。
public struct BASHostStorageWireReport:
    BASSchemaVersioned, Sendable, Equatable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var atomStoreUsedSQLite: Bool
    public var vaultUsedSQLite: Bool
    public var ticketLifecycleUsedSQLite: Bool
    public var auditLedgerUsedSQLite: Bool
    public var preferenceApplied: BASHostStoragePreference
    public var reasonCodes: [String]

    public init(
        schemaVersion: String
            = BASHostStorageWireReport.currentSchemaVersion,
        atomStoreUsedSQLite: Bool = false,
        vaultUsedSQLite: Bool = false,
        ticketLifecycleUsedSQLite: Bool = false,
        auditLedgerUsedSQLite: Bool = false,
        preferenceApplied: BASHostStoragePreference
            = .inMemoryDefault,
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.atomStoreUsedSQLite = atomStoreUsedSQLite
        self.vaultUsedSQLite = vaultUsedSQLite
        self.ticketLifecycleUsedSQLite = ticketLifecycleUsedSQLite
        self.auditLedgerUsedSQLite = auditLedgerUsedSQLite
        self.preferenceApplied = preferenceApplied
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Aggregate predicate:any SQLite store fired this turn?
    public var anySQLiteUsed: Bool {
        atomStoreUsedSQLite ||
        vaultUsedSQLite ||
        ticketLifecycleUsedSQLite ||
        auditLedgerUsedSQLite
    }

    /// Build typed reason codes from booleans + preference.
    /// Used by `BASHostStorageWireReport.derive(...)` for audit
    /// emission.
    public static func makeReasonCodes(
        atomStoreUsedSQLite: Bool,
        vaultUsedSQLite: Bool,
        ticketLifecycleUsedSQLite: Bool,
        auditLedgerUsedSQLite: Bool,
        preference: BASHostStoragePreference
    ) -> [String] {
        var codes: [String] = []
        codes.append(
            "storage-preference:\(preference.rawValue)")
        codes.append(
            "atom-store:" +
            (atomStoreUsedSQLite
                ? "sqlite-backed" : "in-memory"))
        codes.append(
            "vault:" +
            (vaultUsedSQLite
                ? "sqlite-backed" : "in-memory"))
        codes.append(
            "ticket-lifecycle:" +
            (ticketLifecycleUsedSQLite
                ? "sqlite-backed" : "in-memory"))
        codes.append(
            "audit-ledger:" +
            (auditLedgerUsedSQLite
                ? "sqlite-backed" : "in-memory"))
        return codes
    }

    /// Convenience constructor:derive a fully-populated report
    /// from `BASHostStorageOptions`。Used by integration tests +
    /// future Phase Gamma wire-up paths to emit canonical reason
    /// codes。
    public static func derive(
        from options: BASHostStorageOptions
    ) -> BASHostStorageWireReport {
        let atom = options.shouldUseSQLiteAtomStore
        let vault = options.shouldUseSQLiteVault
        let lifecycle = options.shouldUseSQLiteTicketLifecycle
        let ledger = options.shouldUseSQLiteAuditLedger
        return BASHostStorageWireReport(
            atomStoreUsedSQLite: atom,
            vaultUsedSQLite: vault,
            ticketLifecycleUsedSQLite: lifecycle,
            auditLedgerUsedSQLite: ledger,
            preferenceApplied: options.preference,
            reasonCodes: makeReasonCodes(
                atomStoreUsedSQLite: atom,
                vaultUsedSQLite: vault,
                ticketLifecycleUsedSQLite: lifecycle,
                auditLedgerUsedSQLite: ledger,
                preference: options.preference))
    }
}
