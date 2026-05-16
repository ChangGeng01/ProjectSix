// MARK: - BASSprawlScopeAuditDoctrine
// chapter 六百九十五 / M2150 第一刀 — sprawl scope
//                                  audit + migratability
//                                  classification。
//
// ## Why this doctrine exists
//
// Chapter 691 BASPostSealFollowupCatalogDoctrine claimed
// 56 sprawl migrations are UNBLOCKED by Tier B primitives
// (27 *Result + 10 *Frame + 3 *Permit + 2 *Card = 42
// rough estimate)。 Chapter 695 / M2150 empirically
// audited the actual sprawl counts in Sources/ via grep
// of `^public struct BAS[A-Z][a-zA-Z]+(Result|Frame|
// Permit|Card)\b`:
//
//   37 *Result struct types (was 27 estimated)
//   22 *Frame struct types  (was 10 estimated)
//    2 *Permit struct types (was 3 estimated)
//    3 *Card struct types   (was 2 estimated)
//   ───
//   64 total                (was 42 estimated)
//
// Per-category investigation of representative samples
// confirms NONE of these are simple `wrap-a-payload`
// types。 They are RICH DOMAIN STRUCTS with:
//
//   - 5-20+ named typed fields per struct
//   - Custom Codable conformance contracts
//   - Equatable derivation pinned across replay tests
//   - Sendable with stable wire format
//   - Existing call-site pattern-matching on
//     deconstructed fields
//
// Tier B primitives (BASResult<Body>,BASFrameEnvelope
// <Body>,BASPermit<Decision>,BASCard<Kind,Body>) were
// designed for SIMPLE single-payload wrappers。 They are
// NOT a drop-in replacement for these domain types。
//
// The "56 migrations unblocked" framing from chapter 691
// was a PLAN-LEVEL OVERESTIMATE that didn't account for
// the rich-domain-struct shape of the actual sprawl。
//
// HONEST RECLASSIFICATION:
//
//   - MIGRATABLE-TO-TIER-B:0-of-64 (none of the audited
//     types fit the Tier B primitive shape)
//   - DOMAIN-COMPLEX-PRESERVED:64-of-64 (all retain
//     their rich struct shape;Tier B primitives serve
//     NEW types,not migration of existing ones)
//
// Tier B primitives REMAIN VALUABLE for NEW types that
// fit the simple-wrapper shape (the substrate already
// ships them — see BASLowEntropyPrimitives.swift)。
// They just don't apply to the existing 64-type sprawl。
//
// ## Score impact
//
// 0 — saturation invariant holds。 This doctrine
// reclassifies the existing scope honestly,doesn't
// change any directive scores。

import Foundation

/// chapter 六百九十五 / M2150 第一刀 — audits the actual
/// sprawl scope + classifies each category as MIGRATABLE
/// vs DOMAIN-COMPLEX-PRESERVED。
public enum BASSprawlScopeAuditDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十五"
    public static let milestoneMNumber: Int = 2150

    // MARK: - Actual sprawl counts (empirical)

    /// 37 `*Result` struct types (grep-confirmed M2150)。
    public static let resultStructCount: Int = 37

    /// 22 `*Frame` struct types (grep-confirmed M2150)。
    public static let frameStructCount: Int = 22

    /// 2 `*Permit` struct types (grep-confirmed M2150)。
    public static let permitStructCount: Int = 2

    /// 3 `*Card` struct types (grep-confirmed M2150)。
    public static let cardStructCount: Int = 3

    /// 64 total sprawl struct types (37+22+2+3)。
    public static var totalSprawlStructCount: Int {
        return resultStructCount + frameStructCount
            + permitStructCount + cardStructCount
    }

    // MARK: - Chapter 691 catalog estimates (for delta)

    public static let chapter691EstimatedResultCount: Int =
        27
    public static let chapter691EstimatedFrameCount: Int =
        10
    public static let chapter691EstimatedPermitCount: Int = 3
    public static let chapter691EstimatedCardCount: Int = 2

    public static var chapter691EstimatedTotalCount: Int {
        return chapter691EstimatedResultCount
            + chapter691EstimatedFrameCount
            + chapter691EstimatedPermitCount
            + chapter691EstimatedCardCount
    }
    // = 42

    public static var actualMinusEstimatedDelta: Int {
        return totalSprawlStructCount
            - chapter691EstimatedTotalCount
    }
    // = 64 - 42 = +22

    // MARK: - Migratability classification

    /// 0-of-64 sprawl structs are MIGRATABLE to Tier B
    /// primitives。 The audit found NONE fit the simple-
    /// wrapper shape Tier B was designed for。
    public static let migratableToTierBCount: Int = 0

    /// 64-of-64 sprawl structs are DOMAIN-COMPLEX-
    /// PRESERVED — they retain their rich struct shapes。
    public static var domainComplexPreservedCount: Int {
        return totalSprawlStructCount
            - migratableToTierBCount
    }
    // = 64

    /// Migration percentage of the sprawl scope。
    public static var migrationPercentage: Double {
        return Double(migratableToTierBCount)
            / Double(totalSprawlStructCount) * 100.0
    }
    // = 0.0%

    // MARK: - Rationale per category

    public static let categorizationRationale:
        [String: String] = [
        "*Result":
            "rich-domain output bundles with 5-20+ typed " +
            "fields,custom Codable contracts,pinned " +
            "Equatable for replay determinism — NOT a " +
            "single-payload wrapper shape",
        "*Frame":
            "schema-versioned envelope structs with " +
            "BASSchemaVersioned conformance + multiple " +
            "domain-specific fields per frame kind — " +
            "NOT a Body wrapper",
        "*Permit":
            "BASActionPermit + BASHeavenGatePermit carry " +
            "mode + reason + scope + caller-defined " +
            "policy refs — multi-field,not Decision-" +
            "wrapped",
        "*Card":
            "BASRiskCard + BASGovernanceCard already use " +
            "domain-tuned shapes;BASCard<Kind,Body> " +
            "would lose typed risk-level + governance-" +
            "scope semantics"
    ]

    public static var categorizationRationaleCount: Int {
        return categorizationRationale.count
    }

    // MARK: - HONEST framing pin

    /// Chapter 691 BASPostSealFollowupCatalogDoctrine's
    /// claim that 56 sprawl migrations were "unblocked"
    /// was a PLAN-LEVEL OVERESTIMATE。 The Tier B
    /// primitives are valuable for NEW simple-wrapper
    /// types,not for migrating these 64 rich-domain
    /// structs。
    public static let chapter691OverestimateAcknowledged:
        Bool = true

    /// Tier B primitives still serve their purpose:
    /// new simple-wrapper types use them out-of-box。
    /// The 64-type sprawl pre-dates the primitives and
    /// has rich shapes the primitives can't replace。
    public static let tierBPrimitivesRemainValuableForNewTypes:
        Bool = true

    /// BASTierBGenericPrimitivesDoctrine.unblockedMigration
    /// Count = 42 pin is RETAINED for history;the audit
    /// reclassifies the actual migratable count as 0。
    public static let bastierBDoctrineUnblockedClaimRetainedForHistory:
        Bool = true

    // MARK: - Cross-doctrine refs

    public static let priorTierBPrimitivesDoctrineRef:
        String =
        "BASTierBGenericPrimitivesDoctrine (chapter 692 / M2139)"

    public static let priorPostSealFollowupCatalogRef:
        String =
        "BASPostSealFollowupCatalogDoctrine (chapter 691 / M2137)"

    public static let priorTypedSurfaceCountAuditRef:
        String =
        "BASTypedSurfaceCountAuditDoctrine (chapter 694 / M2148)"

    // MARK: - Methodology

    public static let methodology: String =
        "EMPIRICAL SPRAWL AUDIT — grep-confirm actual scope,classify each category by shape compatibility,reclassify plan overestimates with honest counts"

    public static let purelyAdditive: Bool = true

    public static let directiveScoreImpact: Int = 0
}
