// MARK: - BASTurnAuditProjectionsTrioCodableExtensionDoctrine
// chapter 五百六十一 / M1623 — typed surface
//                          commemorating the M1621
//                          Codable extension to 3
//                          Trio/Protocol audit-
//                          projection types
//
// ## Why this typed surface exists
//
// M1621 added Codable + Equatable conformance to 3
// audit-projection aggregator types that previously
// sat at Sendable / Hashable only:
//
//   - BASTurnAuditProjectionsKunlunAxisProtocol
//     (chapter 四百九十三 / M1348)
//   - BASTurnAuditProjectionsKunlunTrio
//     (chapter 四百七十八 / M1288)
//   - BASTurnAuditProjectionsAbyssalThermalTrio
//     (chapter 四百七十八 baseline)
//
// All 3 types hold fields that conform to
// BASSchemaVersioned (Codable + Equatable + Sendable)
// so Codable synthesis works without manual coding。
//
// This is a REAL SUBSTRATE EXTENSION (not just a
// doctrine):the production code changed,gaining new
// conformance witnesses。 8 PROOF tests at M1622 verify
// populated round-trip + sortedKeys determinism +
// distinct-value negative PROOF。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface,no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for
//     this extension status
//   - chapter 三百九二:these 3 types are now part of
//     the replay-determinism contract
//   - chapter 四百二十九:typed-surface count 101 → 102
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1622 → M1623

import Foundation

/// Typed surface commemorating the M1621 Codable
/// extension to 3 Trio/Protocol audit-projection
/// aggregator types。
public enum BASTurnAuditProjectionsTrioCodableExtensionDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百六十一"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1621

    /// M-number of the PROOF tests verifying the
    /// extension。
    public static let proofMNumber: Int = 1622

    /// Number of PROOF tests shipped at M1622。
    public static let proofTestCount: Int = 8

    /// 3 audit-projection aggregator types that gained
    /// Codable + Equatable at M1621。
    public static let typesGainedCodable: [String] = [
        "BASTurnAuditProjectionsKunlunAxisProtocol",
        "BASTurnAuditProjectionsKunlunTrio",
        "BASTurnAuditProjectionsAbyssalThermalTrio"
    ]

    /// Total types extended = 3。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Conformances added per type。
    public static let conformancesAdded: [String] = [
        "Codable",
        "Equatable"
    ]

    /// PROOF method:JSONEncoder + sortedKeys +
    /// JSONDecoder + Equatable round-trip equality。
    public static let proofMethod: String =
        "codable-sortedKeys-json-round-trip"

    /// V1 byte-equality preserved at every commit
    /// boundary — adding Codable is additive
    /// conformance,no behavior change。
    public static let byteEqualityPreserved: Bool = true

    /// These 3 types are now part of the chapter 三百
    /// 九二 replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// Reference to the contract closure milestone
    /// doctrine。
    public static let contractClosureRef: String =
        "BASReplayDeterminismContractClosureDoctrine"

    /// 3 field-type families exercised by the PROOF
    /// tests across the 3 aggregator types。
    public static let fieldTypeFamiliesExercised:
        [String] =
    [
        "kunlun-protocol-stack (BASKunlunAxis + BASAxisAlignment)",
        "kunlun-control-flow (BASAscentLease + BASAxisDeviation + BASGatePressure)",
        "abyssal-thermal (BASAbyssalRunMode + BASAbyssBudget + BASMemoryTemperatureLayer)"
    ]

    /// Total field-type-family count = 3。
    public static var fieldTypeFamilyCount: Int {
        return fieldTypeFamiliesExercised.count
    }
}
