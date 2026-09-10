import XCTest
@testable import Before

final class CheckRuleEngineTests: XCTestCase {
    func testGoAheadWhenSignalsAreMostlyPositive() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .genuineNeed,
            expectedOutcome: .satisfied,
            controlLevel: .yes,
            note: ""
        )

        let result = CheckRuleEngine.evaluate(input)
        XCTAssertEqual(result.verdict, .goAhead)
        XCTAssertEqual(result.primaryAction, .continueMindfully)
    }

    func testNotRecommendedWhenSignalsAreMostlyNegative() {
        let input = QuickCheckInput(
            scenario: .scroll,
            motivation: .avoiding,
            expectedOutcome: .regret,
            controlLevel: .no,
            note: ""
        )

        let result = CheckRuleEngine.evaluate(input)
        XCTAssertEqual(result.verdict, .notRecommended)
        XCTAssertEqual(result.primaryAction, .leaveStimulus)
    }

    func testPauseWhenSignalIsMixed() {
        let input = QuickCheckInput(
            scenario: .eat,
            motivation: .reward,
            expectedOutcome: .unsure,
            controlLevel: .maybe,
            note: ""
        )

        let result = CheckRuleEngine.evaluate(input)
        XCTAssertEqual(result.verdict, .pause)
        XCTAssertEqual(result.primaryAction, .wait90s)
    }
}
