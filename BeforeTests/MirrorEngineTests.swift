import XCTest
@testable import Before

final class MirrorEngineTests: XCTestCase {
    func testHighlightsBoundaryWhenSelfIsShrinking() {
        let result = MirrorEngine.evaluate(
            MirrorInput(
                prompt: "Should I stay in this relationship?",
                emotion: "I feel exhausted and anxious.",
                relationship: "My boundary keeps getting ignored.",
                reality: "We live together.",
                longTerm: "I worry I will keep disappearing inside this.",
                selfLens: "I feel smaller every month."
            )
        )

        XCTAssertEqual(result.nextActionTitle, "Write the boundary")
    }
}
