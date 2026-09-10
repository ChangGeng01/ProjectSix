import XCTest
@testable import Before

final class PendingReflectionStoreTests: XCTestCase {
    override func tearDown() {
        PendingReflectionStore.clear()
        super.tearDown()
    }

    func testRoundTripPreservesPendingReflectionState() {
        let state = PendingReflectionState(
            context: ReflectionContext(
                id: UUID(),
                eventID: UUID(),
                scenario: .buy,
                finalAction: .wait90s
            ),
            shouldPromptOnNextActive: true
        )

        PendingReflectionStore.save(state)

        XCTAssertEqual(PendingReflectionStore.load(), state)
    }

    func testLoadClearsExpiredPendingReflectionState() {
        let state = PendingReflectionState(
            context: ReflectionContext(
                id: UUID(),
                eventID: UUID(),
                scenario: .buy,
                finalAction: .wait90s
            ),
            shouldPromptOnNextActive: true,
            updatedAt: Date(timeIntervalSince1970: 10)
        )

        PendingReflectionStore.save(state)

        let now = Date(timeIntervalSince1970: 10 + BeforePolicy.RuntimeState.pendingReflectionRetentionInterval + 1)
        let loaded = PendingReflectionStore.load(now: now)

        XCTAssertNil(loaded.context)
        XCTAssertFalse(loaded.shouldPromptOnNextActive)
        XCTAssertNil(ProtectedLocalStateStore.loadData(key: "before.pending.reflection.state"))
    }
}
