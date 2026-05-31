// ch1044 DEFER-3 — replay-determinism guard for the CONSEQUENTIAL turn decision.
//
// FINDING (surfaced by this guard): the FULL `BASEBrainTurnResult` is NOT
// byte-identical across two runs of the same turn — `memoryBundle.retrievedAt` is a
// real-clock OBSERVATION timestamp (stamped `Date()` by the brain history store, a
// default param). That is an intentional observation field, not part of the replay
// contract; the consequential decision never depends on it.
//
// The HIGH-1 / red-line-7 replay contract covers the CONSEQUENTIAL decision —
// verdict, commit tokens, action permit, risk card, merged choice, host gate, update
// tickets — which this guard asserts is replay-stable. Any future change that sneaks
// a UUID / clock / random into a CONSEQUENTIAL field (the thing that actually
// authorizes an action) breaks this guard. This is the automated tripwire behind the
// session's "byte-equal when off" carriers (parity shadow, dual Ed25519 sig, …).

import XCTest
@testable import BASHostKit
import BASRuntimeCore
import Foundation

final class BASCoordinatorTurnDeterminismTests: XCTestCase {

    private func assertConsequentialEqual(
        _ a: BASEBrainTurnResult, _ b: BASEBrainTurnResult, _ ctx: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a.sovereignVerdict, b.sovereignVerdict, "verdict [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.sovereignCommitTokens, b.sovereignCommitTokens, "commitTokens [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.actionPermit, b.actionPermit, "permit [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.riskCard, b.riskCard, "risk [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.mergedChoice, b.mergedChoice, "mergedChoice [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.hostGateValue, b.hostGateValue, "hostGate [\(ctx)]", file: file, line: line)
        XCTAssertEqual(a.updateTickets, b.updateTickets, "updateTickets [\(ctx)]", file: file, line: line)
    }

    // MARK: - 1) The consequential decision is replay-stable (default request)

    func testConsequentialDecisionIsReplayStable() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let request = BASCoordinatorTestStubs.makeStubRequest()
        assertConsequentialEqual(
            coordinator.runTurn(request), coordinator.runTurn(request), "default")
    }

    // MARK: - 2) …across varied requests (incl. a high-risk one)

    func testVariedRequestsConsequentialDeterminism() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        for input in ["hello", "delete everything now", "what is 2+2", ""] {
            let req = BASCoordinatorTestStubs.makeStubRequest(userInput: input)
            assertConsequentialEqual(
                coordinator.runTurn(req), coordinator.runTurn(req), input.debugDescription)
        }
    }

    // MARK: - 3) The non-consequential difference is ONLY the observation clock

    /// Documents the finding: the memory bundle's CONTENT (atoms, tags) is stable;
    /// only the real-clock `retrievedAt` observation timestamp varies — never a
    /// consequential field.
    func testMemoryBundleContentIsStable() {
        let coordinator = BASCoordinatorTestStubs.makeStub()
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let r1 = coordinator.runTurn(request)
        let r2 = coordinator.runTurn(request)
        XCTAssertEqual(r1.memoryBundle.atoms, r2.memoryBundle.atoms)
        XCTAssertEqual(r1.memoryBundle.retrievalTags, r2.memoryBundle.retrievalTags)
    }
}
