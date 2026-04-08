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
            quickBufferDuration: .tenMinutes,
            restoreInProgressWorkspaces: false,
            showReviewInsights: false,
            onDeviceIntelligenceMode: .off,
            preferredIntelligenceProvider: .foundationModels,
            allowModelFallbacks: false
        )

        BeforePreferencesStore.save(preferences)

        XCTAssertEqual(BeforePreferencesStore.load(), preferences)
    }

    func testLoadMigratesMissingIntelligenceModeToDefault() throws {
        let legacyData = """
        {
          "homePromptAction": "quick",
          "quickBufferDuration": "fiveMinutes",
          "restoreInProgressWorkspaces": false,
          "showReviewInsights": true
        }
        """.data(using: .utf8)!

        UserDefaults.standard.set(legacyData, forKey: key)

        let loaded = BeforePreferencesStore.load()

        XCTAssertEqual(loaded.homePromptAction, .quick)
        XCTAssertEqual(loaded.quickBufferDuration, .fiveMinutes)
        XCTAssertEqual(loaded.restoreInProgressWorkspaces, false)
        XCTAssertEqual(loaded.showReviewInsights, true)
        XCTAssertEqual(loaded.onDeviceIntelligenceMode, .assistive)
        XCTAssertEqual(loaded.preferredIntelligenceProvider, .gemmaE4B)
        XCTAssertEqual(loaded.allowModelFallbacks, true)
    }
}
