// MARK: - BASChapter651SovereignRebootVerdictLockTrioProofTests
// chapter 六百五十一 / M1982 — PROOF tests for the M1981
//                              BASSovereign reboot+verdict
//                              +lock trio Codable extension
//                              (2nd post-hexa-#6 gap-fill)

import XCTest
@testable import BASSovereign

final class BASChapter651SovereignRebootVerdictLockTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSovereignCleanRebootCoordinatorRebootPlanConformsToCodable() {
        assertCodable(
            BASSovereignCleanRebootCoordinator
                .RebootPlan.self)
    }

    func testBASSovereignVerdictEngineVerdictContextConformsToCodable() {
        assertCodable(
            BASSovereignVerdictEngine.VerdictContext.self)
    }

    func testBASSovereignLockManagerScopeIdentifierConformsToCodable() {
        assertCodable(
            BASSovereignLockManager.ScopeIdentifier.self)
    }
}
