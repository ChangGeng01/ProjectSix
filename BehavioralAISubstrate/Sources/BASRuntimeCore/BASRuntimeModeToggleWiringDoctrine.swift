// MARK: - BASRuntimeModeToggleWiringDoctrine
// chapter 六百六十八 / M2051 — typed surface commemorating
//                              Phase K first chapter:
//                              M2049 BASHostRuntime gains
//                              `buildEBrainTurnWithRuntime
//                              Mode` async opt-in surface
//                              + M2050 pins the
//                              BASTurnRuntimeMode enum
//                              surface。
//
// ## What this chapter ships
//
//   - M2049 第一刀:NEW public async function
//     `BASHostRuntime.buildEBrainTurnWithRuntimeMode(
//      request:currentBrain:projection:deviceStateOverride:
//      runtimeMode:now:)` on EBrainHostRuntimeSynthesis。
//     Default runtimeMode = `.v1ByteEqual` (M2032 baseline
//     preserved)。 .nativeV2 / .stressSweepDual wrap the
//     coordinator in `BASTurnRuntimeEngine` for V2 path
//     experimentation。
//   - M2050 第二刀:7 PROOF tests pinning the
//     `BASTurnRuntimeMode` enum surface — 3 cases,raw
//     values,Codable round-trip,Hashable+Equatable
//     conformances,V1 default contract。
//   - M2051 第三刀:THIS typed surface doctrine + anti-
//     drift tests。
//   - M2052 第四刀:13-file standard close-out sync。
//
// ## Why this is Phase K kernel deliverable
//
// Phase K's goal:add `runtimeMode` knob to
// EBrainHostRuntimeSynthesis so hosts can opt into V2
// path execution。 chapter 669 ships the dual-mode stress
// sweep test asserting V1 + V2 paths produce byte-equal
// `BASEBrainTurnResult` under canonical60 + extended
// fixtures。 chapter 670 wires SampleHost
// `BAS_RUNTIME_MODE` env var to this param。 chapter
// 671 ships Phase K close-out doctrine。 chapter 674
// (Phase L) flips the default from `.v1ByteEqual` →
// `.nativeV2` after 24h dual-mode 0-divergence gate clears。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (sync buildEBrainTurn path UNCHANGED;async opt-in
//     defaults to .v1ByteEqual = byte-equal)
//   - 红线 7 — runtimeMode is a hint,not authority
//   - chapter 二百一一 — single source-of-truth for
//     runtimeMode wiring (no duplicate code paths)
//   - chapter 三百九二 — replay-determinism preserved
//   - ADR-014 OPT-IN — purely additive,default = V1
//   - ADR-016 → M2051

import Foundation

public enum BASRuntimeModeToggleWiringDoctrine {

    public static let chapterTag: String =
        "chapter 六百六十八"
    public static let phase: String = "Phase K"
    public static let phaseGoal: String =
        "runtimeMode toggle + dual-mode CI for Phase L default flip readiness"

    // MARK: - 4-knife M-number pins

    public static let firstKnifeMNumber: Int = 2049
    public static let secondKnifeMNumber: Int = 2050
    public static let thirdKnifeMNumber: Int = 2051
    public static let fourthKnifeMNumber: Int = 2052

    // MARK: - New async surface

    public static let newAsyncSurfaceName: String =
        "buildEBrainTurnWithRuntimeMode"

    public static let newAsyncSurfaceLocation: String =
        "BASHostRuntime extension in EBrainHostRuntimeSynthesis.swift"

    /// The 6 parameters the new async surface accepts。
    public static let newAsyncSurfaceParameters:
        [String] = [
        "request",
        "currentBrain",
        "projection",
        "deviceStateOverride",
        "runtimeMode",
        "now"
    ]

    public static var newAsyncSurfaceParameterCount: Int {
        return newAsyncSurfaceParameters.count
    }

    public static let newAsyncSurfaceDefaultRuntimeMode:
        String = "v1ByteEqual"

    // MARK: - Refactor extracted helper

    public static let extractedHelperName: String =
        "buildCoordinator"

    public static let extractedHelperPrivacy: String =
        "private"

    public static let extractedHelperRationale: String =
        "single source-of-truth for V1 service wiring shared between sync + async paths"

    // MARK: - PROOF tests at M2050

    public static let proofTestCount: Int = 7

    public static let proofTestNames: [String] = [
        "testBASTurnRuntimeModeAllCasesCount",
        "testBASTurnRuntimeModeCases",
        "testBASTurnRuntimeModeRawValues",
        "testBASTurnRuntimeModeIsCodable",
        "testBASTurnRuntimeModeIsHashable",
        "testBASTurnRuntimeModeIsEquatable",
        "testV1ByteEqualIsTheDefaultPhaseKMode"
    ]

    // MARK: - Mode handling

    public static let v1ByteEqualBehavior: String =
        "direct coordinator.runTurn — byte-equal to existing synchronous buildEBrainTurn"

    public static let nativeV2Behavior: String =
        "wraps coordinator in BASTurnRuntimeEngine + calls engine.runTurn — currently delegates to V1 for byte-equality but emits M991 lifecycle envelopes"

    public static let stressSweepDualBehavior: String =
        "same engine wrap as nativeV2; chapter 669 dual-mode stress sweep test uses this mode to compare V1+V2 digests"

    public static let modeCount: Int = 3

    // MARK: - Phase K progress markers

    public static let isPhaseKFirstChapter: Bool = true

    public static let phaseKChaptersTotal: Int = 4

    public static let phaseKChaptersRemainingAfterThis:
        Int = 3

    public static let phaseKRemainingChapters:
        [String] = [
        "chapter 六百六十九",
        "chapter 六百七十",
        "chapter 六百七十一"
    ]

    // MARK: - Backward compatibility

    public static let syncBuildEBrainTurnPreserved:
        Bool = true

    public static let adr014OptInPreserved: Bool = true

    public static let byteEqualityPreserved: Bool = true

    public static let purelyAdditive: Bool = true

    // MARK: - Phase L readiness target

    public static let phaseLDefaultFlipChapterTag:
        String = "chapter 六百七十四"

    public static let phaseLDefaultFlipMNumber: Int = 2074

    public static let phaseLPreFlipGateChapterTag:
        String = "chapter 六百七十三"

    public static let phaseLPreFlipGateDuration: String =
        "24h dual-mode 0-divergence"

    // MARK: - Cross-doctrine refs

    public static let priorPhaseJCompletionRef: String =
        "BASPhaseJKernelCacheCompletionDoctrine"

    public static let priorBASTurnRuntimeEngineRef:
        String = "BASTurnRuntimeEngine"

    public static let priorBASTurnRuntimeModeEnumRef:
        String = "BASTurnRuntimeMode"

    public static let planRef: String =
        "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase K"
}
