import XCTest
@testable import BASSovereign

/// TDD for the alias-aware verify — the cheap fix for the WORST failure (false-.contradicts gaslighting a
/// correct user). No model: synonym/format equivalence normalized before comparing.
final class BASAliasNormalizerTests: XCTestCase {
    private let a = BASAliasNormalizer.common

    func testSynonymsAgreeNotContradict() {
        XCTAssertEqual(a.decide(answer: "United States", claim: "the USA"), .agrees)   // the headline fix
        XCTAssertEqual(a.decide(answer: "UK", claim: "Britain"), .agrees)
        XCTAssertEqual(a.decide(answer: "Netherlands", claim: "Holland"), .agrees)
    }

    func testGenuineDifferenceStillContradicts() {
        XCTAssertEqual(a.decide(answer: "Canberra", claim: "Sydney"), .contradicts)
        XCTAssertEqual(a.decide(answer: "United States", claim: "Canada"), .contradicts)
    }

    func testExactMatchToleratesCaseAndPunctuation() {
        XCTAssertEqual(a.decide(answer: "Canberra", claim: "canberra."), .agrees)
        XCTAssertEqual(a.decide(answer: "Canberra", claim: "  Canberra  "), .agrees)
    }

    func testContainmentAgrees() {
        XCTAssertEqual(a.decide(answer: "United States", claim: "the United States of America"), .agrees)
    }

    func testNormalizeMapsAliasToCanonical() {
        XCTAssertEqual(a.normalize("U.S.A."), "united states")
        XCTAssertEqual(a.normalize("the UK"), "united kingdom")
    }

    func testEmptyClaimContradicts() {
        XCTAssertEqual(a.decide(answer: "Canberra", claim: ""), .contradicts)
    }

    // MARK: audit 2026-06-28 — char-substring false-AFFIRM regression guard (anti-sycophancy must not invert)

    func testShortTokenSubstringDoesNotFalseAffirm() {
        XCTAssertEqual(a.decide(answer: "18", claim: "8"), .contradicts)        // atomic-number facts
        XCTAssertEqual(a.decide(answer: "74", claim: "742"), .contradicts)
        XCTAssertEqual(a.decide(answer: "Australia", claim: "Au"), .contradicts) // symbol vs country
        XCTAssertEqual(a.decide(answer: "Ca", claim: "C"), .contradicts)        // symbol facts
        XCTAssertEqual(a.decide(answer: "Nigeria", claim: "Niger"), .contradicts)
    }

    func testMultiWordContiguousContainmentStillAgrees() {
        // ≥2-token contiguous run is still allowed (the legitimate containment case)
        XCTAssertEqual(a.decide(answer: "United States of America", claim: "United States"), .agrees)
    }

    func testNumericWordEquivalenceAgrees() {
        // closes the numeric gaslight surface on the atomic-number facts (deterministic, not NLI)
        XCTAssertEqual(a.decide(answer: "8", claim: "eight"), .agrees)
        XCTAssertEqual(a.decide(answer: "2", claim: "second"), .agrees)
        XCTAssertEqual(a.decide(answer: "2", claim: "2nd"), .agrees)
        XCTAssertEqual(a.decide(answer: "74", claim: "74"), .agrees)
        // genuine numeric difference still contradicts
        XCTAssertEqual(a.decide(answer: "8", claim: "nine"), .contradicts)
    }

    func testAddedCurrentNameAliases() {
        XCTAssertEqual(a.decide(answer: "Mumbai", claim: "Bombay"), .agrees)
        XCTAssertEqual(a.decide(answer: "Myanmar", claim: "Burma"), .agrees)
    }
}
