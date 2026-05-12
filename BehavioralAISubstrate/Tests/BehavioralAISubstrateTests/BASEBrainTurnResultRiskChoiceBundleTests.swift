// MARK: - BASEBrainTurnResultRiskChoiceBundleTests
// chapter 五百二十九 / M1493 — risk/choice bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultRiskChoiceBundleTests:
    XCTestCase
{

    func testRiskChoiceFieldCountPinnedToFour() {
        XCTAssertEqual(
            BASEBrainTurnResultRiskChoiceBundle
                .riskChoiceFieldCount,
            4,
            "4 risk/choice fields:triScores +" +
            " mergedChoice + riskCard + actionPermit")
    }
}
