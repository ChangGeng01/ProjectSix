// MARK: - BASSubstrateExternalDependencyCatalogDoctrine
// chapter 六百九十五 / M2151 第二刀 — catalog of
//                                  remaining items
//                                  blocked by EXTERNAL
//                                  dependencies (not
//                                  substrate-actionable)。
//
// ## Why this doctrine exists
//
// Chapter 694 BASSignalTenIntegrationTestTriageDoctrine
// confirmed wrapper-based recovery is NOT viable for
// the 12 SIGBUS tests。 Chapter 695 M2150 BASSprawl
// ScopeAuditDoctrine confirmed 0-of-64 sprawl types are
// Tier-B-migratable due to rich-domain shapes。
//
// At chapter 695 / M2151,every remaining item in the
// post-chapter-694 gap audit is BLOCKED BY EXTERNAL
// DEPENDENCIES — i.e. NOT solvable within substrate
// scope。 This doctrine catalogs them with explicit
// "who owns the fix" attribution。
//
// The substrate has reached its TERMINAL HONEST STATE。
// Further substrate-side commits would be busy work
// without solving anything。

import Foundation

/// chapter 六百九十五 / M2151 第二刀 — catalogs all
/// remaining items that are NOT substrate-actionable,
/// with explicit owner attribution per blocking
/// dependency。
public enum BASSubstrateExternalDependencyCatalogDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十五"
    public static let milestoneMNumber: Int = 2151

    // MARK: - Categorical owners

    /// 4 categories of EXTERNAL dependency。
    public static let externalOwnerCategories: [String] = [
        "TOOLCHAIN (Apple Xcode + SwiftPM + Swift compiler)",
        "HOST-APP (call-site adoption + production wiring)",
        "EXTERNAL-ARCHITECTURE (multi-system designs beyond substrate scope)",
        "EXTERNAL-TOOLING (CLI drivers + auxiliary scripts)"
    ]

    public static var externalOwnerCategoryCount: Int {
        return externalOwnerCategories.count
    }

    // MARK: - TOOLCHAIN-owned blocked items

    /// 12 SIGBUS integration tests (BASSubstrateReaudit
    /// ShadowEvaluator 6 + BASMemoryClosedLoop 3 +
    /// M306MultiSessionContinuity 3)。 Wrapper recovery
    /// FALSIFIED at M2146 Diagnostic E。 Owner:Xcode
    /// 26.4.1 + Swift 6.3.1 + macOS 26 SDK toolchain
    /// stabilization。
    public static let blockedSignal10TestCount: Int = 12

    /// 3 empirical SIGBUS diagnostic tests (Diagnostics
    /// C/D/E) documenting the bucket boundary。 Same
    /// toolchain owner。
    public static let blockedDiagnosticTestCount: Int = 3

    /// 419 swift-testing @Test cases that crash the
    /// swiftpm-testing-helper during full-suite
    /// scheduling。 0 complete in full-suite run。 Owner:
    /// SwiftPM + swift-testing toolchain stabilization。
    public static let blockedSwiftTestingTestCount: Int =
        419

    /// Total toolchain-blocked test surface。
    public static var toolchainBlockedTotal: Int {
        return blockedSignal10TestCount
            + blockedDiagnosticTestCount
            + blockedSwiftTestingTestCount
    }

    public static let toolchainOwnerNote: String =
        "Apple Xcode 26.4.1 + Swift 6.3.1 + macOS 26 SDK + SwiftPM concurrent runner"

    public static let toolchainBlockedRecoveryGate: String =
        "wait for Xcode 26.5+ OR SwiftPM swiftpm-testing-helper full-suite scheduling fix"

    // MARK: - HOST-APP-owned blocked items

    /// 6 Tier A Item structs shipped at chapter 692 /
    /// M2138 but with 0 production call sites consuming
    /// them。 Owner:host-app substrate-adoption work。
    public static let blockedTierAItemAdoptionCount: Int =
        6

    /// 64 sprawl struct types (37+22+2+3) — 0-of-64
    /// migratable to Tier B primitives per M2150 audit。
    /// They REMAIN at their existing call-sites with no
    /// substrate action required。
    public static let preservedSprawlStructCount: Int = 64

    /// iOS 26 FoundationModels.Tool real-device PROOF。
    /// Substrate-side BridgeStatus typed surface SHIPPED
    /// pre-chapter-477。 Real-device end-to-end PROOF is
    /// host-app responsibility。
    public static let blockedIOSFoundationModelsProofItems:
        Int = 1

    public static let hostAppOwnerNote: String =
        "host-app integration team — call-site adoption,production wiring,real-device PROOF"

    // MARK: - EXTERNAL-ARCHITECTURE-owned blocked items

    /// Multi-host runtime federation (cross-device turn
    /// sharing,fleet-level state)。 Beyond substrate
    /// scope — requires fleet architecture design。
    public static let blockedMultiHostFederationItems:
        Int = 1

    /// BASTensor MTLBuffer zero-copy backing。 Production-
    /// API redesign with downstream impact on every
    /// tensor consumer。 Owner:cross-team production-
    /// API redesign。
    public static let blockedBASTensorZeroCopyItems: Int = 1

    public static let externalArchitectureOwnerNote:
        String =
        "production-API redesign team / fleet architecture team"

    // MARK: - EXTERNAL-TOOLING-owned blocked items

    /// MLX → CoreML CLI driver (G11 external roadmap
    /// item)。 Substrate ships typed conversion contract
    /// already。 CLI is auxiliary tooling。
    public static let blockedMLXCoreMLCLIItems: Int = 1

    /// Self-tuning scheduler (adaptive optimization from
    /// observed dispatch-outcome history)。 Substrate
    /// has the data;adaptive policy design is external
    /// tooling work。
    public static let blockedSelfTuningSchedulerItems:
        Int = 1

    public static let externalToolingOwnerNote: String =
        "external tooling team — CLI drivers + adaptive optimization design"

    // MARK: - Aggregate

    /// Total non-test items blocked (Tier A adoption +
    /// sprawl preservation + iOS proof + 4 stretch
    /// goals)。
    public static var nonTestBlockedItemCount: Int {
        return blockedTierAItemAdoptionCount
            + blockedIOSFoundationModelsProofItems
            + blockedMultiHostFederationItems
            + blockedBASTensorZeroCopyItems
            + blockedMLXCoreMLCLIItems
            + blockedSelfTuningSchedulerItems
    }
    // = 6 + 1 + 1 + 1 + 1 + 1 = 11

    // MARK: - Substrate-actionable count = 0

    /// Items that REMAIN substrate-actionable at chapter
    /// 695 / M2151。 EXPLICITLY ZERO — substrate has
    /// reached terminal honest state。
    public static let substrateActionableItemsRemaining:
        Int = 0

    // MARK: - Cross-doctrine refs

    public static let priorPostSealFollowupCatalogRef:
        String =
        "BASPostSealFollowupCatalogDoctrine (chapter 691 / M2137)"

    public static let priorSignal10TriageRef: String =
        "BASSignalTenIntegrationTestTriageDoctrine (chapter 693 / M2143 + M2146 + M2147 amendments)"

    public static let priorSprawlScopeAuditRef: String =
        "BASSprawlScopeAuditDoctrine (chapter 695 / M2150)"

    public static let priorTierACompletionRef: String =
        "BASTierACompletionDoctrine (chapter 692 / M2138 + M2148 amendment)"

    // MARK: - Methodology

    public static let methodology: String =
        "EXPLICIT OWNER ATTRIBUTION — every remaining item has a NAMED non-substrate owner;substrate cannot solve what it doesn't own"

    public static let purelyAdditive: Bool = true

    public static let directiveScoreImpact: Int = 0

    /// Substrate AT-REST + Tier A+B+C complete preserved
    /// at chapter 695。
    public static let substrateAtRestPreserved: Bool = true

    // MARK: - M2165 chapter 七百 第一刀 — CONSOLIDATED
    //         from former BASTypedSurfaceCountAuditDoctrine
    //         (deleted at M2165 per chapter 698 anti-
    //         sprawl discipline + chapter 699 + 700
    //         user-authorized consolidation precedent)。
    //
    // User directive 「全面 完成」 at chapter 700
    // explicit-authorized executing chapter 699
    // plannedFutureCuts:merge BASTypedSurfaceCountAudit
    // Doctrine + BASSprawlScopeAuditDoctrine into this
    // doctrine。 Discipline gate from chapter 698 / M2162
    // satisfied via option-b explicit-user-directive。
    //
    // All pins from BASTypedSurfaceCountAuditDoctrine
    // migrated here with `typedAudit_` prefix to avoid
    // name collisions。

    public static let typedAudit_consolidatedFromTypedSurfaceCountAuditDoctrine:
        Bool = true

    public static let typedAudit_consolidatedAtMNumber:
        Int = 2165

    // MARK: - Counting convention (consolidated)

    public static let typedAudit_countedTypeKinds: [String] = [
        "public struct",
        "public enum",
        "public class",
        "public actor",
        "public protocol"
    ]

    public static var typedAudit_countedTypeKindCount:
        Int {
        return typedAudit_countedTypeKinds.count
    }

    public static let typedAudit_excludedCategories:
        [String] = [
        "public typealias (no new memory layout)",
        "nested types inside outer typed surfaces",
        "test-only types under Tests/",
        "test refactors that don't add Sources/ public types"
    ]

    public static var typedAudit_excludedCategoryCount:
        Int {
        return typedAudit_excludedCategories.count
    }

    // MARK: - Per-chapter contribution audit (consolidated)

    public static let typedAudit_chapter692AuditedContribution:
        Int = 10
    public static let typedAudit_chapter692CommentClaim:
        Int = 9

    public static let typedAudit_chapter693AuditedContribution:
        Int = 1
    public static let typedAudit_chapter693CommentClaim:
        Int = 2

    public static let typedAudit_chapter694AuditedContribution:
        Int = 1

    public static let typedAudit_auditedContributionSum:
        Int = 11
    public static let typedAudit_commentClaimSum: Int = 11

    public static let typedAudit_perChapterAttributionsOffBy1ButCanceling:
        Bool = true

    // MARK: - Cumulative totals (consolidated)

    public static let typedAudit_preChapter692TypedSurfaceCount:
        Int = 258
    public static let typedAudit_postChapter694TypedSurfaceCount:
        Int = 270

    public static var typedAudit_verifiedCumulativeMatch:
        Bool {
        return typedAudit_postChapter694TypedSurfaceCount
            == typedAudit_preChapter692TypedSurfaceCount
            + typedAudit_chapter692AuditedContribution
            + typedAudit_chapter693AuditedContribution
            + typedAudit_chapter694AuditedContribution
    }

    // MARK: - Methodology (consolidated)

    public static let typedAudit_methodology: String =
        "EXPLICIT COUNTING CONVENTION — pin what counts and what doesn't,don't infer from inline comments"

    // MARK: - M2165 chapter 七百 第一刀 — CONSOLIDATED
    //         from former BASSprawlScopeAuditDoctrine
    //         (deleted at M2165)。
    //
    // All pins from BASSprawlScopeAuditDoctrine migrated
    // here with `sprawl_` prefix。

    public static let sprawl_consolidatedFromSprawlScopeAuditDoctrine:
        Bool = true

    public static let sprawl_consolidatedAtMNumber: Int =
        2165

    // MARK: - Actual sprawl counts (consolidated)

    public static let sprawl_resultStructCount: Int = 37
    public static let sprawl_frameStructCount: Int = 22
    public static let sprawl_permitStructCount: Int = 2
    public static let sprawl_cardStructCount: Int = 3

    public static var sprawl_totalSprawlStructCount: Int {
        return sprawl_resultStructCount
            + sprawl_frameStructCount
            + sprawl_permitStructCount
            + sprawl_cardStructCount
    }

    // MARK: - Chapter 691 estimates + delta (consolidated)

    public static let sprawl_chapter691EstimatedResultCount:
        Int = 27
    public static let sprawl_chapter691EstimatedFrameCount:
        Int = 10
    public static let sprawl_chapter691EstimatedPermitCount:
        Int = 3
    public static let sprawl_chapter691EstimatedCardCount:
        Int = 2

    public static var sprawl_chapter691EstimatedTotalCount:
        Int {
        return sprawl_chapter691EstimatedResultCount
            + sprawl_chapter691EstimatedFrameCount
            + sprawl_chapter691EstimatedPermitCount
            + sprawl_chapter691EstimatedCardCount
    }

    public static var sprawl_actualMinusEstimatedDelta:
        Int {
        return sprawl_totalSprawlStructCount
            - sprawl_chapter691EstimatedTotalCount
    }

    // MARK: - Migratability (consolidated)

    public static let sprawl_migratableToTierBCount: Int =
        0

    public static var sprawl_domainComplexPreservedCount:
        Int {
        return sprawl_totalSprawlStructCount
            - sprawl_migratableToTierBCount
    }

    public static var sprawl_migrationPercentage: Double {
        return Double(sprawl_migratableToTierBCount)
            / Double(sprawl_totalSprawlStructCount)
            * 100.0
    }

    public static let sprawl_categorizationRationale:
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

    public static var sprawl_categorizationRationaleCount:
        Int {
        return sprawl_categorizationRationale.count
    }

    // MARK: - Honest framing (consolidated)

    public static let sprawl_chapter691OverestimateAcknowledged:
        Bool = true

    public static let sprawl_tierBPrimitivesRemainValuableForNewTypes:
        Bool = true

    public static let sprawl_tierBDoctrineUnblockedClaimRetainedForHistory:
        Bool = true

    // MARK: - Methodology (consolidated)

    public static let sprawl_methodology: String =
        "EMPIRICAL SPRAWL AUDIT — grep-confirm actual scope,classify each category by shape compatibility,reclassify plan overestimates with honest counts"
}
