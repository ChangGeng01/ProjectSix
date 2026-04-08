import XCTest
@testable import Before

final class BeforePreferencesStoreTests: XCTestCase {
    private let key = "before.preferences"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testLoadReturnsDefaultWhenNothingSaved() {
        XCTAssertEqual(BeforePreferencesStore.load(), .default)
    }

    func testSaveAndLoadRoundTrip() {
        let preferences = BeforePreferences(
            homePromptAction: .balance,
            restoreInProgressWorkspaces: false,
            showReviewInsights: false
        )

        BeforePreferencesStore.save(preferences)

        XCTAssertEqual(BeforePreferencesStore.load(), preferences)
    }
}
