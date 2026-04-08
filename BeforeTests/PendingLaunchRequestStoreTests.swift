import XCTest
@testable import Before

final class PendingLaunchRequestStoreTests: XCTestCase {
    func testNormalizedQueueDropsExpiredRequests() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let fresh = PendingLaunchRequest(
            entrySource: .app,
            requestedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )
        let expired = PendingLaunchRequest(
            entrySource: .shortcut,
            requestedAt: now.addingTimeInterval(-500),
            expiresAt: now.addingTimeInterval(-1)
        )
        let data = try JSONEncoder().encode([expired, fresh])

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue, [fresh])
    }

    func testNormalizedQueueDecodesLegacySingleRequestPayload() throws {
        let data = """
        {
          "entrySource": "shortcut",
          "requestedAt": 0
        }
        """.data(using: .utf8)!

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: Date(timeIntervalSince1970: 60))

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.entrySource, .shortcut)
    }

    func testPendingLaunchRequestPreservesModeAndPrompt() throws {
        let now = Date(timeIntervalSince1970: 500)
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            preferredMode: .mirror,
            prompt: "Should I leave this relationship?",
            requestedAt: now
        )

        let data = try JSONEncoder().encode([request])
        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue.first?.preferredMode, .mirror)
        XCTAssertEqual(queue.first?.prompt, "Should I leave this relationship?")
    }
}
