// MARK: - BASCrossModuleCodableExtensionDoctrine
// chapter 五百六十六 / M1643 — typed surface
//                          commemorating the M1641
//                          Codable extension to 5
//                          types ACROSS modules
//                          (BASRuntimeCore +
//                          BASMemory)
//
// ## Why this typed surface exists
//
// Chapters 561-565 extended Codable conformance to 17
// types in the BASHostKit audit-projection family。
// Chapter 566 expands beyond that family into:
//
//   - BASRuntimeCore (2 types):
//     * BASCoreMLFeatureFrame — CoreML input frames
//       used by all CoreML inference paths
//     * BASKnowledgeCycle — cycle detection result
//       for the knowledge-graph subsystem
//
//   - BASMemory (3 types):
//     * BASRAGResult — RAG retrieval pipeline result
//     * BASVectorIndexEntry — vector-index entry
//     * BASVectorTopKResult — top-k similarity result
//
// These types live in DIFFERENT modules from the
// audit-projection extensions of chapters 561-565,
// extending the replay-determinism surface into the
// memory + ML inference layers。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth
//   - chapter 三百九二:these 5 types now in replay-
//     determinism contract surface
//   - chapter 四百二十九:typed-surface count 106 → 107
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1642 → M1643

import Foundation

/// Typed surface commemorating the M1641 Codable
/// extension to 5 types spanning BASRuntimeCore +
/// BASMemory modules。
public enum BASCrossModuleCodableExtensionDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百六十六"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1641

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1642

    /// Number of PROOF tests at M1642。
    public static let proofTestCount: Int = 7

    /// 5 types that gained Codable + Equatable at
    /// M1641。 Some types only added Codable (already
    /// had Equatable) — see conformancesAddedPerType。
    public static let typesGainedCodable: [String] = [
        "BASCoreMLFeatureFrame",
        "BASKnowledgeCycle",
        "BASRAGResult",
        "BASVectorIndexEntry",
        "BASVectorTopKResult"
    ]

    /// Total types extended at M1641 = 5。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Module split — 2 BASRuntimeCore + 3 BASMemory。
    public static let moduleBreakdown:
        [(module: String, count: Int)] =
    [
        ("BASRuntimeCore", 2),
        ("BASMemory", 3)
    ]

    /// Total module count covered = 2。
    public static var modulesCovered: Int {
        return moduleBreakdown.count
    }

    /// Conformance added:Codable (Equatable was
    /// already present on all 5)。
    public static let conformancesAdded: [String] = [
        "Codable"
    ]

    /// PROOF method:5 compile-time conformance + 2
    /// populated round-trip tests on the simplest
    /// types (BASCoreMLFeatureFrame +
    /// BASVectorTopKResult)。
    public static let proofMethod: String =
        "compile-time-codable-conformance-plus-2-populated-round-trips"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 5 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// Differentiator:this extension covers types
    /// OUTSIDE the BASHostKit audit-projection family
    /// (which chapters 561-565 covered)。
    public static let outsideAuditProjectionFamily:
        Bool = true

    /// Reference to the chapter 564 aggregator-arc seal
    /// that complete the audit-projection family
    /// before this cross-module extension。
    public static let priorAuditProjectionArcSealRef:
        String =
        "BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine"
}
