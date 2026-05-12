// MARK: - BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
// chapter 五百六十四 / M1633 — typed milestone
//                          commemorating the 3-chapter
//                          aggregator-extension arc
//                          (chapters 561-563)
//
// ## What this milestone commemorates
//
// Across chapters 561-563,15 audit-projection
// aggregator types gained Codable + Equatable
// conformance via REAL substrate code changes (not
// doctrine-only additions):
//
//   - chapter 561 / M1621:3 types
//     * BASTurnAuditProjectionsKunlunAxisProtocol
//     * BASTurnAuditProjectionsKunlunTrio
//     * BASTurnAuditProjectionsAbyssalThermalTrio
//
//   - chapter 562 / M1625:5 types
//     * BASTurnAuditProjectionsSurfaceTrio
//     * BASTurnAuditProjectionsGateSideDeriveTrio
//     * BASTurnAuditProjectionsKunlunTrioTwo
//     * BASTurnAuditProjectionsLifecycleQuartet
//     * BASTurnAuditProjectionsKunlunTianmenTrio
//
//   - chapter 563 / M1629:7 types
//     * BASTurnAuditProjectionsCthulhuPenta
//     * BASTurnAuditProjectionsKunlunHexa
//     * BASTurnAuditProjectionsKunlunHexaTwo
//     * BASTurnAuditProjectionsLateClusterB
//     * BASTurnAuditProjectionsLateClusterC
//     * BASTurnAuditProjectionsLateClusterD
//     * BASTurnAuditProjectionsKunlunSealRiver
//
// All 15 types are now LEDGER-SERIALIZABLE for replay。
// All earlier BASTurnAuditProjections* types were
// either already Codable (KunlunInputs etc。) or
// namespace enums that don't need it (Counterweight
// Factory)。 The aggregator-extension arc is therefore
// COMPLETE。
//
// ## Pattern parity with chapter 553
//
// This arc-seal doctrine mirrors the chapter 553
// BASCodableCascadeArcSealedDoctrine pattern but for
// the AGGREGATOR layer rather than the cascade layer:
//
//   - chapter 553 sealed:cascade arc covering 16
//     types across 12 commits (chapters 551-553)
//   - chapter 564 seals:aggregator arc covering 15
//     types across 12 commits (chapters 561-563)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     across all 12 arc commits
//   - 红线 7:additive substrate-side change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for
//     the aggregator extension arc seal
//   - chapter 三百九二:these 15 types are now in
//     the replay-determinism contract surface
//   - chapter 四百二十九:typed-surface count 104 → 105
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1632 → M1633

import Foundation

/// Typed milestone doctrine commemorating the closure
/// of the 3-chapter aggregator Codable extension arc
/// (chapters 561-563 / M1621-M1633)。 15 audit-
/// projection aggregator types now ledger-serializable
/// for replay。
public enum BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine {

    /// Chapter where this milestone was sealed。
    public static let chapterTag: String =
        "chapter 五百六十四"

    /// M-number where this milestone was sealed。
    public static let milestoneMNumber: Int = 1633

    // MARK: - Arc range

    /// First chapter that contributed to the arc。
    public static let arcFirstChapter: String =
        "chapter 五百六十一"

    /// Last chapter that contributed to the arc
    /// (chapter 五百六十三)。
    public static let arcLastChapter: String =
        "chapter 五百六十三"

    /// First M-number of the arc (M1621)。
    public static let arcFirstMNumber: Int = 1621

    /// Last M-number of the arc (M1632 — final close-
    /// out)。
    public static let arcLastMNumber: Int = 1632

    /// M-number span (inclusive)。 1632 - 1621 + 1 = 12。
    public static var arcMNumberSpan: Int {
        return arcLastMNumber - arcFirstMNumber + 1
    }

    /// Number of contributing chapters (3 chapters:
    /// 561 + 562 + 563)。
    public static let arcChapterCount: Int = 3

    // MARK: - Aggregator coverage

    /// Total aggregator types extended with Codable +
    /// Equatable across the arc。 3 + 5 + 7 = 15。
    public static let totalAggregatorTypesExtended:
        Int = 15

    /// Per-chapter contributions (3 entries)。
    public static let perChapterContributions:
        [(chapterTag: String,
          mNumber: Int,
          typesAdded: Int)] =
    [
        ("chapter 五百六十一", 1621, 3),
        ("chapter 五百六十二", 1625, 5),
        ("chapter 五百六十三", 1629, 7)
    ]

    /// Sum of perChapterContributions.typesAdded
    /// must equal totalAggregatorTypesExtended。 PROOF
    /// invariant — anti-drift test asserts this。
    public static var sumOfChapterContributions: Int {
        return perChapterContributions
            .reduce(0) { $0 + $1.typesAdded }
    }

    // MARK: - Cross-doctrine refs

    /// Reference to the 3 chapter-specific extension
    /// doctrines that contributed to this arc。
    public static let perChapterExtensionDoctrineRefs:
        [String] =
    [
        "BASTurnAuditProjectionsTrioCodableExtensionDoctrine",
        "BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine",
        "BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine"
    ]

    /// Reference to the chapter 553 cascade arc-seal
    /// doctrine — this aggregator arc mirrors that
    /// pattern。
    public static let parallelArcRef: String =
        "BASCodableCascadeArcSealedDoctrine"

    // MARK: - 15 type list

    /// All 15 aggregator types that gained Codable in
    /// this arc (in chapter order)。
    public static let allTypesGainedCodable: [String] = [
        // chapter 561 (3)
        "BASTurnAuditProjectionsKunlunAxisProtocol",
        "BASTurnAuditProjectionsKunlunTrio",
        "BASTurnAuditProjectionsAbyssalThermalTrio",
        // chapter 562 (5)
        "BASTurnAuditProjectionsSurfaceTrio",
        "BASTurnAuditProjectionsGateSideDeriveTrio",
        "BASTurnAuditProjectionsKunlunTrioTwo",
        "BASTurnAuditProjectionsLifecycleQuartet",
        "BASTurnAuditProjectionsKunlunTianmenTrio",
        // chapter 563 (7)
        "BASTurnAuditProjectionsCthulhuPenta",
        "BASTurnAuditProjectionsKunlunHexa",
        "BASTurnAuditProjectionsKunlunHexaTwo",
        "BASTurnAuditProjectionsLateClusterB",
        "BASTurnAuditProjectionsLateClusterC",
        "BASTurnAuditProjectionsLateClusterD",
        "BASTurnAuditProjectionsKunlunSealRiver"
    ]

    /// Counts must agree — anti-drift PROOF。
    public static var listSizeMatchesTotalCount: Bool {
        return allTypesGainedCodable.count
            == totalAggregatorTypesExtended
    }

    // MARK: - Achievement flags

    /// All 15 types are now ledger-serializable for
    /// replay。
    public static let nowLedgerSerializable: Bool = true

    /// V1 byte-equality preserved at every commit
    /// boundary throughout the arc。
    public static let byteEqualityPreservedThroughout:
        Bool = true

    /// Arc covered REAL substrate changes,not just
    /// doctrine additions。 Differs from the chapter
    /// 553 cascade arc which was also real-substrate;
    /// this flag makes the substrate-side nature
    /// explicit for grep-able doctrine queries。
    public static let realSubstrateChange: Bool = true

    /// Aggregator-extension arc is COMPLETE — no
    /// remaining BASTurnAuditProjections* aggregator
    /// types lack Codable。 The only non-Codable type
    /// in the family is BASTurnAuditProjections
    /// CounterweightFactory which is a namespace enum
    /// (no instance state)。
    public static let arcComplete: Bool = true
}
