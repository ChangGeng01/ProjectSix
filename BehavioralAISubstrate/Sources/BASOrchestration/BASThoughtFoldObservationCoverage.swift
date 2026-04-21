import Foundation
import BASRuntimeCore

// MARK: - L3 thought-fold coverage projection
//
// M42 — additive edge projection from `BASThoughtFold` (the pure
// value carrying one cognition-cycle fold: compact slots + candidate
// signatures + organ package refs + integrity / restore / host-effect
// anchors + a constellation of optional substrate-binding refs) to
// the neutral `BASObservationCoverageSummary` defined in
// `BASRuntimeCore` (M31). **Closes the wave at 14-of-14** layers —
// every cognitive layer (L1 … L14) now carries a coverage-summary
// projection, so an L14 reconciler can reason over the full cognition
// stack in one report.
//
// Like L1 (M39), `BASThoughtFold` has no intrinsic turn/session —
// the fold is a value captured once per cognition cycle and bound to
// whatever audit context the caller is running in. The projection
// therefore takes both keys as arguments.
//
// Unlike L2 (M41) or L5 (M40), `BASThoughtFold` is a value type
// rather than an actor, so only a single pure extension method is
// needed — there is no "async actor path" to keep in parity with a
// "pure snapshot path". The projection is deterministic: same fold
// + same keys always yields the same summary.
//
// Design principles:
//   1. Additive — `BASThoughtFold`, `BASMorphGraph`, the cognition
//      kernel, and every consumer path are untouched. Callers opt
//      in via `coverageSummary(turnID:sessionID:emittedAt:)`.
//   2. Pure — no actor hops; the fold is a value.
//   3. Neutral shape — the L14 reconciler consumes L3 in exactly
//      the same way it consumes every other projected layer.
//   4. Lives in `BASOrchestration` (same module that owns
//      `BASThoughtFold`). Imports only `BASRuntimeCore` — no new
//      cross-module dependency edges.

// MARK: - Budget

/// Pure lookup: what does a single thought-fold cost the L1 wake
/// budget? L3 is the most content-dense layer — a fold bundles the
/// cognition cycle's entire substrate-binding surface:
///   - compact slots (cheap — KV summary rows)
///   - candidate signatures (moderate — each is a frontier anchor)
///   - organ package refs (heavy — each is an L2⟷L3 binding)
///   - a constellation of optional refs (snapshot / resume / morph /
///     etc.) — each that is bound adds light bookkeeping weight
///
/// Degraded folds carry an audit-weight multiplier — a degraded
/// cycle demands extra reconciler attention even if its content
/// surface is small.
public enum BASThoughtFoldObservationBudget {
    /// Flat cost of carrying one thought fold.
    public static let foldBaseCost: Double = 0.04

    /// Cost per compact slot. Slots are lightweight KV summaries.
    public static let perCompactSlotCost: Double = 0.005

    /// Cost per candidate signature. Each signature marks a
    /// frontier anchor the L9 dream loop produced and the fold
    /// absorbed.
    public static let perCandidateSignatureCost: Double = 0.02

    /// Cost per organ package ref. Each ref is a heavy L2⟷L3
    /// binding with its own provenance trail.
    public static let perOrganPackageRefCost: Double = 0.04

    /// Cost per optional substrate-binding ref that is bound
    /// (non-nil, non-empty). The fold can bind up to sixteen such
    /// refs — each bound one adds light audit weight.
    public static let perBoundRefCost: Double = 0.01

    /// Multiplier applied to the raw cost when the fold carries
    /// degraded reason codes. A degraded fold is an audit-worthy
    /// anomaly even if its raw content surface is small.
    public static let degradedMultiplier: Double = 1.3

    /// Count of distinct substrate-binding refs the fold is
    /// carrying. A ref is "bound" when it is non-nil and non-empty.
    public static func boundRefCount(
        for fold: BASThoughtFold
    ) -> Int {
        func nonEmpty(_ s: String?) -> Bool {
            guard let s = s else { return false }
            return !s.isEmpty
        }
        var count = 0
        if nonEmpty(fold.morphID) { count += 1 }
        if nonEmpty(fold.organChecksum) { count += 1 }
        if nonEmpty(fold.frontierChecksum) { count += 1 }
        if nonEmpty(fold.bindingChecksum) { count += 1 }
        if nonEmpty(fold.tissueSignature) { count += 1 }
        if nonEmpty(fold.snapshotRef) { count += 1 }
        if nonEmpty(fold.resumeFrameRef) { count += 1 }
        if nonEmpty(fold.rollbackAnchorRef) { count += 1 }
        if nonEmpty(fold.morphGraphRef) { count += 1 }
        if nonEmpty(fold.hotColdMapRef) { count += 1 }
        if nonEmpty(fold.precisionProfileRef) { count += 1 }
        if nonEmpty(fold.lungStateRef) { count += 1 }
        if nonEmpty(fold.breathSchedulerRef) { count += 1 }
        if nonEmpty(fold.thermalExchangeRef) { count += 1 }
        if nonEmpty(fold.integrityWeaveRef) { count += 1 }
        if nonEmpty(fold.organDeltaPlanRef) { count += 1 }
        return count
    }

    /// Clamped total cost for a thought fold.
    public static func cost(
        for fold: BASThoughtFold
    ) -> Double {
        let raw = foldBaseCost
            + perCompactSlotCost
                * Double(fold.compactSlots.count)
            + perCandidateSignatureCost
                * Double(fold.candidateSignatures.count)
            + perOrganPackageRefCost
                * Double(fold.organPackageRefs.count)
            + perBoundRefCost
                * Double(boundRefCount(for: fold))
        let multiplier = fold.degradedReasonCodes.isEmpty
            ? 1.0
            : degradedMultiplier
        return min(1, max(0, raw * multiplier))
    }
}

// MARK: - Coverage projection

extension BASThoughtFold {
    /// L3 has "core signal coverage" iff the fold sustained the
    /// three structural anchors that make a cognition cycle
    /// resumable and auditable:
    ///
    ///   1. `checksum` is non-empty — the fold has an integrity
    ///      anchor.
    ///   2. `restorePointer` is non-empty — the fold has a resume
    ///      path.
    ///   3. `degradedReasonCodes` is empty — the fold did not fall
    ///      back to a degraded mode.
    ///
    /// A fold that is missing any of these is L3-visible (it still
    /// reports observations) but structurally incomplete — the
    /// reconciler should surface it as a degraded signal in the
    /// audit report.
    public var hasCoreSignalCoverage: Bool {
        !checksum.isEmpty
            && !restorePointer.isEmpty
            && degradedReasonCodes.isEmpty
    }

    /// Neutral coverage summary for L3. Subject accounting:
    ///   - the fold itself (by `foldID`) is always one subject
    ///   - each compact-slot key is its own subject
    ///   - each distinct candidate signature is its own subject
    ///   - each organ package ref is its own subject
    ///
    /// Optional substrate-binding refs (snapshotRef / resumeFrameRef
    /// / morphGraphRef / etc.) contribute to `totalObservations`
    /// when bound but are *not* counted as distinct subjects — they
    /// are anchors into other layers' subject namespaces and
    /// collapsing them here would double-count the other layer.
    ///
    /// `totalObservations` counts the fold (1) + its four content
    /// collections (compact slots + candidate signatures + organ
    /// package refs) + its bound optional refs.
    ///
    /// `emittedAt` is supplied by the caller — the fold is a value
    /// type with no intrinsic wall-clock stamp.
    public func coverageSummary(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASObservationCoverageSummary {
        let boundRefs =
            BASThoughtFoldObservationBudget.boundRefCount(for: self)
        let totalObservations =
            1
            + compactSlots.count
            + candidateSignatures.count
            + organPackageRefs.count
            + boundRefs

        // Defensive union on content-subject IDs. Duplicate compact
        // slot keys cannot happen (Dictionary collapses by key) but
        // duplicate candidate signatures or organ-package refs might
        // if the caller built the fold from an unsanitized source.
        var subjects = Set<String>()
        subjects.insert(foldID)
        for k in compactSlots.keys { subjects.insert(k) }
        for sig in candidateSignatures { subjects.insert(sig) }
        for ref in organPackageRefs { subjects.insert(ref) }

        return BASObservationCoverageSummary(
            layer: .thoughtFold,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: totalObservations,
            distinctSubjectCount: subjects.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASThoughtFoldObservationBudget.cost(for: self),
            emittedAt: emittedAt)
    }
}
