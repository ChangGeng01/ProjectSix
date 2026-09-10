import XCTest
@testable import QinaoLoop

/// M555-M560 (chapter 一百三十八) — pin
/// QinaoSyntheticUserSimulator persona/scenario catalog +
/// aggregator behavior.
final class SyntheticUserSimulatorTests: XCTestCase {

    // MARK: - 1. Persona enum cardinality

    func testPersonaCardinality() {
        XCTAssertEqual(
            QinaoSyntheticUserPersona.allCases.count, 5,
            "5 personas per Appendix Q.2.4 design")
    }

    // MARK: - 2. Persona raw values stable

    func testPersonaRawValuesStable() {
        let rawValues = Set(
            QinaoSyntheticUserPersona.allCases.map(
                \.rawValue))
        XCTAssertEqual(
            rawValues,
            ["anxious", "authoritative", "vulnerable",
             "agentic", "confused"],
            "stable kebab-case raw values")
    }

    // MARK: - 3. Scenario enum cardinality

    func testScenarioCardinality() {
        XCTAssertEqual(
            QinaoSyntheticUserScenario.allCases.count, 3,
            "3 scenarios per Appendix Q.2.4 design")
    }

    // MARK: - 4. All 15 (persona, scenario) prompts non-empty

    func testAllPromptsAreNonEmpty() {
        for persona in QinaoSyntheticUserPersona.allCases {
            for scenario in QinaoSyntheticUserScenario.allCases {
                let prompt = QinaoSyntheticPromptCatalog.prompt(
                    persona: persona,
                    scenario: scenario)
                XCTAssertFalse(
                    prompt.isEmpty,
                    "prompt for \(persona.rawValue)/\(scenario.rawValue) MUST be non-empty")
                XCTAssertGreaterThan(
                    prompt.count, 30,
                    "prompt MUST be substantive (> 30 chars)")
            }
        }
    }

    // MARK: - 5. allPrompts returns 15 entries

    func testAllPromptsReturns15() {
        XCTAssertEqual(
            QinaoSyntheticPromptCatalog.allPrompts.count, 15,
            "5 personas × 3 scenarios = 15 prompts")
    }

    // MARK: - 6. Distinct prompts (no duplication)

    func testAllPromptsAreDistinct() {
        let prompts = QinaoSyntheticPromptCatalog.allPrompts
            .map(\.prompt)
        let uniquePrompts = Set(prompts)
        XCTAssertEqual(
            prompts.count, uniquePrompts.count,
            "all 15 prompts MUST be distinct (no copy-paste)")
    }

    // MARK: - 7. Aggregator empty case

    func testAggregatorEmpty() {
        let result = QinaoSyntheticUserAggregator.aggregate(
            sessions: [],
            expectedPrefixes: ["kunlun", "cthulhu"])
        XCTAssertEqual(result.totalCodeCount, 0)
        XCTAssertEqual(result.sessionCount, 0)
        XCTAssertEqual(
            Set(result.unfiredPrefixes),
            ["kunlun", "cthulhu"],
            "all expected prefixes unfired when sessions empty")
    }

    // MARK: - 8. Aggregator counts per prefix

    func testAggregatorCountsPerPrefix() {
        let session1 = [
            "kunlun.axis.center:0.85",
            "kunlun.l4.ascent:wellformed",
            "cthulhu.organ.alias:counterfactual-forge",
            "permit:answer",
        ]
        let session2 = [
            "kunlun.axis.center:0.75",
            "permit:compare",
            "risk:high",
        ]
        let result = QinaoSyntheticUserAggregator.aggregate(
            sessions: [session1, session2],
            expectedPrefixes: [
                "kunlun", "cthulhu", "permit", "risk",
                "lifecycle",  // never fires
            ])
        XCTAssertEqual(result.totalCodeCount, 7)
        XCTAssertEqual(result.sessionCount, 2)
        XCTAssertEqual(result.prefixCounts["kunlun"], 3)
        XCTAssertEqual(result.prefixCounts["cthulhu"], 1)
        XCTAssertEqual(result.prefixCounts["permit"], 2)
        XCTAssertEqual(result.prefixCounts["risk"], 1)
        XCTAssertEqual(
            result.unfiredPrefixes, ["lifecycle"],
            "lifecycle prefix MUST be flagged as unfired")
    }

    // MARK: - 9. Aggregator detects all-fired case

    func testAggregatorDetectsAllFired() {
        let session = [
            "kunlun.x", "cthulhu.y", "permit:answer",
        ]
        let result = QinaoSyntheticUserAggregator.aggregate(
            sessions: [session],
            expectedPrefixes: [
                "kunlun", "cthulhu", "permit",
            ])
        XCTAssertTrue(
            result.unfiredPrefixes.isEmpty,
            "all expected prefixes fired → unfiredPrefixes empty")
    }

    // MARK: - 10. Persona description coverage

    func testEachPersonaHasDescription() {
        for persona in QinaoSyntheticUserPersona.allCases {
            XCTAssertFalse(
                persona.description.isEmpty,
                "\(persona.rawValue) MUST have non-empty description")
        }
    }
}
