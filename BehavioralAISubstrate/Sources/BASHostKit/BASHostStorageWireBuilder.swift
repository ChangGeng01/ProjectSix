// MARK: - BASHostStorageWireBuilder — chapter 三百〇五 / M792
//
// Phase Gamma 3rd code cut:typed factory that converts
// `BASHostStorageOptions` (chapter 三百〇三) into concrete store
// instances。Lets hosts construct `BASMemoryAtomStore` from typed
// config without manual switch logic per opt-in.
//
// ## Background
//
// chapter 三百〇三 (M790) shipped `BASHostStorageOptions` typed
// config primitive — schema-only, no consumer。
// chapter 三百〇四 (M791) wired the field into
// `BASHostConfiguration` with backward-compat decode。
// chapter 三百〇五 (this) ships the factory that turns the typed
// config into actual store instances。
//
// Hosts use this factory to opt in to SQLite-backed storage with
// a single line:
//
//   let store = try BASHostStorageWireBuilder.makeAtomStore(
//       options: configuration.storageOptions)
//
// Without this factory, hosts had to manually construct
// `BASInMemoryMemoryAtomStore` or `BASSQLiteMemoryAtomStore` based
// on their own config — duplicated logic across hosts.
//
// ## What this ships
//
// One typed enum + one struct (no new BASSchemaVersioned schemas):
//
//   - `BASHostStorageWireError` — typed error: missingURL /
//     storageInitFailed (failure modes from typed config)
//   - `BASHostStorageWireBuilder` — namespace struct exposing 4
//     `make*Store` static methods (atomStore + 3 future cuts):
//       * `makeAtomStore(options:initial:)` — chapter 三百〇五
//       * `makeAuditLedgerURLIfNeeded(options:)` — chapter 三百〇九
//         (planned)
//       * Future cuts add `makeVaultStorage(options:)` (chapter
//         三百〇六) + `makeTicketLifecycleStorage(options:)`
//         (chapter 三百一一)
//
// **0 behavior change**:purely additive. Hosts that don't call
// the factory keep using whatever store they construct manually.
// Default storage path remains unchanged.
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — factory builds stores; doesn't
//     touch verdict/permit logic
//   - 红线 7 watcher hint only — factory is config translation,
//     not decision logic
//   - chapter 二百一一 single-source-of-truth: one canonical
//     factory for all storage construction
//   - chapter 一百八十五 anti-magic-number: error cases typed
//   - ADR-014 backward-compat: `.legacyInMemory` preference
//     produces in-memory store; existing callers work unchanged

import Foundation
@_exported import BASMemory
@_exported import BASRuntimeCore

// MARK: - Typed error taxonomy

/// 2-case typed error for storage construction failures。
public enum BASHostStorageWireError: Error, Sendable, Equatable {
    /// `.sqliteRequired` preference set but no URL provided。
    /// Caller failed to honor fail-fast semantics.
    case missingSQLiteURL(component: String)

    /// SQLite store init threw — the underlying error message is
    /// preserved as a String for diagnostic logs。Equatable so
    /// tests can assert specific failure modes.
    case storageInitFailed(component: String, message: String)
}

// MARK: - Storage wire builder

/// Namespace struct exposing typed factory methods that convert
/// `BASHostStorageOptions` into concrete store instances。
///
/// Hosts call these factories in their initialization paths to
/// opt in to SQLite-backed storage without manual config-to-init
/// translation.
public enum BASHostStorageWireBuilder {

    /// Construct an `BASMemoryAtomStore` from typed storage options。
    ///
    /// Resolution rules (chapter 三百〇三 ADR-014 doctrine):
    ///
    /// - `.inMemoryDefault` preference → always returns
    ///   `BASInMemoryMemoryAtomStore` regardless of URLs
    ///   (legacy backward-compat)
    /// - `.sqliteWhenURLProvided` preference + URL set → returns
    ///   `BASSQLiteMemoryAtomStore` at that URL
    /// - `.sqliteWhenURLProvided` preference + URL nil → falls
    ///   back to `BASInMemoryMemoryAtomStore`
    /// - `.sqliteRequired` preference + URL set → returns
    ///   `BASSQLiteMemoryAtomStore`
    /// - `.sqliteRequired` preference + URL nil → throws
    ///   `BASHostStorageWireError.missingSQLiteURL`
    ///
    /// - Parameters:
    ///   - options: typed storage configuration
    ///   - initial: optional seed atoms for first-construction
    ///     (passed through to either store implementation)
    /// - Returns: concrete `BASMemoryAtomStore` ready for
    ///   substrate use
    /// - Throws: `BASHostStorageWireError.missingSQLiteURL` if
    ///   `.sqliteRequired` is set but URL is nil; or
    ///   `.storageInitFailed` if SQLite init fails.
    public static func makeAtomStore(
        options: BASHostStorageOptions,
        initial: [BASGovernedMemory] = []
    ) throws -> any BASMemoryAtomStore {
        if options.shouldUseSQLiteAtomStore {
            guard let url = options.effectiveAtomStoreURL else {
                // Only reachable under .sqliteRequired with no URL.
                // .sqliteWhenURLProvided returns false from
                // shouldUseSQLite when URL is nil so this path
                // doesn't fire.
                throw BASHostStorageWireError.missingSQLiteURL(
                    component: "atom-store")
            }
            do {
                return try BASSQLiteMemoryAtomStore(
                    databaseURL: url,
                    initial: initial)
            } catch {
                throw BASHostStorageWireError.storageInitFailed(
                    component: "atom-store",
                    message: "\(error)")
            }
        }
        return BASInMemoryMemoryAtomStore(initial: initial)
    }

    /// Helper:emit reason codes for which atom store path fired。
    /// Used by integration tests + future audit emission to
    /// confirm the wire actually produced SQLite when configured.
    public static func atomStoreWireReasonCodes(
        options: BASHostStorageOptions
    ) -> [String] {
        let willUseSQLite = options.shouldUseSQLiteAtomStore
        return [
            "atom-store-wire:" +
            (willUseSQLite ? "sqlite" : "in-memory"),
            "atom-store-preference:\(options.preference.rawValue)",
            "atom-store-url-provided:" +
            (options.effectiveAtomStoreURL != nil
                ? "yes" : "no")
        ]
    }

    // MARK: - L5 Host vault factory (chapter 三百〇六 / M793)

    /// Construct an `BASHostConstitutionSQLiteStorage?` from typed
    /// storage options。Returns nil for in-memory mode (callers
    /// fall back to value-type vault snapshot)。
    ///
    /// Resolution rules (mirrors atom store factory):
    ///
    /// - `.inMemoryDefault` preference → returns nil (caller uses
    ///   value-type `BASHostConstitutionVault` snapshot)
    /// - `.sqliteWhenURLProvided` + URL → returns SQLite storage
    ///   actor
    /// - `.sqliteWhenURLProvided` + nil URL → returns nil
    /// - `.sqliteRequired` + URL → returns SQLite storage actor
    /// - `.sqliteRequired` + nil URL → throws
    ///   `.missingSQLiteURL(component: "vault")`
    ///
    /// Returns optional rather than `any` (vault has no protocol
    /// abstraction over in-memory + SQLite — the in-memory case
    /// uses the value-type `BASHostConstitutionVault` directly,
    /// which doesn't fit a single `any Storage` return type)。
    public static func makeVaultStorage(
        options: BASHostStorageOptions
    ) throws -> BASHostConstitutionSQLiteStorage? {
        guard options.shouldUseSQLiteVault else {
            return nil
        }
        guard let url = options.effectiveVaultURL else {
            // Only reachable under .sqliteRequired with no URL.
            throw BASHostStorageWireError.missingSQLiteURL(
                component: "vault")
        }
        do {
            return try BASHostConstitutionSQLiteStorage(
                databaseURL: url)
        } catch {
            throw BASHostStorageWireError.storageInitFailed(
                component: "vault",
                message: "\(error)")
        }
    }

    /// Helper:emit reason codes for vault wire path。
    public static func vaultWireReasonCodes(
        options: BASHostStorageOptions
    ) -> [String] {
        let willUseSQLite = options.shouldUseSQLiteVault
        return [
            "vault-wire:" +
            (willUseSQLite ? "sqlite" : "in-memory"),
            "vault-preference:\(options.preference.rawValue)",
            "vault-url-provided:" +
            (options.effectiveVaultURL != nil
                ? "yes" : "no")
        ]
    }

    // MARK: - L13 Ticket lifecycle factory (chapter 三百〇七 / M794)

    /// Construct an `BASUpdateTicketLifecycleCoordinator` from
    /// typed storage options。Same ADR-014 resolution rules as
    /// atom store factory:
    ///
    /// - `.inMemoryDefault` → returns coordinator with `storage:
    ///   nil` (legacy in-memory)
    /// - `.sqliteWhenURLProvided` + URL → returns SQLite-backed
    ///   coordinator via `BASUpdateTicketLifecycleCoordinator
    ///   .sqliteBacked(databaseURL:)`
    /// - `.sqliteWhenURLProvided` + nil URL → returns in-memory
    /// - `.sqliteRequired` + URL → SQLite-backed
    /// - `.sqliteRequired` + nil URL → throws .missingSQLiteURL
    ///
    /// Wraps the existing `sqliteBacked(databaseURL:)` factory
    /// (chapter 二百五十 / M737) with typed-options dispatch.
    /// The underlying factory runs `restore()` inline so the
    /// returned coordinator reflects on-disk state.
    public static func makeTicketLifecycleCoordinator(
        options: BASHostStorageOptions,
        clock: @escaping @Sendable () -> Date = { .now },
        auditSink: BASUpdateTicketLifecycleCoordinator.AuditSink?
            = nil
    ) async throws -> BASUpdateTicketLifecycleCoordinator {
        if options.shouldUseSQLiteTicketLifecycle {
            guard let url = options.effectiveTicketLifecycleURL
            else {
                throw BASHostStorageWireError.missingSQLiteURL(
                    component: "ticket-lifecycle")
            }
            do {
                return try await
                    BASUpdateTicketLifecycleCoordinator
                        .sqliteBacked(
                            databaseURL: url,
                            clock: clock,
                            auditSink: auditSink)
            } catch {
                throw BASHostStorageWireError.storageInitFailed(
                    component: "ticket-lifecycle",
                    message: "\(error)")
            }
        }
        return BASUpdateTicketLifecycleCoordinator(
            clock: clock,
            auditSink: auditSink,
            storage: nil)
    }

    /// Helper:emit reason codes for ticket lifecycle wire path。
    public static func ticketLifecycleWireReasonCodes(
        options: BASHostStorageOptions
    ) -> [String] {
        let willUseSQLite = options.shouldUseSQLiteTicketLifecycle
        return [
            "ticket-lifecycle-wire:" +
            (willUseSQLite ? "sqlite" : "in-memory"),
            "ticket-lifecycle-preference:" +
            "\(options.preference.rawValue)",
            "ticket-lifecycle-url-provided:" +
            (options.effectiveTicketLifecycleURL != nil
                ? "yes" : "no")
        ]
    }
}
