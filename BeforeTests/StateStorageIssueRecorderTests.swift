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
}
