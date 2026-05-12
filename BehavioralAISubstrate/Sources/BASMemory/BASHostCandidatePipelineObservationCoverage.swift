import Foundation
import BASRuntimeCore

// MARK: - L5 host-constitution coverage projection
//
// M40 — additive edge projection from `BASHostCandidatePipeline`
// (actor-owned L5 governance state: live constitution + version tree
// + pending candidates + rejection log) to the neutral
// `BASObservationCoverageSummary` defined in `BASRuntimeCore` (M31).
// Extends the M32/M37/M38/M39 wave from 11-of-14 to **12-of-14**
// projected layers. Remaining two: L2 (neuralOrgan), L3 (thoughtFold).
//
// Like L8 (M37), L14 (M38), L1 (M39), the pipeline carries no
// intrinsic turn/session — it represents the host's governance
// front at whatever moment the caller snapshots it. The projection
// therefore takes turn/session/emittedAt as arguments and follows
// the same dual pure/async pattern as the L14 ledger projection:
//
//   1. A pure static helper `projectCoverage(...)` accepts a value
//      snapshot and produces the coverage summary synchronously —
//      useful for snapshot-in-hand callers and deterministic tests.
//   2. An async method on the actor reads its own state, assembles
//      the snapshot, and defers to the pure helper. Both paths
//      produce byte-identical summaries for the same input, which
//      is exactly the parity discipline the rest of the L5 pipeline
//      is built around (see `parityProjection(of:...)`).
//
// Design principles:
//   1. Additive — `BASHostCandidatePipeline`,
//      `BASHostConstitution`, `BASHostVersionTree`, and every
//      consumer path are untouched. Callers opt in via
//      `coverageSummary(turnID:sessionID:emittedAt:)`.
//   2. Pure helper is deterministic — same snapshot + same keys
//      always yield the same summary.
//   3. Neutral shape — the L14 reconciler consumes L5 in exactly
//      the same way it consumes every other projected layer.
//   4. Leaf discipline preserved — this file lives in `BASMemory`
//      and imports only `BASRuntimeCore`.

// MARK: - Budget

/// Pure lookup: what does each L5 governance subject cost the L1
/// wake budget? L5 is the slowest-moving layer (daily / stage /
/// confirmation cadence per the four-frequency model) so each row
/// is a light, steady cost; the main cost peaks are *pending*
/// candidates (they demand preview + decision work) and *frozen*
/// versions (freeze is a strong governance signal that an audit
/// surface should surface).
///
/// Costs are additive with no multiplier — L5 does not have a
/// guard-level-like escalation axis; it is either quiet or it is
/// actively governing.
public enum BASHostCandidatePipelineObservationBudget {
    /// Cost of carrying an active-version anchor. The constitution
    /// always has exactly one active identity, so this is a flat
    /// bookkeeping baseline applied when the active version is
    /// non-empty.
    public static let activeVersionCost: Double = 0.02

    /// Cost per committed historical version that sits in the
    /// version tree. Each version is an audit subject the
    /// reconciler can walk.
    public static let perCommittedVersionCost: Double = 0.01

    /// Cost per pending candidate awaiting preview / approve /
    /// reject. Higher than a committed version because a pending
    /// candidate costs future L10 / L12 / L14 work.
    public static let perPendingCandidateCost: Double = 0.05

    /// Cost per rejection record. The log is append-only so each
    /// entry is permanent audit weight.
    public static let perRejectionCost: Double = 0.03

    /// Cost per frozen version. Freeze is a strong governance signal
    /// (someone deliberately blocked rollback to this version) so
    /// carries a slight premium above a plain committed version.
    public static let perFrozenVersionCost: Double = 0.04

    /// Total cost of a pipeline snapshot. Individual weights are
    /// tabulated then clamped to [0, 1].
    public static func totalCost(
        for snapshot: BASHostCandidatePipelineObservationSnapshot
    ) -> Double {
        let base = snapshot.activeVersionID.isEmpty
            ? 0.0
            : activeVersionCost
        let committed = Double(snapshot.committedVersionIDs.count)
            * perCommittedVersionCost
        let pending = Double(snapshot.pendingCandidateIDs.count)
            * perPendingCandidateCost
        let rejections = Double(snapshot.rejectedCandidateIDs.count)
            * perRejectionCost
        let frozen = Double(snapshot.frozenVersionIDs.count)
            * perFrozenVersionCost
        let raw = base + committed + pending + rejections + frozen
        return min(1, max(0, raw))
    }
}

// MARK: - Snapshot shape

/// Pure, `Sendable`, `Equatable` value capturing the governance
/// front the pipeline exposed at projection time. The pure
/// projection helper is keyed off this type rather than the actor
/// so callers can compose coverage summaries in tests without
/// instantiating the pipeline.
public struct BASHostCandidatePipelineObservationSnapshot:
    Codable, Sendable, Equatable
{
    public let activeVersionID: String
    public let committedVersionIDs: [String]
    public let pendingCandidateIDs: [String]
    public let rejectedCandidateIDs: [String]
    public let frozenVersionIDs: [String]

    public init(
        activeVersionID: String,
        committedVersionIDs: [String],
        pendingCandidateIDs: [String],
        rejectedCandidateIDs: [String],
        frozenVersionIDs: [String]
    ) {
        self.activeVersionID = activeVersionID
        self.committedVersionIDs = committedVersionIDs
        self.pendingCandidateIDs = pendingCandidateIDs
        self.rejectedCandidateIDs = rejectedCandidateIDs
        self.frozenVersionIDs = frozenVersionIDs
    }
}

// MARK: - Coverage projection

extension BASHostCandidatePipeline {
    /// Pure projection from a snapshot value into a coverage summary.
    /// Does not touch actor state so it's safe to call from anywhere.
    ///
    /// Observation / subject accounting:
    ///   - `totalObservations` sums the four record kinds the
    ///     pipeline tracks — one per committed version, one per
    ///     pending candidate, one per rejection, one per frozen
    ///     marker — plus one observation for the active-version
    ///     anchor when non-empty.
    ///   - `distinctSubjectCount` is the size of the union of the
    ///     four ID sets (the active version collapses into the
    ///     committed set; a frozen marker refers to a committed ID;
    ///     a rejection refers to a candidate ID that may or may not
    ///     overlap with pending). Dedup is intentional — a version
    ///     that is both committed and frozen is one governance
    ///     subject, not two.
    ///   - `hasCoreSignalCoverage` is true when the active-version
    ///     anchor is non-empty. A pipeline with no active version
    ///     has not bootstrapped an identity front yet; the turn is
    ///     L5-silent from a coverage standpoint even if rejections
    ///     are being logged (a rejection log without an active
    ///     identity is structurally meaningless).
    public static func projectCoverage(
        from snapshot: BASHostCandidatePipelineObservationSnapshot,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASObservationCoverageSummary {
        let hasActive = !snapshot.activeVersionID.isEmpty
        let totalObservations =
            (hasActive ? 1 : 0)
            + snapshot.committedVersionIDs.count
            + snapshot.pendingCandidateIDs.count
            + snapshot.rejectedCandidateIDs.count
            + snapshot.frozenVersionIDs.count

        // Union the governance ID sets — the active version belongs
        // with the committed set (one ID, one subject) and frozen
        // markers refer to committed IDs. Rejections refer to
        // candidate IDs that may or may not still sit in pending.
        var subjects = Set<String>()
        if hasActive { subjects.insert(snapshot.activeVersionID) }
        for v in snapshot.committedVersionIDs { subjects.insert(v) }
        for v in snapshot.frozenVersionIDs { subjects.insert(v) }
        for c in snapshot.pendingCandidateIDs { subjects.insert(c) }
        for c in snapshot.rejectedCandidateIDs { subjects.insert(c) }

        return BASObservationCoverageSummary(
            layer: .hostConstitution,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: totalObservations,
            distinctSubjectCount: subjects.count,
            hasCoreSignalCoverage: hasActive,
            budgetTotalCost:
                BASHostCandidatePipelineObservationBudget.totalCost(
                    for: snapshot),
            emittedAt: emittedAt)
    }

    /// Async actor path: read the pipeline's state, assemble a
    /// snapshot, and project. Parity with the pure path is
    /// guaranteed by construction — this method only reads state
    /// then calls `projectCoverage(from:...)`.
    public func coverageSummary(
        turnID: String,
        sessionID: String,
        emittedAt: Date = Date()
    ) -> BASObservationCoverageSummary {
        let snapshot = currentCoverageSnapshot()
        return Self.projectCoverage(
            from: snapshot,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt)
    }

    /// The `BASHostCandidatePipelineObservationSnapshot` for the
    /// pipeline's current state. Exposed so L14 reconciler tests
    /// can check actor/pure parity explicitly.
    public func currentCoverageSnapshot(
    ) -> BASHostCandidatePipelineObservationSnapshot {
        let tree = currentVersionTree()
        let constitution = currentConstitution()
        let committed = tree.versions.map { $0.versionID }
        let rejected = rejectionLog().map { $0.candidateID }
        return BASHostCandidatePipelineObservationSnapshot(
            activeVersionID: constitution.activeVersion,
            committedVersionIDs: committed,
            pendingCandidateIDs: tree.pendingCandidateIDs,
            rejectedCandidateIDs: rejected,
            frozenVersionIDs: tree.frozenVersionIDs)
    }
}
