// MARK: - BASAuditObservationProjectionsInputsCodableExtensionDoctrine
// chapter 五百六十五 / M1639 — typed surface
//                          commemorating the M1637
//                          Codable extension to 2
//                          Inputs aggregator types
//
// ## Why this typed surface exists
//
// The aggregator-extension arc (chapters 561-564,
// sealed at M1633) extended Codable to 15 BASTurn
// AuditProjections* aggregator types。 But one layer
// up — the BASAuditObservationProjections*Inputs
// types — still lacked Codable because they aggregate
// the underlying types。
//
// M1637 extends Codable + Equatable to:
//   - BASAuditObservationProjectionsKunlunInputs
//     (holds 4 chapter-561-563-extended types)
//   - BASAuditObservationProjectionsCthulhuInputs
//     (holds 2 chapter-561-562-extended types)
//
// This natural follow-up was enabled by the M1633
// arc-seal — without the underlying types being
// Codable,this extension would not have synthesized
// cleanly。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth
//   - chapter 三百九二:these 2 types now in replay-
//     determinism contract surface
//   - chapter 四百二十九:typed-surface count 105 → 106
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1638 → M1639

import Foundation

/// Typed surface commemorating the M1637 Codable
/// extension to 2 high-level Inputs aggregator types。
public enum BASAuditObservationProjectionsInputsCodableExtensionDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百六十五"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1637

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1638

    /// Number of PROOF tests at M1638。
    public static let proofTestCount: Int = 2

    /// 2 Inputs types that gained Codable + Equatable
    /// at M1637。
    public static let typesGainedCodable: [String] = [
        "BASAuditObservationProjectionsKunlunInputs",
        "BASAuditObservationProjectionsCthulhuInputs"
    ]

    /// Total types extended at M1637 = 2。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Conformances added per type at M1637。
    public static let conformancesAdded: [String] = [
        "Codable",
        "Equatable"
    ]

    /// PROOF method:compile-time Codable conformance
    /// (the underlying aggregators are PROOFed in
    /// chapters 561-563)。
    public static let proofMethod: String =
        "compile-time-codable-conformance-upstream-aggregators-pre-proofed"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 2 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// Reference to the M1633 arc-seal doctrine that
    /// enabled this extension。 Without the chapter
    /// 561-563 aggregator arc being complete,these
    /// Inputs types could not have gained Codable
    /// cleanly。
    public static let prerequisiteArcSealDoctrineRef:
        String =
        "BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine"

    /// Underlying aggregator types that each Inputs
    /// type holds (and therefore depends on for
    /// Codable synthesis)。 Each is in the chapter
    /// 561-563 arc。
    public static let upstreamDependencies:
        [(inputs: String, upstream: [String])] =
    [
        (inputs:
            "BASAuditObservationProjectionsKunlunInputs",
         upstream: [
            "BASTurnAuditProjectionsKunlunTrio",
            "BASTurnAuditProjectionsKunlunHexa",
            "BASTurnAuditProjectionsKunlunTrioTwo",
            "BASTurnAuditProjectionsKunlunHexaTwo"
         ]),
        (inputs:
            "BASAuditObservationProjectionsCthulhuInputs",
         upstream: [
            "BASTurnAuditProjectionsAbyssalThermalTrio",
            "BASTurnAuditProjectionsCthulhuPenta"
         ])
    ]
}
