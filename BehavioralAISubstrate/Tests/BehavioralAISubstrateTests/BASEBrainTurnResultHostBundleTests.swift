// MARK: - BASEBrainTurnResultHostBundleTests
// chapter 五百二十六 / M1481 — host bundle tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnResultHostBundleTests:
    XCTestCase
{

    private func makeHostContext() -> BASHostProfile {
        return BASHostProfile(
            hostID: "host-test",
            longTermGoals: [],
            noGoZones: [])
    }

    func testMinimumBundleHasOnePopulatedField() {
        let bundle = BASEBrainTurnResultHostBundle(
            hostContext: makeHostContext())
        XCTAssertEqual(
            bundle.populatedFieldCount, 1,
            "hostContext is required → minimum count" +
            " is 1")
        XCTAssertFalse(bundle.hasFullHostCoverage)
    }

    func testHostFieldCountPinnedToFive() {
        XCTAssertEqual(
            BASEBrainTurnResultHostBundle
                .hostFieldCount,
            5,
            "5 host cluster fields:hostConstitution +" +
            " hostConstitutionVault + hostVersionTree" +
            " + hostForgetRequest + hostContext")
    }

    func testEquatableValueEquality() {
        let ctx = makeHostContext()
        let b1 = BASEBrainTurnResultHostBundle(
            hostContext: ctx)
        let b2 = BASEBrainTurnResultHostBundle(
            hostContext: ctx)
        XCTAssertEqual(b1, b2)
    }
}
