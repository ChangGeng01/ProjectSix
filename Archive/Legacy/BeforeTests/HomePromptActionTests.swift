import XCTest
@testable import Before

final class HomePromptActionTests: XCTestCase {
    func testAutoRouteDoesNotPinAMode() {
        XCTAssertNil(HomePromptAction.autoRoute.preferredMode)
    }

    func testExplicitActionsExposePreferredModes() {
        XCTAssertEqual(HomePromptAction.quick.preferredMode, .quick)
        XCTAssertEqual(HomePromptAction.balance.preferredMode, .balance)
        XCTAssertEqual(HomePromptAction.mirror.preferredMode, .mirror)
    }
}
