// MARK: - chapter 二百五十 / M737 — SQLite-backed lifecycle factory
//
// Production wire for `BASUpdateTicketLifecycleSQLiteStorage`.
//
// ## Why this exists
//
// Pre-chapter 二百五十 the substrate already shipped:
//   - chapter 二百六十八 / M268 — lifecycle coordinator's optional
//     `storage:` init param
//   - chapter 二百六十八 / M270 — `BASUpdateTicketLifecycleSQLiteStorage`
//     adapter (in BASObservability)
//   - chapter 二百九十八 / M283 — `BASUnifiedStorageLocator` for
//     canonical SQLite file paths (also BASObservability)
//
// What was missing: a **factory helper** that combines the three
// into the canonical "SQLite-backed coordinator with disk state
// pre-loaded" pattern hosts actually need. Without this, every
// host had to write the same 4-line incantation:
//
//   let locator = try BASUnifiedStorageLocator.locate(in: root)
//   let storage = try BASUpdateTicketLifecycleSQLiteStorage(
//       url: locator.lifecycleURL)
//   let coord = BASUpdateTicketLifecycleCoordinator(
//       storage: storage)
//   try await coord.restore()
//
// chapter 二百五十 collapses that into a single static factory:
//
//   let coord = try await BASUpdateTicketLifecycleCoordinator
//       .sqliteBacked(storageRoot: root)
//
// This is附录 V Stage 0 Step 3 of 3: production wire for the L13
// ticket lifecycle storage that already had its primitive shipped
// but no convenient construction site. The factory lives in
// BASHostKit because BASObservability cannot reach `BASEBrainTurnResult`
// without a cycle, and we want to keep production-wire conveniences
// adjacent to the auto-flow extension (chapter 二百六十七 / M267).
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: factory is plumbing.
//   - chapter 二百十一 single-source-of-truth: storage protocol +
//     coordinator + canonical-path locator each stay in their
//     existing modules; this file is convenience-only.
//   - chapter 一百九十一 M91 / chapter 二百六十八 M270 SQLite idiom
//     remains the storage substrate.
//   - 附录 V Stage 0: closes the L13 production-wire gap so hosts
//     can run multi-session ticket continuity end-to-end without
//     boilerplate.

import Foundation
import BASObservability

public extension BASUpdateTicketLifecycleCoordinator {

    /// Construct a SQLite-backed lifecycle coordinator pointing at
    /// the canonical lifecycle file under `storageRoot`. The unified
    /// storage layout (chapter 二百九十八 / M283
    /// `BASUnifiedStorageLocator`) places the file at
    /// `<storageRoot>/lifecycle.sqlite`.
    ///
    /// `restore()` runs inline so the returned coordinator already
    /// reflects the on-disk state. Hosts call this once at runtime
    /// startup and reuse the returned coordinator for the session.
    ///
    /// - Parameters:
    ///   - storageRoot: filesystem root for the substrate's SQLite
    ///     stores (audit ledger + lifecycle). The directory is
    ///     created if absent.
    ///   - clock: source of timestamps for state transitions
    ///     (test seam). Defaults to `{ .now }`.
    ///   - auditSink: optional terminal-transition audit hook
    ///     (chapter 二百六十五 / M265). When non-nil, terminal
    ///     transitions (.distilled / .rejected) feed the supplied
    ///     closure with a synthesized `BASSovereignAuditEntry`.
    /// - Returns: A coordinator whose state already reflects every
    ///   ticket previously persisted to the same root. Hosts can
    ///   immediately call `submit / startTrial / markTrialOutcome
    ///   / approveForDistillation / markDistilled / etc.` and the
    ///   mutations will land both in memory and on disk.
    /// - Throws: any storage / restore error from the underlying
    ///   chapter 一百九十一 M91 idiom (open / schema / decode).
    static func sqliteBacked(
        storageRoot: URL,
        clock: @escaping @Sendable () -> Date = { .now },
        auditSink: AuditSink? = nil
    ) async throws -> BASUpdateTicketLifecycleCoordinator {
        let locations = try BASUnifiedStorageLocator.locate(
            in: storageRoot)
        return try await sqliteBacked(
            databaseURL: locations.lifecycleURL,
            clock: clock,
            auditSink: auditSink)
    }

    /// Construct a SQLite-backed lifecycle coordinator pointing at
    /// an explicit SQLite file URL. Use the
    /// `storageRoot:` overload when the unified-locator layout is
    /// the right convention; this overload is the escape hatch for
    /// hosts that want to place the file outside the canonical
    /// layout (e.g. a dedicated test fixture, an iCloud-synced
    /// location, etc.).
    ///
    /// `restore()` runs inline so the returned coordinator already
    /// reflects the on-disk state.
    ///
    /// - Parameters:
    ///   - databaseURL: explicit SQLite file path. Parent directory
    ///     must exist.
    ///   - clock / auditSink: see `sqliteBacked(storageRoot:...)`.
    /// - Returns: A restored coordinator; see the storageRoot
    ///   overload for semantics.
    /// - Throws: open / schema / decode errors.
    static func sqliteBacked(
        databaseURL: URL,
        clock: @escaping @Sendable () -> Date = { .now },
        auditSink: AuditSink? = nil
    ) async throws -> BASUpdateTicketLifecycleCoordinator {
        let storage = try BASUpdateTicketLifecycleSQLiteStorage(
            url: databaseURL)
        let coord = BASUpdateTicketLifecycleCoordinator(
            clock: clock,
            auditSink: auditSink,
            storage: storage)
        try await coord.restore()
        return coord
    }
}
