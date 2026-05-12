// MARK: - BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
// chapter 五百六十二 / M1627 — typed surface
//                          commemorating the M1625
//                          Codable extension to 5
//                          more audit-projection
//                          aggregator types
//
// ## Why this typed surface exists
//
// M1625 added Codable + Equatable conformance to 5
// audit-projection aggregator types previously stuck
// at Sendable / Hashable only:
//
//   - BASTurnAuditProjectionsSurfaceTrio (chapter 四百
//     九十二 / M1344)
//   - BASTurnAuditProjectionsGateSideDeriveTrio
//     (chapter 五百六 / M1403)
//   - BASTurnAuditProjectionsKunlunTrioTwo (chapter
//     四百八十五 / M1318)
//   - BASTurnAuditProjectionsLifecycleQuartet (chapter
//     四百八十八 / M1328)
//   - BASTurnAuditProjectionsKunlunTianmenTrio (chapter
//     四百九十四 / M1353)
//
// Combined with the chapter 561 / M1621 extension
// (3 aggregator types),this brings the total
// aggregator Codable coverage to:
//
//   3 (chapter 561) + 5 (this chapter) = 8
//   aggregator types now ledger-serializable
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth
//   - chapter 三百九二:these 5 types now in replay-
//     determinism contract surface
//   - chapter 四百二十九:typed-surface count 102 → 103
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1626 → M1627

import Foundation

/// Typed surface commemorating the M1625 Codable
/// extension to 5 more audit-projection aggregator
/// types。
public enum BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百六十二"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1625

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1626

    /// Number of PROOF tests at M1626。
    public static let proofTestCount: Int = 10

    /// 5 audit-projection aggregator types that gained
    /// Codable + Equatable at M1625。
    public static let typesGainedCodable: [String] = [
        "BASTurnAuditProjectionsSurfaceTrio",
        "BASTurnAuditProjectionsGateSideDeriveTrio",
        "BASTurnAuditProjectionsKunlunTrioTwo",
        "BASTurnAuditProjectionsLifecycleQuartet",
        "BASTurnAuditProjectionsKunlunTianmenTrio"
    ]

    /// Total types extended at M1625 = 5。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Combined aggregator-Codable coverage including
    /// the M1621 chapter-561 extension = 8 types。
    public static let combinedAggregatorCount: Int = 8

    /// Reference to the previous extension doctrine
    /// (chapter 561 / M1623) that this chapter
    /// extends。
    public static let previousExtensionDoctrineRef:
        String =
        "BASTurnAuditProjectionsTrioCodableExtensionDoctrine"

    /// Conformances added per type at M1625。
    public static let conformancesAdded: [String] = [
        "Codable",
        "Equatable"
    ]

    /// PROOF method:JSONEncoder + sortedKeys +
    /// JSONDecoder + Equatable round-trip equality。
    public static let proofMethod: String =
        "codable-sortedKeys-json-round-trip"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 5 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// 5 chapter-origin references for the 5 newly-
    /// Codable types。
    public static let originChapterRefs: [String] = [
        "chapter 四百九十二",   // SurfaceTrio
        "chapter 五百六",       // GateSideDeriveTrio
        "chapter 四百八十五",   // KunlunTrioTwo
        "chapter 四百八十八",   // LifecycleQuartet
        "chapter 四百九十四"    // KunlunTianmenTrio
    ]
}
