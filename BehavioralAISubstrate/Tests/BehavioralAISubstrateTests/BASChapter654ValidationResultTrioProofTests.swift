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

    func testBASMambaCheckpointValidationResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMambaCheckpointValidationResult.valid)
        assertCodableRoundTrips(
            BASMambaCheckpointValidationResult.invalid(
                reason: .emptyCheckpointID))
    }

    func testBASCoreMLConversionValidationResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASCoreMLConversionValidationResult.valid)
        assertCodableRoundTrips(
            BASCoreMLConversionValidationResult.invalid(
                reason: .emptyMLXWeightsPath))
    }

    func testBASMambaTrainingValidationResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASMambaTrainingValidationResult.valid)
        assertCodableRoundTrips(
            BASMambaTrainingValidationResult.invalid(
                reason: .emptySessionID))
    }
}
