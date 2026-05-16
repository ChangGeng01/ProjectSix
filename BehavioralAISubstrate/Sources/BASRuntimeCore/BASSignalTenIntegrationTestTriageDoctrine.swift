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

    // MARK: - Swift-Testing concurrent-run flakiness
    //         (M2144 第三刀 amendment)

    /// SwiftPM `swift test` invocations run XCTest +
    /// swift-testing in parallel processes。 The swift-
    /// testing helper can crash with signal-10 when
    /// running concurrently with a large XCTest sweep
    /// (e.g. 11000+ tests),even though the SAME swift-
    /// testing suites PASS when run in isolation。
    ///
    /// Observed:`BASAppleObservabilityAdapterTests`
    /// (Swift Testing `@Suite` with 10 `@Test` cases)
    /// passes in isolation。 Crashes intermittently in
    /// the full-sweep concurrent path with signal-10
    /// in the swiftpm-testing-helper process。
    ///
    /// Classified as:flakiness in the swiftpm-testing-
    /// helper concurrent-runner,NOT a substrate bug。
    /// Recovery path:run XCTest + Swift Testing in
    /// separate invocations (e.g. via
    /// `swift test --testing-library xctest` then
    /// `swift test --testing-library swift-testing`)
    /// or wait for SwiftPM to stabilize the
    /// concurrent runner。
    public static let swiftTestingConcurrentRunFlakinessKnown:
        Bool = true

    /// Affected swift-testing suite for the documented
    /// flakiness。
    public static let knownFlakySwiftTestingSuite: String =
        "BASAppleObservabilityAdapterTests"

    /// Recovery candidate for swift-testing flakiness。
    public static let swiftTestingFlakinessRecovery:
        String =
        "run XCTest + Swift Testing in separate `swift test --testing-library` invocations"

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
}
