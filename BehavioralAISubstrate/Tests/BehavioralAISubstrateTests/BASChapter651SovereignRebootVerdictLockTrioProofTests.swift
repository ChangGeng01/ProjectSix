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

    func testBASSovereignCleanRebootCoordinatorRebootPlanConformsToCodable() {
        // #18: real round-trip (memberwise init reachable via @testable)
        let value = BASSovereignCleanRebootCoordinator.RebootPlan(
            planID: "",
            sessionID: "",
            sourceVersionID: "",
            targetVersionID: "",
            targetAnchorID: "",
            actions: [],
            auditRef: "",
            verdictLevel: .pass,
            bootstrapNextSession: false,
            issuedAt: Date(timeIntervalSince1970: 0))
        assertCodableRoundTrips(value)
    }

    func testBASSovereignVerdictEngineVerdictContextConformsToCodable() {
        // #18: real round-trip
        let value = BASSovereignVerdictEngine.VerdictContext(
            sessionID: "",
            turnID: "",
            operation: .pureInference)
        assertCodableRoundTrips(value)
    }

    func testBASSovereignLockManagerScopeIdentifierConformsToCodable() {
        // #18: real round-trip (via public factory)
        assertCodableRoundTrips(
            BASSovereignLockManager.ScopeIdentifier.session(""))
    }
}
