// MARK: - BASChapter640RuntimeStepEnumTrioProofTests
// chapter 六百四十 / M1938 — PROOF tests for the M1937
//                            cross-module runtime-step
//                            enum trio Codable extension
//                            (5th post-hexa-#4 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module runtime-step enum trio gap-fill —
// 3 non-Error "control-flow step" enums spanning 3
// modules:
//
//   BASRuntimeCore (top-level):
//     - BASEventReplayRange (2-case)
//
//   BASOrgan (top-level):
//     - BASToolCallingPlanStep (3-case)
//
//   BASMemory (nested-in-actor):
//     - BASShadowTrialCoordinator.FinalizeOutcome (3-case)
//
// FIFTH post-hexa-#4 gap-fill chapter。 FIRST non-Error-
// trio chapter in the post-hexa-#4 run — kinds 1-4 were
// all error-trio variants。 BASRuntimeCore 3rd touch
// overall (chapters 624 + 637 prior),BASOrgan 3rd touch
// overall (chapters 634 + 639 prior),BASMemory 3rd
// touch overall (chapters 629 + 631 prior)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 635 hexa #4 catalog precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1937 → M1938

import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan
@testable import BASMemory

final class BASChapter640RuntimeStepEnumTrioProofTests:
    XCTestCase
{

    func testBASEventReplayRangeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASEventReplayRange.singleSession(sessionID: ""))
    }

    func testBASToolCallingPlanStepConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASToolCallingPlanStep.failed(reason: ""))
    }

    func testBASShadowTrialCoordinatorFinalizeOutcomeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASShadowTrialCoordinator.FinalizeOutcome.passed)
    }
}
