// MARK: - BASAgentDelta
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.4:
//
//   AgentDelta
//   - delta_id
//   - agent_id
//   - target_object_ref
//   - delta_type
//   - patch
//   - confidence
//   - reason_codes[]
//   - dependencies[]
//   - conflict_refs[]
//
// AgentDelta is the proposed CHANGE an agent wants to make to a state
// object。 Per Single-Writer-Per-Domain invariant,deltas against
// non-owned domains become proposals routed to the writer (Phase 0
// ch 955 merge engine handles the routing)。
//
// Patch payload is a String (JSON-encoded structured change) rather
// than an `Any` field — keeps Codable + Sendable + Hashable clean。
// Parsers in domain-specific consumers decode it。

import Foundation

public struct BASAgentDelta:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique delta identifier。 Format suggestion:
    /// `delta.<turnID>.<agentID>.<seq>`。
    public let deltaID: String

    /// The agent proposing this delta。 Matches `BASAgentSpec.agentID`。
    public let agentID: String

    /// Reference to the target state object。 Format:
    /// `<domain>#<objectID>` per zero-copy state bus convention。
    /// Example: `candidateFrontier#frontier-v3-q123`。
    public let targetObjectRef: String

    /// Operation type per BASAgentDeltaType。
    public let deltaType: BASAgentDeltaType

    /// JSON-encoded patch payload。 Schema depends on (targetObjectRef
    /// domain × deltaType)。 Empty = pure annotation (no payload)。
    public let patchJson: String

    /// Confidence in this delta ∈ [0.0, 1.0]。 Used by merge engine
    /// for evidence-tier conflict resolution (Phase 0 ch 955)。
    public let confidence: Double

    /// Why this delta — short codes for the audit ledger。 Example:
    /// `["evidence.recent", "user.boundary.respect"]`。 Drives the
    /// SovereignAuditEntry `signalRefs` emission downstream。
    public let reasonCodes: [String]

    /// References to other deltas this one depends on。 Format:
    /// `delta:<deltaID>`。 Merge engine respects DAG ordering — a
    /// delta with unsatisfied dependencies gets queued or rejected。
    public let dependencies: [String]

    /// References to other deltas this one explicitly conflicts with。
    /// Format: `delta:<deltaID>`。 Merge engine uses this to break
    /// ties in evidence-tier conflicts。 Empty = no known conflicts
    /// (merge engine still detects implicit conflicts at write time)。
    public let conflictRefs: [String]

    public init(
        deltaID: String,
        agentID: String,
        targetObjectRef: String,
        deltaType: BASAgentDeltaType,
        patchJson: String = "",
        confidence: Double,
        reasonCodes: [String] = [],
        dependencies: [String] = [],
        conflictRefs: [String] = []
    ) {
        self.deltaID = deltaID
        self.agentID = agentID
        self.targetObjectRef = targetObjectRef
        self.deltaType = deltaType
        self.patchJson = patchJson
        self.confidence = confidence
        self.reasonCodes = reasonCodes
        self.dependencies = dependencies
        self.conflictRefs = conflictRefs
    }
}
