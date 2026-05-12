// MARK: - BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
// chapter 五百六十三 / M1631 — typed surface
//                          commemorating the M1629
//                          Codable extension to 7
//                          more audit-projection
//                          aggregator types
//
// ## Why this typed surface exists
//
// Continues the real-substrate Codable extension arc
// from chapters 561-562:
//
//   - chapter 561 / M1621:3 types
//   - chapter 562 / M1625:5 types
//   - chapter 563 / M1629:7 types (this doctrine)
//
// Combined:15 aggregator types now ledger-serializable
// for replay。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth
//   - chapter 三百九二:7 more types in replay-
//     determinism contract surface
//   - chapter 四百二十九:typed-surface count 103 → 104
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1630 → M1631

import Foundation

/// Typed surface commemorating the M1629 Codable
/// extension to 7 more audit-projection aggregator
/// types。
public enum BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百六十三"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1629

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1630

    /// Number of PROOF tests at M1630。
    public static let proofTestCount: Int = 9

    /// 7 audit-projection aggregator types that gained
    /// Codable + Equatable at M1629。
    public static let typesGainedCodable: [String] = [
        "BASTurnAuditProjectionsCthulhuPenta",
        "BASTurnAuditProjectionsKunlunHexa",
        "BASTurnAuditProjectionsKunlunHexaTwo",
        "BASTurnAuditProjectionsLateClusterB",
        "BASTurnAuditProjectionsLateClusterC",
        "BASTurnAuditProjectionsLateClusterD",
        "BASTurnAuditProjectionsKunlunSealRiver"
    ]

    /// Total types extended at M1629 = 7。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Combined aggregator-Codable coverage across
    /// chapters 561+562+563:3 + 5 + 7 = 15 types。
    public static let combinedAggregatorCount: Int = 15

    /// Reference to chapter 562 extension doctrine。
    public static let previousExtensionDoctrineRef:
        String =
        "BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine"

    /// Conformances added per type at M1629。
    public static let conformancesAdded: [String] = [
        "Codable",
        "Equatable"
    ]

    /// PROOF method。 For most types in this batch
    /// compile-time conformance is the right PROOF
    /// level — the .compute(...) factories have too
    /// many parameters to make full round-trip PROOF
    /// tractable。
    public static let proofMethod: String =
        "compile-time-codable-conformance-with-tractable-round-trips-where-possible"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 7 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// 7 chapter-origin references for the 7 newly-
    /// Codable types。
    public static let originChapterRefs: [String] = [
        "chapter 四百八十六",   // CthulhuPenta
        "chapter 四百八十四",   // KunlunHexa
        "chapter 四百八十七",   // KunlunHexaTwo
        "chapter 四百八十九",   // LateClusterB
        "chapter 四百九十",     // LateClusterC
        "chapter 四百九十一",   // LateClusterD
        "chapter 四百九十二"    // KunlunSealRiver
    ]
}
