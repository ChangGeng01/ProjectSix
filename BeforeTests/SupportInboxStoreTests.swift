import XCTest
@testable import Before

@MainActor
final class SupportInboxStoreTests: XCTestCase {
    func testSeededInboxStartsWithLocalItems() {
        let storage = makeIsolatedStorage()
        let store = SupportInboxStore(defaults: storage.defaults, key: storage.key)

        XCTAssertEqual(store.requests.count, 3)
        XCTAssertGreaterThan(store.pendingCount, 0)
        XCTAssertTrue(store.activeRequests.allSatisfy { $0.status != .archived })
    }

    func testCreatingAndArchivingSupportRequestsUpdatesCounts() throws {
        let storage = makeIsolatedStorage()
        let store = SupportInboxStore(defaults: storage.defaults, key: storage.key, seed: false)

        store.create(kind: .helpMeJudgeThis, message: "Help me see the trade-off.")
        let createdID = try XCTUnwrap(store.requests.first?.id)

        XCTAssertEqual(store.pendingCount, 1)
        XCTAssertEqual(store.requests.first?.kind, .helpMeJudgeThis)

        store.markHeard(createdID)

        XCTAssertEqual(store.heardCount, 1)
        XCTAssertEqual(store.requests.first?.status, .heard)

        store.archive(createdID)

        XCTAssertEqual(store.archivedCount, 1)
        XCTAssertTrue(store.activeRequests.isEmpty)
    }

    func testRequestsPersistAcrossStoreInstances() {
        let storage = makeIsolatedStorage()
        let first = SupportInboxStore(defaults: storage.defaults, key: storage.key, seed: false)
        first.create(kind: .holdMe10Minutes, message: "Stay with me for a moment.")

        let second = SupportInboxStore(defaults: storage.defaults, key: storage.key, seed: false)

        XCTAssertEqual(second.requests.count, 1)
        XCTAssertEqual(second.requests.first?.kind, .holdMe10Minutes)
        XCTAssertEqual(second.requests.first?.message, "Stay with me for a moment.")
    }

    func testClearAllResetsToSeedStateChoice() {
        let storage = makeIsolatedStorage()
        let store = SupportInboxStore(defaults: storage.defaults, key: storage.key, seed: false)
        store.create(kind: .iAmGettingBlurry, message: "I need a clearer read.")

        store.clearAll()

        XCTAssertTrue(store.requests.isEmpty)
    }

    private func makeIsolatedStorage() -> (defaults: UserDefaults, key: String) {
        let key = "before.tests.support.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: key)!
        defaults.removePersistentDomain(forName: key)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: key)
        }
        return (defaults, key)
    }
}
