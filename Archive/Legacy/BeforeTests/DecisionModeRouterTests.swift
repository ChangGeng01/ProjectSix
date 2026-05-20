import XCTest
@testable import Before

final class DecisionModeRouterTests: XCTestCase {
    func testRoutesImpulsivePromptToQuick() {
        let route = DecisionModeRouter.route(prompt: "Should I buy these shoes tonight?")
        XCTAssertEqual(route.mode, .quick)
    }

    func testRoutesTradeoffPromptToBalance() {
        let route = DecisionModeRouter.route(prompt: "Which dinner spot should we choose for tonight?")
        XCTAssertEqual(route.mode, .balance)
    }

    func testRoutesHeavierPromptToMirror() {
        let route = DecisionModeRouter.route(prompt: "Should I leave this relationship or keep trying?")
        XCTAssertEqual(route.mode, .mirror)
    }
}
