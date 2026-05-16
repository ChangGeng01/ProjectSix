// MARK: - BASChapter660HostProjectionTrioProofTests
// chapter 六百六十 / M2018 — PROOF tests

import XCTest
@testable import BASHostKit

final class BASChapter660HostProjectionTrioProofTests: XCTestCase {
    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(String(describing: type),
                       String(describing: type))
    }
    func testBASEventLogTurnProjectionConformsToCodable() {
        assertCodable(BASEventLogTurnProjection.self)
    }
    func testBASTrainingExampleSubmissionConformsToCodable() {
        assertCodable(BASTrainingExampleSubmission.self)
    }
    func testBASShadowEvaluateThenUpgradeOutcomeConformsToCodable() {
        assertCodable(BASShadowEvaluateThenUpgradeOutcome.self)
    }
}
