// ch1051 / v1.0 L9 — GuardBranch as a first-class type (gap-audit slice 3 #10, PARTIAL → BUILT).
//
// The 守护分支 (guard branch) concept was threaded through L9 as `BASCandidateFrontier.guardPaths:
// [String]` + a `guardianBranch` enum case, but had no standalone type. `BASGuardBranch` promotes it
// to a first-class object (trigger / protective action / fallback / reversibility), and
// `fromGuardPaths(_:)` bridges the existing flat refs losslessly. The `guardPaths` field is preserved
// untouched (it has live readers) — this is an additive structured view alongside it (byte-equal-off).

import Foundation
import BASRuntimeCore

/// audit orchestration HIGH-1 — the CANONICAL reversibility bands, single source of truth for the
/// two producers of `BASCandidateFrontier.reversiblePaths` / `.guardPaths`. A `guardPath` is a
/// PROTECTIVE SAFE-RETREAT fallback (HIGH reversibility) — `BASGuardBranch.fromGuardPaths` makes
/// each one "a minimal REVERSIBLE guard branch". `BASAgentFabricAdapters` previously INVERTED this
/// (`guardPaths = reversibility < 0.3`, the DANGER band) while `EBrainNeuralMaterializationCore`
/// used `>= 0.7` (safe band), so the SAME frontier field fed L9 planning OPPOSITE guard sets
/// depending on which producer ran; the `reversiblePaths` threshold also drifted (0.7 vs 0.6).
public enum BASReversibilityBands {
    /// A path is a guard branch (protective, safe to fall back to) at or above this reversibility.
    public static let guardThreshold: Double = 0.7
    /// A path is "reversible" (can be undone) at or above this reversibility.
    public static let reversibleThreshold: Double = 0.7

    public static func isGuardPath(reversibility: Double) -> Bool {
        reversibility >= guardThreshold
    }
    public static func isReversiblePath(reversibility: Double) -> Bool {
        reversibility >= reversibleThreshold
    }
}

/// A protective fallback path in the L9 candidate frontier — the "守护分支".
public struct BASGuardBranch: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"
    public var schemaVersion: String
    public var branchID: String
    public var triggerCondition: String   // when this guard activates ("" if unspecified)
    public var protectiveAction: String   // the protective measure it takes ("" if unspecified)
    public var fallbackRef: String?       // the candidate/path to fall back to
    public var reversible: Bool

    public init(schemaVersion: String = BASGuardBranch.currentSchemaVersion,
                branchID: String, triggerCondition: String = "", protectiveAction: String = "",
                fallbackRef: String? = nil, reversible: Bool = true) {
        self.schemaVersion = schemaVersion
        self.branchID = branchID
        self.triggerCondition = triggerCondition
        self.protectiveAction = protectiveAction
        self.fallbackRef = fallbackRef
        self.reversible = reversible
    }

    /// Promote flat guard-path refs (e.g. `BASCandidateFrontier.guardPaths`) to first-class guard
    /// branches — each ref becomes a minimal reversible guard branch falling back to itself. Lossless.
    public static func fromGuardPaths(_ refs: [String]) -> [BASGuardBranch] {
        refs.map { BASGuardBranch(branchID: $0, fallbackRef: $0, reversible: true) }
    }
}

public extension BASCandidateFrontier {
    /// This frontier's `guardPaths` as first-class `BASGuardBranch`es (the flat field is preserved).
    func guardBranches() -> [BASGuardBranch] { BASGuardBranch.fromGuardPaths(guardPaths) }
}
