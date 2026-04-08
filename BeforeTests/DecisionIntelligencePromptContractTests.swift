import XCTest
@testable import Before

final class DecisionIntelligencePromptContractTests: XCTestCase {
    func testSanitizedFallsBackWhenResponseIsEmpty() {
        let value = DecisionIntelligencePromptContract.sanitized(
            " \n ",
            fallback: "Fallback line",
            limit: 40
        )

        XCTAssertEqual(value, "Fallback line")
    }

    func testSanitizedCollapsesWhitespaceAndClips() {
        let value = DecisionIntelligencePromptContract.sanitized(
            "  This   is   a\nvery long      line that should become tighter and eventually clip cleanly. ",
            fallback: "Fallback line",
            limit: 32
        )

        XCTAssertEqual(value, "This is a very long line that sh…")
    }

    func testQuickRefinementPromptIncludesStructuredFields() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: ""
        )

        let base = QuickCheckResult(
            currentPerspective: "You want a little relief.",
            afterPerspective: "It may not feel worth it tomorrow.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let prompt = DecisionIntelligencePromptContract.quickRefinementPrompt(base: base, input: input)

        XCTAssertTrue(prompt.contains("Scenario: \(input.scenario.title)"))
        XCTAssertTrue(prompt.contains("Motivation: \(input.motivation.title)"))
        XCTAssertTrue(prompt.contains("Expected outcome: \(input.expectedOutcome.title)"))
        XCTAssertTrue(prompt.contains("Control level: \(input.controlLevel.title)"))
        XCTAssertTrue(prompt.contains("Optional note: Not provided."))
        XCTAssertTrue(prompt.contains("Current perspective: \(base.currentPerspective)"))
        XCTAssertTrue(prompt.contains("After perspective: \(base.afterPerspective)"))
    }
}
