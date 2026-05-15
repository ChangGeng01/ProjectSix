// MARK: - BASChapter654ValidationResultTrioProofTests
// chapter 六百五十四 / M1994 — PROOF tests for the M1993
//                              BASRuntimeCore validation-
//                              result trio Codable extension
//                              (6th and FINAL post-hexa-#6
//                              gap-fill,1 chapter from
//                              chapter 六百五十五 hexa #7
//                              opportunity)

import XCTest
@testable import BASRuntimeCore

final class BASChapter654ValidationResultTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASMambaCheckpointValidationResultConformsToCodable() {
        assertCodable(BASMambaCheckpointValidationResult.self)
    }

    func testBASCoreMLConversionValidationResultConformsToCodable() {
        assertCodable(BASCoreMLConversionValidationResult.self)
    }

    func testBASMambaTrainingValidationResultConformsToCodable() {
        assertCodable(BASMambaTrainingValidationResult.self)
    }
}
