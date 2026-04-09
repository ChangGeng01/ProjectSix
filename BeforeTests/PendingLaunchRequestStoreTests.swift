import XCTest
@testable import Before

final class PendingLaunchRequestStoreTests: XCTestCase {
    override func tearDown() {
        PendingLaunchRequestStore.clear()
        SharedProtectedStateStore.clearQuarantine(key: "before.pending.launch.request")
        SharedContainer.defaults.removeObject(forKey: "before.pending.launch.request")
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

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

    func testNormalizedQueueDropsLegacyPromptPayloadFromDefaultsData() throws {
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
        XCTAssertNil(queue.first?.prompt)
    }

    func testNormalizedQueueDecodesEnvelopePayloadWithoutPromptInDefaults() throws {
        let now = Date(timeIntervalSince1970: 500)
        let data = """
        [
          {
            "id": "\(UUID().uuidString)",
            "entrySource": "shortcut",
            "preferredModeRaw": "mirror",
            "scenarioRaw": null,
            "requestedAt": \(now.timeIntervalSince1970),
            "expiresAt": \(now.addingTimeInterval(60).timeIntervalSince1970),
            "schemaVersion": 1,
            "hasProtectedPayload": true
          }
        ]
        """.data(using: .utf8)!

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.preferredMode, .mirror)
        XCTAssertNil(queue.first?.prompt)
    }

    func testEnqueueAndConsumeRoundTripUsesSharedProtectedQueueInsteadOfDefaults() {
        PendingLaunchRequestStore.clear()

        let now = Date()
        let request = PendingLaunchRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            entrySource: .shortcut,
            preferredMode: .mirror,
            prompt: "Keep this private.",
            requestedAt: now
        )

        PendingLaunchRequestStore.enqueue(request)

        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNotNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNotNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )
        )

        let restored = PendingLaunchRequestStore.consume()

        XCTAssertEqual(restored?.preferredMode, .mirror)
        XCTAssertEqual(restored?.prompt, "Keep this private.")
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )
        )
    }

    func testExpiredProtectedPayloadIsPurgedWhenQueueIsLoaded() {
        PendingLaunchRequestStore.clear()

        let now = Date()
        let expiredRequest = PendingLaunchRequest(
            id: UUID(uuidString: "FFFFFFFF-1111-2222-3333-444444444444")!,
            entrySource: .shortcut,
            preferredMode: .quick,
            prompt: "Expired sensitive prompt",
            requestedAt: now.addingTimeInterval(-BeforePolicy.LaunchRequests.expirationInterval - 30)
        )

        PendingLaunchRequestStore.enqueue(expiredRequest)

        XCTAssertNotNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.ffffffff-1111-2222-3333-444444444444"
            )
        )

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.ffffffff-1111-2222-3333-444444444444"
            )
        )
    }

    func testConsumePurgesLegacySharedDefaultsQueueWithoutRestoringIt() throws {
        PendingLaunchRequestStore.clear()

        let now = Date(timeIntervalSince1970: 900)
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            preferredMode: .balance,
            prompt: "Legacy sensitive launch prompt",
            requestedAt: now
        )

        let data = try JSONEncoder().encode([request])
        SharedContainer.defaults.set(data, forKey: "before.pending.launch.request")

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
    }

    func testConsumeQuarantinesUnreadableSharedProtectedQueue() {
        PendingLaunchRequestStore.clear()

        let key = "before.pending.launch.request"
        let raw = Data("broken-queue".utf8)
        SharedProtectedStateStore.saveData(raw, key: key)

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: key))
        XCTAssertEqual(SharedProtectedStateStore.quarantinedData(key: key), raw)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }

    func testConsumeRemovesOrphanProtectedPayloads() {
        PendingLaunchRequestStore.clear()

        let orphanKey = "before.pending.launch.request.payload.12345678-1234-1234-1234-1234567890ab"
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("orphan".utf8), key: orphanKey))

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: orphanKey))
    }

    func testUnreadableQueueCleanupRemovesOrphanPayloads() {
        PendingLaunchRequestStore.clear()

        let queueKey = "before.pending.launch.request"
        let orphanKey = "before.pending.launch.request.payload.aaaaaaaa-1234-5678-90ab-aaaaaaaaaaaa"
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("broken-queue".utf8), key: queueKey))
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("orphan".utf8), key: orphanKey))

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: orphanKey))
    }
}
