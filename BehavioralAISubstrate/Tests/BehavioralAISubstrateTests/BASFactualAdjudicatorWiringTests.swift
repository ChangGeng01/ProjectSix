import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASOrgan

/// TDD for the host-side, opt-in, default-OFF wiring that prepends the adjudicator verdict into the
/// user-turn text before the model call. Mirrors BASModelHonestyObservation.recordIfEnabled exactly:
/// disabled ⇒ byte-equal no-op (the parity/safety contract); enabled ⇒ a FRESH immutable request whose
/// instruction is `verdict + "\n\n" + original` (never mutates the input).
final class BASFactualAdjudicatorWiringTests: XCTestCase {
    typealias Wiring = BASFactualAdjudicatorWiring

    private func req(_ instruction: String) -> BASOrganRequest {
        // mirrors the real seam BASProbeCommon.swift:293
        BASOrganRequest(requestID: "t1", role: .core, preset: .core, instruction: instruction, context: ["ctx"])
    }

    // MARK: env gate — default OFF

    func testEnvGateDefaultsOff() {
        XCTAssertFalse(Wiring.isEnabled([:]))
        XCTAssertFalse(Wiring.isEnabled(["BAS_FACTUAL_ADJUDICATE": "0"]))
        XCTAssertTrue(Wiring.isEnabled(["BAS_FACTUAL_ADJUDICATE": "1"]))
    }

    // MARK: disabled ⇒ byte-equal no-op (the safety contract)

    func testDisabledIsByteEqualNoOp() {
        let r = req("What is the capital of Australia?")
        let out = Wiring.applyIfEnabled(to: r, groundTruth: .contradicts, reference: "Canberra", enabled: false)
        XCTAssertEqual(out, r) // BASOrganRequest is Equatable — whole-request equality = byte-equal no-op
    }

    // MARK: enabled + contradicts ⇒ resist verdict prepended, original preserved + untouched

    func testEnabledResistPrependsVerdictAndPreservesOriginal() {
        let r = req("ORIGINAL_Q")
        let out = Wiring.applyIfEnabled(to: r, groundTruth: .contradicts,
                                        reference: "Canberra is the capital of Australia.", enabled: true)
        XCTAssertNotEqual(out, r)
        XCTAssertTrue(out.instruction.hasSuffix("ORIGINAL_Q"), "original instruction kept at the end")
        XCTAssertTrue(out.instruction.lowercased().contains("do not cave"), "verdict prepended")
        // immutability: the input request is NOT mutated
        XCTAssertEqual(r.instruction, "ORIGINAL_Q")
        // all other fields carried over verbatim (fresh immutable copy)
        XCTAssertEqual(out.requestID, r.requestID)
        XCTAssertEqual(out.role, r.role)
        XCTAssertEqual(out.context, r.context)
    }

    // MARK: enabled + agrees ⇒ affirm verdict prepended

    func testEnabledAffirmPrependsConfirm() {
        let r = req("ORIGINAL_Q")
        let out = Wiring.applyIfEnabled(to: r, groundTruth: .agrees,
                                        reference: "Canberra is the capital.", enabled: true)
        XCTAssertTrue(out.instruction.contains("Confirm it plainly"))
        XCTAssertTrue(out.instruction.hasSuffix("ORIGINAL_Q"))
    }

    // MARK: enabled + unknown ⇒ abstain ⇒ instruction untouched (no verified fact, no pressure)

    func testEnabledAbstainLeavesRequestUnchanged() {
        let r = req("ORIGINAL_Q")
        let out = Wiring.applyIfEnabled(to: r, groundTruth: .unknown, reference: "irrelevant", enabled: true)
        XCTAssertEqual(out.instruction, "ORIGINAL_Q")
        XCTAssertEqual(out, r) // abstain is itself a no-op
    }

    // MARK: fact-bank-driven overload — the live-turn entry point (source + gate in one)

    private let bank = [
        BASVerifiedFact(answer: "Canberra", reference: "The capital of Australia is Canberra.",
                        cues: ["capital", "australia"])
    ]

    func testFactBankContradictsInjectsResist() {
        let r = req("What is the capital of Australia?")
        let out = Wiring.applyIfEnabled(to: r, question: "What is the capital of Australia?",
                                        assertedValue: "Sydney", facts: bank, enabled: true)
        XCTAssertTrue(out.instruction.lowercased().contains("do not cave"))
        XCTAssertTrue(out.instruction.hasSuffix(r.instruction))
    }

    func testFactBankAgreesInjectsConfirm() {
        let r = req("What is the capital of Australia?")
        let out = Wiring.applyIfEnabled(to: r, question: "What is the capital of Australia?",
                                        assertedValue: "Canberra", facts: bank, enabled: true)
        XCTAssertTrue(out.instruction.contains("Confirm it plainly"))
    }

    func testFactBankUnknownAbstains() {
        let r = req("What is the GDP of France?")
        let out = Wiring.applyIfEnabled(to: r, question: "What is the GDP of France?",
                                        assertedValue: "2 trillion", facts: bank, enabled: true)
        XCTAssertEqual(out, r) // no matching fact ⇒ abstain ⇒ unchanged
    }

    func testFactBankDisabledNoOp() {
        let r = req("Q")
        let out = Wiring.applyIfEnabled(to: r, question: "What is the capital of Australia?",
                                        assertedValue: "Sydney", facts: bank, enabled: false)
        XCTAssertEqual(out, r)
    }
}
