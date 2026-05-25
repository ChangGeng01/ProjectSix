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

    public init() {}

    // MARK: - Write (single-writer-enforced)

    /// Write a state object on behalf of `agent`。 Enforces
    /// Single-Writer-Per-Domain: agent.writeDomains MUST contain
    /// the object's domain,and forbiddenDomains MUST NOT contain
    /// it (forbidden wins on conflict)。
    ///
    /// Returns the stored object with version incremented。 Throws
    /// on authorization failure (caught at audit-time)。
    public func writeObject(
        domain: BASStateDomain,
        objectID: String,
        payloadJson: String,
        byAgent agent: BASAgentSpec
    ) throws -> BASStateGraphObject {
        // Forbidden-domains check wins regardless of write rights
        if agent.forbiddenDomains.contains(domain) {
            throw BASSharedStateGraphError.forbiddenDomain(
                agentID: agent.agentID, domain: domain)
        }
        guard agent.writeDomains.contains(domain) else {
            throw BASSharedStateGraphError.unauthorizedWriter(
                agentID: agent.agentID, domain: domain)
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
