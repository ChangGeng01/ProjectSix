// ch1055 / v1.0 §6 step 3 — proofs for the pre-work sovereign gate.

import XCTest
import Foundation
@testable import BASHostKit
import BASObservability

final class BASSovereignPreflightGateTests: XCTestCase {

    private func makeReq(kills: [BASKillSwitchID] = [], input: String = "hi") -> BASEBrainTurnRequest {
        BASEBrainTurnRequest(userInput: input,
                             deviceState: BASCoordinatorTestStubs.nominalDeviceState,
                             hostID: "h", recordedAt: Date(timeIntervalSince1970: 1000),
                             activeKillSwitches: kills)
    }

    // Default gate (no policy) proceeds.
    func testProceedsByDefault() {
        XCTAssertEqual(BASSovereignPreflightGate().evaluate(makeReq()), .proceed)
    }

    // A denying kill-switch present → deny before work; a non-denying one still proceeds.
    func testDeniesOnKillSwitch() {
        let gate = BASSovereignPreflightGate(denyingKillSwitches: [.forceGuardMode])
        let denied = gate.evaluate(makeReq(kills: [.forceGuardMode]))
        XCTAssertEqual(denied, .deny(reason: "kill_switch:force_guard_mode"))
        XCTAssertFalse(denied.isProceed)
        XCTAssertTrue(gate.evaluate(makeReq(kills: [.disableFastPath])).isProceed,
                      "a kill-switch not in the deny set must not block")
    }

    // The host hardNoGo predicate denies with its own reason.
    func testDeniesOnHardNoGo() {
        let gate = BASSovereignPreflightGate(hardNoGo: {
            $0.userInput.contains("forbidden") ? "matched_forbidden" : nil
        })
        XCTAssertEqual(gate.evaluate(makeReq(input: "this is forbidden")).denyReason, "matched_forbidden")
        XCTAssertTrue(gate.evaluate(makeReq(input: "ok")).isProceed)
    }

    // Kill-switch is checked before the predicate (deterministic order).
    func testKillSwitchTakesPrecedence() {
        let gate = BASSovereignPreflightGate(denyingKillSwitches: [.forceGuardMode],
                                             hardNoGo: { _ in "predicate_reason" })
        XCTAssertEqual(gate.evaluate(makeReq(kills: [.forceGuardMode])).denyReason,
                       "kill_switch:force_guard_mode")
    }
}
