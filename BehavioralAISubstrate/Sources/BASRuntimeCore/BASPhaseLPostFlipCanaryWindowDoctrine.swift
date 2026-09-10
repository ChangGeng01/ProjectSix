// MARK: - BASPhaseLPostFlipCanaryWindowDoctrine
// chapter 六百七十五 / M2077 — Phase L post-flip canary
//                              window pin。

import Foundation

public enum BASPhaseLPostFlipCanaryWindowDoctrine {
    public static let chapterTag: String =
        "chapter 六百七十五"
    public static let phase: String = "Phase L"

    public static let firstKnifeMNumber: Int = 2077
    public static let secondKnifeMNumber: Int = 2078
    public static let thirdKnifeMNumber: Int = 2079
    public static let fourthKnifeMNumber: Int = 2080

    public static let flipChapterTag: String =
        "chapter 六百七十四"
    public static let flipMNumber: Int = 2074

    /// 5-chapter post-flip canary window per BASPhaseLPre
    /// FlipGateContractDoctrine M2063。 V1 path remains
    /// callable via explicit `.v1ByteEqual` mode for 5
    /// chapters after the flip (canary window) before
    /// V1 deletion (Phase O) becomes eligible。
    public static let canaryWindowChapters: Int = 5

    public static let canaryStartChapterTag: String =
        "chapter 六百七十五"
    public static let canaryEndChapterTag: String =
        "chapter 六百八十"
    public static let v1DeletionEligibleAtChapterTag:
        String = "chapter 六百八十六"

    /// During the canary window,V1 path MUST remain
    /// callable via:
    ///   - `BASTurnRuntimeEngineConfiguration(runtime` +
    ///     `Mode: .v1ByteEqual)` explicit init
    ///   - `BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal` env
    public static let v1PathStillCallable: Bool = true

    public static let v1CallableMechanisms: [String] = [
        "explicit init(runtimeMode: .v1ByteEqual)",
        "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal env var"
    ]

    public static let priorChapter674Ref: String =
        "BASPhaseLDefaultFlipCompletionDoctrine"

    public static let phaseLChaptersTotal: Int = 4
    public static let phaseLClosedAt: String =
        "chapter 六百七十五"

    public static let isPhaseLFinalChapter: Bool = true
}
