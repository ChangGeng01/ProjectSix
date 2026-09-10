// MARK: - BASRuntimeModeOverrideDoctrine
// chapter 六百七十二 / M2067 — typed surface commemorating
//                              Phase L safety net at M2065。

import Foundation

public enum BASRuntimeModeOverrideDoctrine {
    public static let chapterTag: String =
        "chapter 六百七十二"
    public static let phase: String = "Phase L"

    public static let firstKnifeMNumber: Int = 2065
    public static let secondKnifeMNumber: Int = 2066
    public static let thirdKnifeMNumber: Int = 2067
    public static let fourthKnifeMNumber: Int = 2068

    public static let overrideEnvVarName: String =
        "BAS_RUNTIME_MODE_OVERRIDE"

    public static let priorityOrder: [String] = [
        "BAS_RUNTIME_MODE_OVERRIDE (if set + valid)",
        "BAS_RUNTIME_MODE (if set + valid)",
        "defaultModeWhenAbsent (.v1ByteEqual)"
    ]

    public static let newApiMethods: [String] = [
        "currentRuntimeModeRespectingOverride(environment:)",
        "isOverrideActive(environment:)"
    ]

    public static let proofTestCount: Int = 14

    public static let originalCurrentRuntimeModeUnchanged:
        Bool = true

    public static let isPhaseLPreFlipSafetyNet: Bool = true

    public static let phaseLFlipChapter: String =
        "chapter 六百七十四"
    public static let phaseLFlipMNumber: Int = 2074

    public static let taggedCommitName: String =
        "pre-default-flip-M2068"
    public static let taggedCommitMNumber: Int = 2068

    public static let priorPhaseKCloseOutRef: String =
        "BASPhaseKRuntimeModeToggleCompletionDoctrine"
    public static let priorPreFlipGateContractRef:
        String = "BASPhaseLPreFlipGateContractDoctrine"

    public static let revertPathName: String =
        "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal"

    public static let zeroRedeployRollback: Bool = true
}
