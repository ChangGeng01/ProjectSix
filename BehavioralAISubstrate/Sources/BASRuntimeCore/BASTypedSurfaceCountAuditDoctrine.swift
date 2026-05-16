// MARK: - BASTypedSurfaceCountAuditDoctrine
// chapter 六百九十四 / M2148 第三刀 — typed surface
//                                  count audit + counting
//                                  convention pin。
//
// ## Why this doctrine exists
//
// During the chapter 694 gap audit,discovered the per-
// chapter typedSurfaceCount contribution comments in
// chapter 692 + 693 are off-by-1 in opposite directions:
//
//   - chapter 692 comment claims "+9" but actual = +10
//     (6 Item structs + 4 doctrines:BASTierA +
//     BASTierB + BASTierCADR019 + BASAllTier)
//   - chapter 693 comment claims "+2" but actual = +1
//     (1 doctrine:BASSignalTen + M595 test refactor
//     incorrectly counted as a typed surface)
//
// The errors cancel (10 + 1 = 11 = 9 + 2),so the
// cumulative pin at 269 is CORRECT。 But per-chapter
// attribution is wrong。
//
// ## Counting convention
//
// "Typed surface" definition pinned post-M2148:
//
//   COUNTED:
//     - Top-level `public struct`,`public enum`,
//       `public class`,`public actor`,`public protocol`
//
//   NOT COUNTED:
//     - `public typealias` (no new memory layout — just
//       a name alias for an existing type)
//     - Nested types inside an outer typed surface (the
//       outer surface is counted once)
//     - Test-only types (lives under Tests/,not Sources/)
//     - Test refactors that don't add new Sources/
//       public types (e.g. M2142 M595 family-aggregation)
//
// This convention is now FIRST-CLASS pin to prevent
// future off-by-N drift。
//
// ## Audit results (chapters 692 + 693 + 694)

import Foundation

/// chapter 六百九十四 / M2148 第三刀 — audits the
/// per-chapter typedSurfaceCount contributions and pins
/// the counting convention as a first-class doctrine。
public enum BASTypedSurfaceCountAuditDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十四"
    public static let milestoneMNumber: Int = 2148

    // MARK: - Counting convention pin

    /// 5 type-kinds COUNT as typed surfaces。
    public static let countedTypeKinds: [String] = [
        "public struct",
        "public enum",
        "public class",
        "public actor",
        "public protocol"
    ]

    public static var countedTypeKindCount: Int {
        return countedTypeKinds.count
    }

    /// 4 categories EXCLUDED from typed surface count。
    public static let excludedCategories: [String] = [
        "public typealias (no new memory layout)",
        "nested types inside outer typed surfaces",
        "test-only types under Tests/",
        "test refactors that don't add Sources/ public types"
    ]

    public static var excludedCategoryCount: Int {
        return excludedCategories.count
    }

    // MARK: - Per-chapter contribution audit

    /// Chapter 692 (M2138-M2141) per-knife contributions:
    ///   - M2138 BASTierACompletionBridges.swift:
    ///       6 Item structs + 1 BASTierACompletionDoctrine
    ///       = 7
    ///   - M2139 BASTierBGenericPrimitivesDoctrine.swift:
    ///       1 doctrine = 1
    ///   - M2140 BASTierCADR019Generics.swift:
    ///       1 doctrine = 1
    ///   - M2141 BASAllTierFullCompletionDoctrine.swift:
    ///       1 doctrine = 1
    ///   Total chapter 692:7 + 1 + 1 + 1 = 10
    public static let chapter692AuditedContribution: Int =
        10

    /// Chapter 692 commit comment claim (off-by-1):
    public static let chapter692CommentClaim: Int = 9

    /// Chapter 693 (M2142-M2145) per-knife contributions:
    ///   - M2142 M595 family-aggregation:0 (test refactor,
    ///       no new Sources/ types per counting convention)
    ///   - M2143 BASSignalTenIntegrationTestTriageDoctrine:
    ///       1 doctrine = 1
    ///   - M2144 amendment to existing doctrine:0
    ///   - M2145 chapter 693 close-out (13-file sync):0
    ///   Total chapter 693:0 + 1 + 0 + 0 = 1
    public static let chapter693AuditedContribution: Int = 1

    /// Chapter 693 commit comment claim (off-by-1):
    public static let chapter693CommentClaim: Int = 2

    /// Sum of audited contributions matches sum of comment
    /// claims (10 + 1 = 9 + 2 = 11)。 Off-by-N errors
    /// cancel,cumulative pin 269 is correct。
    public static let auditedContributionSum: Int = 11
    public static let commentClaimSum: Int = 11

    /// Honest acknowledgment that the per-chapter
    /// comment attributions had off-by-1 errors in
    /// opposite directions that cancel in the cumulative
    /// total。 Documenting this prevents future
    /// confusion when someone audits the per-chapter
    /// numbers expecting consistency。
    public static let perChapterAttributionsOffBy1ButCanceling:
        Bool = true

    // MARK: - Chapter 694 own contribution

    /// Chapter 694 (M2146-M2149) per-knife contributions:
    ///   - M2146 BASSignal10EmpiricalDiagnosisTests +
    ///       triage doctrine refinement:0 new Sources/
    ///       types (test additions + amendments to
    ///       existing doctrine)
    ///   - M2147 swift-testing framing correction:0
    ///       (amendments only)
    ///   - M2148 BASTypedSurfaceCountAuditDoctrine
    ///       (this doctrine):1
    ///   - M2149 chapter 694 close-out:0
    ///   Total chapter 694:0 + 0 + 1 + 0 = 1
    public static let chapter694AuditedContribution: Int = 1

    // MARK: - Cumulative totals

    /// Pre-chapter-692 typedSurfaceCount (chapter 691
    /// AT-REST seal)。
    public static let preChapter692TypedSurfaceCount: Int =
        258

    /// Post-chapter-694 typedSurfaceCount = 258 + 10 + 1
    /// + 1 = 270。
    public static let postChapter694TypedSurfaceCount: Int =
        270

    public static var verifiedCumulativeMatch: Bool {
        return postChapter694TypedSurfaceCount
            == preChapter692TypedSurfaceCount
            + chapter692AuditedContribution
            + chapter693AuditedContribution
            + chapter694AuditedContribution
    }

    // MARK: - Cross-doctrine refs

    public static let prePostSealFollowupCatalogRef: String =
        "BASPostSealFollowupCatalogDoctrine (chapter 691 / M2137)"

    public static let priorTriageDoctrineRef: String =
        "BASSignalTenIntegrationTestTriageDoctrine (chapter 693 / M2143 + M2146/M2147 refinements)"

    public static let priorAllTierCompletionRef: String =
        "BASAllTierFullCompletionDoctrine (chapter 692 / M2141)"

    // MARK: - Methodology

    public static let methodology: String =
        "EXPLICIT COUNTING CONVENTION — pin what counts and what doesn't,don't infer from inline comments"

    public static let purelyAdditive: Bool = true

    public static let directiveScoreImpact: Int = 0
}
