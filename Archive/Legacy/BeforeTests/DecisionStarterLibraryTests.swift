import XCTest
@testable import Before

final class DecisionStarterLibraryTests: XCTestCase {
    func testEachModeHasThreeStarterPrompts() {
        XCTAssertEqual(DecisionStarterLibrary.suggestions(for: .quick).count, 3)
        XCTAssertEqual(DecisionStarterLibrary.suggestions(for: .balance).count, 3)
        XCTAssertEqual(DecisionStarterLibrary.suggestions(for: .mirror).count, 3)
    }

    func testHomeFeaturedCoversAllModes() {
        let modes = DecisionStarterLibrary.homeFeatured.map(\.mode)
        XCTAssertEqual(modes, [.quick, .balance, .mirror])
    }
}
