import XCTest
@testable import BASHostKit
@testable import BASSovereign

/// Audit fix: the corpus must actually be BUNDLED (SPM resource via Bundle.module), not just exist in an
/// eval dir — otherwise the fact bank is empty on device and every turn abstains. If Bundle.module resolves
/// it here, it ships in the resource bundle the device app links.
final class BASBundledFactCorpusTests: XCTestCase {

    func testBundledCorpusLoadsRealFacts() {
        let facts = BASBundledFactCorpus.load()
        XCTAssertGreaterThan(facts.count, 1000, "the 1131-fact starter corpus must bundle + load")
        XCTAssertTrue(facts.allSatisfy { !$0.answer.isEmpty && !$0.reference.isEmpty && !$0.cues.isEmpty },
                      "every bundled fact has answer/reference/cues")
    }

    func testBundledCorpusResolvesAKnownFact() {
        // end-to-end: bundled facts feed the substring resolve (no model) for a known capital
        let facts = BASBundledFactCorpus.load()
        let r = BASFactBank.resolve(question: "What is the capital of Australia?",
                                    assertedValue: "Sydney", facts: facts)
        XCTAssertEqual(r?.groundTruth, .contradicts) // user asserts wrong capital
    }
}
