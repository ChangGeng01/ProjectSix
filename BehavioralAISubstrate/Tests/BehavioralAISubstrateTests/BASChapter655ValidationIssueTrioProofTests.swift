// MARK: - BASChapter655ValidationIssueTrioProofTests
// chapter 六百五十五 / M1998 — PROOF tests for the M1997
//                              cross-module validation-
//                              issue trio Codable extension
//                              (6th and TRUE FINAL post-
//                              hexa-#6 gap-fill; chapter
//                              656 hexa #7 catalog
//                              opportunity NEXT)

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter655ValidationIssueTrioProofTests:
    XCTestCase
{

    func testBASTurnRuntimeStagePlanValidationIssueConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASTurnRuntimeStagePlanValidationIssue
                .sequentialStepHasMultipleStages(
                    stepIndex: 0, stageCount: 0))
    }

    func testBASTurnRuntimeStageLedgerValidationIssueConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASTurnRuntimeStageLedgerValidationIssue
                .recordsExceedingPlanCount(0))
    }

    func testBASLayerMLHeadRegistrationErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASLayerMLHeadRegistrationError.duplicateHeadID(""))
    }
}
