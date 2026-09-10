import Foundation

/// A public, auditable record of one forget cascade execution.
///
/// Every `QinaoMemory.forget(...)` call — whether targeting a single
/// ID, a scope, a sensitivity, or wiping the vault entirely — produces
/// exactly one `ForgetCascadeReceipt`.  The receipt is appended to
/// `QinaoMemory.cascadeLedger()` so the host (and, later, sovereign
/// audit) can prove that a delete request reached every tier and left
/// no live trace behind.
///
/// The receipt is intentionally structural — it does not carry the
/// original content, only IDs / refs and a short human summary — so it
/// can be safely surfaced to the host even when the deleted rows
/// themselves must not cross the governance boundary.
///
/// Four-layer nesting note (§3.1 of the plan): this type is the host's
/// proof-of-delete, not the brain's knob.  The host never controls how
/// the cascade runs; it only observes *that* it ran completely.
public struct QinaoForgetCascadeReceipt: Sendable, Equatable, Codable {

    /// Why the cascade was requested.  Helps the host show the right
    /// confirmation copy / audit message after the fact.
    public enum Trigger: String, Sendable, Equatable, Codable, CaseIterable {
        /// Single ID deletion.  `rootTargets` has exactly one entry.
        case singleID = "single_id"
        /// Scope-wide deletion (`.user` / `.session` / `.system`).
        case scope = "scope"
        /// Sensitivity-wide deletion (`.low` / `.medium` / `.high`).
        case sensitivity = "sensitivity"
        /// Full wipe.  `rootTargets` is empty; every live row was
        /// targeted.
        case all = "all"
    }

    /// Execution outcome of the cascade.  Drives the host-visible
    /// severity and, once L14 Phase-4 lands, determines whether the
    /// cascade needs a sovereign counter-signature before the host can
    /// consider the delete "settled".
    public enum ExecutionState: String, Sendable, Equatable, Codable, CaseIterable {
        /// Cascade matched ≥1 row, every matched row was removed, and
        /// every dependent cache / fold ref was invalidated.
        case completed = "completed"
        /// Cascade matched ≥1 row but one or more rows were routed to
        /// quarantine rather than hard-deleted (sensitivity overrides
        /// or pending sovereign review).
        case partialQuarantined = "partial_quarantined"
        /// Cascade matched zero rows — no-op delete.  The receipt is
        /// still produced so every `forget(...)` call has a paper
        /// trail, but `removedMemoryIDs` and `quarantinedMemoryIDs`
        /// are both empty.
        case empty = "empty"
    }

    /// Ed25519-free cascade identifier.  UUID string so it sorts
    /// lexicographically and is globally unique.
    public let cascadeID: String

    /// What the host actually asked to forget, in string form:
    /// UUID strings for `singleID`; scope raw value for `scope`;
    /// sensitivity raw value for `sensitivity`; empty for `all`.
    public let rootTargets: [String]

    /// What the trigger was.  Lets audit downstream classify.
    public let trigger: Trigger

    /// IDs of memories that were removed outright.
    public let removedMemoryIDs: [UUID]

    /// IDs of memories that were routed to quarantine instead of hard
    /// delete.  (Empty until the quarantine bucket is enabled for a
    /// given sensitivity in a future milestone.)
    public let quarantinedMemoryIDs: [UUID]

    /// Opaque refs for caches / projections / fold bundles that must
    /// be invalidated alongside the removed rows.  Currently always
    /// includes the recall-frontstage cache ref so the host can route
    /// downstream projections; future projection layers extend this.
    public let cacheRefsInvalidated: [String]

    /// When the cascade was executed.
    public let executedAt: Date

    /// Final cascade outcome.
    public let executionState: ExecutionState

    /// One-line human-readable summary.  Stable enough to key UI copy
    /// on in simple cases.
    public let summary: String

    public init(
        cascadeID: String,
        rootTargets: [String],
        trigger: Trigger,
        removedMemoryIDs: [UUID],
        quarantinedMemoryIDs: [UUID] = [],
        cacheRefsInvalidated: [String] = [],
        executedAt: Date,
        executionState: ExecutionState,
        summary: String
    ) {
        self.cascadeID = cascadeID
        self.rootTargets = rootTargets
        self.trigger = trigger
        self.removedMemoryIDs = removedMemoryIDs
        self.quarantinedMemoryIDs = quarantinedMemoryIDs
        self.cacheRefsInvalidated = cacheRefsInvalidated
        self.executedAt = executedAt
        self.executionState = executionState
        self.summary = summary
    }
}
