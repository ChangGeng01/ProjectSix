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
//   let store = try await BASHostStorageWireBuilder.makeAtomStore(
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
import BASSovereign

// MARK: - Typed error taxonomy

/// 2-case typed error for storage construction failures。
public enum BASHostStorageWireError:
    Error, Sendable, Equatable, Codable
{
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
        initial: [BASGovernedMemory] = [],
        eventSourcedSessionID: String =
            "host.event-sourced-atom-store",
        failureLog:
            BASHostStorageInitialAtomAdmitFailureLog? = nil
    ) async throws -> any BASMemoryAtomStore {
        // chapter 四百二 / M947 — event-sourced opt-in branch
        if options.useEventSourcedAtomStore {
            let eventLog = try makeEventLog(options: options)
            let store = BASEventSourcedMemoryAtomStore(
                eventLog: eventLog,
                sessionID: eventSourcedSessionID)
            // Seed initial atoms by emitting admit events
            // (preserves typed contract — every atom-state change
            // flows through the event log)。
            //
            // audit M-l MED-8 — seed INLINE (was `Task.detached`, now the
            // factory is `async`). The detached seed let makeAtomStore
            // RETURN the store before seeding finished: a caller reading it
            // immediately raced the seed and saw an empty / partial store,
            // silently violating the documented `initial:` contract. The
            // SQLite / in-memory branches already seed synchronously via
            // their `initial:` constructor — only this event-sourced branch
            // was async, and only it was fire-and-forget.
            for atom in initial {
                // chapter 五百三十六 / M1522 — wire-in of the typed
                // observability sink (M1521)。 When `failureLog == nil`,
                // behavior is the M1517 documented silent-swallow。 When
                // non-nil,each admission failure is recorded for host
                // inspection。 ADR-014 OPT-IN preserved。
                do {
                    try await store.admit(atom)
                } catch {
                    if let log = failureLog {
                        await log.record(
                            atomID: atom.id,
                            error: error)
                    }
                }
            }
            return store
        }
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

    // MARK: - chapter 四百二 / M947 event log factory

    /// Construct an `any BASEventLogStorage` from typed storage
    /// options。Same ADR-014 resolution rules:
    ///
    /// - `.inMemoryDefault` preference → in-memory log
    /// - `.sqliteWhenURLProvided` + URL → SQLite-backed log
    /// - `.sqliteWhenURLProvided` + nil URL → in-memory log
    /// - `.sqliteRequired` + URL → SQLite-backed log
    /// - `.sqliteRequired` + nil URL → throws .missingSQLiteURL
    public static func makeEventLog(
        options: BASHostStorageOptions
    ) throws -> any BASEventLogStorage {
        if options.shouldUseSQLiteEventLog {
            guard let url = options.effectiveEventLogURL else {
                throw BASHostStorageWireError.missingSQLiteURL(
                    component: "event-log")
            }
            do {
                return try BASSQLiteEventLogStorage(
                    databaseURL: url)
            } catch {
                throw BASHostStorageWireError.storageInitFailed(
                    component: "event-log",
                    message: "\(error)")
            }
        }
        return BASInMemoryEventLogStorage()
    }

    /// Helper:emit reason codes for event-log wire path。
    public static func eventLogWireReasonCodes(
        options: BASHostStorageOptions
    ) -> [String] {
        let willUseSQLite = options.shouldUseSQLiteEventLog
        return [
            "event-log-wire:" +
            (willUseSQLite ? "sqlite" : "in-memory"),
            "event-log-preference:" +
            "\(options.preference.rawValue)",
            "event-log-url-provided:" +
            (options.effectiveEventLogURL != nil
                ? "yes" : "no"),
            "event-sourced-atom-store:" +
            (options.useEventSourcedAtomStore
                ? "enabled" : "disabled")
        ]
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

    // MARK: - L14 Audit ledger storage factory (chapter 三百〇八 / M795)

    /// Construct a `BASSovereignLedgerStorage` from typed storage
    /// options。Returns nil for in-memory mode (caller passes
    /// `BASSovereignLedgerNullStorage()` to ledger init);returns
    /// `BASSovereignLedgerSQLiteStorage` for configured cases。
    ///
    /// Same ADR-014 resolution rules:
    ///
    /// - `.inMemoryDefault` → returns nil (legacy path —
    ///   `BASSovereignLedgerNullStorage` used by ledger default)
    /// - `.sqliteWhenURLProvided` + URL → SQLite ledger storage
    /// - `.sqliteWhenURLProvided` + nil URL → returns nil
    ///   (graceful fallback)
    /// - `.sqliteRequired` + URL → SQLite ledger storage
    /// - `.sqliteRequired` + nil URL → throws .missingSQLiteURL(
    ///   component: "audit-ledger")
    ///
    /// Returns optional rather than `any` because the in-memory
    /// path uses `BASSovereignLedgerNullStorage()` which is a
    /// concrete null-object implementation; nil signals "use the
    /// default null storage". This mirrors vault factory's nil
    /// semantic.
    public static func makeAuditLedgerStorage(
        options: BASHostStorageOptions
    ) throws -> (any BASSovereignLedgerStorage)? {
        guard options.shouldUseSQLiteAuditLedger else {
            return nil
        }
        guard let url = options.effectiveAuditLedgerURL else {
            throw BASHostStorageWireError.missingSQLiteURL(
                component: "audit-ledger")
        }
        do {
            return try BASSovereignLedgerSQLiteStorage(
                path: url.path)
        } catch {
            throw BASHostStorageWireError.storageInitFailed(
                component: "audit-ledger",
                message: "\(error)")
        }
    }

    /// Helper:emit reason codes for audit ledger wire path。
    public static func auditLedgerWireReasonCodes(
        options: BASHostStorageOptions
    ) -> [String] {
        let willUseSQLite = options.shouldUseSQLiteAuditLedger
        return [
            "audit-ledger-wire:" +
            (willUseSQLite ? "sqlite" : "in-memory"),
            "audit-ledger-preference:" +
            "\(options.preference.rawValue)",
            "audit-ledger-url-provided:" +
            (options.effectiveAuditLedgerURL != nil
                ? "yes" : "no")
        ]
    }

    // MARK: - Bundle assembly (chapter 三百〇九 / M796)

    /// Construct all 4 storage components from typed options in
    /// one call。Returns a `BASHostStorageWireBundle` containing
    /// each component (or nil for in-memory mode where applicable)
    /// + the post-construction wire report。
    ///
    /// Hosts use this when they want to opt in to ALL 4 SQLite
    /// paths consistently from a single typed config. Equivalent
    /// to calling all 4 individual factories sequentially, but
    /// guarantees consistent error handling + emits the typed
    /// wire report in one step.
    ///
    /// - Throws: any of the 4 factories' typed errors. Whichever
    ///   factory fails first aborts assembly.
    public static func makeBundle(
        options: BASHostStorageOptions,
        atomStoreInitial: [BASGovernedMemory] = [],
        ticketLifecycleClock: @escaping @Sendable () -> Date
            = { .now },
        ticketLifecycleAuditSink:
            BASUpdateTicketLifecycleCoordinator.AuditSink? = nil,
        eventSourcedSessionID: String =
            "host.event-sourced-atom-store",
        atomStoreFailureLog:
            BASHostStorageInitialAtomAdmitFailureLog? = nil
    ) async throws -> BASHostStorageWireBundle {
        // chapter 四百二 / M947:if event-sourced atom store is
        // requested,construct one event log and pass it through
        // to both the atom store factory + the bundle's eventLog
        // field。Same eventLog instance avoids double-write paths。
        var sharedEventLog: (any BASEventLogStorage)? = nil
        let atomStore: any BASMemoryAtomStore
        if options.useEventSourcedAtomStore {
            let log = try makeEventLog(options: options)
            sharedEventLog = log
            let store = BASEventSourcedMemoryAtomStore(
                eventLog: log,
                sessionID: eventSourcedSessionID)
            // audit M-l MED-8 — seed INLINE (was `Task.detached`).
            // makeBundle is already async; the detached seed returned the
            // bundle with an un-seeded store, racing any immediate reader.
            for atom in atomStoreInitial {
                // chapter 五百三十六 / M1522 — typed observability sink;
                // parallel to the makeAtomStore path。 ADR-014 OPT-IN.
                do {
                    try await store.admit(atom)
                } catch {
                    if let bundleLog = atomStoreFailureLog {
                        await bundleLog.record(
                            atomID: atom.id,
                            error: error)
                    }
                }
            }
            atomStore = store
        } else {
            atomStore = try await makeAtomStore(
                options: options,
                initial: atomStoreInitial,
                failureLog: atomStoreFailureLog)
        }
        let vault = try makeVaultStorage(options: options)
        let lifecycle = try await makeTicketLifecycleCoordinator(
            options: options,
            clock: ticketLifecycleClock,
            auditSink: ticketLifecycleAuditSink)
        let auditLedger = try makeAuditLedgerStorage(
            options: options)
        let report = BASHostStorageWireReport.derive(
            from: options)
        return BASHostStorageWireBundle(
            atomStore: atomStore,
            vault: vault,
            ticketLifecycle: lifecycle,
            auditLedger: auditLedger,
            wireReport: report,
            eventLog: sharedEventLog)
    }
}

// MARK: - BASHostStorageWireBundle (chapter 三百〇九 / M796)

/// Typed bundle containing all 4 storage components constructed
/// from one `BASHostStorageOptions` config + the post-construction
/// wire report。
///
/// Hosts wire this through their initialization paths to thread
/// all 4 stores via a single typed value:
///
///     let bundle = try await BASHostStorageWireBuilder.makeBundle(
///         options: hostConfig.storageOptions)
///     // bundle.atomStore — ready for substrate use
///     // bundle.vault — nil if in-memory; non-nil for SQLite
///     // bundle.ticketLifecycle — coordinator (in-memory or SQLite)
///     // bundle.auditLedger — nil if in-memory; non-nil for SQLite
///     // bundle.wireReport — typed audit trail of what fired
///
/// Bundle is **not** Sendable — `BASSovereignLedgerStorage`
/// protocol doesn't promise Sendable. Callers thread the bundle
/// through their initialization paths within a single isolation
/// domain; once each store is handed off to its owning actor,
/// concurrency is managed at the actor level (chapter 一百九十一
/// M91 SQLite serialization doctrine).
public struct BASHostStorageWireBundle {
    public let atomStore: any BASMemoryAtomStore
    public let vault: BASHostConstitutionSQLiteStorage?
    public let ticketLifecycle: BASUpdateTicketLifecycleCoordinator
    public let auditLedger: (any BASSovereignLedgerStorage)?
    public let wireReport: BASHostStorageWireReport
    /// chapter 四百二 / M947:event log surface added when host
    /// opts into event-sourced atom storage。Nil when
    /// `useEventSourcedAtomStore == false` (legacy path)。
    public let eventLog: (any BASEventLogStorage)?

    public init(
        atomStore: any BASMemoryAtomStore,
        vault: BASHostConstitutionSQLiteStorage?,
        ticketLifecycle: BASUpdateTicketLifecycleCoordinator,
        auditLedger: (any BASSovereignLedgerStorage)?,
        wireReport: BASHostStorageWireReport,
        eventLog: (any BASEventLogStorage)? = nil
    ) {
        self.atomStore = atomStore
        self.vault = vault
        self.ticketLifecycle = ticketLifecycle
        self.auditLedger = auditLedger
        self.wireReport = wireReport
        self.eventLog = eventLog
    }
}
