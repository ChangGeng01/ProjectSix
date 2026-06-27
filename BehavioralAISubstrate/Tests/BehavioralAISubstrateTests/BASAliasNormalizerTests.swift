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
}
