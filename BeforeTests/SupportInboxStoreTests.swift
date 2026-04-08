import XCTest
@testable import Before

@MainActor
final class SupportInboxStoreTests: XCTestCase {
    func testSeededInboxStartsWithLocalItems() {
        let store = SupportInboxStore()

        XCTAssertEqual(store.requests.count, 3)
        XCTAssertGreaterThan(store.pendingCount, 0)
        XCTAssertTrue(store.activeRequests.allSatisfy { $0.status != .archived })
    }

    func testCreatingAndArchivingSupportRequestsUpdatesCounts() throws {
        let store = SupportInboxStore(seed: false)

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
}
