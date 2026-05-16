// MARK: - BASChapter696RecoveryProgressDoctrine
// chapter 六百九十六 / M2156 第三刀 — pins the chapter
//                                  696 recovery progress
//                                  + sync-surface refactor
//                                  pattern as reusable
//                                  doctrine。
//
// ## Why this doctrine exists
//
// User directive 「全面 完成 尚未解决 项目」 (chapter
// 696 / 2026-05-16) pushed for substrate-side resolution
// of items chapter 695 had catalogued as external-blocked。
//
// Chapter 696 found a SUBSTRATE-ACTIONABLE recovery path
// for half the SIGBUS bucket:
//
//   - 6 of 12 BASSubstrateReauditShadowEvaluator tests
//     RECOVERED via evaluateSync sync surface (M2154)
//   - 6 of 12 (BASMemoryClosedLoop + M306) REMAIN
//     skipped — they call into `public actor` types
//     (BASMemoryClosedLoopApplier + BASMemoryUsage
//     Tracker + BASSovereignAuditLedger) whose async
//     surface is enforced by Swift's actor model
//
// This 50% recovery contradicts the chapter 695 / M2152
// claim "substrate-actionable items remaining = 0"。
// The chapter 695 audit was bounded by what was
// considered at audit time;chapter 696 expanded the
// scope via empirical investigation。
//
// ## The recovery pattern (reusable)
//
// For any future SIGBUS-bucketed test:
//
//   1. Identify which substrate API the test calls into
//   2. Check if that API is `async` because of:
//      (a) genuine actor isolation → recovery NOT
//          viable via this pattern
//      (b) historical off-MainActor wrapping with no
//          actor isolation requirement → recovery
//          IS viable
//   3. For (b),ship a SYNC SURFACE alongside the
//      async one (purely additive,ADR-014 OPT-IN
//      preserved)
//   4. Migrate test from `async throws` to sync
//   5. Replace `await asyncMethod(...)` with `syncMethod
//      (...)`
//   6. Test now follows Diagnostic A pattern (sync test
//      + direct sync invocation) → PASSES
//
// ## Score impact
//
// 0 — saturation invariant holds。 No directive scores
// move。 But concrete test coverage RESTORED for 6
// previously-skipped integration tests。

import Foundation

/// chapter 六百九十六 / M2156 第三刀 — pins the chapter
/// 696 recovery progress + sync-surface refactor pattern。
public enum BASChapter696RecoveryProgressDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十六"
    public static let milestoneMNumber: Int = 2156

    // MARK: - Recovery counts

    /// Total SIGBUS-bucketed tests at chapter 693 / M2143
    /// triage doctrine inventory。
    public static let totalSignal10TestsAtTriage: Int = 12

    /// Tests RECOVERED at chapter 696 / M2154 via sync-
    /// surface refactor。
    public static let testsRecoveredAtM2154: Int = 6

    /// Tests REMAINING skipped post-M2154 (blocked by
    /// actor-model)。
    public static let testsRemainingSkipped: Int = 6

    /// Recovery percentage。
    public static var recoveryPercentage: Double {
        return Double(testsRecoveredAtM2154)
            / Double(totalSignal10TestsAtTriage) * 100.0
    }
    // = 50.0%

    public static var recoveryArithmeticHolds: Bool {
        return testsRecoveredAtM2154
            + testsRemainingSkipped
            == totalSignal10TestsAtTriage
    }

    // MARK: - Recovery pattern (reusable)

    /// 6-step recovery pattern documented for future
    /// SIGBUS-bucketed test migrations。
    public static let recoveryPatternSteps: [String] = [
        "1. Identify substrate API the test calls into",
        "2. Check if API is async because of (a) genuine actor isolation or (b) historical off-MainActor wrapping",
        "3. For (b),ship SYNC SURFACE alongside async (purely additive,ADR-014 OPT-IN preserved)",
        "4. Migrate test from `async throws` to sync",
        "5. Replace `await asyncMethod(...)` with `syncMethod(...)`",
        "6. Test now follows Diagnostic A pattern → PASSES"
    ]

    public static var recoveryPatternStepCount: Int {
        return recoveryPatternSteps.count
    }

    // MARK: - Substrate surfaces shipped at chapter 696

    /// 1 new substrate sync surface shipped at M2154。
    public static let substrateSyncSurfacesShippedAtChapter696:
        Int = 1

    /// Per-surface inventory。
    public static let syncSurfaceInventory: [String] = [
        "BASSubstrateReauditShadowEvaluator.evaluateSync(prompt:body:prePermitMode:sessionRef:turnRef:) -> BASShadowEvaluationResult"
    ]

    // MARK: - Remaining 6 tests:actor-blocked

    /// Why the remaining 6 cannot follow the same pattern。
    public static let actorBlockedAPIs: [String] = [
        "BASMemoryClosedLoopApplier (public actor)",
        "BASMemoryUsageTracker (public actor)",
        "BASSovereignAuditLedger (public actor)"
    ]

    public static var actorBlockedAPICount: Int {
        return actorBlockedAPIs.count
    }

    /// Recovery for actor-blocked tests would require
    /// breaking actor isolation,which is a bigger
    /// architectural decision than chapter 696 scope。
    public static let actorBlockedRecoveryRequiresIsolationBreak:
        Bool = true

    // MARK: - Cross-doctrine refs

    public static let priorSignal10TriageRef: String =
        "BASSignalTenIntegrationTestTriageDoctrine (chapter 693 / M2143 + M2146 + M2147 + M2155 chain)"

    public static let priorMaximallyResolvedRef: String =
        "BASSubstrateMaximallyResolvedDoctrine (chapter 695 / M2152 + M2155 amendment)"

    public static let priorEmpiricalDiagnosisRef: String =
        "BASSignal10EmpiricalDiagnosisTests (chapter 694 / M2146 Diagnostic A pattern)"

    // MARK: - HONEST framing pins

    /// Chapter 695 / M2152 "terminal state" claim was
    /// scope-bounded by what was audited at the time。
    /// Chapter 696 expanded the scope via empirical
    /// investigation and found a new recovery path。
    public static let chapter695TerminalStateScopeBounded:
        Bool = true

    /// Future empirical investigations MAY discover more
    /// recovery patterns for the 6 remaining tests OR
    /// other items currently catalogued as external-
    /// blocked。 No claim of "permanently irrecoverable"。
    public static let futureRecoveryPathsMayExist: Bool =
        true

    // MARK: - Methodology

    public static let methodology: String =
        "EMPIRICAL RECOVERY PATTERN DISCOVERY — when prior claim was 'not viable' or 'terminal',test NEW patterns;document new findings as additive amendments;don't accept catalog as permanent"

    public static let purelyAdditive: Bool = true

    public static let directiveScoreImpact: Int = 0
}
