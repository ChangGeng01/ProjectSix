// MARK: - BASSignalTenIntegrationTestTriageDoctrine
// chapter 六百九十三 / M2143 第二刀 — pre-existing
//                                  signal-10 (SIGBUS)
//                                  integration test
//                                  failure triage doctrine。
//
// ## What this doctrine pins
//
// 12 known integration tests crash with `signal code 10`
// (SIGBUS) when run on the current toolchain (Xcode
// 26.4.1 / Swift 6.3.1 / arm64-apple-macosx26.0)。 All
// 12 share a common shape:
//
//   - `async` (or `async throws`) `XCTestCase` method
//   - constructs a `BASHostRuntime` via
//     `.fixtureGeneric`
//   - calls `runtime.startSession(...)` (sometimes
//     wrapped in `Task.detached`)
//   - process aborts with `signal code 10` before the
//     XCTest assertion logic runs
//
// ## Affected tests (12)
//
// BASSubstrateReauditShadowEvaluatorTests:
//   - testEvaluateNonEmptyBodyProducesReauditReasonCode
//   - testEvaluateLongBodyEmitsTruncationCode
//   - testEvaluateShortBodyDoesNotEmitTruncationCode
//   - testCustomEvaluatorVersionPropagates
//   - testCustomWorkflowAndRiskAccepted
//   - testBodyTruncationInitClampsBelow64
//
// BASMemoryClosedLoopApplierHostRuntimeIntegrationTests:
//   - testHostRuntimeDrivesClosedLoopWithRealSessions
//   - testRuntimeWithoutRetrievalRecordingProducesNoMutations
//   - testSQLiteBackedClosedLoopSurvivesRuntimeRestart
//
// M306MultiSessionContinuityTests:
//   - testAppendRejectsRuntimeSignatureAndAcceptsCleared
//   - testRehydrationLoadsPreviousSessionEntries
//   - testVerificationLedgerSeesBothEntries
//
// ## Tests NOT affected
//
// Same XCTestCase classes contain tests that PASS:
//   - testDefaultEvaluatorVersionMatchesConstant (sync)
//   - testEvaluateEmptyBodyReturnsSkipped (async,empty-
//     body skip path,no startSession call)
//   - testConformsToProtocol (sync)
//   - testDistinctSessionConfigsProduceDistinctAuditIDs
//     (sync)
//   - testBothSessionsCarryM298ThroughM305Codes (sync)
//   - testAuditLedgerUsesCanonicalFilenameUnderRoot (sync)
//
// → Pattern correlates with `async + startSession`
// invocation,not with the test class itself。
//
// ## Suspected root cause
//
// Three contributing factors hypothesized (uncategorized
// because no debugger access to confirm):
//
//   1. Swift 6 strict concurrency + XCTest's async test
//      invocation + Task.detached interaction has a
//      narrow window where execution context drifts to
//      an invalid memory page。 The crash is consistent
//      enough to be deterministic but happens too early
//      for the test body to even start。
//   2. Phase L M2074 `BASTurnRuntimeEngineConfiguration
//      .default()` flip (v1ByteEqual → nativeV2) may
//      have introduced a code path that allocates memory
//      with stricter alignment than the host expects
//      under Swift 6。 (However:`HostRuntimeCore.start
//      Session(...)` does not directly consume the V2
//      runtime engine,so this is a downstream chain
//      hypothesis,not a direct linkage。)
//   3. Macos 26 SDK + xctest binary linkage may have
//      changed how async test methods bridge to
//      Objective-C XCTest infrastructure。 Earlier
//      toolchains (Xcode 24/25) may not have surfaced
//      this。
//
// ## Triage classification
//
// PRE-EXISTING:not introduced by chapter 692 / Tier
// A+B+C completion arc。 Verified via stash-test against
// chapter 689 / 690 / 691 / 692 commit boundaries (all
// 12 tests failed identically before chapter 693)。
//
// NOT-BLOCKING:60/60 score sealed at chapter 689 holds;
// substrate AT-REST declared at chapter 691 holds;Tier
// A+B+C completion at chapter 692 holds。
//
// OPTIONAL:per chapter 691 BASPostSealFollowupCatalog
// Doctrine,toolchain compatibility issues fall in the
// "external-architecture / external-tooling" deferral
// category。
//
// ## Recovery paths (any one,not all)
//
//   1. Toolchain rollback:downgrade Xcode to 25.x and
//      verify tests turn green (host-side gate)。
//   2. Toolchain upgrade:wait for Xcode 26.5+ and
//      retry。
//   3. Test infrastructure rewrite:eliminate `Task
//      .detached` from BASSubstrateReauditShadowEvaluator
//      (use `await runtime.startSession(...)` directly
//      if a thread-safe async surface ships)。
//   4. Phase L revert:set `BAS_RUNTIME_MODE_OVERRIDE=
//      v1-byte-equal` at process launch (already pinned
//      as Phase L safety net at chapter 672 / M2065 +
//      chapter 670 / M2057 SampleHost bridge)。 Test
//      harness may need explicit env-var injection。
//   5. Per-test XCTSkip with this doctrine reference
//      (chapter 693 / M2143 ships these skips alongside
//      this doctrine)。
//
// ## Verification gate for un-skipping
//
// When recovery candidate ships,run:
//
//   swift test --filter "BASSubstrateReauditShadowEvaluator
//     Tests|BASMemoryClosedLoopApplierHostRuntime
//     IntegrationTests|M306MultiSessionContinuityTests"
//
// Expected:12/12 PASS,zero signal-10 failures。

import Foundation

/// chapter 六百九十三 / M2143 第二刀 — pins the
/// pre-existing signal-10 (SIGBUS) integration test
/// failure bucket。
public enum BASSignalTenIntegrationTestTriageDoctrine {

    public static let chapterTag: String =
        "chapter 六百九十三"
    public static let milestoneMNumber: Int = 2143

    // MARK: - Affected test inventory

    /// 12 known affected test method names。
    public static let affectedTestMethodNames: [String] = [
        // BASSubstrateReauditShadowEvaluatorTests (6)
        "BASSubstrateReauditShadowEvaluatorTests.testEvaluateNonEmptyBodyProducesReauditReasonCode",
        "BASSubstrateReauditShadowEvaluatorTests.testEvaluateLongBodyEmitsTruncationCode",
        "BASSubstrateReauditShadowEvaluatorTests.testEvaluateShortBodyDoesNotEmitTruncationCode",
        "BASSubstrateReauditShadowEvaluatorTests.testCustomEvaluatorVersionPropagates",
        "BASSubstrateReauditShadowEvaluatorTests.testCustomWorkflowAndRiskAccepted",
        "BASSubstrateReauditShadowEvaluatorTests.testBodyTruncationInitClampsBelow64",
        // BASMemoryClosedLoopApplierHostRuntime
        // IntegrationTests (3)
        "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests.testHostRuntimeDrivesClosedLoopWithRealSessions",
        "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests.testRuntimeWithoutRetrievalRecordingProducesNoMutations",
        "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests.testSQLiteBackedClosedLoopSurvivesRuntimeRestart",
        // M306MultiSessionContinuityTests (3)
        "M306MultiSessionContinuityTests.testAppendRejectsRuntimeSignatureAndAcceptsCleared",
        "M306MultiSessionContinuityTests.testRehydrationLoadsPreviousSessionEntries",
        "M306MultiSessionContinuityTests.testVerificationLedgerSeesBothEntries"
    ]

    public static var affectedTestCount: Int {
        return affectedTestMethodNames.count
    }

    // MARK: - Affected test class inventory

    /// 3 known affected test classes。
    public static let affectedTestClasses: [String] = [
        "BASSubstrateReauditShadowEvaluatorTests",
        "BASMemoryClosedLoopApplierHostRuntimeIntegrationTests",
        "M306MultiSessionContinuityTests"
    ]

    public static var affectedTestClassCount: Int {
        return affectedTestClasses.count
    }

    // MARK: - Pattern signature

    /// Common shape:async test method + BASHostRuntime
    /// .startSession() invocation → signal 10 SIGBUS
    /// crash before test body assertions execute。
    public static let commonPatternSignature: String =
        "async XCTestCase method + BASHostRuntime.startSession() → SIGBUS"

    // MARK: - Toolchain context

    public static let observedToolchain: String =
        "Xcode 26.4.1 / Swift 6.3.1 / arm64-apple-macosx26.0"

    public static let signalCode: Int = 10
    public static let signalName: String = "SIGBUS"

    // MARK: - Triage classification

    public static let isPreExisting: Bool = true
    public static let isBlocking: Bool = false
    public static let isOptional: Bool = true

    /// Confirmed pre-existing by stash-test against
    /// chapter 689 / 690 / 691 / 692 commit boundaries
    /// — all 12 tests failed identically before chapter
    /// 693。
    public static let preExistingVerificationMethod: String =
        "stash-test against chapter 689/690/691/692 boundaries"

    /// Falls in chapter 691 BASPostSealFollowupCatalog
    /// Doctrine's "external-architecture / external-
    /// tooling" deferral category。
    public static let deferralCategoryRef: String =
        "BASPostSealFollowupCatalogDoctrine external-architecture/external-tooling"

    // MARK: - Recovery paths

    /// 5 recovery candidates,any single one sufficient。
    public static let recoveryCandidates: [String] = [
        "toolchain-rollback-to-xcode-25",
        "toolchain-upgrade-to-xcode-26.5",
        "test-infrastructure-eliminate-task-detached",
        "phase-l-revert-via-BAS_RUNTIME_MODE_OVERRIDE-env-var",
        "per-test-XCTSkip-with-doctrine-reference"
    ]

    public static var recoveryCandidateCount: Int {
        return recoveryCandidates.count
    }

    /// Chosen recovery path for chapter 693:per-test
    /// XCTSkip with explicit doctrine reference (#5
    /// above)。
    public static let chosenRecoveryPathChapter693:
        String = "per-test-XCTSkip-with-doctrine-reference"

    // MARK: - Score impact

    public static let directiveScoreImpact: Int = 0

    /// 60/60 saturation invariant holds — toolchain
    /// triage doctrines don't move directive scores。
    public static let saturationInvariantPreserved: Bool =
        true

    // MARK: - Cross-doctrine refs

    public static let priorPostSealFollowupCatalogRef:
        String =
        "BASPostSealFollowupCatalogDoctrine (chapter 691 / M2137)"

    public static let priorPhaseLFlipRef: String =
        "BASPhaseLDefaultFlipCompletionDoctrine (chapter 674 / M2074)"

    /// Phase L safety net for V2 rollback at process
    /// launch level (env-var-driven)。
    public static let phaseLEnvOverrideMechanism: String =
        "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal"

    // MARK: - Methodology pin

    public static let methodology: String =
        "HONEST TRIAGE — name the problem,document the bucket,don't pretend it's fixed"

    public static let purelyAdditive: Bool = true

    // MARK: - Swift-Testing full-suite scheduling SIGBUS
    //         (M2144 amendment ORIGINAL + M2147 CORRECTION)
    //
    // M2144 ORIGINAL framing:claimed swift-testing
    // "passes in isolation,crashes only when concurrent
    // with the 11000+ XCTest sweep"。
    //
    // M2147 EMPIRICAL CORRECTION:full-suite Swift Testing
    // ALSO crashes when run in isolation via
    // `swift test --enable-swift-testing --disable-xctest`。
    // 398 of 419 `@Test` cases (across 67 `@Suite`s) start
    // before SIGBUS,ZERO complete (no `✔ passed` markers)。
    //
    // CORRECTED ROOT-CAUSE FRAMING:swiftpm-testing-helper
    // crashes during full-suite scheduling regardless of
    // concurrent XCTest presence。 Narrow filter
    // (`--filter <SuiteName>`) DOES pass — the issue is
    // scope-correlated,not concurrency-correlated。
    //
    // Classified as:full-suite scheduling bug in the
    // swiftpm-testing-helper process,NOT a substrate bug
    // AND NOT a concurrent-runner flakiness。
    //
    // Recovery candidates:
    //   1. Filter to narrower scope (`swift test --filter
    //      <specific-suite-name>`) for partial coverage
    //   2. Wait for SwiftPM/swift-testing toolchain fix
    //   3. Toolchain bisect to find when full-suite
    //      scheduling broke
    //
    // The M2144 ORIGINAL framing pins below are PRESERVED
    // for history tracking but the boolean shifts to
    // false-with-correction semantics — see
    // M2147CorrectionApplied flag below。

    /// M2144 ORIGINAL claim:swift-testing concurrent-run
    /// flakiness。 PRESERVED for history tracking; the
    /// claim was empirically incorrect per M2147。
    public static let swiftTestingConcurrentRunFlakinessKnown:
        Bool = true

    /// M2147 CORRECTION:the M2144 framing was empirically
    /// incorrect。 Real root cause is full-suite scheduling
    /// crash regardless of XCTest concurrency。 This pin
    /// flags that the M2144 framing has been superseded。
    public static let m2147CorrectionApplied: Bool = true

    /// Refined swift-testing failure framing post-M2147。
    public static let swiftTestingFailureFraming: String =
        "full-suite scheduling SIGBUS in swiftpm-testing-helper,independent of XCTest concurrency。 398 of 419 @Test cases start before crash,ZERO complete。 Narrow `--filter` scope passes。"

    /// Affected swift-testing suite for the documented
    /// flakiness (narrow-scope passes,full-suite crashes)。
    public static let knownFlakySwiftTestingSuite: String =
        "BASAppleObservabilityAdapterTests"

    /// Recovery candidate for swift-testing failure
    /// (CORRECTED post-M2147)。
    public static let swiftTestingFlakinessRecovery:
        String =
        "narrow `--filter` scope for partial coverage,or await SwiftPM/swift-testing toolchain fix"

    /// Empirical evidence pin:full-suite Swift Testing
    /// crashes even with XCTest disabled (verified at
    /// M2147 via `swift test --enable-swift-testing
    /// --disable-xctest`)。
    public static let fullSuiteCrashesEvenWithXCTestDisabled:
        Bool = true

    /// Total `@Test` cases across all `@Suite`s。
    public static let swiftTestingTestCount: Int = 419

    /// Total `@Suite` cases。
    public static let swiftTestingSuiteCount: Int = 67

    /// `@Test` cases observed starting before SIGBUS
    /// (M2147 empirical observation)。
    public static let swiftTestingStartedBeforeCrash: Int =
        398

    /// `@Test` cases observed completing before SIGBUS
    /// (M2147:zero — process aborts before any
    /// completes)。
    public static let swiftTestingCompletedBeforeCrash:
        Int = 0

    // MARK: - M2146 第一刀 empirical diagnosis update
    //
    // Chapter 694 / M2146 empirically tested 4 isolation
    // diagnostics (BASSignal10EmpiricalDiagnosisTests) to
    // narrow the bucket from the 3 original hypotheses。
    //
    // Diagnostic outcomes:
    //   A (sync test + direct startSession)         → PASS
    //   C (async test + direct startSession)        → CRASH
    //   D (async test + Task.detached startSession) → CRASH
    //   E (sync test + Task.detached startSession)  → CRASH
    //
    // Conclusions:
    //   - Task.detached itself is SUFFICIENT to trigger
    //     SIGBUS (Diagnostic E,sync test method)
    //   - async XCTestCase + sync startSession is ALSO
    //     sufficient (Diagnostic C,no Task.detached)
    //   - The ONLY passing pattern is sync test method
    //     + direct sync startSession invocation
    //   - Hypothesis #2 (V2 path) FALSIFIED by code
    //     inspection — BASHostRuntime.startSession()
    //     uses V1 sync path,does not touch V2 engine
    //   - Hypothesis #1 (Task.detached bridging)
    //     PARTIALLY CONFIRMED but narrower:both
    //     Task.detached AND async test method are
    //     independently sufficient triggers
    //   - Hypothesis #3 (macOS 26 SDK linkage) still
    //     UNVERIFIABLE without toolchain bisection

    /// Empirical diagnosis ran at chapter 694 / M2146。
    public static let empiricalDiagnosisRunAtMNumber: Int =
        2146

    /// 4 diagnostics ran (A/C/D/E)。
    public static let empiricalDiagnosticCount: Int = 4

    /// 1 of 4 diagnostics PASSED (sync test + direct
    /// startSession);3 of 4 CRASHED。
    public static let empiricalDiagnosticsPassed: Int = 1
    public static let empiricalDiagnosticsCrashed: Int = 3

    /// Refined pattern signature post-M2146 empirical
    /// diagnosis。 The ORIGINAL pattern signature
    /// (`async XCTestCase method + Task.detached +
    /// startSession`) was too restrictive — Task.detached
    /// + sync test method ALSO crashes,and async test
    /// + direct call (no Task) ALSO crashes。
    public static let refinedPatternSignaturePostM2146:
        String =
        "Task.detached invoking startSession OR async XCTestCase method invoking startSession → SIGBUS。 Only sync test method + direct sync startSession passes。"

    /// Hypothesis #2 (V2 path) FALSIFIED at M2146 via
    /// code inspection of HostRuntimeCore.swift。 The V2
    /// path is opt-in via `buildEBrainTurnWithRuntimeMode
    /// (...)` async surface;BASHostRuntime.startSession()
    /// uses V1 sync `makeEBrainTurn(...)` path。 V2
    /// engine never executes in the failing tests。
    public static let hypothesisTwoV2PathFalsified: Bool =
        true

    /// Hypothesis #1 (Task.detached bridging) PARTIALLY
    /// CONFIRMED at M2146 + REFINED:Task.detached is one
    /// of two independent triggers;async test method is
    /// the other。
    public static let hypothesisOneTaskDetachedRefined:
        Bool = true

    /// Recovery via test refactor (sync method + Task
    /// + expectation) does NOT work — Task.detached
    /// trigger fires regardless of test method type
    /// (Diagnostic E)。 No wrapper-based recovery exists;
    /// the 12 SIGBUS tests CANNOT be un-skipped via test
    /// code changes alone — substrate or toolchain fix
    /// required。
    public static let wrapperBasedRecoveryViable: Bool =
        false

    /// Empirical-diagnosis test file ref。
    public static let empiricalDiagnosisTestFile: String =
        "Tests/BehavioralAISubstrateTests/BASSignal10EmpiricalDiagnosisTests.swift"

    // MARK: - M2162 chapter 六百九十八 第一刀 — diagnostic
    //         placeholder cleanup
    //
    // M2146 originally shipped 4 diagnostics (A/C/D/E)
    // with A passing and C/D/E as XCTSkip-placeholder
    // tests documenting bucket boundaries。 M2158 added
    // Diagnostic F (sync + non-detached Task + actor)
    // as another PASSING diagnostic。
    //
    // M2162 (chapter 698) acknowledges the C/D/E XCTSkip
    // placeholders are DOCTRINE SPRAWL — their empirical
    // findings already live in the empirical pins above
    // (refinedPatternSignaturePostM2146,hypothesis flags,
    // etc)。 Keeping 3 skipped tests "for documentation"
    // is redundant when the doctrine IS the documentation。
    //
    // M2162 removes C/D/E from the test file。 Active
    // diagnostics:2 (A + F),both PASSING。

    /// Active empirical diagnostics post-M2162 (A + F)。
    public static let activeDiagnosticCountPostM2162: Int =
        2

    /// Skip placeholders removed at M2162 (C + D + E)。
    public static let skipPlaceholdersRemovedAtM2162: Int =
        3

    /// Original M2146 diagnostic count for history。
    public static let originalDiagnosticCountM2146: Int = 4

    /// M2158 added Diagnostic F → 5 total before cleanup;
    /// M2162 removed C/D/E → 2 active。
    public static let postCleanupActivePlusRemovedTotal:
        Int = 5
    // = 2 active + 3 removed

    // MARK: - M2155 chapter 六百九十六 第二刀 — sync-surface
    //         recovery correction
    //
    // M2146 ORIGINAL claim:wrapperBasedRecoveryViable =
    // false。 Empirical truth at M2146 was that
    // Task.detached + DispatchSemaphore/expectation
    // wrappers all crashed (Diagnostic E)。
    //
    // M2154 chapter 696 SHIPPED a DIFFERENT recovery
    // pattern that DOES work:SUBSTRATE-LEVEL SYNC
    // SURFACE。 Adding `evaluateSync(...)` to
    // BASSubstrateReauditShadowEvaluator (no Task.detached
    // internally) + migrating tests to sync test methods
    // (no async/throws) UN-SKIPPED 6-of-12 SIGBUS tests。
    //
    // Recovery pattern signature:
    //   - Substrate ships SYNC method alongside async
    //   - Test migrates from `async throws` → sync
    //   - Test calls sync method directly
    //   - Matches Diagnostic A (sync+sync) → PASSES
    //
    // REMAINING 6 tests (BASMemoryClosedLoop 3 + M306 3)
    // require ACTOR-SURFACE refactor (the failing tests
    // call into `public actor` methods that are async by
    // Swift's actor model)。 This is a BIGGER refactor
    // beyond chapter 696 scope。
    //
    // M2146 wrapperBasedRecoveryViable pin RETAINED for
    // history (it was correct for wrapper patterns at
    // the time);M2155 adds SYNC SURFACE recovery
    // viability as a SEPARATE pin。

    /// M2155 CORRECTION:sync-surface recovery IS viable
    /// (different pattern than wrapper-based)。
    public static let syncSurfaceRecoveryViable: Bool =
        true

    /// 6 of 12 originally-skipped SIGBUS tests RECOVERED
    /// at chapter 696 / M2154 via sync-surface refactor。
    public static let signal10TestsRecoveredAtChapter696:
        Int = 6

    /// 6 of 12 originally-skipped SIGBUS tests REMAIN
    /// skipped — they call into `public actor` methods
    /// requiring async (BASMemoryClosedLoopApplier +
    /// BASSovereignAuditLedger)。
    public static let signal10TestsRemainingSkippedPostM2154:
        Int = 6

    public static var signal10RecoveredPlusRemainingTotal:
        Int {
        return signal10TestsRecoveredAtChapter696
            + signal10TestsRemainingSkippedPostM2154
    }
    // = 12

    /// Recovery pattern signature for the 6 tests
    /// recovered at M2154。
    public static let chapter696RecoveryPattern: String =
        "substrate ships sync method alongside async;test migrates `async throws` → sync;test calls sync method directly (Diagnostic A pattern)"

    /// Affected substrate surface for the recovery
    /// shipped at M2154。
    public static let chapter696RecoveryShipsSurface:
        String =
        "BASSubstrateReauditShadowEvaluator.evaluateSync(prompt:body:prePermitMode:sessionRef:turnRef:)"

    /// Why the remaining 6 tests cannot use the same
    /// pattern。
    public static let remaining6BlockedReason: String =
        "BASMemoryClosedLoopApplier + BASMemoryUsageTracker + BASSovereignAuditLedger are `public actor` types — Swift's actor model enforces async access。 Sync surfaces would require breaking actor isolation。"

    // MARK: - M2160 chapter 六百九十七 第三刀 — 100%
    //         recovery correction
    //
    // M2155 claimed 6 of 12 RECOVERED + 6 REMAINING actor-
    // blocked。 Chapter 697 M2158 + M2159 falsified the
    // "remaining 6 cannot follow sync-surface pattern"
    // claim by finding a SECOND recovery pattern:
    //
    //   Diagnostic F (sync test + non-detached Task +
    //   actor calls,NO startSession in Task) → PASS
    //
    // M2158 migrated 3 M306 tests using Diagnostic F →
    // PASSED。 M2159 migrated 3 BASMemoryClosedLoop tests
    // using Diagnostic F → PASSED。
    //
    // 100% SIGBUS BUCKET RECOVERY ACHIEVED:
    //   - 6 of 12 via sync-surface (chapter 696 M2154)
    //   - 6 of 12 via non-detached-Task (chapter 697
    //     M2158 + M2159)
    //   - 12 of 12 = 100%
    //
    // M2155 pins RETAINED for history (correct at the
    // time of M2155);M2160 adds new pins documenting
    // the additional recovery。

    /// M2160 CORRECTION:remaining 6 ALSO recoverable via
    /// Diagnostic F pattern (non-detached Task)。
    public static let allTwelveSignal10TestsRecoveredAtChapter697:
        Bool = true

    /// 6 additional tests recovered at chapter 697 / M2158
    /// + M2159 (above the 6 already recovered at chapter
    /// 696 / M2154)。
    public static let signal10TestsRecoveredAtChapter697:
        Int = 6

    /// Total post-chapter-697 recovery = 12 of 12 = 100%。
    public static var totalSignal10TestsRecoveredAfterChapter697:
        Int {
        return signal10TestsRecoveredAtChapter696
            + signal10TestsRecoveredAtChapter697
    }
    // = 12

    /// 0 tests remain skipped post-chapter-697 (the 3
    /// Diagnostic C/D/E tests are intentional bucket-
    /// boundary documentation,not the original 12)。
    public static let signal10TestsRemainingSkippedPostChapter697:
        Int = 0

    /// Recovery pattern shipped at chapter 697 (M2158 +
    /// M2159)。
    public static let chapter697RecoveryPattern: String =
        "sync test method + non-detached `Task { ... }` + actor calls (NO startSession inside the Task) → PASS (Diagnostic F pattern)"

    /// 2 distinct recovery patterns now exist for the
    /// SIGBUS bucket。
    public static let recoveryPatternCount: Int = 2

    public static let recoveryPatternInventory: [String] = [
        "M2154 sync-surface pattern (chapter 696):substrate ships sync method alongside async;test migrates to sync。 Used for 6 evaluator tests。",
        "M2158/M2159 non-detached-Task pattern (chapter 697):sync test + `Task { ... }` for actor calls + XCTestExpectation。 Used for 6 actor-using tests (M306 + BASMemoryClosedLoop)。"
    ]
}
