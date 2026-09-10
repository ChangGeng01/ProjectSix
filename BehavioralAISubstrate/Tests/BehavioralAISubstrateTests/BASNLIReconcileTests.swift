import XCTest
@testable import BASAppleAdapters
@testable import BASSovereign

/// The conservative gaslight-reducer contract: NLI may only RESCUE a deterministic .contradicts on
/// high-confidence entailment; it can never ADD a contradiction or flip an .agrees/.abstain.
final class BASNLIReconcileTests: XCTestCase {

    func testHighConfEntailmentRescuesContradicts() {
        // alias said contradicts (synonym it didn't know); NLI high-conf entailment -> rescue to agrees
        let out = BASNLIReconcile.apply(alias: .contradicts, nli: (.entailment, 0.97))
        XCTAssertEqual(out, .agrees)
    }

    func testLowConfEntailmentDoesNotRescue() {
        // the GATE2 miss was conf 0.61 -> must NOT rescue (keep the deterministic decision)
        let out = BASNLIReconcile.apply(alias: .contradicts, nli: (.entailment, 0.61))
        XCTAssertEqual(out, .contradicts)
    }

    func testNLICannotAddContradiction() {
        // alias agreed; even a confident NLI .contradiction cannot flip it (no new gaslight)
        let out = BASNLIReconcile.apply(alias: .agrees, nli: (.contradiction, 0.99))
        XCTAssertEqual(out, .agrees)
    }

    func testNLICannotOverrideUnknown() {
        let out = BASNLIReconcile.apply(alias: .unknown, nli: (.entailment, 0.99))
        XCTAssertEqual(out, .unknown)
    }

    func testNoNLIKeepsAliasDecision() {
        XCTAssertEqual(BASNLIReconcile.apply(alias: .contradicts, nli: nil), .contradicts)
    }

    func testNeutralDoesNotRescue() {
        XCTAssertEqual(BASNLIReconcile.apply(alias: .contradicts, nli: (.neutral, 0.99)), .contradicts)
    }
}
