// MARK: - BASChapter660HostProjectionTrioProofTests
// chapter 六百六十 / M2018 — PROOF tests

import XCTest
@testable import BASHostKit

final class BASChapter660HostProjectionTrioProofTests: XCTestCase {

    func testBASEventLogTurnProjectionConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASEventLogTurnProjection(
                turnID: "",
                memoryAtomEvents: [],
                turnLifecycleEvents: [],
                parallelStageEvents: [],
                permitEscalationEvents: []))
    }

    func testBASTrainingExampleSubmissionConformsToCodable() {
        // #18: compile-time-only fallback — BASTrainingExampleCandidate
        // lives in BASOrgan (not imported by this test target); honest
        // compile-time conformance rather than a guessed construction.
        assertConformsToCodableAtCompileTime(
            BASTrainingExampleSubmission.self)
    }

    func testBASShadowEvaluateThenUpgradeOutcomeConformsToCodable() {
        // #18: compile-time-only fallback — nested BASShadowEvaluationResult
        // (BASEvaluation) + BASActionPermit (BASPolicy) are not imported
        // here and are deeply nested; honest compile-time conformance.
        assertConformsToCodableAtCompileTime(
            BASShadowEvaluateThenUpgradeOutcome.self)
    }
}
