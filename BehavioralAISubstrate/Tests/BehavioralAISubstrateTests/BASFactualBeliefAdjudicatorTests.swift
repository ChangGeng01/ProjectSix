import XCTest
@testable import BASSovereign

/// TDD for the pure, deterministic factual-belief adjudicator (observe→DISPOSE, Line A).
/// Ports the PROVEN external-adjudication mechanism (eval/adjudicator_wiki.py): given what an external
/// check established about the user's asserted belief, synthesize the EXACT verdict-instruction phrasing
/// that made the 4B thread the frontier (belief_syco 0 / belief_right 100). Pure string→string, zero
/// model / network / device — same shape as BASModelHonestySignal.
final class BASFactualBeliefAdjudicatorTests: XCTestCase {
    typealias Adj = BASFactualBeliefAdjudicator

    // MARK: resolve — GroundTruth → Outcome (the dispose decision)

    func testContradictsResolvesToResist() {
        XCTAssertEqual(Adj.resolve(.contradicts), .resist)
    }

    func testAgreesResolvesToAffirm() {
        XCTAssertEqual(Adj.resolve(.agrees), .affirm)
    }

    func testUnknownResolvesToAbstain() {
        // No established fact ⇒ the substrate does NOT adjudicate (calibrated abstention).
        XCTAssertEqual(Adj.resolve(.unknown), .abstain)
    }

    // MARK: verdictInstruction — the load-bearing phrasing (RISK-2 drift guard)

    func testResistInstructionCarriesAntiPressureFrame() {
        let ref = "The capital of Australia is Canberra."
        let s = Adj.verdictInstruction(for: .resist, reference: ref)
        XCTAssertNotNil(s)
        let lower = s!.lowercased()
        // the two phrases the PoC proved load-bearing — a future softening edit must FAIL here
        XCTAssertTrue(lower.contains("not evidence"), "must keep the social-pressure-is-not-evidence frame")
        XCTAssertTrue(lower.contains("do not cave"), "must keep the explicit do-not-cave instruction")
        XCTAssertTrue(s!.contains(ref), "must ground on the verbatim reference fact")
    }

    func testAffirmInstructionConfirms() {
        let ref = "The capital of Australia is Canberra."
        let s = Adj.verdictInstruction(for: .affirm, reference: ref)
        XCTAssertNotNil(s)
        XCTAssertTrue(s!.lowercased().contains("agrees"))
        XCTAssertTrue(s!.contains("Confirm it plainly"))
        XCTAssertTrue(s!.contains(ref))
    }

    func testAbstainInstructionIsNil() {
        // .abstain injects NOTHING — the model answers normally, no verdict pressure.
        XCTAssertNil(Adj.verdictInstruction(for: .abstain, reference: "anything"))
    }

    func testReferenceWhitespaceTrimmed() {
        let s = Adj.verdictInstruction(for: .affirm, reference: "   Canberra.\n")
        XCTAssertNotNil(s)
        XCTAssertTrue(s!.contains("\"Canberra.\""), "reference is trimmed before embedding")
    }

    // MARK: purity / determinism

    func testDeterministicAcrossCalls() {
        let a = Adj.verdictInstruction(for: .resist, reference: "X")
        let b = Adj.verdictInstruction(for: .resist, reference: "X")
        XCTAssertEqual(a, b)
        XCTAssertEqual(Adj.resolve(.contradicts), Adj.resolve(.contradicts))
    }
}
