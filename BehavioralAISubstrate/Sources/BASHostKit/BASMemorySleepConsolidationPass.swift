// MARK: - BASMemorySleepConsolidationPass — T3.1 sleep/consolidation cycle
//
// Off-turn orchestrator for the L8 memory "sleep" pass:score →
// tier-reconcile → forget-quarantine → checkpoint,bounded by the
// per-turn maintenance window the L1 power clock already computes
// (`BASBudgetFrame.maintenanceAllowed` + `maintenanceClass` →
// `evolutionSchedulerMaintenanceWindowMs`)。
//
// ## What this composes (all pre-existing primitives — this file
// adds ORCHESTRATION only)
//
//   1. `BASRustBrainHistoryStore.integrityChainHashHex` —
//      PRE chain hash (deterministic checkpoint primitive)
//   2. `BASRustBrainHistoryStore.atomImportanceScores` — Rust
//      importance verdict (bas_rust_tracker_atom_importance_scores)
//   3. `BASMemoryClosedLoopApplier.applyImportanceReport` — the
//      shipped L8 closed loop executes tier moves (dryRun honored)
//   4. `BASRustBrainHistoryStore.forgetCandidates` — Rust forget
//      verdict (bas_rust_tracker_forget_candidates,retainFraction
//      parameterized)
//   5. `BASBrainHistoryAtomID` join → `BASMemoryAtomStore.
//      updateGovernanceStatus(forID:to:.quarantined)` — QUARANTINE,
//      never remove
//   6. ledger mark + POST chain hash
//   7. `BASConsolidationCheckpoint` emission (off-turn surface)
//
// ## Doctrine pins
//
//   - ADR-014 / byte-equality:gated behind ONE default-off flag
//     (`sleepConsolidationEnabled`,mirroring the
//     `BASMemoryForgetCascadeRunner.useRoutedFilter` static-flag
//     precedent)。 Flag off ⇒ the pass is never constructed or
//     invoked ⇒ the turn result is byte-equal by construction。
//   - 亏的不要:forgetting is QUARANTINE (reversible,
//     `manual_review` release condition)。 This actor NEVER calls
//     `store.remove(forID:)` — preserving the
//     `BASMemoryClosedLoopApplier` header doctrine (chapter
//     一百零二 五级删除:destructive transitions are higher-layer
//     concerns)。
//   - Swift executes,Rust decides (ch881):the forget verdict
//     comes from `bas_rust_tracker_forget_candidates`;the
//     importance verdict from
//     `bas_rust_tracker_atom_importance_scores`。 Swift only maps
//     IDs and writes reversible status transitions。 (Tier moves
//     deliberately reuse the SHIPPED `BASMemoryClosedLoopApplier`
//     loop — chapter 二百五十三 — rather than re-deriving them。)
//   - Gates never auto-promote:the emitted checkpoint is audit
//     evidence for a human;nothing here flips a default。
//   - Window-budget honesty:elapsed time is checked between
//     stages;an exhausted window stops the pipeline and the
//     checkpoint records partial completion honestly。
//
// ## Ledger mark (chain-hash semantics)
//
// Tier moves + quarantines mutate the L8 STORE,not the tracker,
// so the tracker chain hash alone would never distinguish an
// applied pass from a dry-run。 An applied pass therefore records
// ONE tamper-evident ledger entry in the tracker (atomID =
// `consolidationLedgerAtomID`,permitMode `maintenance`),making
// `postChainHash != preChainHash` ⟺ "this pass mutated state"。
// The ledger atomID is excluded from the forget-candidate join so
// the pass never tries to quarantine its own bookkeeping。

import Foundation
import BASMemory
import BASRustCoreBridge

/// Input for one consolidation pass。 Snapshot semantics — the
/// caller enumerates its governed store BEFORE invoking;the pass
/// never mutates the request (immutability doctrine)。
public struct BASSleepConsolidationRequest: Sendable {
    /// Governed-store snapshot:store atomID → current tier。
    public let atomTiers: [String: BASMemoryTier]
    /// Reference clock for scoring recency (deterministic tests
    /// inject a fixed date)。
    public let now: Date
    /// Exponential half-life for the recency factor。
    public let halfLife: TimeInterval
    /// Fraction of distinct atoms to RETAIN (clamped to [0, 1]
    /// in Rust)。 Parameterized — never hardcoded。
    public let retainFraction: Double
    /// Maintenance class granted by the budget frame。
    public let maintenanceClass: BASMaintenanceClass
    /// Maintenance window in milliseconds。 The pass stops early
    /// (honestly) once elapsed time reaches this budget。
    public let windowMs: Int
    /// True ⇒ compute every report but apply nothing。
    public let dryRun: Bool
    /// Compact device-state summary for the checkpoint。
    public let deviceStateSummary: String

    public init(
        atomTiers: [String: BASMemoryTier],
        now: Date,
        halfLife: TimeInterval =
            BASMemorySleepConsolidationPass.defaultHalfLife,
        retainFraction: Double =
            BASMemorySleepConsolidationPass.defaultRetainFraction,
        maintenanceClass: BASMaintenanceClass,
        windowMs: Int,
        dryRun: Bool = false,
        deviceStateSummary: String = ""
    ) {
        self.atomTiers = atomTiers
        self.now = now
        self.halfLife = halfLife
        self.retainFraction = retainFraction
        self.maintenanceClass = maintenanceClass
        self.windowMs = windowMs
        self.dryRun = dryRun
        self.deviceStateSummary = deviceStateSummary
    }
}

/// T3.1 sleep/consolidation orchestrator。 Composes the shipped
/// Rust verdict FFIs + the L8 closed-loop applier + reversible
/// quarantine into one window-bounded,checkpoint-emitting pass。
public actor BASMemorySleepConsolidationPass {

    // MARK: - The ONE gating flag (default-off,ADR-014)

    /// Default-off opt-in for the whole sleep/consolidation
    /// cycle。 Mirrors the `BASMemoryForgetCascadeRunner.
    /// useRoutedFilter` static-flag precedent (the
    /// `BASLanguageAugmentationFeatureFlags` enum is pinned at 5
    /// cases by its test suite,so this flag lives here)。
    /// While false,`runSleepConsolidationIfPermitted` returns
    /// nil WITHOUT constructing this actor — byte-equal by
    /// construction。
    public nonisolated(unsafe) static var
        sleepConsolidationEnabled: Bool = false

    // MARK: - Defaults (anti-magic-number)

    /// Matches `BASRustBrainHistoryStore.atomImportanceScores`
    /// default (24h recency half-life)。
    public static let defaultHalfLife: TimeInterval = 24 * 3600

    /// Matches `BASRustBrainHistoryStore.forgetCandidates`
    /// default (keep top 80% of distinct atoms)。
    public static let defaultRetainFraction: Double = 0.8

    /// Canonical input string for the ledger-mark atomID。
    public static let ledgerInput = "bas.sleep.consolidation.ledger"

    /// Tracker atomID of the ledger mark (canonical SHA256-prefix
    /// derivation — same join algebra as every other atom)。
    public static let consolidationLedgerAtomID: String =
        BASBrainHistoryAtomID.derive(forInput: ledgerInput)

    /// sessionRef stamped on ledger records。
    public static let ledgerSessionRef = "sleep.consolidation"

    /// permitMode stamped on ledger records — distinguishable
    /// from turn verdict modes ("safe"/"warn"/"block")。
    public static let ledgerPermitMode = "maintenance"

    /// Reason code written on every quarantine record。
    public static let quarantineReasonCode =
        "sleep_consolidation_forget_candidate"

    /// Release conditions — mirrors the governance contract in
    /// `EBrainHostRuntime+MemoryService` (manual review only;
    /// never auto-released)。
    public static let quarantineReleaseConditions =
        ["manual_review", "host_reauthorize"]

    // MARK: - Wiring

    private let historyStore: BASRustBrainHistoryStore
    private let ledgerTracker: BASRustMemoryUsageTrackerActor
    private let applier: BASMemoryClosedLoopApplier
    private let store: any BASMemoryAtomStore
    /// Tracker atomID → governed-store atomID join。 Identity by
    /// default:both sides share the `BASBrainHistoryAtomID`
    /// SHA256-prefix derivation。 Hosts with a different store
    /// keying inject their own mapping;nil ⇒ unjoined (recorded,
    /// never acted on)。
    private let storeAtomID: @Sendable (String) -> String?
    /// Clock seam for window-budget measurement (injectable for
    /// deterministic budget-honesty tests)。
    private let clock: @Sendable () -> Date

    public init(
        tracker: BASRustMemoryUsageTrackerActor,
        applier: BASMemoryClosedLoopApplier,
        store: any BASMemoryAtomStore,
        storeAtomID: @escaping @Sendable (String) -> String? =
            { $0 },
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        // The history store is a thin per-call wrapper over the
        // SHARED tracker actor — chain hashes and verdicts are
        // computed over the host's live record set。
        self.historyStore = BASRustBrainHistoryStore(
            tracker: tracker)
        self.ledgerTracker = tracker
        self.applier = applier
        self.store = store
        self.storeAtomID = storeAtomID
        self.clock = clock
    }

    // MARK: - The pass

    /// Run one window-bounded consolidation pass and emit the
    /// checkpoint。 Never throws — every stage failure is caught,
    /// recorded in `failureReasons`,and reflected as partial
    /// completion (errors are reported,not swallowed)。
    public func run(
        _ request: BASSleepConsolidationRequest
    ) async -> BASConsolidationCheckpoint {
        let startedAt = clock()
        var completedStages: [String] = []
        var failureReasons: [String] = []
        var partialCompletion = false

        var preChainHash = ""
        var appliedMutations: [String: BASMemoryTier] = [:]
        var rejectedMutations: [String: BASMemoryTier] = [:]
        // audit memory-b F7 — the scorer's tier-move verdict, captured on BOTH dry-run
        // and applied passes so a dry-run observation is not structurally empty.
        var recommendedTierMoves: [String: BASMemoryTier] = [:]
        var rustImportanceScoreCount = 0
        var forgetCandidateIDs: [String] = []
        var quarantinedAtomIDs: [String] = []
        var unjoinedCandidateIDs: [String] = []
        var quarantineRecords: [BASMemoryQuarantineRecord] = []

        /// True once the maintenance window is spent。 Checked
        /// BETWEEN stages — a stage that started is allowed to
        /// finish (no torn writes)。
        func windowExhausted() -> Bool {
            let elapsedMs = clock()
                .timeIntervalSince(startedAt) * 1000
            return Int(elapsedMs) >= max(0, request.windowMs)
        }

        pipeline: do {
            // ① PRE chain hash — the deterministic checkpoint
            // anchor。 A failure here means the Rust core is
            // unavailable;nothing downstream can run honestly。
            do {
                preChainHash = try await historyStore
                    .integrityChainHashHex()
                completedStages.append(
                    BASConsolidationCheckpoint.Stage.preChainHash)
            } catch {
                failureReasons.append(
                    "pre_chain_hash: \(error)")
                partialCompletion = true
                break pipeline
            }
            if windowExhausted() {
                partialCompletion = true
                break pipeline
            }

            // ② Rust importance verdict (evidence;Rust decides)。
            do {
                let scores = try await historyStore
                    .atomImportanceScores(
                        now: request.now,
                        halfLife: request.halfLife)
                rustImportanceScoreCount = scores.count
                completedStages.append(
                    BASConsolidationCheckpoint.Stage
                        .rustImportanceScores)
            } catch {
                failureReasons.append(
                    "rust_importance_scores: \(error)")
                partialCompletion = true
                break pipeline
            }
            if windowExhausted() {
                partialCompletion = true
                break pipeline
            }

            // ③ Tier moves via the SHIPPED L8 closed loop
            // (dryRun honored;store remains the authority)。
            let applyOutcome = await applier.applyImportanceReport(
                atomTiers: request.atomTiers,
                now: request.now,
                dryRun: request.dryRun)
            appliedMutations = applyOutcome.appliedMutations
            rejectedMutations = applyOutcome.rejectedMutations
            // audit memory-b F7: surface the scorer's recommendation regardless of
            // dryRun — the report is computed either way; a dry-run just doesn't WRITE
            // it. Without this the dry-run checkpoint dropped the entire verdict.
            recommendedTierMoves = Dictionary(
                uniqueKeysWithValues: applyOutcome.report.mutations.map {
                    ($0.atomID, $0.recommendedTier)
                })
            completedStages.append(
                BASConsolidationCheckpoint.Stage.tierApply)
            if windowExhausted() {
                partialCompletion = true
                break pipeline
            }

            // ④ Rust forget verdict。 The ledger-mark atom is
            // excluded — the pass never quarantines its own
            // bookkeeping。
            do {
                forgetCandidateIDs = try await historyStore
                    .forgetCandidates(
                        now: request.now,
                        halfLife: request.halfLife,
                        retainFraction: request.retainFraction)
                    .filter { $0 != Self.consolidationLedgerAtomID }
                completedStages.append(
                    BASConsolidationCheckpoint.Stage
                        .rustForgetCandidates)
            } catch {
                failureReasons.append(
                    "rust_forget_candidates: \(error)")
                partialCompletion = true
                break pipeline
            }
            if windowExhausted() {
                partialCompletion = true
                break pipeline
            }

            // ⑤ QUARANTINE the joined candidates — reversible
            // (`manual_review` release),NEVER remove (亏的不要)。
            // Dry-run skips the writes entirely (the Rust verdict
            // from ④ is still on the checkpoint for inspection)。
            if !request.dryRun {
                for candidateID in forgetCandidateIDs {
                    guard let storeID = storeAtomID(candidateID)
                    else {
                        unjoinedCandidateIDs.append(candidateID)
                        continue
                    }
                    let didQuarantine = await store
                        .updateGovernanceStatus(
                            forID: storeID, to: .quarantined)
                    guard didQuarantine else {
                        unjoinedCandidateIDs.append(candidateID)
                        continue
                    }
                    quarantinedAtomIDs.append(storeID)
                    quarantineRecords.append(
                        BASMemoryQuarantineRecord(
                            quarantineID:
                                "quarantine.sleep.\(storeID)",
                            memoryRef: storeID,
                            reasonCodes:
                                [Self.quarantineReasonCode],
                            lineageCutRef: nil,
                            releaseConditions:
                                Self.quarantineReleaseConditions))
                }
            }
            completedStages.append(
                BASConsolidationCheckpoint.Stage.quarantineWrite)
        }

        // ⑥ Ledger mark — the tamper-evidence ANCHOR. audit M-h F6 (memory-b F6 / hostkit-rest
        // MED-4): this used to sit INSIDE the `pipeline` block after ⑤, so a window-exhaust
        // `break pipeline` after a MUTATING stage (③ tier-apply or ⑤ quarantine) SKIPPED it → the
        // store was mutated but postChainHash == preChainHash, breaking the documented invariant
        // "chain hash moves ⟺ the pass mutated state" (an external tamper that also skipped the mark
        // would then read as clean). It now runs OUTSIDE the window budget (exactly like the
        // post-chain-hash below): a single cheap tracker append that ALWAYS fires when the pass
        // mutated state, wherever the pipeline stopped. Dry-runs / no-op passes write nothing.
        let didMutate = !appliedMutations.isEmpty
            || !quarantinedAtomIDs.isEmpty
        if !request.dryRun && didMutate {
            do {
                let nowMs = Int(
                    request.now.timeIntervalSince1970 * 1000)
                let turnRef = "consolidation.\(nowMs)"
                _ = try await ledgerTracker.record(
                    atomID: Self.consolidationLedgerAtomID,
                    sessionRef: Self.ledgerSessionRef,
                    turnRef: turnRef,
                    permitMode: Self.ledgerPermitMode,
                    retrievedAt: request.now)
                completedStages.append(
                    BASConsolidationCheckpoint.Stage.ledgerMark)
            } catch {
                failureReasons.append("ledger_mark: \(error)")
                partialCompletion = true
            }
        }

        // POST chain hash — always attempted at emission so the
        // checkpoint reflects the ACTUAL tracker state,even for
        // partial passes (emission is outside the budgeted
        // mutation stages;a partial pass still deserves an
        // honest anchor)。
        var postChainHash = ""
        do {
            postChainHash = try await historyStore
                .integrityChainHashHex()
            completedStages.append(
                BASConsolidationCheckpoint.Stage.postChainHash)
        } catch {
            failureReasons.append("post_chain_hash: \(error)")
            partialCompletion = true
        }

        return BASConsolidationCheckpoint(
            preChainHash: preChainHash,
            postChainHash: postChainHash,
            appliedMutations: appliedMutations,
            rejectedMutations: rejectedMutations,
            recommendedTierMoves: recommendedTierMoves,
            forgetCandidateAtomIDs: forgetCandidateIDs,
            quarantinedAtomIDs: quarantinedAtomIDs,
            unjoinedForgetCandidateAtomIDs: unjoinedCandidateIDs,
            quarantineRecords: quarantineRecords,
            rustImportanceScoreCount: rustImportanceScoreCount,
            maintenanceClass: request.maintenanceClass.rawValue,
            windowMs: request.windowMs,
            dryRun: request.dryRun,
            completedStages: completedStages,
            partialCompletion: partialCompletion,
            failureReasons: failureReasons,
            deviceStateSummary: request.deviceStateSummary,
            startedAt: startedAt,
            finishedAt: clock())
    }
}
