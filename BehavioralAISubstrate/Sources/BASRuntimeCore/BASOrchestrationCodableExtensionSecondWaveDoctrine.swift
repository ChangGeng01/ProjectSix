// MARK: - BASOrchestrationCodableExtensionSecondWaveDoctrine
// chapter 五百七十二 / M1667 — typed surface
//                          commemorating the M1665
//                          second-wave Codable
//                          extension into BAS
//                          Orchestration
//
// ## Why this typed surface exists
//
// Second wave of the BASOrchestration Codable
// extension started at chapter 571。 2 more decision
// types gained Codable conformance:
//
//   - BASKunlunPermitEscalationDecision
//   - BASForbiddenCandidateZoneGateDecision
//
// Combined with chapter 571 (2 types):
//   - chapter 571:AssertionCeilingDecision +
//     AbyssalPermitEscalationDecision
//   - chapter 572:KunlunPermitEscalationDecision +
//     ForbiddenCandidateZoneGateDecision
//   = 4 BASOrchestration decision types now ledger-
//     serializable
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth
//   - chapter 三百九二:2 more types in replay-
//     determinism contract surface
//   - chapter 四百二十九:typed-surface count 112 → 113
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1666 → M1667

import Foundation

/// Typed surface commemorating the M1665 second-wave
/// Codable extension into BASOrchestration。
public enum BASOrchestrationCodableExtensionSecondWaveDoctrine {

    /// Chapter where this extension was shipped。
    public static let chapterTag: String =
        "chapter 五百七十二"

    /// M-number of the production conformance change。
    public static let extensionMNumber: Int = 1665

    /// M-number of the PROOF tests。
    public static let proofMNumber: Int = 1666

    /// Number of PROOF tests at M1666。
    public static let proofTestCount: Int = 2

    /// 2 BASOrchestration types that gained Codable at
    /// M1665。
    public static let typesGainedCodable: [String] = [
        "BASKunlunPermitEscalationDecision",
        "BASForbiddenCandidateZoneGateDecision"
    ]

    /// Total types extended at M1665 = 2。
    public static var totalTypesExtended: Int {
        return typesGainedCodable.count
    }

    /// All 2 types are in BASOrchestration module。
    public static let module: String = "BASOrchestration"

    /// Conformance added:Codable (Equatable was
    /// already present)。
    public static let conformancesAdded: [String] = [
        "Codable"
    ]

    /// PROOF method:2 compile-time conformance checks。
    public static let proofMethod: String =
        "compile-time-codable-conformance"

    /// V1 byte-equality preserved。
    public static let byteEqualityPreserved: Bool = true

    /// These 2 types are now in the chapter 三百九二
    /// replay-determinism contract surface。
    public static let nowInReplayDeterminismContract:
        Bool = true

    /// Reference to chapter 571 first-wave doctrine。
    public static let priorWaveDoctrineRef: String =
        "BASOrchestrationCodableExtensionDoctrine"

    /// Combined Orchestration Codable extension count
    /// across chapters 571 + 572:2 + 2 = 4 types。
    public static let combinedOrchestrationCount: Int = 4
}
