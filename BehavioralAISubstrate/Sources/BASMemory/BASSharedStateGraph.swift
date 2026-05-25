// MARK: - BASSharedStateGraph
// chapter 九百五十四 / M3475 (Phase 0 / ch2)
//
// User design Section 8 Single Writer Per Domain — concurrency invariant
// for parallel agents。 Each state domain has ONE writer agent role;
// others may read or propose deltas (which the merge engine routes
// back to the writer)。
//
// Per Root Law 3 (单状态图) — all agents operate on ONE typed state
// graph,not per-agent forks。 This actor IS that graph。
//
// Enforcement model:
//   - WRITE:`writeObject(_:byAgent:)` requires the agent's
//     `BASAgentSpec.writeDomains` to contain the target domain。
//     Throws `BASSharedStateGraphError.unauthorizedWriter` otherwise。
//   - READ:`readObject(_:byAgent:)` requires the agent's
//     `readDomains` (or `writeDomains`) to contain the domain。
//   - FORBIDDEN:if domain is in agent's `forbiddenDomains`,both
//     read + write throw — defense in depth (even if write/read
//     domains accidentally include it)。
//
// State storage:in Phase 0 this is in-memory only (Dictionary keyed
// by `<domain>#<objectID>`)。 Phase 1 ch 959 wires persistence via
// `BASRoutedEventLogStorage` for the trace log。 Phase 6+ may add
// snapshot/restore for app-suspension scenarios。

import Foundation

public enum BASSharedStateGraphError: Error, Equatable, Sendable {
    case unauthorizedWriter(
        agentID: String, domain: BASStateDomain)
    case unauthorizedReader(
        agentID: String, domain: BASStateDomain)
    case forbiddenDomain(
        agentID: String, domain: BASStateDomain)
    case objectNotFound(ref: String)
    case malformedObjectRef(ref: String)
    /// chapter 九百五十六.5 / M3485.5 USER-PASS gap #1 fix:
    /// global Single-Writer-Per-Domain registry。 Previously only
    /// per-agent writeDomains was checked — two different agents
    /// could both have `.candidateFrontier` in their writeDomains
    /// and both successfully write,violating the invariant at the
    /// system level。 Now `registerWriter(role:domain:)` enforces
    /// ONE agentID per domain at registration time。 Attempting to
    /// register a second agentID for the same domain throws this case。
    case domainAlreadyClaimed(
        domain: BASStateDomain,
        existingWriterAgentID: String,
        newWriterAgentID: String)
    /// chapter 九百五十六.5 USER-PASS gap #1: write attempt by agent
    /// whose ID does not match the registered writer for the domain。
    /// Per-agent `writeDomains` is necessary but not sufficient — the
    /// global registry is the final authority。
    case writerIdentityMismatch(
        domain: BASStateDomain,
        registeredWriterAgentID: String,
        attemptingAgentID: String)
}

/// A single state-graph object — opaque JSON-encoded payload + the
/// agent that last wrote it。 Identity is `(domain, objectID)`。
public struct BASStateGraphObject:
    Sendable, Equatable, Hashable, Codable
{
    public let domain: BASStateDomain
    public let objectID: String
    /// JSON-encoded payload。 Domain-specific consumer decodes。
    public let payloadJson: String
    /// Agent ID of the last writer。 Empty string = never written
    /// (impossible in steady state — read-after-empty-write throws)。
    public let lastWriterAgentID: String
    /// Monotonic version counter, increments on every successful write。
    /// Lets merge engine detect interleaving writes within a turn。
    public let version: Int64

    public init(
        domain: BASStateDomain,
        objectID: String,
        payloadJson: String,
        lastWriterAgentID: String,
        version: Int64
    ) {
        self.domain = domain
        self.objectID = objectID
        self.payloadJson = payloadJson
        self.lastWriterAgentID = lastWriterAgentID
        self.version = version
    }

    /// Format: `<domain>#<objectID>` per zero-copy state-bus convention。
    public var ref: String { "\(domain.rawValue)#\(objectID)" }

    /// Parse a `<domain>#<objectID>` ref into the pair。 Throws
    /// `BASSharedStateGraphError.malformedObjectRef` if format wrong。
    public static func parse(
        ref: String
    ) throws -> (domain: BASStateDomain, objectID: String) {
        guard let hashIdx = ref.firstIndex(of: "#") else {
            throw BASSharedStateGraphError.malformedObjectRef(
                ref: ref)
        }
        let domainStr = String(ref[..<hashIdx])
        let objectID = String(ref[ref.index(after: hashIdx)...])
        guard
            let domain = BASStateDomain(rawValue: domainStr),
            !objectID.isEmpty
        else {
            throw BASSharedStateGraphError.malformedObjectRef(
                ref: ref)
        }
        return (domain, objectID)
    }
}

/// Shared state graph actor。 All agents read/write through here。
/// Single-Writer-Per-Domain enforced via the writing-agent's
/// `BASAgentSpec.writeDomains` (passed at write time)。
public actor BASSharedStateGraph {

    /// Storage keyed by `<domain>#<objectID>` ref。
    private var objects: [String: BASStateGraphObject] = [:]

    /// Monotonic version counter per domain。 Increments on every
    /// successful write within that domain — used by merge engine
    /// to detect intra-turn interleaving。
    private var domainVersions: [BASStateDomain: Int64] = [:]

    /// chapter 九百五十六.5 / M3485.5 USER-PASS gap #1 fix:
    /// global Single-Writer-Per-Domain registry。 Maps each
    /// `BASStateDomain` to the SINGLE registered writer agentID
    /// (NOT role — agentID,because two agents could share a role
    /// in non-strict registry mode but still must not share a
    /// write domain)。 Empty initially; populated via
    /// `registerWriter(agentID:domain:)`。
    /// Writes succeed ONLY if (a) per-agent writeDomains allows AND
    /// (b) global registry has this agentID as the domain's writer。
    private var domainWriters: [BASStateDomain: String] = [:]

    /// chapter 九百五十六.7 / M3485.7 — optional persistence。
    /// When non-nil,every successful `writeObject` + `registerWriter`
    /// (and auto-claim) is write-through to the storage adapter。
    /// `hydrate()` reloads state from the adapter at startup。 Nil
    /// = in-memory only (default,preserves byte-equal call-site
    /// behavior per 红线 7 + ADR-014 OPT-IN)。
    private let storage: (any BASSharedStateGraphStorage)?

    public init(
        storage: (any BASSharedStateGraphStorage)? = nil
    ) {
        self.storage = storage
    }

    // MARK: - Hydration (USER-PASS gap #6 / ch 956.7 SQL persistence)

    /// chapter 九百五十六.7 — rebuild the in-memory state from the
    /// storage adapter at session boot。 No-op if no storage was
    /// provided。 Per Root Law 7 (可回放),this together with the
    /// event-sourced trace log (Phase 1 ch 959) gives full session
    /// resumption after a restart。
    ///
    /// Idempotent:calling `hydrate()` multiple times reloads from
    /// disk each time and overwrites in-memory state with the
    /// persisted snapshot。 Caller should hydrate ONCE at startup
    /// and not again during a session。
    public func hydrate() async throws {
        guard let storage else { return }
        let objects = try await storage.loadAllObjects()
        var newObjects: [String: BASStateGraphObject] = [:]
        newObjects.reserveCapacity(objects.count)
        var newVersions: [BASStateDomain: Int64] = [:]
        for obj in objects {
            newObjects[obj.ref] = obj
            let cur = newVersions[obj.domain] ?? 0
            if obj.version > cur {
                newVersions[obj.domain] = obj.version
            }
        }
        self.objects = newObjects
        self.domainVersions = newVersions
        let writers = try await storage.loadAllWriters()
        var newWriters: [BASStateDomain: String] = [:]
        for w in writers { newWriters[w.domain] = w.agentID }
        self.domainWriters = newWriters
    }

    // MARK: - Writer registration (USER-PASS gap #1 fix)

    /// chapter 九百五十六.5 USER-PASS gap #1 fix:register an agent
    /// as the SOLE writer for a domain。 Per Single-Writer-Per-Domain
    /// invariant,at most ONE agent (by agentID) may be the writer
    /// of a given `BASStateDomain` system-wide。 Throws
    /// `domainAlreadyClaimed` if a different agent already owns it。
    /// Re-registering the SAME agent for the SAME domain is a no-op
    /// (idempotent),supporting hot-reload patterns。
    ///
    /// Should be called at agent-registry build time (Phase 1 ch 956
    /// `BASAgentRegistry`)。 Per design intent the wiring is:
    /// `BASAgentRegistry.register(spec)` → for each domain in
    /// `spec.writeDomains`,call `graph.registerWriter(agentID:domain:)`。
    public func registerWriter(
        agentID: String,
        domain: BASStateDomain
    ) async throws {
        if let existing = domainWriters[domain] {
            if existing == agentID {
                return  // idempotent re-register
            }
            throw BASSharedStateGraphError.domainAlreadyClaimed(
                domain: domain,
                existingWriterAgentID: existing,
                newWriterAgentID: agentID)
        }
        domainWriters[domain] = agentID
        // chapter 九百五十六.7 SQL write-through
        try await storage?.upsertWriter(
            domain: domain, agentID: agentID)
    }

    /// Read accessor for the registry — used by tests + audit + the
    /// merge engine apply step to verify writer identity matches
    /// before applying patches。 nil = no writer registered yet。
    public func writerForDomain(_ domain: BASStateDomain) -> String? {
        domainWriters[domain]
    }

    // MARK: - Write (single-writer-enforced + global registry)

    /// Write a state object on behalf of `agent`。 Enforces
    /// Single-Writer-Per-Domain at TWO levels per ch 956.5
    /// USER-PASS gap #1 fix:
    ///   1. Per-agent: `agent.writeDomains` MUST contain target domain
    ///   2. Global registry: `domainWriters[domain]` MUST equal
    ///      `agent.agentID` (if registry has been populated for this
    ///      domain)。 If domain has no registered writer,registry
    ///      check is skipped — but `writeObject` IS the canonical
    ///      writer-claiming operation when caller has not called
    ///      `registerWriter` explicitly (auto-claim on first write
    ///      to keep migration simple)。
    /// Also enforces `forbiddenDomains` (defense in depth)。
    public func writeObject(
        domain: BASStateDomain,
        objectID: String,
        payloadJson: String,
        byAgent agent: BASAgentSpec
    ) async throws -> BASStateGraphObject {
        // Forbidden-domains check wins regardless of write rights
        if agent.forbiddenDomains.contains(domain) {
            throw BASSharedStateGraphError.forbiddenDomain(
                agentID: agent.agentID, domain: domain)
        }
        // Per-agent writeDomains check
        guard agent.writeDomains.contains(domain) else {
            throw BASSharedStateGraphError.unauthorizedWriter(
                agentID: agent.agentID, domain: domain)
        }
        // chapter 九百五十六.5 USER-PASS gap #1 fix: global registry
        // check。 If domain has a registered writer that's NOT this
        // agent,reject with writerIdentityMismatch。 If no registered
        // writer yet,auto-claim on this first write (migration-friendly)。
        if let registered = domainWriters[domain] {
            if registered != agent.agentID {
                throw BASSharedStateGraphError
                    .writerIdentityMismatch(
                        domain: domain,
                        registeredWriterAgentID: registered,
                        attemptingAgentID: agent.agentID)
            }
        } else {
            // Auto-claim: this agent becomes the canonical writer。
            // Subsequent writes from other agents will throw
            // writerIdentityMismatch even if their writeDomains
            // includes this domain — preserves Single-Writer at
            // system level without forcing explicit registerWriter
            // call upfront。
            domainWriters[domain] = agent.agentID
            // chapter 九百五十六.7 SQL write-through (auto-claim)
            try await storage?.upsertWriter(
                domain: domain, agentID: agent.agentID)
        }
        let nextVersion = (domainVersions[domain] ?? 0) + 1
        domainVersions[domain] = nextVersion
        let obj = BASStateGraphObject(
            domain: domain,
            objectID: objectID,
            payloadJson: payloadJson,
            lastWriterAgentID: agent.agentID,
            version: nextVersion)
        objects[obj.ref] = obj
        // chapter 九百五十六.7 SQL write-through (object)
        try await storage?.upsertObject(obj)
        return obj
    }

    // MARK: - Read (read-domain-enforced)

    /// Read a state object by ref。 Agent must have the domain in
    /// `readDomains` OR `writeDomains` (writer can always read own
    /// domain)。 Forbidden-domains wins regardless。
    public func readObject(
        ref: String,
        byAgent agent: BASAgentSpec
    ) throws -> BASStateGraphObject {
        let parsed = try BASStateGraphObject.parse(ref: ref)
        if agent.forbiddenDomains.contains(parsed.domain) {
            throw BASSharedStateGraphError.forbiddenDomain(
                agentID: agent.agentID, domain: parsed.domain)
        }
        let canRead =
            agent.readDomains.contains(parsed.domain) ||
            agent.writeDomains.contains(parsed.domain)
        guard canRead else {
            throw BASSharedStateGraphError.unauthorizedReader(
                agentID: agent.agentID, domain: parsed.domain)
        }
        guard let obj = objects[ref] else {
            throw BASSharedStateGraphError.objectNotFound(ref: ref)
        }
        return obj
    }

    // MARK: - Introspection (no agent gate — for audit / replay only)

    /// Count of distinct objects currently stored。 No authorization
    /// — intended for audit / debug / test inspection only。
    public func objectCount() -> Int { objects.count }

    /// All refs currently stored。 Same audit-only contract as
    /// `objectCount`。
    public func allRefs() -> [String] { Array(objects.keys).sorted() }

    /// Current monotonic version of a domain。 Audit-only。
    public func domainVersion(_ domain: BASStateDomain) -> Int64 {
        domainVersions[domain] ?? 0
    }
}
