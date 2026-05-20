import XCTest
@testable import Before

final class BalanceBoardEngineTests: XCTestCase {
    func testHighlightsRealityWhenConcreteConstraintExists() {
        let result = BalanceBoardEngine.evaluate(
            BalanceBoardInput(
                prompt: "Should I book this trip?",
                desire: "I want the break.",
                concern: "I do not want to overspend.",
                constraint: "My budget is tight this month.",
                longTerm: "I do not want debt hanging over me."
            )
        )

        XCTAssertEqual(result.focusTitle, "Let reality lead first")
    }
}
