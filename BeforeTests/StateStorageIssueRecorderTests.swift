import XCTest
@testable import Before

final class StateStorageIssueRecorderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StateStorageIssueRecorder.clear()
        PersistenceIssueRecorder.clear()
    }

    override func tearDown() {
        StateStorageIssueRecorder.clear()
        PersistenceIssueRecorder.clear()
        super.tearDown()
    }

    func testStateStorageIssueRecorderHandlesConcurrentAccess() {
        DispatchQueue.concurrentPerform(iterations: 64) { index in
            let error = NSError(
                domain: "Before.Tests.StateStorage",
                code: index,
                userInfo: [NSLocalizedDescriptionKey: "failure-\(index)"]
            )
            _ = StateStorageIssueRecorder.record(error: error, operation: "recording \(index)")
            _ = StateStorageIssueRecorder.latestNotice()
        }

        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }

    func testPersistenceIssueRecorderHandlesConcurrentAccess() {
        DispatchQueue.concurrentPerform(iterations: 64) { index in
            let error = NSError(
                domain: "Before.Tests.Persistence",
                code: index,
                userInfo: [NSLocalizedDescriptionKey: "failure-\(index)"]
            )
            _ = PersistenceIssueRecorder.record(error: error, operation: "persisting \(index)")
            _ = PersistenceIssueRecorder.latestNotice()
        }

        XCTAssertNotNil(PersistenceIssueRecorder.latestNotice())
    }

    func testStateStorageIssueRecorderRingBufferRetainsLastFive() {
        StateStorageIssueRecorder.clear()

        for index in 0..<7 {
            let error = NSError(
                domain: "Before.Tests.StateStorage.Ring",
                code: index,
                userInfo: [NSLocalizedDescriptionKey: "ring-failure-\(index)"]
            )
            _ = StateStorageIssueRecorder.record(error: error, operation: "ring-op-\(index)")
        }

        let notices = StateStorageIssueRecorder.recentNotices()
        XCTAssertEqual(notices.count, StateStorageIssueRecorder.ringBufferCapacity)

        // Oldest retained is op 2 (since op 0 and op 1 were rotated out).
        XCTAssertTrue(notices.first?.contains("ring-op-2") ?? false, "first retained notice should be op 2, got: \(notices.first ?? "nil")")
        // Newest is op 6.
        XCTAssertTrue(notices.last?.contains("ring-op-6") ?? false, "last retained notice should be op 6, got: \(notices.last ?? "nil")")
        XCTAssertEqual(StateStorageIssueRecorder.latestNotice(), notices.last)
    }

    func testStateStorageIssueRecorderClearEmptiesRingBuffer() {
        StateStorageIssueRecorder.clear()

        let error = NSError(domain: "Before.Tests.StateStorage.Clear", code: 1)
        _ = StateStorageIssueRecorder.record(error: error, operation: "before-clear")
        XCTAssertFalse(StateStorageIssueRecorder.recentNotices().isEmpty)

        StateStorageIssueRecorder.clear()
        XCTAssertTrue(StateStorageIssueRecorder.recentNotices().isEmpty)
        XCTAssertNil(StateStorageIssueRecorder.latestNotice())
    }
}
