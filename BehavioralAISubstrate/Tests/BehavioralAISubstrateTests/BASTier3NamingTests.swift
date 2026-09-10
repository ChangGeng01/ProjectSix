// ch1051 / v1.0 — proofs for the Tier-3 naming nits: ConsentMatrix alias + GuardBranch type.

import XCTest
import Foundation
@testable import BASMemory
@testable import BASOrchestration

final class BASTier3NamingTests: XCTestCase {

    // ConsentMatrix is an alias of BASConsentLattice (same type, no duplication).
    func testConsentMatrixAliasesLattice() {
        XCTAssertTrue(BASConsentMatrix.self == BASConsentLattice.self,
                      "BASConsentMatrix must be the outline name for BASConsentLattice")
    }

    // GuardBranch is a real first-class type with the expected fields.
    func testGuardBranchType() {
        let g = BASGuardBranch(branchID: "g1", triggerCondition: "risk>0.8",
                               protectiveAction: "delay", fallbackRef: "cand-2", reversible: true)
        XCTAssertEqual(g.branchID, "g1")
        XCTAssertEqual(g.fallbackRef, "cand-2")
        XCTAssertTrue(g.reversible)
    }

    // fromGuardPaths losslessly promotes the flat guard-path refs to guard branches.
    func testGuardBranchFromGuardPaths() {
        let branches = BASGuardBranch.fromGuardPaths(["p1", "p2", "p3"])
        XCTAssertEqual(branches.map { $0.branchID }, ["p1", "p2", "p3"])
        XCTAssertEqual(branches.map { $0.fallbackRef }, ["p1", "p2", "p3"])
        XCTAssertTrue(branches.allSatisfy { $0.reversible })
        XCTAssertTrue(BASGuardBranch.fromGuardPaths([]).isEmpty)
    }
}
