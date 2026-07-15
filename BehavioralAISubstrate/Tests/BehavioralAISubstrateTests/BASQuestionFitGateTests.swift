import XCTest
@testable import BASHostKit

/// tier-0 expansion (2026-07-11, operator-directed): the NLI question-fit gate closes the
/// 完善-round residual — qualifier-differing questions at HIGH cosine short-circuiting to
/// non-sequiturs. The 0.82 breach itself is the first tooth.
final class BASQuestionFitGateTests: XCTestCase {

    func testTheCanberraBreachIsRefused() {
        // 2026-07-04 corpus validation breach: cosine 0.82, answer would be a non-sequitur.
        XCTAssertFalse(BASQuestionFitGate.fits(
            question: "What is the capital of Australia's largest state?",
            reference: "The capital of Australia is Canberra."),
            "'largest'/'state' are restrictions the fact does not address — UNFIT (cosine can't see this)")
    }

    func testPlainCoveredQuestionFits() {
        XCTAssertTrue(BASQuestionFitGate.fits(
            question: "What is the capital of Australia?",
            reference: "The capital of Australia is Canberra."))
    }

    func testPossessiveAndMorphologyNormalize() {
        XCTAssertTrue(BASQuestionFitGate.fits(
            question: "Australia's capital?",
            reference: "The capital of Australia is Canberra."),
            "possessive normalizes: australia's → australia")
        XCTAssertTrue(BASQuestionFitGate.fits(
            question: "How many planets are in the solar system?",
            reference: "There are eight planets in the Solar System."),
            "plural/stem slack: planets/planet family via ≥4-char shared prefix")
    }

    func testExtraReferenceWordsAreFine() {
        XCTAssertTrue(BASQuestionFitGate.fits(
            question: "capital of France?",
            reference: "The capital of France is Paris, a city on the Seine founded centuries ago."),
            "asymmetry: the ANSWER may say more; only the QUESTION's restrictions must be covered")
    }

    func testUnrelatedQualifierRefuses() {
        XCTAssertFalse(BASQuestionFitGate.fits(
            question: "capital of France in 1420?",
            reference: "The capital of France is Paris."),
            "a temporal qualifier the fact does not address must refuse")
    }

    func testEmptyOrStopwordOnlyQuestionRefuses() {
        XCTAssertFalse(BASQuestionFitGate.fits(question: "what is the", reference: "anything"))
        XCTAssertFalse(BASQuestionFitGate.fits(question: "", reference: "anything"))
    }
}
