// MARK: - BASLeaseLifeCodableExtensionWaveTwoDoctrine
// chapter 五百八十二 / M1707 — typed surface
//                          commemorating the M1705
//                          BASLeaseLife wave 2 Codable
//                          extension
//
// ## Why this typed surface exists
//
// Second wave of BASLeaseLife Codable extension,
// continuing the chapter 581 first-ever extension into
// this module。 Adds 2 more struct types + 1
// supporting enum,bringing cumulative BASLeaseLife
// Codable count to 4 types + 1 enum。
//
// 2 BASLeaseLife struct types + 1 supporting enum
// gained Codable conformance at M1705:
//
//   - OSThermalState (NECESSARY PRECURSOR)
//     * String raw-value enum with 4 cases
//       (nominal/fair/serious/critical)
//     * Required by BASThermalTwin.Reading.osState
//
//   - BASThermalTwin.Reading
//     * 5-field composite:osState (OSThermalState,
//       now Codable),thermalLevel (BASThermalLevel),
//       guardLevel (BASThermalGuardLevel),
//       accumulatedPressure (Double),observedAt (Date)
//
//   - BASLungStateAccumulator.Snapshot
//     * 4-field composite:pressure (Double),turnCount
//       (Int),lastTurnAt (Date?),lastDecayAt (Date?)
//
// Combined BASLeaseLife Codable count:
//   - chapter 581 wave 1:2 types (BreathScheduler.
//     Request + ScheduledBreath)
//   - chapter 582 wave 2:2 types + 1 enum  ← this
//   = 4 BASLeaseLife types + 1 supporting enum now
//   ledger-serializable
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for
//     wave 2
//   - chapter 三百九二:2 more types + 1 enum in
//     replay-determinism contract surface
//   - chapter 四百二十九:typed-surface count 122 → 123
//   - chapter 581 precedent:BASLeaseLifeCodable
//     ExtensionDoctrine (wave 1)
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1706 → M1707

import Foundation

/// Typed surface commemorating the M1705 wave 2
/// Codable extension into BASLeaseLife。 Continues the
/// chapter 581 first-ever extension。
public enum BASLeaseLifeCodableExtensionWaveTwoDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百八十二"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1705

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1706

    /// Number of PROOF tests at M1706。
    public static let proofTestCount: Int = 3

    /// 2 BASLeaseLife struct types + 1 supporting
    /// enum that gained Codable at M1705。
    public static let typesGainedCodable: [String] = [
        "BASThermalTwin.OSThermalState",
        "BASThermalTwin.Reading",
        "BASLungStateAccumulator.Snapshot"
    ]

    /// Total types extended at M1705 = 3 (2 structs +
    /// 1 supporting enum)。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// Number of struct types (excluding the
    /// supporting enum)。
    public static let structTypesCount: Int = 2

    /// Number of supporting enums。
    public static let supportingEnumCount: Int = 1

    /// All types are in BASLeaseLife module。
    public static let module: String = "BASLeaseLife"

    /// Conformance added:Codable。
    public static let conformancesAdded: [String] = [
        "Codable"
    ]

    /// PROOF method:3 compile-time conformance checks。
    public static let proofMethod: String =
        "compile-time-codable-conformance"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 3 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// Reference to the chapter 581 wave 1 doctrine。
    public static let waveOneDoctrineRef: String =
        "BASLeaseLifeCodableExtensionDoctrine"

    /// Combined BASLeaseLife Codable struct count:
    /// 2 (chapter 581 wave 1) + 2 (this wave 2) = 4。
    public static let combinedLeaseLifeStructCount:
        Int = 4

    /// Wave number within the BASLeaseLife extension
    /// (chapter 581 = 1,this = 2)。
    public static let leaseLifeWaveNumber: Int = 2

    /// Beyond-arc chapter number (chapter 581 = 1,
    /// chapter 582 = 2)。
    public static let beyondArcChapterNumber: Int = 2
}
