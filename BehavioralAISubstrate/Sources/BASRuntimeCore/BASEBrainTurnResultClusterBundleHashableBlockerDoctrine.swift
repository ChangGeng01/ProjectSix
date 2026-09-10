// MARK: - BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
// chapter 五百四十二 / M1546 — typed milestone doctrine
//                              documenting which
//                              underlying types BLOCK
//                              Hashable synthesis on
//                              the 9 cluster bundles
//
// Background:chapter 541 / M1541 added Codable
// conformance to all 9 BASEBrainTurnResult cluster
// bundles。 Adding Hashable was explored at chapter 542
// / M1545 but synthesis is BLOCKED because several
// underlying types (BASRecoveryDisposition,BASRuntime
// Trace, etc.) conform to `BASSchemaVersioned` which
// requires Codable + Equatable + Sendable but NOT
// Hashable。
//
// This doctrine catalogues the specific blocking types
// + provides a typed surface future refactors can
// reference when deciding whether to:
//
//   1. Promote BASSchemaVersioned to require Hashable
//      (large blast radius — all conformers re-verify)
//   2. Provide manual Hashable conformance per cluster
//      bundle (hashes a typed subset of fields)
//   3. Leave bundles as Equatable+Codable+Sendable
//      (current decision pending stakeholder review)
//
// Documenting the blocker is itself entropy reduction:
// without this doctrine,a future maintainer might
// attempt Hashable synthesis,hit the same compile
// error,and waste cycles re-deriving the blocker list。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (this doctrine is metadata only;no behavioral
//     change)
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     Hashable blocker analysis
//   - chapter 三百九二:replay-determinism preserved
//   - chapter 四百二十九:typed-surface count 87 → 88
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1545 → M1546

import Foundation

/// Typed surface cataloguing the BASSchemaVersioned-
/// derived types that currently BLOCK Hashable synthesis
/// on the 9 BASEBrainTurnResult cluster bundles。
public enum BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
{

    /// Typed enum naming the broad categories of blocker
    /// (used to discriminate per-bundle blocker patterns)。
    public enum BlockerCategory:
        String, Codable, Equatable, Hashable, Sendable,
        CaseIterable
    {
        /// Type conforms to BASSchemaVersioned which
        /// requires Codable + Equatable + Sendable but
        /// NOT Hashable。 This is the dominant blocker
        /// category at chapter 542。
        case basSchemaVersionedLacksHashable

        /// Type is a class or has reference semantics
        /// (cannot synthesize Hashable on value type
        /// containing reference type without manual
        /// conformance)。 Not currently observed in the
        /// 9 cluster bundles。
        case referenceTypeContainment

        /// Type contains a function-type stored property
        /// (closures don't conform to Hashable)。 Not
        /// currently observed in the 9 cluster bundles。
        case closureStoredProperty
    }

    /// Concrete blocking types observed when Hashable
    /// synthesis was attempted at M1545。 Each entry is
    /// a pair of (underlying type name,blocker
    /// category)。
    public static let blockingTypes:
        [(typeName: String,
          category: BlockerCategory)] =
    [
        ("BASRecoveryDisposition",
            .basSchemaVersionedLacksHashable),
        ("BASRuntimeTrace",
            .basSchemaVersionedLacksHashable)
    ]

    /// Count of distinct blocking types catalogued at
    /// chapter 542。 Pinned at 2 — additional types may
    /// exist downstream of these but synthesis halts at
    /// the first observed blocker per bundle。
    public static let blockingTypeCount: Int = 2

    /// Bundle that exercised the M1545 Hashable attempt
    /// (and surfaced the 2 blockers)。 This bundle has
    /// both fields,making it the diagnostic canary。
    public static let canaryBundleTypeName: String =
        "BASEBrainTurnResultForensicMetadataBundle"

    /// Currently-resolved decision (M1545 + M1546):
    /// leave all 9 cluster bundles as Codable + Equatable
    /// + Sendable until a follow-up arc revisits the
    /// trade-off。 The decision can flip if hosts request
    /// Hashable for set-membership / dictionary-key uses。
    public static let currentDecision: String =
        "no-hashable-conformance-pending-stakeholder-review"

    /// Are the 9 cluster bundles currently Hashable?
    /// Pinned `false` at M1546 — flipping requires
    /// resolving the BASSchemaVersioned-lacks-Hashable
    /// blocker。
    public static let clusterBundlesAreHashable: Bool =
        false
}
