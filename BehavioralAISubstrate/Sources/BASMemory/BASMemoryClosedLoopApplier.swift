// MARK: - BASMemoryClosedLoopApplier — chapter 二百五十三 / M740
//
// L8 Memory Importance closed-loop integration — Stage 1 Step 3
// of 3.
//
// ## Why this exists
//
// chapter 二百五十一 (M738) shipped `BASMemoryUsageTracker` (the
// retrieval-event log). chapter 二百五十二 (M739) shipped
// `BASMemoryImportanceScorer` (the pure-function scorer that
// reads the log and recommends tier mutations). What's still
// open: the **closed loop** — turn the scorer's recommendations
// into actual tier transitions on the L8 atom store.
//
// chapter 二百五十三 ships the orchestration primitive:
// `BASMemoryClosedLoopApplier` is an actor that wraps a store,
// a tracker, and a scorer, and exposes:
//
//   - `recordRetrieval(atomID:sessionRef:turnRef:permitMode:)` —
//     convenience: forwards to tracker.record()
//   - `markHelped(recordID:helped:)` — convenience: forwards to
//     tracker.markHelped()
//   - `applyImportanceReport()` — read tracker → score → apply
//     each `mutations[]` recommendation to the store via
//     `updateTier(forID:to:)`. Returns the report so the host
//     can audit what changed.
//
// This is the additive integration site hosts wire into their
// L8 retrieval path. Existing retrieval flows do **not** need to
// change schema or the `BASMemoryAtomStore` protocol — the
// applier sits alongside them.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: the applier is a
//     coordinator, not a permit gate. Tier mutations go through
//     the existing `BASMemoryAtomStore` protocol; every existing
//     L8 governance gate (admission status, sensitivity, scope)
//     remains in effect on whichever store conforms.
//   - 红线 7 watcher-only-hint upheld: the scorer's
//     `recommendedTier` is consumed by the applier, but the host
//     gets the report and can reject it before passing to
//     `applyImportanceReport(autoApply: false)` is supported via
//     the `dryRun:` flag for hosts that want to inspect first.
//   - chapter 二百十一 single-source-of-truth: the applier owns
//     the orchestration logic; it does not redefine tracker /
//     scorer / store contracts.
//   - chapter 一百零二 五级删除: tier mutation is a level-2
//     transition (atom stays governed, just relocated). The
//     applier never invokes `remove(forID:)` or
//     `updateGovernanceStatus(...)` — those remain higher-layer
//     concerns triggered by separate signals (contamination,
//     forget cascade, etc.).
//
// ## Closed-loop flow (a worked example)
//
//   1. Host receives a turn: at the L8 retrieval site, calls
//      `applier.recordRetrieval(atomID: ..., sessionRef: ...,
//      turnRef: ..., permitMode: ...)` for each consumed atom.
//   2. Post-LLM, host knows whether an atom was actually used —
//      calls `applier.markHelped(recordID: ..., helped: true)`
//      for the helpful atoms.
//   3. At a periodic checkpoint (per N turns / per session end /
//      per BG maintenance window), host calls
//      `applier.applyImportanceReport()`. The applier:
//      - asks the scorer to compute scores for every atom that
//        has a tier in the store
//      - filters to `mutations` (recommended != current)
//      - calls `store.updateTier(forID:to:)` for each
//      - returns the report so the host can audit
//   4. Host optionally calls `applier.purgeOldUsage(olderThan:)`
//      to bound usage-log size.

import Foundation

/// Result of one closed-loop apply pass.
public struct BASMemoryClosedLoopApplyOutcome:
    Codable, Sendable, Equatable
{
    /// The full report computed for this pass.
    public let report: BASMemoryImportanceReport
    /// Tier mutations actually applied (atomID → newTier).
    /// Reflects what the underlying store said yes to via
    /// `updateTier(forID:to:) -> Bool`. An atom dropped from the
    /// store between scoring and apply will not be in this map.
    public let appliedMutations: [String: BASMemoryTier]
    /// Mutations the report recommended but the store rejected
    /// (e.g. atomID no longer present). For observability.
    public let rejectedMutations: [String: BASMemoryTier]
    /// True iff this was a dry-run pass (no mutations applied
    /// regardless of report).
    public let dryRun: Bool

    public init(
        report: BASMemoryImportanceReport,
        appliedMutations: [String: BASMemoryTier],
        rejectedMutations: [String: BASMemoryTier],
        dryRun: Bool
    ) {
        self.report = report
        self.appliedMutations = appliedMutations
        self.rejectedMutations = rejectedMutations
        self.dryRun = dryRun
    }
}

/// Closed-loop orchestrator: combines a store, a tracker, and a
/// scorer into the L8 memory-importance pipeline. Hosts wire one
/// instance per L8 deployment.
public actor BASMemoryClosedLoopApplier {
    private let store: any BASMemoryAtomStore
    private let tracker: BASMemoryUsageTracker
    private let scorer: BASMemoryImportanceScorer

    public init(
        store: any BASMemoryAtomStore,
        tracker: BASMemoryUsageTracker,
        scorer: BASMemoryImportanceScorer =
            BASMemoryImportanceScorer()
    ) {
        self.store = store
        self.tracker = tracker
        self.scorer = scorer
    }

    // MARK: - Retrieval forwarding

    /// Record one retrieval event. Forwards to the underlying
    /// tracker. Returns the recordID so the host can later call
    /// `markHelped(recordID:helped:)`.
    @discardableResult
    public func recordRetrieval(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) async throws -> String {
        try await tracker.record(
            atomID: atomID,
            sessionRef: sessionRef,
            turnRef: turnRef,
            permitMode: permitMode,
            retrievedAt: retrievedAt)
    }

    /// Update the helped flag for a previously-recorded retrieval
    /// event. Forwards to the underlying tracker.
    public func markHelped(
        recordID: String,
        helped: Bool
    ) async throws {
        try await tracker.markHelped(
            recordID: recordID,
            helped: helped)
    }

    /// GC: remove records older than `cutoff`. Forwards to the
    /// underlying tracker. Returns the count purged.
    @discardableResult
    public func purgeOldUsage(
        olderThan cutoff: Date
    ) async throws -> Int {
        try await tracker.purge(olderThan: cutoff)
    }

    // MARK: - Closed-loop apply

    /// Read the usage log → score every atom in `atomTiers` →
    /// apply recommended tier mutations to the store. Returns
    /// the outcome bundle for audit.
    ///
    /// - Parameters:
    ///   - atomTiers: snapshot of (atomID, currentTier) pairs the
    ///     scorer should evaluate. Hosts build this from their
    ///     L8 atom store enumeration before calling.
    ///   - now: clock seam for deterministic tests.
    ///   - dryRun: if true, computes the report but applies
    ///     nothing. Useful for "what would happen" inspection.
    public func applyImportanceReport(
        atomTiers: [String: BASMemoryTier],
        now: Date = Date(),
        dryRun: Bool = false
    ) async -> BASMemoryClosedLoopApplyOutcome {
        let allRecords = await tracker.allRecords()
        let report = scorer.scoreAll(
            atomTiers: atomTiers,
            records: allRecords,
            now: now)

        var applied: [String: BASMemoryTier] = [:]
        var rejected: [String: BASMemoryTier] = [:]
        guard !dryRun else {
            return BASMemoryClosedLoopApplyOutcome(
                report: report,
                appliedMutations: applied,
                rejectedMutations: rejected,
                dryRun: true)
        }

        // Apply each mutation through the store. The store is
        // authoritative — if it returns false (atom absent), we
        // record that and continue.
        for mutation in report.mutations {
            let didUpdate = await store.updateTier(
                forID: mutation.atomID,
                to: mutation.recommendedTier)
            if didUpdate {
                applied[mutation.atomID] =
                    mutation.recommendedTier
            } else {
                rejected[mutation.atomID] =
                    mutation.recommendedTier
            }
        }
        return BASMemoryClosedLoopApplyOutcome(
            report: report,
            appliedMutations: applied,
            rejectedMutations: rejected,
            dryRun: false)
    }
}
