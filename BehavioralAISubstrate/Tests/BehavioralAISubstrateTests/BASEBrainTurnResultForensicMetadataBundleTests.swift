// MARK: - BASEBrainTurnResultForensicMetadataBundleTests
// chapter 五百三十二 / M1505 — forensic metadata bundle
//                              tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration

final class BASEBrainTurnResultForensicMetadataBundleTests:
    XCTestCase
{

    func testForensicMetadataFieldCountPinnedToThree() {
        XCTAssertEqual(
            BASEBrainTurnResultForensicMetadataBundle
                .forensicMetadataFieldCount,
            3,
            "3 forensic metadata fields:" +
            " policyLineage + recoveryDisposition +" +
            " runtimeTrace")
    }
}
