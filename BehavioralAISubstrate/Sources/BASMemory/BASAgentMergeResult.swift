// MARK: - BASAgentMergeResult
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design Section 7.6:
//
//   AgentMergeResult
//   - merge_id
//   - accepted_deltas[]
//   - rejected_deltas[]
//   - conflict_resolution[]
//   - resulting_state_ref
//   - merge_reason_codes[]
//
// Output of the Merge & Arbitration Engine (Phase 0 ch 955)。 Per
// user's Section 9.4 conflict resolution priority:
//
//   Sovereign > Risk > Host > Evidence > Agent priority > Recency
//
// Merge result is the audit trail showing WHICH deltas were accepted,
// WHICH rejected,WHY each conflict resolved the way it did,and a
// state-bus ref to the resulting state object。
//
// Critical for replay (Phase 0 ch 959 trace log) and for debugging
// "why did agent X's proposal get rejected" user questions。

import Foundation

public struct BASAgentMergeResult:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique merge identifier。 Format suggestion:
    /// `merge.<turnID>.<seq>`。
    public let mergeID: String

    /// Delta IDs that were accepted into the resulting state。
    /// Format: `delta:<deltaID>`。
    public let acceptedDeltaIDs: [String]

    /// Delta IDs that were rejected (paired with reason in
    /// conflictResolution below)。 Format: `delta:<deltaID>`。
    public let rejectedDeltaIDs: [String]

    /// Per-conflict resolution explanations。 One entry per resolved
    /// conflict。 Format suggestion:
    /// `"delta:X vs delta:Y → accept X by Sovereign-tier (reason:...)"`。
    /// Empty = no conflicts resolved (all deltas were independent)。
    public let conflictResolution: [String]

    /// State-bus reference to the resulting state object after this
    /// merge applied its accepted deltas。 Format: `<domain>#<objectID>`。
    /// Downstream layers (L10 / L11 / L12 / L14) consume from this ref。
    public let resultingStateRef: String

    /// Audit-friendly reason codes for the merge as a whole (vs
    /// per-conflict in conflictResolution above)。 Example:
    /// `["merge.consistent", "writer.respected"]`。 Flows into
    /// `SovereignAuditEntry.signalRefs` via prefix `agentFabric.merged:`。
    public let mergeReasonCodes: [String]

    public init(
        mergeID: String,
        acceptedDeltaIDs: [String] = [],
        rejectedDeltaIDs: [String] = [],
        conflictResolution: [String] = [],
        resultingStateRef: String,
        mergeReasonCodes: [String] = []
    ) {
        self.mergeID = mergeID
        self.acceptedDeltaIDs = acceptedDeltaIDs
        self.rejectedDeltaIDs = rejectedDeltaIDs
        self.conflictResolution = conflictResolution
        self.resultingStateRef = resultingStateRef
        self.mergeReasonCodes = mergeReasonCodes
    }
}
