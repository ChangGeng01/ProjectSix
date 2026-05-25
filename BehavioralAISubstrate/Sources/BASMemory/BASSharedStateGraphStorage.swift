// MARK: - BASSharedStateGraphStorage protocol
// chapter 九百五十六.7 / M3485.7 — front-load Phase 1 ch 959 persistence
//
// Per user directive「继续 提高 Metal sql rust c c++ 比例」 — raise the
// SQL ratio in the Agent Fabric implementation。 Phase 1 ch 959 was
// going to add a `BASRoutedEventLogStorage`-style trace log;this
// chapter front-loads the persistence story by giving
// `BASSharedStateGraph` an optional storage adapter。
//
// Protocol shape:read / write of state objects + writer-registry
// rows。 Both surfaces are async + throwing — the adapter may go to
// disk,a network store,or stay in-memory (no-op adapter for tests)。
//
// SQLite implementation lands in `BASSharedStateGraphSQLiteStorage`。
// `BASSharedStateGraph` defaults to NO storage (in-memory only) so
// existing call sites remain byte-equal per 红线 7 + ADR-014 OPT-IN
// discipline。 Hosts opt-in to persistence by passing a storage
// adapter to the actor's initializer (added in a follow-up chapter
// once this protocol + SQLite impl land cleanly)。
//
// Per Root Law 7 (可回放):persisted state objects + writer registry
// are sufficient to rebuild the shared graph at process restart。
// Caller responsible for replaying the event-sourced log (Phase 1 ch
// 959) on top of the loaded snapshot for full turn-level replay。

import Foundation

/// Adapter for `BASSharedStateGraph` persistence。 Implementations
/// MUST be `Sendable` because the graph actor calls them across
/// the actor boundary。 All methods are `async throws` so disk /
/// network / encoding failures surface to the caller。
///
/// ## Idempotency contract
///
///   - `upsertObject(_:)` — insert or replace by `(domain, objectID)`。
///     Idempotent:same input → same row。
///   - `upsertWriter(domain:agentID:)` — insert or replace by domain。
///     Re-registering the same agentID is a no-op (per ch 956.5 gap #1
///     fix in `BASSharedStateGraph.registerWriter`)。
///   - `deleteObject(ref:)` — real DELETE,not tombstone。 Returns
///     normally even if the row was absent (idempotent)。
///
/// ## Crash safety
///
/// Implementations SHOULD use WAL journal + synchronous=NORMAL
/// (chapter 二百四十八 / M735 idiom) so a process crash leaves the
/// DB in a consistent prior state — partial writes do NOT corrupt
/// the snapshot。
public protocol BASSharedStateGraphStorage: Sendable {

    // MARK: - State object persistence

    /// Upsert one state object。 Replaces existing row at
    /// `(obj.domain, obj.objectID)` if present。
    func upsertObject(
        _ obj: BASStateGraphObject) async throws

    /// Load one state object by `(domain, objectID)`。 Returns nil
    /// if absent。
    func loadObject(
        ref: String) async throws -> BASStateGraphObject?

    /// Load EVERY state object。 Used at graph hydration time。
    /// Order is unspecified — caller (the graph actor) re-keys
    /// internally by ref。
    func loadAllObjects() async throws -> [BASStateGraphObject]

    /// Real DELETE by ref。 Idempotent — absent row is success。
    func deleteObject(ref: String) async throws

    // MARK: - Writer-registry persistence (USER-PASS gap #1)

    /// Upsert the registered writer for a domain。 Per
    /// `BASSharedStateGraph.registerWriter`:idempotent
    /// re-register of the SAME agent;different agent for the
    /// same domain is a caller-side error caught BEFORE this
    /// is called (storage is plumbing,not a gate)。
    func upsertWriter(
        domain: BASStateDomain,
        agentID: String) async throws

    /// Load EVERY writer registration。 Used at graph hydration
    /// time to rebuild the `domainWriters` dict。
    func loadAllWriters(
    ) async throws -> [(domain: BASStateDomain, agentID: String)]
}
