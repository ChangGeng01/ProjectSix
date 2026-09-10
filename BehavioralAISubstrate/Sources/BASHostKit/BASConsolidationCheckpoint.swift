// MARK: - BASConsolidationCheckpoint — T3.1 sleep/consolidation cycle
//
// Codable audit artifact emitted by ONE
// `BASMemorySleepConsolidationPass.run(_:)` invocation。 This is
// the OFF-TURN evidence surface for the sleep/consolidation
// cycle:it is NEVER written into `BASEBrainTurnResult`,so the
// pinned replay digest (`ebrain-turn-result-json-sha256-
// sortedKeys-utf8`,ADR-014) is unaffected by construction。
//
// ## Doctrine pins
//
//   - Gates never auto-promote:the checkpoint is printed /
//     recorded for a HUMAN to read。 Nothing consumes it to flip
//     a default。
//   - 亏的不要:`quarantinedAtomIDs` lists atoms moved to
//     `.quarantined` (reversible,`manual_review` release) —
//     the pass NEVER removes。 There is deliberately no
//     "removedAtomIDs" field。
//   - Window-budget honesty:`partialCompletion` +
//     `completedStages` record exactly how far the pass got
//     before the maintenance window closed — a partial pass is
//     reported as partial,never dressed up as complete。
//
// ## Chain-hash semantics
//
// `preChainHash` / `postChainHash` are the Rust tracker's
// SHA256 chain hash (`BASRustBrainHistoryStore.
// integrityChainHashHex`)。 An APPLIED pass leaves one ledger
// record in the tracker (the "ledger mark"),so
// `postChainHash != preChainHash` ⟺ the pass actually mutated
// something。 A dry-run writes nothing → the two hashes match。

import Foundation
import BASMemory

/// Codable checkpoint for one sleep/consolidation pass。
/// Off-turn surface only — never part of the turn result。
public struct BASConsolidationCheckpoint:
    Codable, Sendable, Equatable
{
    /// Stable stage names,in pipeline order。 `completedStages`
    /// holds a prefix-plus-postHash subset of these。
    public enum Stage {
        public static let preChainHash = "pre_chain_hash"
        public static let rustImportanceScores =
            "rust_importance_scores"
        public static let tierApply = "tier_apply"
        public static let rustForgetCandidates =
            "rust_forget_candidates"
        public static let quarantineWrite = "quarantine_write"
        public static let ledgerMark = "ledger_mark"
        public static let postChainHash = "post_chain_hash"
    }

    /// Rust tracker chain hash BEFORE any mutation stage ran。
    /// Empty when the pre-hash stage itself failed。
    public let preChainHash: String

    /// Rust tracker chain hash at checkpoint emission。 Equal to
    /// `preChainHash` for dry-run / no-op passes;different when
    /// the ledger mark recorded an applied pass。
    public let postChainHash: String

    /// Tier mutations the L8 store accepted
    /// (store atomID → new tier)。 Empty on dry-run。
    public let appliedMutations: [String: BASMemoryTier]

    /// Tier mutations the report recommended but the store
    /// rejected (atom absent at apply time)。
    public let rejectedMutations: [String: BASMemoryTier]

    /// The importance scorer's tier-move VERDICT (atomID → recommended tier),
    /// recorded on BOTH dry-run and applied passes (audit memory-b F7 / hostkit-rest
    /// MED-4). Before this, a dry-run's `appliedMutations`/`rejectedMutations` were
    /// both empty (nothing is written on a dry-run), so the checkpoint carried
    /// STRUCTURALLY-ZERO information about what the pass observed — the whole point of
    /// a dry-run (see what WOULD move) was lost. This surfaces the scorer's actual
    /// recommendation so an observation reflects the real universe without writing.
    public let recommendedTierMoves: [String: BASMemoryTier]

    /// Rust forget verdict (tracker atomIDs,score-ascending
    /// candidates below the retain threshold)。 Recorded even on
    /// dry-run — Rust decides,Swift executes (ch881)。
    public let forgetCandidateAtomIDs: [String]

    /// Store atomIDs actually moved to `.quarantined`
    /// (reversible)。 Empty on dry-run。
    public let quarantinedAtomIDs: [String]

    /// Forget candidates that could not be joined to a governed
    /// store atom (no mapping,or atom absent)。 Observability —
    /// these were NOT acted on。
    public let unjoinedForgetCandidateAtomIDs: [String]

    /// One governance record per quarantined atom,carrying the
    /// `manual_review` release condition (chapter governance
    /// contract — quarantine is released only by manual review /
    /// host reauthorization,never automatically)。
    public let quarantineRecords: [BASMemoryQuarantineRecord]

    /// Count of Rust importance-score entries computed (evidence
    /// the Rust scorer ran;the full entries stay off-checkpoint
    /// to keep the artifact small)。
    public let rustImportanceScoreCount: Int

    /// Maintenance class the budget frame granted this pass。
    public let maintenanceClass: String

    /// Maintenance window (ms) the pass was given。
    public let windowMs: Int

    /// True iff this pass computed reports but applied nothing。
    public let dryRun: Bool

    /// Stage names that COMPLETED,in execution order。
    public let completedStages: [String]

    /// True iff the pass stopped before the full pipeline ran
    /// (window exhausted or a stage failed)。
    public let partialCompletion: Bool

    /// Human-readable per-stage failure descriptions (empty on a
    /// clean pass)。 Never silently swallowed。
    public let failureReasons: [String]

    /// Compact device-state summary at invocation time
    /// (foreground / thermal / battery / charging)。
    public let deviceStateSummary: String

    public let startedAt: Date
    public let finishedAt: Date

    public init(
        preChainHash: String,
        postChainHash: String,
        appliedMutations: [String: BASMemoryTier],
        rejectedMutations: [String: BASMemoryTier],
        recommendedTierMoves: [String: BASMemoryTier] = [:],
        forgetCandidateAtomIDs: [String],
        quarantinedAtomIDs: [String],
        unjoinedForgetCandidateAtomIDs: [String],
        quarantineRecords: [BASMemoryQuarantineRecord],
        rustImportanceScoreCount: Int,
        maintenanceClass: String,
        windowMs: Int,
        dryRun: Bool,
        completedStages: [String],
        partialCompletion: Bool,
        failureReasons: [String],
        deviceStateSummary: String,
        startedAt: Date,
        finishedAt: Date
    ) {
        self.preChainHash = preChainHash
        self.postChainHash = postChainHash
        self.appliedMutations = appliedMutations
        self.rejectedMutations = rejectedMutations
        self.recommendedTierMoves = recommendedTierMoves
        self.forgetCandidateAtomIDs = forgetCandidateAtomIDs
        self.quarantinedAtomIDs = quarantinedAtomIDs
        self.unjoinedForgetCandidateAtomIDs =
            unjoinedForgetCandidateAtomIDs
        self.quarantineRecords = quarantineRecords
        self.rustImportanceScoreCount = rustImportanceScoreCount
        self.maintenanceClass = maintenanceClass
        self.windowMs = windowMs
        self.dryRun = dryRun
        self.completedStages = completedStages
        self.partialCompletion = partialCompletion
        self.failureReasons = failureReasons
        self.deviceStateSummary = deviceStateSummary
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    // audit memory-b F7 — byte-stable decode: a checkpoint LOGGED before
    // `recommendedTierMoves` existed omits the key; it decodes to `[:]` rather than
    // failing (the synthesized Decodable would throw on the missing key). `encode`
    // stays synthesized, so new checkpoints round-trip the field.
    private enum CodingKeys: String, CodingKey {
        case preChainHash, postChainHash, appliedMutations, rejectedMutations
        case recommendedTierMoves, forgetCandidateAtomIDs, quarantinedAtomIDs
        case unjoinedForgetCandidateAtomIDs, quarantineRecords, rustImportanceScoreCount
        case maintenanceClass, windowMs, dryRun, completedStages, partialCompletion
        case failureReasons, deviceStateSummary, startedAt, finishedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preChainHash = try c.decode(String.self, forKey: .preChainHash)
        postChainHash = try c.decode(String.self, forKey: .postChainHash)
        appliedMutations = try c.decode([String: BASMemoryTier].self, forKey: .appliedMutations)
        rejectedMutations = try c.decode([String: BASMemoryTier].self, forKey: .rejectedMutations)
        recommendedTierMoves = try c.decodeIfPresent(
            [String: BASMemoryTier].self, forKey: .recommendedTierMoves) ?? [:]
        forgetCandidateAtomIDs = try c.decode([String].self, forKey: .forgetCandidateAtomIDs)
        quarantinedAtomIDs = try c.decode([String].self, forKey: .quarantinedAtomIDs)
        unjoinedForgetCandidateAtomIDs = try c.decode(
            [String].self, forKey: .unjoinedForgetCandidateAtomIDs)
        quarantineRecords = try c.decode(
            [BASMemoryQuarantineRecord].self, forKey: .quarantineRecords)
        rustImportanceScoreCount = try c.decode(Int.self, forKey: .rustImportanceScoreCount)
        maintenanceClass = try c.decode(String.self, forKey: .maintenanceClass)
        windowMs = try c.decode(Int.self, forKey: .windowMs)
        dryRun = try c.decode(Bool.self, forKey: .dryRun)
        completedStages = try c.decode([String].self, forKey: .completedStages)
        partialCompletion = try c.decode(Bool.self, forKey: .partialCompletion)
        failureReasons = try c.decode([String].self, forKey: .failureReasons)
        deviceStateSummary = try c.decode(String.self, forKey: .deviceStateSummary)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        finishedAt = try c.decode(Date.self, forKey: .finishedAt)
    }

    /// True iff the pass changed anything at all (tier moves or
    /// quarantines)。 Drives the ledger-mark decision。
    public var didMutate: Bool {
        !appliedMutations.isEmpty || !quarantinedAtomIDs.isEmpty
    }
}
