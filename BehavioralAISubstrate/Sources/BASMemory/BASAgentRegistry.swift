// MARK: - BASAgentRegistry
// chapter 九百五十六 / M3485 (Phase 1 / ch1)
//
// User design Section 4 sub-system #1: Agent Registry — register /
// discover agents within the fabric。 Mirrors `BASOrganRegistry`
// (Sources/BASOrgan/BASOrganRegistry.swift) pattern but for agent
// SPECS (not organ adapters)。
//
// Per Root Law 1 (单宿主) + Single-Writer-Per-Domain: registry
// enforces ONE agent per `BASAgentRole` at registration time when
// strict mode is on。 Allows multiple agents with same role only
// when explicitly opted in (e.g. multiple Watcher instances)。
//
// Append-only in spirit (re-register same agentID overwrites,
// like BASOrganRegistry)。 Unregister is explicit。
//
// Phase 1 ch 957/958 uses this to discover Scout / Planner /
// Risk / Surface adapters per turn。

import Foundation

public actor BASAgentRegistry {

    public enum RegistryError:
        Error, Equatable, Sendable, Codable
    {
        case unknownAgent(agentID: String)
        case duplicateRoleInStrictMode(
            role: BASAgentRole,
            existingAgentID: String,
            newAgentID: String)
    }

    public struct Entry: Sendable, Equatable {
        public let spec: BASAgentSpec
        public let registeredAt: Date
    }

    private var entries: [String: Entry] = [:]
    private var registrationOrder: [String] = []
    /// When true,registering two agents with the same role throws
    /// `duplicateRoleInStrictMode`。 Used in Phase 1 core-agent
    /// registration to enforce one-agent-per-core-role。 Watcher
    /// registration uses strict=false。
    private let strictRoleUniqueness: Bool
    private let clock: @Sendable () -> Date

    public init(
        strictRoleUniqueness: Bool = false,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.strictRoleUniqueness = strictRoleUniqueness
        self.clock = clock
    }

    // MARK: - Registration

    public func register(_ spec: BASAgentSpec) throws {
        if strictRoleUniqueness {
            for (_, entry) in entries
            where entry.spec.role == spec.role
                && entry.spec.agentID != spec.agentID
            {
                throw RegistryError.duplicateRoleInStrictMode(
                    role: spec.role,
                    existingAgentID: entry.spec.agentID,
                    newAgentID: spec.agentID)
            }
        }
        if entries[spec.agentID] == nil {
            registrationOrder.append(spec.agentID)
        }
        entries[spec.agentID] = Entry(
            spec: spec, registeredAt: clock())
    }

    public func unregister(agentID: String) throws {
        guard entries[agentID] != nil else {
            throw RegistryError.unknownAgent(agentID: agentID)
        }
        entries[agentID] = nil
        registrationOrder.removeAll { $0 == agentID }
    }

    /// chapter 九百九十六.5 META-REVIEW Round-15 CRITICAL-1 fix:
    /// Round-15 deep review caught that the Single-Writer-Per-
    /// Domain global registry (per ch 956.5 USER-PASS gap #1)
    /// was DOCUMENTED but UNWIRED in production。
    /// `BASSharedStateGraph.registerWriter(...)` existed,but
    /// `BASAgentRegistry.register(...)` never called it。 Effective
    /// behavior:registry stayed empty in production →
    /// `writeObject(...)` fell through the domainWriters check
    /// + auto-claimed on first write → first-write-wins race。
    /// Root Law 3 (Single-Writer-Per-Domain) was system-level
    /// doctrine but enforced only at test scope。
    ///
    /// Fix:explicit wire-up method that callers invoke AFTER
    /// registration to install the per-domain writer claims on
    /// the shared state graph。 Throws if any spec's writeDomain
    /// is already claimed by a DIFFERENT agent (genuine
    /// single-writer enforcement)。
    ///
    /// Idempotent:re-wiring the same registry → graph pair
    /// no-ops (the graph rejects re-claim with the SAME agentID
    /// silently per registerWriter contract)。
    ///
    /// - Parameter graph: the BASSharedStateGraph instance that
    ///   the dispatcher will write through。 ONE per coordinator。
    /// - Throws: `BASSharedStateGraphError.domainAlreadyClaimed`
    ///   if two registered agents have overlapping writeDomains
    ///   (the FIRST registered wins;subsequent agents'
    ///   conflicting domains throw)。
    /// chapter 九百九十六.9 META-REVIEW Round-17 CRITICAL-2 fix:
    /// pre-fix the two-phase wire was atomic WITHIN a single call
    /// but two concurrent `wire(toGraph:)` calls from different
    /// registries on the SAME graph could both pass Phase-1
    /// validation (against current empty state) + race in Phase 2
    /// → partial install across both,leaving graph inconsistent。
    /// Fix:delegate the entire batch to the graph's new
    /// `registerWriterBatch(claims:)` method which runs validate-
    /// then-install inside the actor's mailbox isolation,so two
    /// concurrent wire() calls serialize naturally。
    public func wire(
        toGraph graph: BASSharedStateGraph
    ) async throws {
        // chapter 九百九十六.7 META-REVIEW Round-16 CRITICAL-2 fix:
        // pre-fix this loop did registerWriter inline + threw on
        // first conflict,leaving partial claims in the graph
        // (agent A's [X,Y] claimed,then B's Y throws,then B's
        // Z never gets claimed → silent auto-claim race for Z)。
        // The thrown error implied atomic failure but graph was
        // in inconsistent partial state。 Same class as the
        // auto-claim race the registry was meant to prevent。
        //
        // Fix:two-phase commit。
        //   Phase 1 (validation):collect all (agentID, domain)
        //     pairs in registration order。 Check intra-batch
        //     conflicts (same domain claimed by two different
        //     agents in our batch) AND existing-graph conflicts
        //     (graph already claimed this domain by a different
        //     agent)。 If ANY conflict → throw BEFORE any
        //     registerWriter calls。
        //   Phase 2 (commit):only if Phase 1 passes,call
        //     registerWriter for each pair。 Per registerWriter's
        //     own idempotency contract this still works for
        //     re-wire of the same (registry,graph) pair。
        //
        // Atomic w.r.t. domain claims:either ALL claims install
        // or NONE do。 If two concurrent `wire()` calls run on
        // the same graph from different registries,each is
        // atomic individually but the second may see Phase-1
        // conflicts created by the first;both still fail-closed
        // cleanly (no silent partial state)。

        // chapter 九百九十六.9 Round-17 CRITICAL-2 fix:gather
        // the batch in registration order + delegate to graph's
        // atomic registerWriterBatch which validates AND installs
        // within the actor's mailbox isolation。 No need to
        // probe writerForDomain separately — the batch method
        // does that internally during its own Phase 1。
        var batch: [(agentID: String, domain: BASStateDomain)] =
            []
        for agentID in registrationOrder {
            guard let entry = entries[agentID] else { continue }
            for domain in entry.spec.writeDomains {
                batch.append(
                    (agentID: entry.spec.agentID,
                     domain: domain))
            }
        }
        // Single atomic transaction on the graph actor:
        // validate-then-install,no Phase 1 / Phase 2 race
        // window because both phases run before any await
        // boundary other than the storage upsert (which is
        // SQL-first per ch 956.11 USER-PASS-4 CR2)。
        try await graph.registerWriterBatch(claims: batch)
    }

    /// chapter 九百九十六.9 META-REVIEW Round-17 CRITICAL-1 fix:
    /// release a registered agent's claim on the shared state
    /// graph so the domain becomes available for re-binding by
    /// a different agent。 Pre-fix `unregister(agentID:)` removed
    /// the registry-side entry but the graph still held the
    /// writer claim → registry believed domain was free,graph
    /// rejected re-binding with stale agentID → permanent
    /// "ghost claim" from the deleted agent blocking re-use。
    ///
    /// New `unregister(agentID:fromGraph:)` overload: drops
    /// each `entry.spec.writeDomains` claim from the graph
    /// BEFORE removing from the registry。 If graph deletion
    /// throws (storage IO failure),the registry entry stays
    /// so caller can retry。 Original `unregister(agentID:)` is
    /// preserved for callers that don't need graph cleanup
    /// (e.g. test scaffolding,no-graph scenarios)。
    public func unregister(
        agentID: String,
        fromGraph graph: BASSharedStateGraph
    ) async throws {
        guard let entry = entries[agentID] else {
            throw RegistryError.unknownAgent(agentID: agentID)
        }
        // Drop graph claims FIRST per same "SQL-first" discipline。
        // If any unregisterWriter throws,registry stays
        // consistent — caller can retry。
        for domain in entry.spec.writeDomains {
            try await graph.unregisterWriter(
                agentID: agentID, domain: domain)
        }
        // Only after all claims released safely,remove from
        // registry。
        entries[agentID] = nil
        registrationOrder.removeAll { $0 == agentID }
    }

    // MARK: - Resolution

    /// Get the spec for a specific agent ID。 Throws if not registered。
    public func spec(forAgent agentID: String) throws -> BASAgentSpec {
        guard let entry = entries[agentID] else {
            throw RegistryError.unknownAgent(agentID: agentID)
        }
        return entry.spec
    }

    /// Get all specs matching a role,in registration order。 Empty
    /// = no agent registered for that role。 In strict mode this
    /// returns 0 or 1 spec; non-strict can return many (e.g.
    /// multiple watchers)。
    public func specs(forRole role: BASAgentRole) -> [BASAgentSpec] {
        registrationOrder.compactMap { id -> BASAgentSpec? in
            guard let entry = entries[id],
                  entry.spec.role == role
            else { return nil }
            return entry.spec
        }
    }

    /// All registered specs in registration order。 Useful for the
    /// Agent Router to consider activation candidates。
    public func allSpecs() -> [BASAgentSpec] {
        registrationOrder.compactMap { entries[$0]?.spec }
    }

    public func count() -> Int { entries.count }

    public func hasRole(_ role: BASAgentRole) -> Bool {
        entries.values.contains { $0.spec.role == role }
    }
}
