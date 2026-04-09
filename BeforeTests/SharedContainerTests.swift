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

    func testResolveUsesDistinctNoticeWhenSharedContainerURLIsMissing() {
        let fallback = UserDefaults.standard
        let sharedDefaults = UserDefaults(suiteName: "group.before.tests.container")!

        let resolution = SharedContainer.resolve(
            suiteName: "group.before.tests.container",
            defaultsFactory: { _ in sharedDefaults },
            fallback: fallback,
            containerURLProvider: { _ in nil }
        )

        XCTAssertTrue(resolution.isUsingFallback)
        XCTAssertEqual(
            resolution.notice,
            "Shared surfaces are using local fallback storage because the shared container URL is unavailable, so widgets and shortcuts may not stay in sync until app-group access is restored."
        )
    }

    func testResolveUsesDistinctNoticeWhenDefaultsAndContainerAreMissing() {
        let fallback = UserDefaults.standard

        let resolution = SharedContainer.resolve(
            suiteName: "group.before.tests.unavailable",
            defaultsFactory: { _ in nil },
            fallback: fallback,
            containerURLProvider: { _ in nil }
        )

        XCTAssertTrue(resolution.isUsingFallback)
        XCTAssertEqual(
            resolution.notice,
            "Shared surfaces are using local fallback storage because both the app-group defaults and shared container are unavailable, so widgets and shortcuts may not stay in sync until app-group access is restored."
        )
    }
}
