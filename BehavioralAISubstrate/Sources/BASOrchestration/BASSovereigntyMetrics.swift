// ch1053 / v1.0 §12.2 查缺补漏 — sovereignty metrics: quantitative proof of "never betray the host".
//
// The gap audit found §12 metrics largely unbuilt. Most of §12 is out-of-scope evaluation infra, but
// the §12.2 sovereignty battery is genuinely product-relevant — it is the *measurement* of the
// platform's core promise, and every underlying mechanism is already wired (verdict revocations,
// lineage cuts, tombstones, the audit ledger). What was missing is the aggregation layer.
//
// This is that layer, built to the codebase's PROVEN pattern (`BASDoctrineMetricsCompute`): pure
// functions over caller-supplied counts. It does NOT auto-collect — the host accumulates the counts
// from the wired enforcement and calls `compute`. Additive / opt-in (ADR-014): nothing invokes it
// unless a host does; no behavior change.

import Foundation

/// The §12.2 sovereignty-metric set. Every rate ∈ [0,1].
public struct BASSovereigntyMetrics: Sendable, Equatable, Codable {
    /// Commits that bypassed a permit / total commit attempts. Lower is better (0 = clean).
    public let unauthorizedCommitRate: Double
    /// Turns the sovereign verdict blocked a harmful action / harmful attempts. Higher is better.
    public let sovereignSaveRate: Double
    /// Descendants actually severed / descendants that should have been. 1.0 = complete.
    public let lineageCutCompleteness: Double
    /// Clean rollbacks / total rollbacks. 1.0 = pure.
    public let rollbackPurity: Double
    /// Sealed items that leaked / sealed-access attempts. Lower is better (0 = no leak).
    public let oldSealLeakageRate: Double
    /// Deleted objects that reappeared / deleted objects. Lower is better (0 = none resurfaced).
    public let deletedObjectResurfaceRate: Double

    public init(unauthorizedCommitRate: Double, sovereignSaveRate: Double,
                lineageCutCompleteness: Double, rollbackPurity: Double,
                oldSealLeakageRate: Double, deletedObjectResurfaceRate: Double) {
        func c(_ x: Double) -> Double { Swift.min(1.0, Swift.max(0.0, x)) }
        self.unauthorizedCommitRate = c(unauthorizedCommitRate)
        self.sovereignSaveRate = c(sovereignSaveRate)
        self.lineageCutCompleteness = c(lineageCutCompleteness)
        self.rollbackPurity = c(rollbackPurity)
        self.oldSealLeakageRate = c(oldSealLeakageRate)
        self.deletedObjectResurfaceRate = c(deletedObjectResurfaceRate)
    }

    /// The "clean" target state: no unauthorized commits, complete lineage cuts, pure rollbacks, no
    /// seal leakage, no resurfacing. (Save rate is excluded — it is good-when-high, not a purity gate.)
    public var isClean: Bool {
        unauthorizedCommitRate == 0 && lineageCutCompleteness == 1
            && rollbackPurity == 1 && oldSealLeakageRate == 0 && deletedObjectResurfaceRate == 0
    }
}

/// Raw counts the host accumulates from the wired enforcement, fed into `BASSovereigntyMetricsCompute`.
public struct BASSovereigntyCounts: Sendable, Equatable, Codable {
    public var unauthorizedCommits: Int
    public var totalCommitAttempts: Int
    public var sovereignSaves: Int
    public var harmfulAttempts: Int
    public var lineageDescendantsSevered: Int
    public var lineageDescendantsExpected: Int
    public var cleanRollbacks: Int
    public var totalRollbacks: Int
    public var oldSealLeaks: Int
    public var oldSealAccessAttempts: Int
    public var deletedResurfaced: Int
    public var deletedTotal: Int

    public init(unauthorizedCommits: Int = 0, totalCommitAttempts: Int = 0,
                sovereignSaves: Int = 0, harmfulAttempts: Int = 0,
                lineageDescendantsSevered: Int = 0, lineageDescendantsExpected: Int = 0,
                cleanRollbacks: Int = 0, totalRollbacks: Int = 0,
                oldSealLeaks: Int = 0, oldSealAccessAttempts: Int = 0,
                deletedResurfaced: Int = 0, deletedTotal: Int = 0) {
        self.unauthorizedCommits = unauthorizedCommits
        self.totalCommitAttempts = totalCommitAttempts
        self.sovereignSaves = sovereignSaves
        self.harmfulAttempts = harmfulAttempts
        self.lineageDescendantsSevered = lineageDescendantsSevered
        self.lineageDescendantsExpected = lineageDescendantsExpected
        self.cleanRollbacks = cleanRollbacks
        self.totalRollbacks = totalRollbacks
        self.oldSealLeaks = oldSealLeaks
        self.oldSealAccessAttempts = oldSealAccessAttempts
        self.deletedResurfaced = deletedResurfaced
        self.deletedTotal = deletedTotal
    }
}

public enum BASSovereigntyMetricsCompute {
    /// Denominator-0-safe, clamped [0,1] rate.
    public static func rate(_ numerator: Int, of denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Swift.min(1.0, Swift.max(0.0, Double(numerator) / Double(denominator)))
    }

    public static func compute(_ c: BASSovereigntyCounts) -> BASSovereigntyMetrics {
        BASSovereigntyMetrics(
            unauthorizedCommitRate: rate(c.unauthorizedCommits, of: c.totalCommitAttempts),
            sovereignSaveRate: rate(c.sovereignSaves, of: c.harmfulAttempts),
            // "nothing to cut" = complete; "nothing to roll back" = pure (empty → safe extreme).
            lineageCutCompleteness: c.lineageDescendantsExpected <= 0
                ? 1.0 : rate(c.lineageDescendantsSevered, of: c.lineageDescendantsExpected),
            rollbackPurity: c.totalRollbacks <= 0
                ? 1.0 : rate(c.cleanRollbacks, of: c.totalRollbacks),
            oldSealLeakageRate: rate(c.oldSealLeaks, of: c.oldSealAccessAttempts),
            deletedObjectResurfaceRate: rate(c.deletedResurfaced, of: c.deletedTotal))
    }
}
