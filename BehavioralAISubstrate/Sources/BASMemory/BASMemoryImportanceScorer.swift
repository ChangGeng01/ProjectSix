// MARK: - BASMemoryImportanceScorer — chapter 二百五十二 / M739
//
// L8 importance scoring — Stage 1 Step 2 of 3
// (Memory Importance Loop).
//
// ## Why this exists
//
// chapter 二百五十一 (M738) shipped `BASMemoryUsageTracker` —
// the typed retrieval-event log. The scorer is the next link in
// the closed loop: read the log, compute per-atom importance
// scores, recommend tier promotion / demotion. The L8 retrieval
// integration (chapter 二百五十三) wires both.
//
// Pre-chapter 二百五十二 the L8 atom store could mutate tiers via
// `BASMemoryAtomStore.updateTier(forID:to:)` but **nothing
// generated tier change recommendations from usage data**. The
// existing reconciler (M21) emits transitions only on contamination
// / quarantine / eviction signals — not on "hot atom needs
// promotion to keep retrieval fast".
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: scorer is a **pure function**.
//     No side effects. No actor. No persist. The host that owns
//     the atom store applies recommendations or rejects them per
//     its own policy (which still respects every existing L8
//     governance gate).
//   - 红线 7 watcher-only-hint: `recommendedTier` is a HINT.
//     `BASMemoryImportanceReport.scores[].recommendedTier` is
//     observability — the host runtime decides whether to apply
//     it. Auto-application is up to the integration site (chapter
//     二百五十三 wires it through `updateTier` with policy gates).
//   - chapter 二百十一 single-source-of-truth: the score struct
//     and the scorer struct live in this one file. The data they
//     consume (`BASMemoryUsageRecord`) lives in the tracker file
//     (chapter 二百五十一).
//
// ## Score formula
//
// Total score is a weighted geometric mean of four components,
// each clamped to [0, 1]:
//
//   - **recency**: `exp(-(now - mostRecent) / halfLife)`. Newer
//     retrievals weigh more. Default half-life = 1 day; a recall
//     1 day ago contributes 0.5; 2 days ago contributes 0.25.
//   - **frequency**: `min(1, log10(1 + count) / log10(1 + sat))`.
//     More retrievals = higher, log-saturated so 1000 retrievals
//     and 100 retrievals look more similar than 10 vs 1. Default
//     saturation = 50 retrievals.
//   - **helped**: `(helped + 0.5 * unknown) / (helped + notHelped
//     + unknown)`. Explicit helped events boost; explicit
//     notHelped events depress; unknown is half-credit. Empty
//     usage = 0.5 (neutral).
//   - **tierDecay**: tier-aware decay constant — defaults
//     `[hot: 1.0, warm: 0.7, cold: 0.4]`. Higher-tier atoms get a
//     small boost to their score so they don't get demoted by
//     short usage gaps; cold atoms need stronger usage signal to
//     promote.
//
// Recommended tier:
//   - `total >= promoteThreshold` AND currentTier != .hot:
//     bump up one tier (cold → warm, warm → hot).
//   - `total <= demoteThreshold` AND currentTier != .cold:
//     bump down one tier (hot → warm, warm → cold).
//   - otherwise: hold.

import Foundation

/// One importance score for one atom, derived from usage history.
/// Pure value type — instantiated by the scorer, consumed by the
/// host runtime when it decides whether to apply tier mutations.
public struct BASMemoryImportanceScore: Sendable, Equatable,
    Codable, Hashable
{
    public let atomID: String
    public let currentTier: BASMemoryTier
    public let recencyComponent: Double
    public let frequencyComponent: Double
    public let helpedComponent: Double
    public let tierDecayComponent: Double
    public let totalScore: Double
    public let recommendedTier: BASMemoryTier
    public let recordCount: Int
    public let computedAt: Date

    public init(
        atomID: String,
        currentTier: BASMemoryTier,
        recencyComponent: Double,
        frequencyComponent: Double,
        helpedComponent: Double,
        tierDecayComponent: Double,
        totalScore: Double,
        recommendedTier: BASMemoryTier,
        recordCount: Int,
        computedAt: Date = Date()
    ) {
        self.atomID = atomID
        self.currentTier = currentTier
        self.recencyComponent = recencyComponent
        self.frequencyComponent = frequencyComponent
        self.helpedComponent = helpedComponent
        self.tierDecayComponent = tierDecayComponent
        self.totalScore = totalScore
        self.recommendedTier = recommendedTier
        self.recordCount = recordCount
        self.computedAt = computedAt
    }

    /// True iff `recommendedTier != currentTier`. Hosts use this
    /// to filter the report down to just the tickets that would
    /// produce a mutation.
    public var changesTier: Bool {
        recommendedTier != currentTier
    }
}

/// Aggregate report covering every atom that had at least one
/// usage record.
public struct BASMemoryImportanceReport: Sendable, Equatable,
    Codable
{
    public let scores: [BASMemoryImportanceScore]
    public let promotionCount: Int
    public let demotionCount: Int
    public let holdCount: Int
    public let computedAt: Date

    public init(
        scores: [BASMemoryImportanceScore],
        computedAt: Date = Date()
    ) {
        self.scores = scores
        self.computedAt = computedAt
        var promo = 0
        var demo = 0
        var hold = 0
        for s in scores {
            switch (s.currentTier, s.recommendedTier) {
            case (.cold, .warm), (.cold, .hot),
                 (.warm, .hot):
                promo += 1
            case (.hot, .warm), (.hot, .cold),
                 (.warm, .cold):
                demo += 1
            default:
                hold += 1
            }
        }
        self.promotionCount = promo
        self.demotionCount = demo
        self.holdCount = hold
    }

    /// Atoms whose recommended tier differs from current.
    public var mutations: [BASMemoryImportanceScore] {
        scores.filter { $0.changesTier }
    }
}

/// Pure-function scorer. Construct once with thresholds + decay
/// params; reuse forever. Stateless / Sendable / immutable.
public struct BASMemoryImportanceScorer: Codable, Sendable, Equatable,
    Hashable
{
    /// Default tunables. Hosts override per their workload.
    public static let defaultPromoteThreshold: Double = 0.65
    public static let defaultDemoteThreshold: Double = 0.20
    public static let defaultRecencyHalfLifeSeconds: Double =
        86_400  // 1 day
    public static let defaultFrequencySaturation: Double = 50
    public static let defaultTierDecayHot: Double = 1.0
    public static let defaultTierDecayWarm: Double = 0.7
    public static let defaultTierDecayCold: Double = 0.4

    public let promoteThreshold: Double
    public let demoteThreshold: Double
    public let recencyHalfLifeSeconds: Double
    public let frequencySaturation: Double
    public let tierDecayHot: Double
    public let tierDecayWarm: Double
    public let tierDecayCold: Double

    public init(
        promoteThreshold: Double =
            BASMemoryImportanceScorer.defaultPromoteThreshold,
        demoteThreshold: Double =
            BASMemoryImportanceScorer.defaultDemoteThreshold,
        recencyHalfLifeSeconds: Double =
            BASMemoryImportanceScorer
                .defaultRecencyHalfLifeSeconds,
        frequencySaturation: Double =
            BASMemoryImportanceScorer
                .defaultFrequencySaturation,
        tierDecayHot: Double =
            BASMemoryImportanceScorer.defaultTierDecayHot,
        tierDecayWarm: Double =
            BASMemoryImportanceScorer.defaultTierDecayWarm,
        tierDecayCold: Double =
            BASMemoryImportanceScorer.defaultTierDecayCold
    ) {
        // Clamp every parameter to a sensible range so misuse
        // doesn't produce NaN scores.
        self.promoteThreshold =
            Self.clamp(promoteThreshold, lo: 0, hi: 1)
        self.demoteThreshold =
            Self.clamp(demoteThreshold, lo: 0, hi: 1)
        self.recencyHalfLifeSeconds =
            max(1, recencyHalfLifeSeconds)
        self.frequencySaturation =
            max(1, frequencySaturation)
        self.tierDecayHot =
            Self.clamp(tierDecayHot, lo: 0, hi: 1)
        self.tierDecayWarm =
            Self.clamp(tierDecayWarm, lo: 0, hi: 1)
        self.tierDecayCold =
            Self.clamp(tierDecayCold, lo: 0, hi: 1)
    }

    /// Score one atom from its usage history. Pure function — no
    /// state. `records` should be filtered to entries belonging
    /// to `atomID`; passing extras inflates the count component.
    public func score(
        atomID: String,
        currentTier: BASMemoryTier,
        records: [BASMemoryUsageRecord],
        now: Date = Date()
    ) -> BASMemoryImportanceScore {
        let recency = recencyComponent(records: records, now: now)
        let frequency = frequencyComponent(records: records)
        let helped = helpedComponent(records: records)
        let tierDecay = tierDecayComponent(for: currentTier)

        // Weighted geometric-mean style: product of (1+ε)
        // components, then root-4.
        let epsilon = 0.0001
        let product =
            (recency + epsilon) *
            (frequency + epsilon) *
            (helped + epsilon) *
            (tierDecay + epsilon)
        let raw = pow(product, 0.25)
        let geometricTotal = Self.clamp(raw, lo: 0, hi: 1)

        // audit blindspot-③ HIGH: a brand-new atom has NO usage records, so recency/frequency/helped
        // are all 0 and the geometric mean collapses to ~0.001 (NEAR-MIN) despite the +ε — the +ε only
        // prevents a hard 0, it does NOT lift the mean to the "neutral" the old comment claimed. So a
        // fresh atom was scored near-min and recommended for DEMOTION on arrival, before it could ever
        // be used. With zero usage the importance is genuinely UNKNOWN, so keep the promise: a
        // no-history atom STAYS in its current tier (never demoted on arrival) and reports a neutral
        // total; once usage accrues, the geometric score governs as before.
        let hasHistory = !records.isEmpty
        let total = hasHistory ? geometricTotal : 0.5
        let recommended = hasHistory
            ? recommendedTier(for: currentTier, total: geometricTotal)
            : currentTier

        return BASMemoryImportanceScore(
            atomID: atomID,
            currentTier: currentTier,
            recencyComponent: recency,
            frequencyComponent: frequency,
            helpedComponent: helped,
            tierDecayComponent: tierDecay,
            totalScore: total,
            recommendedTier: recommended,
            recordCount: records.count,
            computedAt: now)
    }

    /// Score every atom that appears in `records`. Atoms not in
    /// `atomTiers` are skipped (no current tier known). Returns a
    /// `BASMemoryImportanceReport` with promotion / demotion /
    /// hold counts pre-aggregated.
    public func scoreAll(
        atomTiers: [String: BASMemoryTier],
        records: [BASMemoryUsageRecord],
        now: Date = Date()
    ) -> BASMemoryImportanceReport {
        // Bucket records by atomID for one pass.
        var bucket: [String: [BASMemoryUsageRecord]] = [:]
        for record in records {
            bucket[record.atomID, default: []].append(record)
        }
        // Score each (atom, current-tier) pair.
        var scores: [BASMemoryImportanceScore] = []
        for (atomID, currentTier) in atomTiers {
            let atomRecords = bucket[atomID] ?? []
            scores.append(score(
                atomID: atomID,
                currentTier: currentTier,
                records: atomRecords,
                now: now))
        }
        // Stable order by atomID for deterministic reports.
        scores.sort { $0.atomID < $1.atomID }
        return BASMemoryImportanceReport(
            scores: scores, computedAt: now)
    }

    // MARK: - Component formulas

    fileprivate func recencyComponent(
        records: [BASMemoryUsageRecord],
        now: Date
    ) -> Double {
        guard let mostRecent = records.map({ $0.retrievedAt })
            .max() else { return 0 }
        let age = max(0, now.timeIntervalSince(mostRecent))
        // True half-life decay: exp(-t * ln(2) / halfLife)
        // → 1 halfLife later == 0.5, 2 halfLives later == 0.25.
        // Without the `ln(2)` multiplier the curve uses 1/e
        // (≈ 0.368) at one halfLife, which is exponential-decay
        // time constant semantics, not half-life semantics.
        let ln2 = log(2.0)
        let decayed = exp(
            -age * ln2 / max(1, recencyHalfLifeSeconds))
        return Self.clamp(decayed, lo: 0, hi: 1)
    }

    fileprivate func frequencyComponent(
        records: [BASMemoryUsageRecord]
    ) -> Double {
        let count = Double(records.count)
        if count <= 0 { return 0 }
        let saturation = max(1, frequencySaturation)
        let raw = log10(1 + count) / log10(1 + saturation)
        return Self.clamp(raw, lo: 0, hi: 1)
    }

    fileprivate func helpedComponent(
        records: [BASMemoryUsageRecord]
    ) -> Double {
        if records.isEmpty { return 0.5 }
        var helped = 0.0
        var notHelped = 0.0
        var unknown = 0.0
        for r in records {
            switch r.helpedFlag {
            case .helped: helped += 1
            case .notHelped: notHelped += 1
            case .unknown: unknown += 1
            }
        }
        let weighted = helped + 0.5 * unknown
        let total = helped + notHelped + unknown
        guard total > 0 else { return 0.5 }
        return Self.clamp(weighted / total, lo: 0, hi: 1)
    }

    fileprivate func tierDecayComponent(
        for tier: BASMemoryTier
    ) -> Double {
        switch tier {
        case .hot: return tierDecayHot
        case .warm: return tierDecayWarm
        case .cold: return tierDecayCold
        }
    }

    // MARK: - Tier promotion / demotion

    fileprivate func recommendedTier(
        for currentTier: BASMemoryTier,
        total: Double
    ) -> BASMemoryTier {
        if total >= promoteThreshold {
            return Self.tierAbove(currentTier)
        } else if total <= demoteThreshold {
            return Self.tierBelow(currentTier)
        } else {
            return currentTier
        }
    }

    fileprivate static func tierAbove(
        _ tier: BASMemoryTier
    ) -> BASMemoryTier {
        switch tier {
        case .cold: return .warm
        case .warm: return .hot
        case .hot: return .hot  // already at top
        }
    }

    fileprivate static func tierBelow(
        _ tier: BASMemoryTier
    ) -> BASMemoryTier {
        switch tier {
        case .hot: return .warm
        case .warm: return .cold
        case .cold: return .cold  // already at bottom
        }
    }

    fileprivate static func clamp(
        _ value: Double,
        lo: Double,
        hi: Double
    ) -> Double {
        if value.isNaN { return lo }
        return min(hi, max(lo, value))
    }
}
