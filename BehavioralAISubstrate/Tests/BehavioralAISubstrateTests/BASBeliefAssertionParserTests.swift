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

    // MARK: audit 2026-06-28 — over-capture / negation regression guards (false-.contradicts gaslight)

    func testNegatedCaptureAbstains() {
        // "The answer is not Sydney" must NOT extract "Sydney" as the belief (it's a denial)
        XCTAssertNil(P.assertedValue(in: "The answer is not Sydney."))
    }

    func testClauseBoundaryTruncatesCapture() {
        // "the US my friend agreed" must truncate at "my" → "the US" (so the alias table still resolves US)
        XCTAssertEqual(P.assertedValue(in: "I'm sure it's the US my friend agreed"), "the US")
    }

    func testClauseBoundaryTruncatesAtConjunction() {
        // captures "Mars and Venus" (within the 40-char bound) → truncate at "and" → "Mars"
        XCTAssertEqual(P.assertedValue(in: "The answer is Mars and Venus."), "Mars")
    }

    func testLeadingHedgeAdverbsStripped() {
        // audit #2: "definitely Canberra" survived as a 2-token claim → false-.contradicts a correct user
        XCTAssertEqual(P.assertedValue(in: "I think it's definitely Canberra."), "Canberra")
        XCTAssertEqual(P.assertedValue(in: "The answer is actually Tokyo."), "Tokyo")
        XCTAssertEqual(P.assertedValue(in: "It's probably Jupiter, right?"), "Jupiter")
    }

    // MARK: - Reported / third-party speech (audit 2026-06-29): abstain, never resist a RIGHT user

    func testReportedSpeechAbstains() {
        // The friend's WRONG claim ("Sydney") must NOT be extracted as the user's belief — the user is RIGHT
        // (Canberra). Extracting "Sydney" here previously injected "do not cave" against a correct user.
        XCTAssertNil(P.assertedValue(in: "What is the capital of Australia? My friend says the answer is Sydney, but he's wrong, it's Canberra."))
    }

    func testSaysAttributionAbstains() {
        XCTAssertNil(P.assertedValue(in: "He says it's Sydney, right?"))
        XCTAssertNil(P.assertedValue(in: "She claims the answer is Pluto."))
    }

    func testAccordingToAndHearsayAbstain() {
        XCTAssertNil(P.assertedValue(in: "According to my teacher the answer is Pluto."))
        XCTAssertNil(P.assertedValue(in: "They say it's Mercury, right?"))
        XCTAssertNil(P.assertedValue(in: "I heard it's Venus."))
    }

    func testFirstPersonStillExtractsAfterReportedSpeechGuard() {
        // No regression: genuine first-person assertion frames still extract (the markers don't appear in them).
        XCTAssertEqual(P.assertedValue(in: "I'm pretty sure it's Sydney, right?"), "Sydney")
        XCTAssertEqual(P.assertedValue(in: "I think it's Saturn."), "Saturn")
        XCTAssertEqual(P.assertedValue(in: "The answer is Paris."), "Paris")
    }
}
