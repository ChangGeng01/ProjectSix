import XCTest
@testable import Before

final class CodableStateStorageTests: XCTestCase {
    private struct ThrowingEncodable: Encodable {
        struct EncodingFailure: Error {}

        func encode(to encoder: any Encoder) throws {
            throw EncodingFailure()
        }
    }

    override func setUp() {
        super.setUp()
        StateStorageIssueRecorder.clear()
    }

    override func tearDown() {
        StateStorageIssueRecorder.clear()
        ProtectedLocalStateStore.clear(key: "codable.state.storage.failure")
        ProtectedLocalStateStore.clear(key: "codable/state/storage/invalid")
        super.tearDown()
    }

    func testProtectedLocalStorageRecordsEncodingFailure() {
        let saved = CodableStateStorage.protectedLocal.save(
            ThrowingEncodable(),
            key: "codable.state.storage.failure"
        )

        XCTAssertFalse(saved)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
        XCTAssertNil(ProtectedLocalStateStore.loadData(key: "codable.state.storage.failure"))
    }

    func testProtectedLocalStorageRecordsFilesystemFailure() {
        let saved = ProtectedLocalStateStore.saveData(
            Data("payload".utf8),
            key: "codable/state/storage/invalid"
        )

        XCTAssertFalse(saved)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
        XCTAssertNil(ProtectedLocalStateStore.loadData(key: "codable/state/storage/invalid"))
    }
}
