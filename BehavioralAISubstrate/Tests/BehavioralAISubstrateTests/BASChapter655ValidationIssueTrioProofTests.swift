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

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASTurnRuntimeStagePlanValidationIssueConformsToCodable() {
        assertCodable(
            BASTurnRuntimeStagePlanValidationIssue.self)
    }

    func testBASTurnRuntimeStageLedgerValidationIssueConformsToCodable() {
        assertCodable(
            BASTurnRuntimeStageLedgerValidationIssue.self)
    }

    func testBASLayerMLHeadRegistrationErrorConformsToCodable() {
        assertCodable(
            BASLayerMLHeadRegistrationError.self)
    }
}
