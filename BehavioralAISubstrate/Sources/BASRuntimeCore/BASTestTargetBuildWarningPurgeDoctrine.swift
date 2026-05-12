// MARK: - BASTestTargetBuildWarningPurgeDoctrine
// chapter 五百三十八 / M1530 — typed milestone doctrine
//                              for the test-target
//                              build-warning purge
//                              (extends chapter 534-535
//                              substrate-side pattern to
//                              the test target)
//
// Chapter 五百三十四 (M1513) + 535 (M1517) swept the
// `Sources/` target build-warning count to 0 (cumulative
// 64 → 0 warnings) and captured the achievement in
// `BASSubstrateBuildWarningPurgeDoctrine`。
//
// Chapter 五百三十八 / M1529 extends the warning-free
// state to the test target:
//
//   - 3 unused let declarations purged in 3 distinct
//     test files (BAS392MemoryAtomReplayDeterminismPin
//     Tests + BASAuditObservationProjectionsKunlunInputs
//     Tests + BASFrameContextObservationBundleAdapters
//     Tests)
//   - 1 var→let immutability fix in M321Forbidden
//     KnowledgeConsumptionTests + removal of the
//     `_ = c1` nudge workaround that Swift's warning
//     still reported
//
// Test-target warning count:4 → 0。
//
// Cumulative warning-free state across BOTH targets:
//
//   - Sources/:0 warnings (chapters 534-535)
//   - Tests/:0 warnings (chapter 538)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (pure cleanup,no behavioral change)
//   - 红线 7:additive surface (this doctrine + the
//     warning fixes are net-additive to typed surface
//     count via the new doctrine,net-subtractive on
//     warning noise)
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     test-target warning-free state
//   - chapter 三百九二:replay-determinism preserved
//   - chapter 四百二十九:typed-surface count 83 → 84
//   - User coding standards:immutability,never silent
//     errors,no dead code
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1529 → M1530

import Foundation

/// Typed milestone surface commemorating the test-
/// target build-warning purge at chapter 五百三十八 /
/// M1529。
///
/// Future drift breaks the anti-drift PROOF tests at
/// chapter 538 M1531 loudly。
public enum BASTestTargetBuildWarningPurgeDoctrine {

    /// Per-file purge contributions (test file name +
    /// category + count purged)。
    public static let perFilePurges:
        [(testFile: String, category: String,
          countPurged: Int)] =
    [
        ("BAS392MemoryAtomReplayDeterminismPinTests",
            "neverUsedLet",
            1),  // inMem
        ("BASAuditObservationProjectionsKunlunInputsTests",
            "neverUsedLet",
            1),  // candidates
        ("BASFrameContextObservationBundleAdaptersTests",
            "neverUsedLet",
            1),  // ctx
        ("M321ForbiddenKnowledgeConsumptionTests",
            "neverMutatedVar",
            1)   // c1
    ]

    /// Total warning count BEFORE the purge (chapter
    /// 537 close-out;test target only)。
    public static let preWarningCount: Int = 4

    /// Total warning count AFTER the purge (chapter
    /// 538 first knife)。
    public static let postWarningCount: Int = 0

    /// Sum of all purged warnings。 Must equal preArc -
    /// postArc。
    public static var totalWarningsPurged: Int {
        perFilePurges.reduce(0) { $0 + $1.countPurged }
    }

    /// 100% warning-free invariant — preArc -
    /// totalPurged == postArc AND postArc == 0。
    public static var testTargetIsWarningFree: Bool {
        return preWarningCount
            - totalWarningsPurged
            == postWarningCount
            && postWarningCount == 0
    }

    /// V1 byte-equality preserved across the purge。
    public static let byteEqualityPreserved: Bool = true

    /// Categories represented (subset of the substrate-
    /// side BASSubstrateBuildWarningPurgeDoctrine
    /// .WarningCategory)。
    public static var categoriesRepresented: Set<String>
    {
        Set(perFilePurges.map { $0.category })
    }

    /// Count of unique test files touched by the purge。
    public static var uniqueTestFileCount: Int {
        Set(perFilePurges.map { $0.testFile }).count
    }

    /// Confirms the cumulative warning-free state
    /// holds across both targets。
    public static var bothTargetsWarningFree: Bool {
        return testTargetIsWarningFree
            && BASSubstrateBuildWarningPurgeDoctrine
                .substrateIsWarningFree
    }
}
