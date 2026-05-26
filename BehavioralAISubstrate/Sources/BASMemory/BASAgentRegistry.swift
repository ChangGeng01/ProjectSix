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
    public func wire(
        toGraph graph: BASSharedStateGraph
    ) async throws {
        // Iterate in registration order so the conflict resolution
        // is deterministic — earlier-registered agent wins the
        // domain claim,later-registered agents throw on conflict。
        for agentID in registrationOrder {
            guard let entry = entries[agentID] else { continue }
            for domain in entry.spec.writeDomains {
                try await graph.registerWriter(
                    agentID: entry.spec.agentID,
                    domain: domain)
            }
        }
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
