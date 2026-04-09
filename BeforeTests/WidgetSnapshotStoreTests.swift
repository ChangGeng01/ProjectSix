import XCTest
@testable import Before

final class WidgetSnapshotStoreTests: XCTestCase {
    override func tearDown() {
        WidgetSnapshotStore.clear()
        SharedPublicStateStore.clearQuarantine(key: "before.widget.snapshot")
        SharedContainer.defaults.removeObject(forKey: "before.widget.snapshot")
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testSaveAndLoadRoundTripUsesSharedPublicStorage() {
        WidgetSnapshotStore.clear()

        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Give it room",
                body: "A little distance can change a buying answer."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        WidgetSnapshotStore.save(snapshot)

        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.widget.snapshot"))
        XCTAssertNotNil(SharedPublicStateStore.loadData(key: "before.widget.snapshot"))

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, "Give it room")
        XCTAssertEqual(loaded.messageBody, "A little distance can change a buying answer.")
    }

    func testLoadMigratesLegacyDefaultsSnapshotIntoSharedPublicStorage() throws {
        WidgetSnapshotStore.clear()

        let legacySnapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Unsafe override",
                body: "My private reminder should never appear here."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(legacySnapshot)
        SharedContainer.defaults.set(data, forKey: "before.widget.snapshot")

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, "Give it room")
        XCTAssertEqual(loaded.messageBody, "A little distance can change a buying answer.")
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.widget.snapshot"))
        XCTAssertNotNil(SharedPublicStateStore.loadData(key: "before.widget.snapshot"))
    }

    func testLoadQuarantinesCorruptedSharedPublicSnapshot() {
        WidgetSnapshotStore.clear()

        let key = "before.widget.snapshot"
        let raw = Data("broken-snapshot".utf8)
        SharedPublicStateStore.saveData(raw, key: key)

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, WidgetSnapshot.empty.messageHeadline)
        XCTAssertEqual(loaded.messageBody, WidgetSnapshot.empty.messageBody)
        XCTAssertNil(SharedPublicStateStore.loadData(key: key))
        XCTAssertEqual(SharedPublicStateStore.quarantinedData(key: key), raw)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }
}
