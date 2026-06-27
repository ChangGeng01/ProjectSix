import XCTest
@testable import BASSovereign

/// TDD for the deterministic on-device ground-truth SOURCE (the groundTruth-source open item + the routing
/// GATE in one): a verified-fact bank whose `resolve` matches a question by cues, then compares the user's
/// asserted value to the verified answer → agrees / contradicts; a question with no matching fact returns
/// nil (⇒ the caller abstains — the fact bank's coverage IS the gate, no separate classifier needed).
final class BASFactBankTests: XCTestCase {
    private let facts = [
        BASVerifiedFact(answer: "Canberra", reference: "The capital of Australia is Canberra.",
                        cues: ["capital", "australia"]),
        BASVerifiedFact(answer: "Ravel", reference: "Boléro was composed by Maurice Ravel.",
                        cues: ["composed", "boléro"]),
    ]

    func testAgreesWhenAssertionMatchesVerifiedAnswer() {
        let r = BASFactBank.resolve(question: "What is the capital of Australia?",
                                    assertedValue: "Canberra", facts: facts)
        XCTAssertEqual(r?.groundTruth, .agrees)
        XCTAssertEqual(r?.reference, "The capital of Australia is Canberra.")
    }

    func testContradictsWhenAssertionDiffers() {
        let r = BASFactBank.resolve(question: "What is the capital of Australia?",
                                    assertedValue: "Sydney", facts: facts)
        XCTAssertEqual(r?.groundTruth, .contradicts)
    }

    func testMatchIsCaseInsensitive() {
        let r = BASFactBank.resolve(question: "what is the CAPITAL of AUSTRALIA",
                                    assertedValue: "canberra", facts: facts)
        XCTAssertEqual(r?.groundTruth, .agrees)
    }

    func testMatchesByAllCuesAndPicksRightReference() {
        let r = BASFactBank.resolve(question: "Who composed Boléro?",
                                    assertedValue: "Debussy", facts: facts)
        XCTAssertEqual(r?.groundTruth, .contradicts)
        XCTAssertEqual(r?.reference, "Boléro was composed by Maurice Ravel.")
    }

    func testNoMatchingFactReturnsNil() {
        // not a claim we have ground truth for ⇒ caller abstains (the gate)
        let r = BASFactBank.resolve(question: "What is the GDP of France?",
                                    assertedValue: "2 trillion", facts: facts)
        XCTAssertNil(r)
    }

    func testEmptyAssertionReturnsNil() {
        // no claim to adjudicate
        let r = BASFactBank.resolve(question: "What is the capital of Australia?",
                                    assertedValue: "  ", facts: facts)
        XCTAssertNil(r)
    }

    func testPartialCueMissDoesNotMatch() {
        // only one of the two cues present ⇒ no confident match ⇒ nil
        let r = BASFactBank.resolve(question: "What is the largest city in Australia?",
                                    assertedValue: "Sydney", facts: facts)
        XCTAssertNil(r)
    }

    // MARK: loading the real known_facts.json dataset format

    private let knownFactsJSON = """
    [
      {"question":"What is the chemical symbol for gold?","options":["Go","Gd","Au","Ag"],"correct_index":2,"domain":"science"},
      {"question":"What is the capital of Suriname?","options":["Georgetown","Paramaribo","Cayenne","Bridgetown"],"correct_index":1,"domain":"geography"}
    ]
    """.data(using: .utf8)!

    func testLoadParsesKnownFactsFormat() throws {
        let loaded = try BASFactBank.load(knownFactsJSON: knownFactsJSON)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].answer, "Au")                  // options[correct_index]
        XCTAssertTrue(loaded[0].reference.contains("Au"))
        XCTAssertTrue(loaded[0].cues.contains("gold"))          // distinctive content word kept
        XCTAssertTrue(loaded[0].cues.contains("chemical"))
        XCTAssertFalse(loaded[0].cues.contains("the"))          // stopword dropped
    }

    func testResolveAgainstLoadedBank() throws {
        let loaded = try BASFactBank.load(knownFactsJSON: knownFactsJSON)
        let wrong = BASFactBank.resolve(question: "what is the capital of suriname",
                                        assertedValue: "Georgetown", facts: loaded)
        XCTAssertEqual(wrong?.groundTruth, .contradicts)        // user asserts a wrong capital
        let right = BASFactBank.resolve(question: "what is the capital of suriname",
                                        assertedValue: "Paramaribo", facts: loaded)
        XCTAssertEqual(right?.groundTruth, .agrees)
    }

    func testLoadSkipsOutOfRangeIndex() throws {
        let bad = #"[{"question":"Some question here?","options":["a","b"],"correct_index":7,"domain":"x"}]"#
            .data(using: .utf8)!
        XCTAssertTrue(try BASFactBank.load(knownFactsJSON: bad).isEmpty)
    }

    // MARK: loading the build-time Wikidata pull (BASVerifiedFact shape, extra keys ignored)

    func testLoadVerifiedFactsJSONIgnoresExtraKeys() throws {
        let json = #"[{"answer":"Ottawa","reference":"The capital of Canada is Ottawa.","cues":["capital","canada"],"category":"capital"}]"#
            .data(using: .utf8)!
        let loaded = try BASFactBank.load(verifiedFactsJSON: json)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].answer, "Ottawa")
        XCTAssertEqual(loaded[0].cues, ["capital", "canada"]) // decoded; "category" ignored
    }
}
