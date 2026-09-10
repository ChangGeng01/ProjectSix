// MARK: - BASTypedObservabilitySinkCatalogueDoctrine
// chapter 五百四十 / M1537 — unified typed milestone
//                            doctrine cataloguing all 3
//                            typed observability sinks
//                            shipped to date (chapters
//                            536 + 537 + 539)
//
// Across chapters 536-539 the substrate gained 3 typed
// observability sinks that resolve documented silent-
// swallow paths into structured failure records hosts
// can opt into observing:
//
//   1. BASHostStorageInitialAtomAdmitFailureLog
//      (chapter 536 / M1521-M1524) — covers 2 paths in
//      BASHostStorageWireBuilder
//   2. BASTurnRuntimeEngineObservationFailureLog
//      (chapter 537 / M1525-M1528) — covers 4 paths in
//      BASTurnRuntimeEngine
//   3. BASAuditEmissionFailureLog
//      (chapter 539 / M1533-M1536) — covers 2 cross-
//      module paths in BASHostKit + BASSovereign
//
// 3 sinks total covering 8 documented silent-swallow
// paths。 Each sink is opt-in (ADR-014):default nil →
// behavior unchanged from pre-sink era;non-nil → record
// failures to the actor sink。
//
// This doctrine commemorates the achievement as a typed
// surface that:
//
//   1. Catalogues each sink with its origin chapter +
//      M-number range + path count
//   2. Pins the cumulative invariant (3 sinks,8 paths)
//      so future drift breaks loudly
//   3. Provides anti-drift PROOF tests at chapter 540
//      第二刀 + wire-in PROOF tests at 第三刀
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (the catalogue is metadata only;sinks remain
//     opt-in)
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     observability sink catalogue
//   - chapter 三百九二:replay-determinism via
//     Codable + Equatable record
//   - chapter 四百二十九:typed-surface count 85 → 86
//   - User error-handling standard:errors NO LONGER
//     silently swallowed across 8 documented paths
//     when hosts opt in
//   - ADR-014 OPT-IN:default behavior unchanged across
//     all sinks
//   - ADR-016 advances M1536 → M1537

import Foundation

/// Discriminates which typed observability sink an entry
/// represents in the catalogue。
public enum BASTypedObservabilitySinkID:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Chapter 536:
    /// BASHostStorageInitialAtomAdmitFailureLog
    case hostStorageInitialAtomAdmit

    /// Chapter 537:
    /// BASTurnRuntimeEngineObservationFailureLog
    case turnRuntimeEngineObservation

    /// Chapter 539:
    /// BASAuditEmissionFailureLog (cross-module)
    case auditEmission
}

/// Typed catalogue entry pairing a sink's identity with
/// its origin chapter + M-number range + path count +
/// type name。
public struct BASTypedObservabilitySinkCatalogueEntry:
    Codable, Sendable, Equatable, Hashable
{
    public let id: BASTypedObservabilitySinkID
    public let typeName: String
    public let originChapter: String
    public let mNumberFirst: Int
    public let mNumberLast: Int
    public let coveredPathCount: Int

    public init(
        id: BASTypedObservabilitySinkID,
        typeName: String,
        originChapter: String,
        mNumberFirst: Int,
        mNumberLast: Int,
        coveredPathCount: Int
    ) {
        self.id = id
        self.typeName = typeName
        self.originChapter = originChapter
        self.mNumberFirst = mNumberFirst
        self.mNumberLast = mNumberLast
        self.coveredPathCount = coveredPathCount
    }
}

/// Unified typed milestone surface cataloguing all 3
/// observability sinks shipped to date (chapters 536 +
/// 537 + 539)。
public enum BASTypedObservabilitySinkCatalogueDoctrine {

    /// The 3 catalogue entries in chronological order。
    public static let entries:
        [BASTypedObservabilitySinkCatalogueEntry] =
    [
        BASTypedObservabilitySinkCatalogueEntry(
            id: .hostStorageInitialAtomAdmit,
            typeName:
                "BASHostStorageInitialAtomAdmitFailureLog",
            originChapter: "chapter 五百三十六",
            mNumberFirst: 1521,
            mNumberLast: 1524,
            coveredPathCount: 2),
        BASTypedObservabilitySinkCatalogueEntry(
            id: .turnRuntimeEngineObservation,
            typeName:
                "BASTurnRuntimeEngineObservationFailureLog",
            originChapter: "chapter 五百三十七",
            mNumberFirst: 1525,
            mNumberLast: 1528,
            coveredPathCount: 4),
        BASTypedObservabilitySinkCatalogueEntry(
            id: .auditEmission,
            typeName:
                "BASAuditEmissionFailureLog",
            originChapter: "chapter 五百三十九",
            mNumberFirst: 1533,
            mNumberLast: 1536,
            coveredPathCount: 2)
    ]

    /// Count of typed observability sinks shipped to
    /// date。 Pinned at 3。
    public static let sinkCount: Int = 3

    /// Total silent-swallow paths covered across all
    /// sinks。 Computed sum;must equal 2+4+2 = 8。
    public static var totalCoveredPathCount: Int {
        entries.reduce(0) { $0 + $1.coveredPathCount }
    }

    /// 8-path invariant — must hold。
    public static let expectedTotalCoveredPathCount: Int
        = 8

    /// Confirms the catalogue's sink count + total
    /// covered path count match the pinned invariants。
    public static var catalogueIsConsistent: Bool {
        return entries.count == sinkCount
            && totalCoveredPathCount
                == expectedTotalCoveredPathCount
    }

    /// First chapter of the observability-sink arc。
    public static let firstChapterMNumber: Int = 1521

    /// Last chapter of the observability-sink arc。
    public static let lastChapterMNumber: Int = 1536

    /// Lookup an entry by its sink ID。 Returns nil if
    /// the ID isn't catalogued (which would indicate
    /// drift)。
    public static func entry(
        for id: BASTypedObservabilitySinkID
    ) -> BASTypedObservabilitySinkCatalogueEntry? {
        return entries.first { $0.id == id }
    }
}
