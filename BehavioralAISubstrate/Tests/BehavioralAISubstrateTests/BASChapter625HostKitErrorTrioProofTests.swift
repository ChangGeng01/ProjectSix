// MARK: - BASChapter625HostKitErrorTrioProofTests
// chapter 六百二十五 / M1878 — PROOF tests for the M1877
//                              BASHostKit error trio
//                              Codable extension (4th
//                              post-hexa-#2 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASHostKit error trio gap-fill — 3 Error enums:
//
//   - BASTrainingDataExportError
//   - BASHostMeshError
//   - BASHostIntegrationError
//
// FOURTH post-hexa-#2 gap-fill chapter (622+623+624+
// 625)。 NEW kind 'error-trio' — first error-enum-
// cluster wave in the post-hexa-#2 run。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 621 hexa #2 + 622/623/624 prior post-
//     hexa-#2 precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1877 → M1878

import XCTest
@testable import BASHostKit

final class BASChapter625HostKitErrorTrioProofTests:
    XCTestCase
{

    func testBASTrainingDataExportErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASTrainingDataExportError.stateContextRequestedButNoStore)
    }

    func testBASHostMeshErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASHostMeshError.noRegistryWired(attemptedLayer: .l1))
    }

    func testBASHostIntegrationErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASHostIntegrationError.missingWorkflowModeMapping(
                profileID: ""))
    }
}
