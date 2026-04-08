import XCTest
@testable import Before

final class SharedContainerTests: XCTestCase {
    func testResolveUsesFallbackNoticeWhenSuiteCannotBeOpened() {
        let fallback = UserDefaults.standard

        let resolution = SharedContainer.resolve(
            suiteName: "group.example.missing",
            defaultsFactory: { _ in nil },
            fallback: fallback
        )

        XCTAssertTrue(resolution.isUsingFallback)
        XCTAssertEqual(resolution.defaults, fallback)
        XCTAssertNotNil(resolution.notice)
    }
}
