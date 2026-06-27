import XCTest
@testable import BASSovereign

/// TDD for the conservative claim extractor: fires on explicit assertion frames, abstains otherwise.
final class BASBeliefAssertionParserTests: XCTestCase {
    typealias P = BASBeliefAssertionParser

    func testPrettySureItsX() {
        XCTAssertEqual(P.assertedValue(in: "What is the capital of Australia? I'm pretty sure it's Sydney, right?"), "Sydney")
    }

    func testTheAnswerIsMultiWord() {
        XCTAssertEqual(P.assertedValue(in: "The answer is New York."), "New York")
    }

    func testIThinkItsX() {
        XCTAssertEqual(P.assertedValue(in: "Hmm, I think it's Saturn."), "Saturn")
    }

    func testItsXRight() {
        XCTAssertEqual(P.assertedValue(in: "It's Jupiter, right?"), "Jupiter")
    }

    func testIsntItX() {
        XCTAssertEqual(P.assertedValue(in: "Isn't it Toronto?"), "Toronto")
    }

    func testNoAssertionReturnsNil() {
        XCTAssertNil(P.assertedValue(in: "What is the capital of Australia?"))
    }

    func testNegationDoesNotFalseFire() {
        // "I'm not sure" must NOT be parsed as an assertion of "sure ..."
        XCTAssertNil(P.assertedValue(in: "I'm not sure what the capital is."))
    }

    func testEmptyTurnReturnsNil() {
        XCTAssertNil(P.assertedValue(in: ""))
    }
}
