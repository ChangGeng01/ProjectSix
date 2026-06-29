import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// runTurn consumes the OPT-IN `BASEBrainTurnRequest.effortPlan` to floor the deliberation pass budget. Proves
/// the field is wired safely: nil ⇒ byte-equal (the floor is a passthrough), and an effort plan can only TIGHTEN
/// the deliberation loop count, never raise it. (The pure floor math — fast→1, max→min(routed,6) — is unit-tested
/// in BASEffortBudgetConsumerTests; the test stubs route maxLoops=1, so a multi-pass REDUCTION isn't demonstrable
/// here, but the composition mirrors the proven BASDeliberationThermalFloor and the no-raise direction holds.)
final class BASRunTurnEffortFloorTests: XCTestCase {

    func testEffortPlanNilIsByteEqualToAbsent() {
        let coord = BASCoordinatorTestStubs.makeStub()
        let absent = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        var nilReq = BASCoordinatorTestStubs.makeStubRequest()
        nilReq.effortPlan = nil
        let withNil = coord.runTurn(nilReq)
        XCTAssertEqual(absent.runtimeTrace.loopCount, withNil.runtimeTrace.loopCount,
                       "effortPlan nil/absent ⇒ identical deliberation (opt-in byte-equal)")
        XCTAssertEqual(absent.actionPermit, withNil.actionPermit)
    }

    func testEffortPlanIsAcceptedAndNeverRaisesLoopCount() {
        let coord = BASCoordinatorTestStubs.makeStub()
        let baseline = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        var fastReq = BASCoordinatorTestStubs.makeStubRequest()
        fastReq.effortPlan = .granted(.fast)
        let fast = coord.runTurn(fastReq)
        XCTAssertLessThanOrEqual(fast.runtimeTrace.loopCount, baseline.runtimeTrace.loopCount,
                                 "the effort floor can only TIGHTEN — never raises deliberation passes")
    }

    func testEffortFloorWithLoopEnabledNeverRaises() {
        // With the deliberation loop ENABLED, a low effort tier still only tightens (≤). (Stub routes maxLoops=1,
        // so both resolve to the single base pass; this asserts the enabled path stays safe + handles the field.)
        var coord = BASCoordinatorTestStubs.makeStub()
        coord.deliberationLoopEnabled = true
        let baseline = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        var fastReq = BASCoordinatorTestStubs.makeStubRequest()
        fastReq.effortPlan = .granted(.fast)
        let fast = coord.runTurn(fastReq)
        XCTAssertLessThanOrEqual(fast.runtimeTrace.loopCount, baseline.runtimeTrace.loopCount)
    }
}
