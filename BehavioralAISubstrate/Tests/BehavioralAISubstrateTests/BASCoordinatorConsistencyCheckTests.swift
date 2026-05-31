// ch1044 (a) — coordinator self-consistency (regression) detector tests.
// The meaningful halt signal: a stored verdict strictly laxer than the
// coordinator's own rules re-derived from the same settled state.

import XCTest
@testable import BASHostKit
import BASPolicy
import BASRuntimeCore

final class BASCoordinatorConsistencyCheckTests: XCTestCase {

    private func makeRisk(_ level: BASBrainRiskLevel) -> BASRiskCard {
        BASRiskCard(
            totalRisk: 0.2, riskLevel: level, uncertainty: 0.1,
            irreversibility: 0.1, manipulationStrength: 0.1, gsiScore: 0.1,
            recommendedMode: .answer)
    }

    private func makePermit(_ mode: BASActionPermitMode) -> BASActionPermit {
        BASActionPermit(
            mode: mode, reasonCodes: ["t"], outputLengthCap: 200,
            tonePolicy: "calm", templatePolicy: "default")
    }

    // MARK: - 1) A real stub turn is self-consistent

    func testStubTurnIsConsistent() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(
            BASCoordinatorConsistencyCheck.check(result), .consistent,
            "the stub turn's stored verdict must match its own re-derived rules")
    }

    // MARK: - 2) A simulated regression is flagged (the halt signal)

    func testSimulatedRegressionIsFlagged() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        var result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(BASCoordinatorConsistencyCheck.check(result), .consistent)
        // SIMULATE a regression: mutate the settled state to warrant deadStop
        // (extreme risk + go-ahead permit) WITHOUT recomputing the stored verdict —
        // as if a rule change / stale inputs left it wrongly lax.
        result.riskCard = makeRisk(.extreme)
        result.actionPermit = makePermit(.answer)
        let check = BASCoordinatorConsistencyCheck.check(result)
        XCTAssertTrue(check.isRegression, "expected a regression, got \(check)")
        if case .regression(let stored, let atLeast) = check {
            XCTAssertEqual(atLeast, .deadStop)         // extreme + answer → deadStop
            XCTAssertLessThan(stored, .deadStop)        // stored stayed lax
        }
    }

    // MARK: - 3) No verdict → nothing to check

    func testNoVerdictWhenAbsent() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        var result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        result.sovereignVerdict = nil
        XCTAssertEqual(BASCoordinatorConsistencyCheck.check(result), .noVerdict)
    }

    // MARK: - 4) Never false-alarms: a clearly-strict stored verdict is consistent

    func testStricterStoredVerdictIsConsistent() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        var result = coordinator.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        // Relax the state to benign (low risk, benign permit) but leave the stored
        // verdict as-is — stored >= re-derived → consistent (we only flag laxer).
        result.riskCard = makeRisk(.low)
        result.actionPermit = makePermit(.answer)
        XCTAssertEqual(BASCoordinatorConsistencyCheck.check(result), .consistent)
    }
}
