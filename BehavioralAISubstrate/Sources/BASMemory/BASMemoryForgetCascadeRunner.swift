import Foundation
import BASRuntimeCore

// chapter 七百十七 第一刀 / M2256 — Per matrix「Rust:forget
// cascade」 the partition primitive lives in
// bas-retrieval-ranker (chapter 七百十三 第一刀)。 The
// `useRoutedFilter` feature flag below gates whether the
// production `apply()` method routes its set-partition through
// the Rust C ABI。 Per chapter 七百十六 lesson:flip only when
// chapter 七百十七 第二刀 perf measurement shows Rust wins for
// typical cascade sizes (rootTargets ~1-10, dependentRefs
// ~0-50, records ~10-1000)。

/// M101 — `BASMemoryForgetCascadeRunner`: substrate-side pure-value
/// executor for L8 forget cascades.
///
/// ## Why this exists
///
/// Plan `l2-silly-piglet.md` §T5 ("L8 Sanctum Vault operator
/// workflow + ForgetCascade 真实执行") calls for "a runnable
/// `BASMemoryForgetCascade` runner that actually removes atoms
/// from the atom store". Pre-M101 the substrate had a
/// `BASMemoryForgetCascade` schema with a free-text
/// `executionState: String` and **no runner** —— callers that
/// wanted to execute a cascade had to hand-roll the record
/// mutation + deduplication + state transition themselves.
///
/// M101 lands a pure-function runner in the M94 discipline
/// (typed execution-state enum + pure-value transform + no
/// runtime integration beyond the substrate). A sovereign-lock
/// gate sits at the composition layer (future M102+) — substrate
/// runner is value-type-only, does not consult sovereign state.
///
/// ## What it does
///
/// `apply(_:to:now:)` takes a cascade + a `BASTemporalMemoryField`
/// and returns:
///   1. A new field with the cascade's `rootTargets` +
///      `dependentRefs` scrubbed from the `records` collection.
///   2. An updated cascade value stamped with `.completed` (or
///      `.skipped` when nothing matched) and the list of
///      successfully removed record IDs.
///
/// The runner is **pure**: same inputs → same outputs, no global
/// state, no I/O. Host-side orchestration (sovereign lock check,
/// audit ledger append, L14 LINEAGE_CUT marker) is the caller's
/// responsibility — the runner just transforms the data.
///
/// ## DAG discipline
///
/// Pure `Foundation` + `BASRuntimeCore`-visible schema. No Qinao
/// imports. No actor. No async. Composition layer
/// (`EBrainHostRuntime+MemoryService`) can wrap the runner in an
/// actor for thread safety; the runner itself stays pure so tests
/// and audit replays can reason about it without concurrency
/// overhead.

// MARK: - BASForgetCascadeExecutionState

/// Typed lifecycle state for a forget-cascade runner outcome.
///
/// Stable raw values that cross-layer consumers can key on without
/// importing the substrate. Parallels
/// `BASRetractionExecutionState` (M94) — same 5-state machine,
/// distinct typed surface for forget-cascade audit trails.
public enum BASForgetCascadeExecutionState:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// The cascade is queued but has not started. Present so
    /// callers can initialize a cascade from schema + transition
    /// through the runner deterministically.
    case queued = "queued"
    /// The runner picked up the cascade and is in the middle of
    /// applying it.
    case inFlight = "in-flight"
    /// The cascade finished successfully — at least one target
    /// was removed.
    case completed = "completed"
    /// The runner ran but found no matching records — the cascade
    /// was a no-op. Distinguished from `.completed` so audit
    /// surfaces can tell "removed something" from "wanted to
    /// remove but nothing matched".
    case skipped = "skipped"
    /// The runner could not apply the cascade (e.g. the cascade
    /// was malformed). `reasonCodes` on the outcome carries the
    /// why.
    case failed = "failed"

    /// Whether this state is terminal (the cascade cannot be
    /// transitioned out of this state).
    public var isTerminal: Bool {
        switch self {
        case .queued, .inFlight: return false
        case .completed, .skipped, .failed: return true
        }
    }
}

// MARK: - BASForgetCascadeOutcome

/// Pure-value report of a single `apply(...)` invocation. Carries
/// the updated cascade, the list of record IDs that were actually
/// removed, and timing metadata. Pure `Codable` so audit pipelines
/// can stream it into the ledger alongside a `LINEAGE_CUT` marker.
public struct BASForgetCascadeOutcome: BASSchemaVersioned, Equatable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// The cascade after state transition — `executionState`
    /// reflects the terminal state chosen by the runner.
    public var cascade: BASMemoryForgetCascade
    /// Typed terminal state the runner decided.
    public var terminalState: BASForgetCascadeExecutionState
    /// Record IDs (matching `BASTemporalMemoryRecord.memoryID`)
    /// that were actually removed from the input field. Empty
    /// when `terminalState == .skipped` or `.failed`.
    // blindspot LOW id10: the field is `memoryID`, not `recordID`
    // (recordID belongs to the distinct SQL usage-tracker record type).
    public var removedRecordIDs: [String]
    /// Free-text reason codes — e.g. `"nothing-to-remove"` when
    /// `.skipped`, or `"target-id-not-found"` when `.failed`.
    public var reasonCodes: [String]
    /// When the runner started the apply.
    public var startedAt: Date
    /// When the runner finished the apply.
    public var finishedAt: Date

    public init(
        schemaVersion: String
            = BASForgetCascadeOutcome.currentSchemaVersion,
        cascade: BASMemoryForgetCascade,
        terminalState: BASForgetCascadeExecutionState,
        removedRecordIDs: [String] = [],
        reasonCodes: [String] = [],
        startedAt: Date,
        finishedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.cascade = cascade
        self.terminalState = terminalState
        self.removedRecordIDs = removedRecordIDs
        self.reasonCodes = reasonCodes
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

// MARK: - BASMemoryForgetCascadeRunner

/// Pure-function forget-cascade executor. Value-type; every call
/// returns new values, no internal state.
///
/// The runner matches cascade targets (`rootTargets` +
/// `dependentRefs`) against the record IDs in the supplied
/// `BASTemporalMemoryField.records` and emits a new field with
/// the matched records removed. The input field is never
/// mutated — callers threading the field through a pipeline can
/// safely share references.
public struct BASMemoryForgetCascadeRunner: Sendable {
    public init() {}

    /// chapter 七百十七 第一刀 — opt-in feature flag。 When ON,
    /// `apply()` routes the set-partition step through
    /// `BASAutoRouteRanker.forgetCascadeFilter` (Rust C ABI)
    /// instead of the inline `Set<String>` partition。
    ///
    /// Default `false` preserves the V1 byte-pinned Swift path。
    /// The byte-equality test in
    /// `BASChapter717ForgetCascadeByteEqualityTests` proves
    /// both paths produce identical (remainingRecords,
    /// removedIDs) for any input。
    ///
    /// chapter 八百八十一 / M3090 — DECLINE-WITH-TRIGGER。
    /// Knife 1 LIVE measurement on Mac mini (2026-05-23) ran
    /// the Swift Set partition vs Rust C ABI at production
    /// grid (records ∈ {10, 100, 1K, 10K} × targets ∈
    /// {1, 10, 100, 1K} × hit ∈ {10%, 50%, 100%})。 Swift won
    /// EVERY shape by 2-3× (e.g. 10K×1K: Swift 1.79ms vs Rust
    /// 4.62ms = Swift 2.58× faster)。 Root cause:string FFI
    /// encode/decode + HashMap rebuild costs dominate at
    /// every production size。 Per 「亏的不要硬上」 discipline,
    /// chapter 881 PINS the decline (same pattern as ch
    /// 874/875 RoPE/RMSNorm decline-pending-consumer)。
    ///
    /// Trigger conditions for future re-evaluation:
    ///   (a) Batched-cascade API where N cascades amortize the
    ///       FFI hop in a single call。
    ///       **Chapter 八百八十五 / M3115 status update**:
    ///       implemented as `forget_cascade_filter_batch_rayon`
    ///       in `bas-retrieval-ranker/src/forget_cascade.rs`
    ///       (pure-Rust crate-level)。 Measurement: rayon CAN win
    ///       at batch ≥ ~512 cascades per call (2.69× over
    ///       sequential at batch=1024,2.28× over Swift)。 But
    ///       the substrate processes ONE cascade per turn — no
    ///       batching consumer exists。 Crate-level Rust kernel
    ///       SHIPPED + audit pin + 3 consumer-side triggers
    ///       documented (see `BASChapter885
    ///       BatchedCascadePendingConsumerAuditTests`)。 Net
    ///       result for trigger (a):partially satisfied (Rust
    ///       infra exists) but consumer-pressure trigger not
    ///       fired,so per-call default stays Swift。
    ///   (b) Numeric ID encoding (UInt64 not String) — removes
    ///       UTF-8 encode/decode work
    ///   (c) Forget cascade sizes exceed 100K × 10K (orders
    ///       of magnitude beyond measured grid)
    ///
    /// `BASChapter881ForgetCascadeDeclineAuditTests` pins the
    /// decline + trigger conditions。 `BASChapter881
    /// ForgetCascadeBaselineTests` (skip-by-default) holds
    /// the measurement file for future re-runs。
    public nonisolated(unsafe) static var useRoutedFilter:
        Bool = false

    /// Apply a forget cascade to a memory field.
    ///
    /// Behavior:
    ///
    /// 1. **Validation (pre-flight)** — empty `rootTargets` AND
    ///    empty `dependentRefs` → return `.failed` with reason
    ///    `"empty-cascade-targets"`, field unchanged.
    /// 2. **No-match short-circuit** — cascade has targets but
    ///    none match any record in the field → `.skipped` with
    ///    reason `"nothing-to-remove"`, field unchanged.
    /// 3. **Happy path** — at least one target matched a record
    ///    → remove those records from the field, return
    ///    `.completed` with the list of removed IDs and an
    ///    updated cascade.
    ///
    /// The "target ID" vs "record ID" matching uses
    /// `BASTemporalMemoryRecord.memoryID` against the union of
    /// `cascade.rootTargets + cascade.dependentRefs`.
    ///
    /// - Parameters:
    ///   - cascade: the cascade to apply. Input is not mutated;
    ///     `outcome.cascade` carries the updated copy.
    ///   - field: the memory field to transform. Input is not
    ///     mutated; return tuple's `.field` is the new copy.
    ///   - now: clock for `startedAt` / `finishedAt`. Defaults to
    ///     `Date()` but injectable for deterministic tests.
    ///
    /// - Returns: `(field: BASTemporalMemoryField, outcome:
    ///   BASForgetCascadeOutcome)` — pure pair; caller threads
    ///   the new field forward, caller writes the outcome into
    ///   audit pipelines.
    public func apply(
        _ cascade: BASMemoryForgetCascade,
        to field: BASTemporalMemoryField,
        now: @escaping () -> Date = { Date() }
    ) -> (
        field: BASTemporalMemoryField,
        outcome: BASForgetCascadeOutcome
    ) {
        let startedAt = now()

        // Pre-flight: empty cascade is a bug — fail fast with a
        // stable reason so the caller's audit surface can key on
        // it.
        if cascade.rootTargets.isEmpty
            && cascade.dependentRefs.isEmpty {
            let finishedAt = now()
            var failedCascade = cascade
            failedCascade.executionState =
                BASForgetCascadeExecutionState.failed.rawValue
            return (
                field: field,
                outcome: BASForgetCascadeOutcome(
                    cascade: failedCascade,
                    terminalState: .failed,
                    reasonCodes: ["empty-cascade-targets"],
                    startedAt: startedAt,
                    finishedAt: finishedAt))
        }

        // chapter 七百十七 第一刀 / M2256 — partition routes
        // either through the Rust forgetCascadeFilter (when
        // flag on) or through the inline Swift Set<String>
        // partition (legacy default)。 Both paths produce
        // (remainingRecords,removedIDs) with identical
        // insertion-order semantics — pinned by
        // BASChapter717ForgetCascadeByteEqualityTests。
        //
        // LEGACY PATH (kept,unchanged when flag is off):
        //     var targetIDs = Set<String>()
        //     for id in cascade.rootTargets {
        //         targetIDs.insert(id) }
        //     for id in cascade.dependentRefs {
        //         targetIDs.insert(id) }
        //     for record in field.records {
        //         if targetIDs.contains(record.memoryID) {
        //             removedIDs.append(record.memoryID)
        //         } else { remainingRecords.append(record) }
        //     }
        var remainingRecords: [BASTemporalMemoryRecord] = []
        var removedIDs: [String] = []
        remainingRecords.reserveCapacity(field.records.count)
        if Self.useRoutedFilter {
            // Route through Rust C ABI。 Build ID arrays once,
            // partition once,then materialize record slices。
            let recordIDs = field.records.map {
                $0.memoryID }
            var targetIDsArray = cascade.rootTargets
            targetIDsArray.append(
                contentsOf: cascade.dependentRefs)
            let r = BASAutoRouteRanker.forgetCascadeFilter(
                recordIds: recordIDs,
                targetIds: targetIDsArray)
            removedIDs.reserveCapacity(
                r.value.removed.count)
            for i in r.value.kept {
                remainingRecords.append(
                    field.records[i])
            }
            for i in r.value.removed {
                removedIDs.append(recordIDs[i])
            }
        } else {
            // Inline Set<String> partition — legacy path。
            var targetIDs = Set<String>()
            for id in cascade.rootTargets {
                targetIDs.insert(id)
            }
            for id in cascade.dependentRefs {
                targetIDs.insert(id)
            }
            for record in field.records {
                if targetIDs.contains(record.memoryID) {
                    removedIDs.append(record.memoryID)
                } else {
                    remainingRecords.append(record)
                }
            }
        }

        // No-match short-circuit: field is unchanged; cascade is
        // marked skipped so the audit surface sees "ran but
        // no-op".
        if removedIDs.isEmpty {
            let finishedAt = now()
            var skippedCascade = cascade
            skippedCascade.executionState =
                BASForgetCascadeExecutionState.skipped.rawValue
            return (
                field: field,
                outcome: BASForgetCascadeOutcome(
                    cascade: skippedCascade,
                    terminalState: .skipped,
                    reasonCodes: ["nothing-to-remove"],
                    startedAt: startedAt,
                    finishedAt: finishedAt))
        }

        // Happy path: build new field with matched records
        // removed. Every other collection on the field
        // (temperatureProfiles / provenanceSeals / episodeArcs /
        // etc.) is preserved byte-for-byte. The cascade itself
        // stays in `forgetCascades` (caller decides whether to
        // prune it after audit) — the runner does not self-delete.
        let newField = BASTemporalMemoryField(
            schemaVersion: field.schemaVersion,
            records: remainingRecords,
            temperatureProfiles: field.temperatureProfiles,
            provenanceSeals: field.provenanceSeals,
            episodeArcs: field.episodeArcs,
            conflictClusters: field.conflictClusters,
            continuityAnchors: field.continuityAnchors,
            replayFrames: field.replayFrames,
            quarantineRecords: field.quarantineRecords,
            sanctumEntries: field.sanctumEntries,
            forgetCascades: field.forgetCascades)

        let finishedAt = now()
        var completedCascade = cascade
        completedCascade.executionState =
            BASForgetCascadeExecutionState.completed.rawValue
        return (
            field: newField,
            outcome: BASForgetCascadeOutcome(
                cascade: completedCascade,
                terminalState: .completed,
                removedRecordIDs: removedIDs,
                reasonCodes: [],
                startedAt: startedAt,
                finishedAt: finishedAt))
    }
}
