import XCTest
@testable import Before

final class QuickBufferDurationTests: XCTestCase {
    func testDefaultPreferencesUseNinetySecondBuffer() {
        XCTAssertEqual(BeforePreferences.default.quickBufferDuration, .ninetySeconds)
        XCTAssertEqual(CheckAction.wait90s.title(using: .ninetySeconds), "Wait 90 seconds")
    }

    func testWaitActionUsesConfiguredBufferTitle() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .fiveMinutes,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true
        )

        XCTAssertEqual(CheckAction.wait90s.title(using: preferences.quickBufferDuration), "Wait 5 minutes")
        XCTAssertEqual(preferences.quickBufferDuration.notificationTitle, "5 minutes are up")
    }
}
